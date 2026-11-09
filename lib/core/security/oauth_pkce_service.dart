import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../constants/provider_presets.dart';
import '../error/failures.dart';
import '../logging/sanitized_logger.dart';
import 'secure_storage_service.dart';

class OAuthProviderConfig {
  const OAuthProviderConfig({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.scopes,
    required this.extraAuthParams,
  });

  final String authorizationEndpoint;
  final String tokenEndpoint;
  final List<String> scopes;
  final Map<String, String> extraAuthParams;

  static const OAuthProviderConfig gmail = OAuthProviderConfig(
    authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenEndpoint: 'https://oauth2.googleapis.com/token',
    scopes: [
      'https://mail.google.com/',
      'openid',
      'email',
    ],
    extraAuthParams: {
      'access_type': 'offline',
      'prompt': 'consent',
    },
  );

  static const OAuthProviderConfig outlook = OAuthProviderConfig(
    authorizationEndpoint:
        'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
    tokenEndpoint:
        'https://login.microsoftonline.com/common/oauth2/v2.0/token',
    scopes: [
      'https://outlook.office.com/IMAP.AccessAsUser.All',
      'https://outlook.office.com/SMTP.Send',
      'offline_access',
      'openid',
      'email',
    ],
    extraAuthParams: {
      'prompt': 'select_account',
    },
  );

  static OAuthProviderConfig forProvider(MailProviderType type) {
    return switch (type) {
      MailProviderType.gmail => gmail,
      MailProviderType.outlook => outlook,
      _ => throw UnsupportedError('OAuth2 is not preconfigured for $type'),
    };
  }
}

/// Pure-local OAuth 2.0 Authorization Code + PKCE (S256) client.
///
/// Zero custom backend:
/// - Desktop (macOS / Windows): ephemeral localhost loopback HTTP callback + system browser.
/// - Mobile (iOS / Android): ASWebAuthenticationSession / Chrome Auth Tab via custom scheme.
class OAuthPkceService {
  OAuthPkceService({
    http.Client? httpClient,
    SanitizedLogger? logger,
  })  : _httpClient = httpClient ?? http.Client(),
        _logger = logger ?? SanitizedLogger.instance;

  static const String mobileCallbackScheme = 'com.localmail.client';
  static const String mobileRedirectUri = '$mobileCallbackScheme:/oauth2redirect';

  /// Optional compile-time overrides via `--dart-define`.
  static const String defaultGmailClientId =
      String.fromEnvironment('GMAIL_OAUTH_CLIENT_ID');
  static const String defaultOutlookClientId =
      String.fromEnvironment('OUTLOOK_OAUTH_CLIENT_ID');

  final http.Client _httpClient;
  final SanitizedLogger _logger;

  static String? defaultClientIdFor(MailProviderType provider) {
    return switch (provider) {
      MailProviderType.gmail =>
        defaultGmailClientId.isEmpty ? null : defaultGmailClientId,
      MailProviderType.outlook =>
        defaultOutlookClientId.isEmpty ? null : defaultOutlookClientId,
      _ => null,
    };
  }

  /// Launches the interactive PKCE browser flow and exchanges code for tokens.
  Future<OAuthTokenBundle> authorize({
    required MailProviderType providerType,
    required String clientId,
    String? loginHintEmail,
  }) async {
    final trimmedClientId = clientId.trim();
    if (trimmedClientId.isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.oauthRequired,
        userMessage: '请先填写 OAuth 2.0 客户端 ID（Client ID）后再进行授权登录。',
      );
    }

    final config = OAuthProviderConfig.forProvider(providerType);
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _deriveCodeChallenge(codeVerifier);
    final state = _generateRandomUrlSafe(24);

    final useDesktopLoopback =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

    if (useDesktopLoopback) {
      return _authorizeViaDesktopLoopback(
        config: config,
        clientId: trimmedClientId,
        codeVerifier: codeVerifier,
        codeChallenge: codeChallenge,
        state: state,
        loginHintEmail: loginHintEmail,
      );
    }

    return _authorizeViaMobileWebAuth(
      config: config,
      clientId: trimmedClientId,
      codeVerifier: codeVerifier,
      codeChallenge: codeChallenge,
      state: state,
      loginHintEmail: loginHintEmail,
    );
  }

  Future<OAuthTokenBundle> _authorizeViaDesktopLoopback({
    required OAuthProviderConfig config,
    required String clientId,
    required String codeVerifier,
    required String codeChallenge,
    required String state,
    String? loginHintEmail,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}/oauth2redirect';
    final callbackCompleter = Completer<Uri>();

    final subscription = server.listen((HttpRequest request) async {
      final uri = request.requestedUri;
      if (uri.path == '/oauth2redirect') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write(
            '<!DOCTYPE html><html><meta charset="utf-8">'
            '<body style="font-family:-apple-system,sans-serif;text-align:center;padding:48px;">'
            '<h2>授权已完成</h2><p>您可以关闭此浏览器标签页并返回邮箱客户端。</p>'
            '</body></html>',
          );
        await request.response.close();
        if (!callbackCompleter.isCompleted) {
          callbackCompleter.complete(uri);
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });

    try {
      final authUri = _buildAuthUri(
        config: config,
        clientId: clientId,
        redirectUri: redirectUri,
        codeChallenge: codeChallenge,
        state: state,
        loginHintEmail: loginHintEmail,
      );

      final launched = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AuthFailure(
          reason: AuthFailureReason.unknown,
          userMessage: '无法打开系统浏览器完成 OAuth 授权。',
        );
      }

      final callbackUri = await callbackCompleter.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw const AuthFailure(
          reason: AuthFailureReason.oauthCancelled,
          userMessage: 'OAuth 授权超时，请重试。',
        ),
      );

      return await _handleCallbackAndExchange(
        callbackUri: callbackUri,
        expectedState: state,
        config: config,
        clientId: clientId,
        redirectUri: redirectUri,
        codeVerifier: codeVerifier,
      );
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  }

  Future<OAuthTokenBundle> _authorizeViaMobileWebAuth({
    required OAuthProviderConfig config,
    required String clientId,
    required String codeVerifier,
    required String codeChallenge,
    required String state,
    String? loginHintEmail,
  }) async {
    final authUri = _buildAuthUri(
      config: config,
      clientId: clientId,
      redirectUri: mobileRedirectUri,
      codeChallenge: codeChallenge,
      state: state,
      loginHintEmail: loginHintEmail,
    );

    final String resultUrl;
    try {
      resultUrl = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: mobileCallbackScheme,
      );
    } catch (e) {
      throw AuthFailure(
        reason: AuthFailureReason.oauthCancelled,
        userMessage: 'OAuth 授权已取消或失败。',
        technicalDetail: e.toString(),
        cause: e,
      );
    }

    return _handleCallbackAndExchange(
      callbackUri: Uri.parse(resultUrl),
      expectedState: state,
      config: config,
      clientId: clientId,
      redirectUri: mobileRedirectUri,
      codeVerifier: codeVerifier,
    );
  }

  Uri _buildAuthUri({
    required OAuthProviderConfig config,
    required String clientId,
    required String redirectUri,
    required String codeChallenge,
    required String state,
    String? loginHintEmail,
  }) {
    final params = <String, String>{
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': config.scopes.join(' '),
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'state': state,
      ...config.extraAuthParams,
      if (loginHintEmail != null && loginHintEmail.trim().isNotEmpty)
        'login_hint': loginHintEmail.trim(),
    };
    return Uri.parse(config.authorizationEndpoint).replace(queryParameters: params);
  }

  Future<OAuthTokenBundle> _handleCallbackAndExchange({
    required Uri callbackUri,
    required String expectedState,
    required OAuthProviderConfig config,
    required String clientId,
    required String redirectUri,
    required String codeVerifier,
  }) async {
    final error = callbackUri.queryParameters['error'];
    if (error != null) {
      final desc = callbackUri.queryParameters['error_description'] ?? error;
      throw AuthFailure(
        reason: error == 'access_denied'
            ? AuthFailureReason.oauthCancelled
            : AuthFailureReason.unknown,
        userMessage: 'OAuth 授权被拒绝或失败：$desc',
        technicalDetail: desc,
      );
    }

    final returnedState = callbackUri.queryParameters['state'];
    if (returnedState != expectedState) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'OAuth 状态校验失败，请重新尝试授权。',
      );
    }

    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: '未从授权回调中获取到授权码（code）。',
      );
    }

    final response = await _httpClient.post(
      Uri.parse(config.tokenEndpoint),
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logger.warn(
        'OAuthPkce',
        'Token exchange HTTP ${response.statusCode}: ${response.body}',
      );
      throw AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: '换取 OAuth 访问令牌失败（HTTP ${response.statusCode}）。',
        technicalDetail: SanitizedLogger.sanitize(response.body),
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    return OAuthTokenBundle(
      accessToken: (json['access_token'] as String?) ?? '',
      refreshToken: json['refresh_token'] as String?,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      clientId: clientId,
      tokenEndpoint: config.tokenEndpoint,
      scopes: config.scopes,
    );
  }

  /// Refreshes an expired [OAuthTokenBundle] directly against the provider token endpoint.
  Future<OAuthTokenBundle> refreshToken(OAuthTokenBundle current) async {
    final refreshToken = current.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.oauthTokenExpired,
        userMessage: 'OAuth 刷新令牌缺失或已失效，请重新授权登录。',
      );
    }

    final response = await _httpClient.post(
      Uri.parse(current.tokenEndpoint),
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': current.clientId,
        'refresh_token': refreshToken,
        'scope': current.scopes.join(' '),
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logger.warn(
        'OAuthPkce',
        'Token refresh HTTP ${response.statusCode}: ${response.body}',
      );
      throw AuthFailure(
        reason: AuthFailureReason.oauthTokenExpired,
        userMessage: 'OAuth 授权已过期，请重新登录该邮箱账户。',
        technicalDetail: SanitizedLogger.sanitize(response.body),
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    return OAuthTokenBundle(
      accessToken: (json['access_token'] as String?) ?? '',
      refreshToken: (json['refresh_token'] as String?) ?? refreshToken,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      clientId: current.clientId,
      tokenEndpoint: current.tokenEndpoint,
      scopes: current.scopes,
    );
  }

  static String _generateCodeVerifier() => _generateRandomUrlSafe(64);

  static String _deriveCodeChallenge(String verifier) {
    final digest = sha256.convert(ascii.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static String _generateRandomUrlSafe(int length) {
    final rng = Random.secure();
    final bytes = List<int>.generate(length, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
