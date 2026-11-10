import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    required this.desktopLoopbackHost,
  });

  final String authorizationEndpoint;
  final String tokenEndpoint;
  final List<String> scopes;
  final Map<String, String> extraAuthParams;

  /// Google recommends the IP literal; Microsoft matches loopback by host and
  /// path and the portal only accepts `localhost` for http loopback URIs.
  final String desktopLoopbackHost;

  static const OAuthProviderConfig gmail = OAuthProviderConfig(
    authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenEndpoint: 'https://oauth2.googleapis.com/token',
    scopes: ['https://mail.google.com/', 'openid', 'email'],
    extraAuthParams: {'access_type': 'offline', 'prompt': 'consent'},
    desktopLoopbackHost: '127.0.0.1',
  );

  static const OAuthProviderConfig outlook = OAuthProviderConfig(
    authorizationEndpoint:
        'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
    tokenEndpoint: 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
    scopes: [
      'https://outlook.office.com/IMAP.AccessAsUser.All',
      'https://outlook.office.com/SMTP.Send',
      'offline_access',
      'openid',
      'email',
    ],
    extraAuthParams: {'prompt': 'select_account'},
    desktopLoopbackHost: 'localhost',
  );

  static OAuthProviderConfig forProvider(MailProviderType type) {
    return switch (type) {
      MailProviderType.gmail => gmail,
      MailProviderType.outlook => outlook,
      _ => throw UnsupportedError('OAuth2 is not preconfigured for $type'),
    };
  }
}

/// A short-lived Google access token obtained from the on-device
/// `AuthorizationClient`. No refresh token is created on the device.
@immutable
class GoogleAuthToken {
  const GoogleAuthToken({
    required this.accessToken,
    required this.expiresAt,
    this.grantedScopes = const [],
  });

  final String accessToken;
  final DateTime expiresAt;
  final List<String> grantedScopes;
}

/// Android bridge to Google Play Services `AuthorizationClient`.
///
/// Implementations must never perform interactive UI unless [interactive] is
/// true; background token renewal calls it with `false`.
abstract interface class GoogleAuthPlatform {
  Future<GoogleAuthToken> authorize({
    required String email,
    required List<String> scopes,
    required bool interactive,
    String? previousAccessToken,
  });
}

class MethodChannelGoogleAuthPlatform implements GoogleAuthPlatform {
  static const MethodChannel _channel = MethodChannel(
    'com.localmail.local_mail_client/google_auth',
  );

  @override
  Future<GoogleAuthToken> authorize({
    required String email,
    required List<String> scopes,
    required bool interactive,
    String? previousAccessToken,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'authorize',
      {
        'email': email,
        'scopes': scopes,
        'interactive': interactive,
        'previousAccessToken': previousAccessToken,
      },
    );
    final accessToken = (result?['accessToken'] as String?) ?? '';
    final expiresIn = (result?['expiresIn'] as num?)?.toInt() ?? 3300;
    final granted = ((result?['grantedScopes'] as List<dynamic>?) ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);
    return GoogleAuthToken(
      accessToken: accessToken,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      grantedScopes: granted,
    );
  }
}

/// Opens the provider's official authorization page in a system browser and
/// returns the redirect URI the provider sent back.
class OAuthBrowserLauncher {
  const OAuthBrowserLauncher();

  Future<Uri> authenticate({
    required Uri authUri,
    required String callbackScheme,
  }) async {
    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: callbackScheme,
    );
    return Uri.parse(result);
  }

  Future<bool> openExternal(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Pure-local OAuth 2.0 authorization client.
///
/// - Android Gmail: Google Play Services `AuthorizationClient` (access token
///   only, renewed silently; no fabricated refresh token).
/// - Desktop (macOS / Windows / Linux): loopback HTTP callback + system browser.
/// - Mobile Outlook / iOS Gmail: system browser + custom scheme.
class OAuthPkceService {
  OAuthPkceService({
    http.Client? httpClient,
    SanitizedLogger? logger,
    GoogleAuthPlatform? googleAuthPlatform,
    OAuthBrowserLauncher? browserLauncher,
    TargetPlatform? platformOverride,
    bool? isWebOverride,
    String? gmailDesktopClientId,
    String? gmailIosClientId,
    String? outlookClientId,
    Duration? httpTimeout,
  }) : _httpClient = httpClient ?? http.Client(),
       _httpTimeout = httpTimeout ?? const Duration(seconds: 30),
       _logger = logger ?? SanitizedLogger.instance,
       _googleAuthPlatform =
           googleAuthPlatform ?? MethodChannelGoogleAuthPlatform(),
       _browserLauncher = browserLauncher ?? const OAuthBrowserLauncher(),
       _platform = platformOverride ?? defaultTargetPlatform,
       _isWeb = isWebOverride ?? kIsWeb,
       _gmailDesktopClientId =
           (gmailDesktopClientId ?? defaultGmailDesktopClientId).trim(),
       _gmailIosClientId = (gmailIosClientId ?? defaultGmailIosClientId).trim(),
       _outlookClientId = (outlookClientId ?? defaultOutlookClientId).trim();

  static const String mobileCallbackScheme = 'com.localmail.client';
  static const String mobileRedirectUri =
      '$mobileCallbackScheme://oauth2redirect';

  /// Compile-time configuration for non-Android builds. Android Gmail uses the
  /// Android OAuth client registered for the package + signing SHA-1 instead.
  static const String defaultGmailDesktopClientId = String.fromEnvironment(
    'GMAIL_OAUTH_DESKTOP_CLIENT_ID',
    // Legacy define kept so existing desktop build scripts keep working.
    defaultValue: String.fromEnvironment('GMAIL_OAUTH_CLIENT_ID'),
  );
  static const String defaultGmailIosClientId = String.fromEnvironment(
    'GMAIL_OAUTH_IOS_CLIENT_ID',
  );
  static const String defaultOutlookClientId = String.fromEnvironment(
    'OUTLOOK_OAUTH_CLIENT_ID',
  );

  static const String googleUserInfoEndpoint =
      'https://www.googleapis.com/oauth2/v3/userinfo';

  final http.Client _httpClient;
  final Duration _httpTimeout;
  final SanitizedLogger _logger;
  final GoogleAuthPlatform _googleAuthPlatform;
  final OAuthBrowserLauncher _browserLauncher;
  final TargetPlatform _platform;
  final bool _isWeb;
  final String _gmailDesktopClientId;
  final String _gmailIosClientId;
  final String _outlookClientId;

  /// Play Services AuthorizationClient is a single shared device session, so
  /// every Android Google call is queued globally across accounts. Per-account
  /// resolver locks still serialize each account's own refresh.
  Future<void> _googleAuthorizationTail = Future<void>.value();

  bool get _isAndroid => !_isWeb && _platform == TargetPlatform.android;
  bool get _isDesktop =>
      !_isWeb &&
      (_platform == TargetPlatform.macOS ||
          _platform == TargetPlatform.windows ||
          _platform == TargetPlatform.linux);

  /// Returns the public client ID for browser-based flows, or null when this
  /// build has no usable configuration. Android Gmail returns null because it
  /// authenticates through Play Services without a bundled client ID.
  String? clientIdFor(MailProviderType provider) {
    if (_isWeb) return null;
    return switch (provider) {
      MailProviderType.gmail =>
        _isAndroid
            ? null
            : _nonEmpty(
                _platform == TargetPlatform.iOS
                    ? _gmailIosClientId
                    : _gmailDesktopClientId,
              ),
      MailProviderType.outlook => _nonEmpty(_outlookClientId),
      _ => null,
    };
  }

  bool isConfiguredFor(MailProviderType provider) {
    return switch (provider) {
      MailProviderType.gmail => _isAndroid || clientIdFor(provider) != null,
      MailProviderType.outlook => clientIdFor(provider) != null,
      _ => false,
    };
  }

  String unavailableMessageFor(MailProviderType provider) {
    return switch (provider) {
      MailProviderType.gmail =>
        _platform == TargetPlatform.iOS
            ? '此构建未配置 Google 登录。开发者需提供 GMAIL_OAUTH_IOS_CLIENT_ID 并注册反向客户端 URL scheme。'
            : '此构建未配置 Google 登录。开发者需在构建时提供 GMAIL_OAUTH_DESKTOP_CLIENT_ID（桌面）或 GMAIL_OAUTH_IOS_CLIENT_ID（iOS）。',
      MailProviderType.outlook =>
        '此构建未配置 Microsoft 登录。开发者需在构建时提供 OUTLOOK_OAUTH_CLIENT_ID。',
      _ => '此构建未配置该服务商的 OAuth 登录。',
    };
  }

  /// Launches the provider's official authorization page.
  ///
  /// [expectedEmail] binds the result to the account the user is adding. A
  /// Google token for a different account is rejected before saving.
  Future<OAuthTokenBundle> authorize({
    required MailProviderType providerType,
    String? expectedEmail,
    String? loginHintEmail,
  }) async {
    final expected = (expectedEmail ?? loginHintEmail ?? '').trim();
    if (expected.isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.oauthRequired,
        userMessage: '请先填写要登录的邮箱地址。',
      );
    }

    final config = OAuthProviderConfig.forProvider(providerType);

    if (providerType == MailProviderType.gmail && _isAndroid) {
      return _authorizeGmailOnAndroid(config: config, expectedEmail: expected);
    }

    if (_isWeb) {
      throw const AuthFailure(
        reason: AuthFailureReason.oauthNotConfigured,
        userMessage: '当前平台暂不支持系统浏览器 OAuth 回调，请使用桌面或移动客户端。',
      );
    }

    final clientId = clientIdFor(providerType);
    if (clientId == null) {
      throw AuthFailure(
        reason: AuthFailureReason.oauthNotConfigured,
        userMessage: unavailableMessageFor(providerType),
      );
    }

    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _deriveCodeChallenge(codeVerifier);
    final state = _generateRandomUrlSafe(24);
    final nonce = _generateRandomUrlSafe(24);

    if (_isDesktop) {
      return _authorizeViaDesktopLoopback(
        providerType: providerType,
        config: config,
        clientId: clientId,
        codeVerifier: codeVerifier,
        codeChallenge: codeChallenge,
        state: state,
        nonce: nonce,
        loginHintEmail: expected,
      );
    }

    return _authorizeViaMobileWebAuth(
      providerType: providerType,
      config: config,
      clientId: clientId,
      codeVerifier: codeVerifier,
      codeChallenge: codeChallenge,
      state: state,
      nonce: nonce,
      loginHintEmail: expected,
      expectedEmail: expected,
    );
  }

  Future<OAuthTokenBundle> _authorizeGmailOnAndroid({
    required OAuthProviderConfig config,
    required String expectedEmail,
    bool interactive = true,
    bool validateEmail = true,
    String? previousAccessToken,
  }) {
    return _serializeGoogleAuthorization(
      () => _authorizeGmailOnAndroidLocked(
        config: config,
        expectedEmail: expectedEmail,
        interactive: interactive,
        validateEmail: validateEmail,
        previousAccessToken: previousAccessToken,
      ),
    );
  }

  Future<T> _serializeGoogleAuthorization<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previous = _googleAuthorizationTail;
    _googleAuthorizationTail = previous.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<OAuthTokenBundle> _authorizeGmailOnAndroidLocked({
    required OAuthProviderConfig config,
    required String expectedEmail,
    bool interactive = true,
    bool validateEmail = true,
    String? previousAccessToken,
  }) async {
    try {
      final token = await _googleAuthPlatform.authorize(
        // Android account names are normalised to lower case by Google.
        email:
            _canonicalGoogleEmail(expectedEmail) ?? expectedEmail.toLowerCase(),
        scopes: config.scopes,
        interactive: interactive,
        previousAccessToken: previousAccessToken,
      );
      if (token.accessToken.isEmpty) {
        throw const AuthFailure(
          reason: AuthFailureReason.oauthRequired,
          userMessage: 'Google 未返回可用的访问令牌，请重新登录。',
        );
      }
      _ensureRequiredScopes(MailProviderType.gmail, token.grantedScopes);
      var boundEmail = expectedEmail;
      if (validateEmail) {
        final actualEmail = await _fetchGoogleEmail(token.accessToken);
        _ensureSameGoogleEmail(expectedEmail, actualEmail);
        boundEmail = actualEmail;
      }
      return OAuthTokenBundle(
        accessToken: token.accessToken,
        refreshToken: null,
        expiresAt: token.expiresAt,
        clientId: '',
        tokenEndpoint: '',
        scopes: config.scopes,
        accountEmail: boundEmail,
        deviceAuthorization: true,
      );
    } on PlatformException catch (error) {
      throw _mapGooglePlatformError(error, expectedEmail);
    }
  }

  Future<OAuthTokenBundle> _authorizeViaDesktopLoopback({
    required MailProviderType providerType,
    required OAuthProviderConfig config,
    required String clientId,
    required String codeVerifier,
    required String codeChallenge,
    required String state,
    required String nonce,
    required String loginHintEmail,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri =
        'http://${config.desktopLoopbackHost}:${server.port}/oauth2redirect';
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
        nonce: nonce,
        loginHintEmail: loginHintEmail,
      );

      final launched = await _browserLauncher.openExternal(authUri);
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
        providerType: providerType,
        callbackUri: callbackUri,
        expectedState: state,
        config: config,
        clientId: clientId,
        redirectUri: redirectUri,
        codeVerifier: codeVerifier,
        nonce: nonce,
        expectedEmail: loginHintEmail,
      );
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  }

  Future<OAuthTokenBundle> _authorizeViaMobileWebAuth({
    required MailProviderType providerType,
    required OAuthProviderConfig config,
    required String clientId,
    required String codeVerifier,
    required String codeChallenge,
    required String state,
    required String nonce,
    required String loginHintEmail,
    required String expectedEmail,
  }) async {
    final redirectUri =
        providerType == MailProviderType.gmail &&
            _platform == TargetPlatform.iOS
        ? _googleIosRedirectUri(clientId)
        : mobileRedirectUri;
    final callbackScheme = Uri.parse(redirectUri).scheme;

    final authUri = _buildAuthUri(
      config: config,
      clientId: clientId,
      redirectUri: redirectUri,
      codeChallenge: codeChallenge,
      state: state,
      nonce: nonce,
      loginHintEmail: loginHintEmail,
    );

    final Uri callbackUri;
    try {
      callbackUri = await _browserLauncher.authenticate(
        authUri: authUri,
        callbackScheme: callbackScheme,
      );
    } catch (error) {
      throw AuthFailure(
        reason: AuthFailureReason.oauthCancelled,
        userMessage: 'OAuth 授权已取消或系统浏览器无法完成回调。',
        technicalDetail: SanitizedLogger.sanitize(error.toString()),
        cause: error,
      );
    }

    return _handleCallbackAndExchange(
      providerType: providerType,
      callbackUri: callbackUri,
      expectedState: state,
      config: config,
      clientId: clientId,
      redirectUri: redirectUri,
      codeVerifier: codeVerifier,
      nonce: nonce,
      expectedEmail: expectedEmail,
    );
  }

  Uri _buildAuthUri({
    required OAuthProviderConfig config,
    required String clientId,
    required String redirectUri,
    required String codeChallenge,
    required String state,
    required String nonce,
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
      'nonce': nonce,
      ...config.extraAuthParams,
      if (loginHintEmail != null && loginHintEmail.trim().isNotEmpty)
        'login_hint': loginHintEmail.trim(),
    };
    return Uri.parse(config.authorizationEndpoint)
        .replace(queryParameters: params);
  }

  Future<OAuthTokenBundle> _handleCallbackAndExchange({
    required MailProviderType providerType,
    required Uri callbackUri,
    required String expectedState,
    required OAuthProviderConfig config,
    required String clientId,
    required String redirectUri,
    required String codeVerifier,
    required String nonce,
    required String expectedEmail,
  }) async {
    _ensureCallbackMatches(callbackUri, redirectUri);

    // The state check must also run for provider error responses, otherwise a
    // forged custom-scheme callback could inject arbitrary error text.
    final returnedState = callbackUri.queryParameters['state'];
    if (returnedState != expectedState) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'OAuth 状态校验失败，请重新尝试授权。',
      );
    }

    final error = callbackUri.queryParameters['error'];
    if (error != null) {
      final description = callbackUri.queryParameters['error_description'];
      _logger.warn(
        'OAuthPkce',
        'Provider returned OAuth error ${_safeProviderText(error)}',
      );
      throw AuthFailure(
        reason: error == 'access_denied'
            ? AuthFailureReason.oauthCancelled
            : AuthFailureReason.unknown,
        userMessage: error == 'access_denied'
            ? '已取消 OAuth 授权。'
            : 'OAuth 授权失败（${_safeProviderText(error)}），请重试。',
        technicalDetail: description == null
            ? null
            : _safeProviderText(description),
      );
    }

    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: '未从授权回调中获取到授权码（code）。',
      );
    }

    final response = await _sendHttp(
      () => _httpClient.post(
        Uri.parse(config.tokenEndpoint),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': codeVerifier,
        },
      ),
      operation: '换取 OAuth 访问令牌',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logger.warn('OAuthPkce', 'Token exchange HTTP ${response.statusCode}');
      throw AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: '换取 OAuth 访问令牌失败（HTTP ${response.statusCode}）。',
        technicalDetail: SanitizedLogger.sanitize(response.body),
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = (json['access_token'] as String?) ?? '';
    if (accessToken.isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.oauthRequired,
        userMessage: '服务商未返回访问令牌，请重新登录。',
      );
    }

    final grantedScopes = _scopesFromJson(json['scope']);
    _ensureRequiredScopes(providerType, grantedScopes);

    final newRefreshToken = (json['refresh_token'] as String?)?.trim();
    if (newRefreshToken == null || newRefreshToken.isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.oauthRequired,
        userMessage:
            '服务商未返回刷新令牌（refresh token），保存后将无法保持登录。'
            '请重新登录，并在授权页同意“离线访问/持续访问”权限。',
      );
    }

    var boundEmail = expectedEmail;
    if (providerType == MailProviderType.gmail) {
      final actualEmail = await _fetchGoogleEmail(accessToken);
      _ensureSameGoogleEmail(expectedEmail, actualEmail);
      boundEmail = actualEmail;
    } else if (providerType == MailProviderType.outlook) {
      boundEmail = _verifyOutlookIdToken(
        rawIdToken: json['id_token'],
        clientId: clientId,
        expectedEmail: expectedEmail,
        expectedNonce: nonce,
      );
    }

    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    return OAuthTokenBundle(
      accessToken: accessToken,
      refreshToken: newRefreshToken,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      clientId: clientId,
      tokenEndpoint: config.tokenEndpoint,
      // Persist the canonical requested scopes, never a provider's short or
      // Graph-resolving spelling, so refresh requests keep the Outlook resource.
      scopes: config.scopes,
      accountEmail: boundEmail,
    );
  }

  /// Renews an Android Gmail token without any interactive UI. Callers in the
  /// background must treat `interaction_required` as "please sign in again".
  Future<OAuthTokenBundle> refreshDeviceAuthorization({
    required MailProviderType providerType,
    required OAuthTokenBundle current,
  }) async {
    final email = current.accountEmail?.trim();
    if (!current.deviceAuthorization ||
        providerType != MailProviderType.gmail ||
        email == null ||
        email.isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.oauthTokenExpired,
        userMessage: '设备授权信息不完整，请重新登录该 Google 账户。',
      );
    }
    return _authorizeGmailOnAndroid(
      config: OAuthProviderConfig.gmail,
      expectedEmail: email,
      interactive: false,
      validateEmail: false,
      previousAccessToken: current.accessToken,
    );
  }

  /// Refreshes an expired browser-flow [OAuthTokenBundle] against the provider
  /// token endpoint using its refresh token.
  Future<OAuthTokenBundle> refreshToken(OAuthTokenBundle current) async {
    if (current.deviceAuthorization) {
      throw const AuthFailure(
        reason: AuthFailureReason.oauthTokenExpired,
        userMessage: '设备授权令牌需要通过 Google 登录重新获取。',
      );
    }
    final refreshToken = current.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.oauthTokenExpired,
        userMessage: 'OAuth 刷新令牌缺失或已失效，请重新授权登录。',
      );
    }

    final response = await _sendHttp(
      () => _httpClient.post(
        Uri.parse(current.tokenEndpoint),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'client_id': current.clientId,
          'refresh_token': refreshToken,
          'scope': current.scopes.join(' '),
        },
      ),
      operation: '刷新 OAuth 令牌',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logger.warn('OAuthPkce', 'Token refresh HTTP ${response.statusCode}');
      throw AuthFailure(
        reason: AuthFailureReason.oauthTokenExpired,
        userMessage: 'OAuth 授权已过期，请重新登录该邮箱账户。',
        technicalDetail: SanitizedLogger.sanitize(response.body),
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = (json['access_token'] as String?) ?? '';
    if (accessToken.isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.oauthTokenExpired,
        userMessage: 'OAuth 授权已过期，请重新登录该邮箱账户。',
      );
    }
    final provider = _providerForTokenEndpoint(current.tokenEndpoint);
    final responseScopes = _scopesFromJson(json['scope']);
    _ensureRequiredScopes(
      provider,
      responseScopes.isEmpty ? current.scopes : responseScopes,
    );
    final nextScopes = OAuthProviderConfig.forProvider(provider).scopes;
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    return OAuthTokenBundle(
      accessToken: accessToken,
      refreshToken: (json['refresh_token'] as String?) ?? refreshToken,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      clientId: current.clientId,
      tokenEndpoint: current.tokenEndpoint,
      scopes: nextScopes,
      accountEmail: current.accountEmail,
    );
  }

  static const String _googleMailScope = 'https://mail.google.com/';
  static const List<String> _outlookRequiredScopes = [
    'https://outlook.office.com/IMAP.AccessAsUser.All',
    'https://outlook.office.com/SMTP.Send',
  ];

  /// Rejects tokens that do not actually carry the IMAP/SMTP scopes we need.
  /// Google returns grant aliases such as full userinfo URLs, so only the one
  /// mandatory mail scope is compared; OpenID scope spelling is not required.
  void _ensureRequiredScopes(
    MailProviderType providerType,
    List<String> grantedScopes,
  ) {
    final granted = grantedScopes.map(_normalizeScope).toSet();
    switch (providerType) {
      case MailProviderType.gmail:
        if (!granted.contains(_normalizeScope(_googleMailScope))) {
          throw const AuthFailure(
            reason: AuthFailureReason.oauthRequired,
            userMessage:
                'Google 未授予 Gmail IMAP/SMTP 所需的邮件权限（https://mail.google.com/），'
                '请重新登录并在 Google 页面同意邮件访问权限。',
          );
        }
      case MailProviderType.outlook:
        final canonicalOutlook = grantedScopes
            .map(_canonicalOutlookScope)
            .whereType<String>()
            .map(_normalizeScope)
            .toSet();
        final missing = _outlookRequiredScopes
            .where(
              (scope) => !canonicalOutlook.contains(_normalizeScope(scope)),
            )
            .toList(growable: false);
        if (missing.isNotEmpty) {
          throw AuthFailure(
            reason: AuthFailureReason.oauthRequired,
            userMessage:
                'Microsoft 未授予 Outlook IMAP/SMTP 所需权限（${missing.join('、')}），'
                '请重新登录并同意邮件访问权限。',
          );
        }
      default:
        break;
    }
  }

  static String _normalizeScope(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
  }

  /// Accepts Microsoft's full/short/percent-encoded spellings only for the two
  /// known Outlook Exchange resources. Graph or any other host is rejected so
  /// a short scope can never be silently re-requested against Graph.
  static String? _canonicalOutlookScope(String raw) {
    String value;
    try {
      value = Uri.decodeComponent(raw.trim()).toLowerCase();
    } catch (_) {
      value = raw.trim().toLowerCase();
    }
    value = value.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      if (uri.scheme != 'https') return null;
      if (uri.host != 'outlook.office.com' &&
          uri.host != 'outlook.office365.com') {
        return null;
      }
      final path = uri.path.toLowerCase().replaceAll(RegExp(r'/+$'), '');
      return switch (path) {
        '/imap.accessasuser.all' => _outlookRequiredScopes[0],
        '/smtp.send' => _outlookRequiredScopes[1],
        _ => null,
      };
    }
    return switch (value) {
      'imap.accessasuser.all' => _outlookRequiredScopes[0],
      'smtp.send' => _outlookRequiredScopes[1],
      _ => null,
    };
  }

  static List<String> _scopesFromJson(Object? raw) {
    if (raw is String) {
      return raw
          .split(RegExp(r'\s+'))
          .where((scope) => scope.trim().isNotEmpty)
          .toList(growable: false);
    }
    if (raw is List) {
      return raw
          .map((scope) => scope.toString().trim())
          .where((scope) => scope.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  static MailProviderType _providerForTokenEndpoint(String tokenEndpoint) {
    return tokenEndpoint.contains('microsoftonline.com')
        ? MailProviderType.outlook
        : MailProviderType.gmail;
  }

  static void _ensureCallbackMatches(Uri callbackUri, String redirectUri) {
    final expected = Uri.parse(redirectUri);
    bool isRootPath(String path) => path.isEmpty || path == '/';
    final pathMatches =
        callbackUri.path == expected.path ||
        (isRootPath(callbackUri.path) && isRootPath(expected.path));
    // Some URI normalisers turn a host-only custom URI into a trailing slash;
    // only root paths are interchangeable, every other path stays exact.
    final matches =
        callbackUri.scheme.toLowerCase() == expected.scheme.toLowerCase() &&
        callbackUri.host.toLowerCase() == expected.host.toLowerCase() &&
        callbackUri.port == expected.port &&
        pathMatches;
    if (!matches) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'OAuth 回调地址不匹配，已拒绝本次授权，请重新登录。',
      );
    }
  }

  static String _safeProviderText(String value) {
    final safe = SanitizedLogger.sanitize(value)
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .trim();
    return safe.length <= 200 ? safe : '${safe.substring(0, 200)}…';
  }

  /// Validates the Microsoft ID token claims. The token is fetched directly
  /// from the fixed HTTPS token endpoint, so OIDC Core 3.1.3.7 item 6 permits
  /// TLS server validation instead of a local signature check; issuer,
  /// audience, expiry and nonce claims are still checked here.
  String _verifyOutlookIdToken({
    required Object? rawIdToken,
    required String clientId,
    required String expectedEmail,
    required String expectedNonce,
  }) {
    final claims = _decodeJwtClaims(rawIdToken);
    if (claims == null) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'Microsoft 未返回可用的身份令牌，无法确认登录账号，请重试。',
      );
    }

    final audience = claims['aud'];
    final audienceMatches =
        audience == clientId ||
        (audience is List && audience.contains(clientId));
    if (!audienceMatches) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'Microsoft 身份令牌的受众与本应用不匹配，已拒绝本次授权。',
      );
    }

    final issuer = claims['iss'];
    final issuerMatches =
        issuer is String &&
        (RegExp(r'^https://login\.microsoftonline\.com/[0-9a-fA-F-]{36}/v2\.0$')
                .hasMatch(issuer) ||
            RegExp(r'^https://login\.microsoftonline\.com/[0-9a-fA-F-]{36}/$')
                .hasMatch(issuer) ||
            RegExp(r'^https://sts\.windows\.net/[0-9a-fA-F-]{36}/$')
                .hasMatch(issuer));
    if (!issuerMatches) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'Microsoft 身份令牌的签发方不受信任，已拒绝本次授权。',
      );
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = claims['exp'];
    if (expiresAt is! num || now > expiresAt.toInt() + 60) {
      throw const AuthFailure(
        reason: AuthFailureReason.oauthTokenExpired,
        userMessage: 'Microsoft 身份令牌已过期，请重新登录。',
      );
    }
    final notBefore = claims['nbf'];
    if (notBefore is num && notBefore.toInt() > now + 60) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'Microsoft 身份令牌尚未生效，请检查设备时间后重试。',
      );
    }

    if (claims['nonce'] != expectedNonce) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'Microsoft 身份令牌的 nonce 校验失败，已拒绝本次授权。',
      );
    }

    final actualEmail = _emailFromClaims(claims);
    if (actualEmail == null) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'Microsoft 身份令牌中没有可用于确认账号的邮箱信息，请使用主邮箱地址重试。',
      );
    }
    _ensureSameEmail(expectedEmail, actualEmail, providerName: 'Microsoft');
    return actualEmail;
  }

  static Map<String, dynamic>? _decodeJwtClaims(Object? rawToken) {
    if (rawToken is! String) return null;
    final parts = rawToken.split('.');
    if (parts.length != 3) return null;
    try {
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      payload = payload.padRight(
        payload.length + (4 - payload.length % 4) % 4,
        '=',
      );
      final decoded = jsonDecode(utf8.decode(base64Decode(payload)));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String? _emailFromClaims(Map<String, dynamic> claims) {
    for (final key in const [
      'email',
      'preferred_username',
      'upn',
      'unique_name',
    ]) {
      final value = claims[key];
      if (value is! String) continue;
      // Microsoft account aliases can be returned as live.com#user@example.com.
      final normalized = value.split('#').last.trim();
      if (normalized.contains('@')) return normalized;
    }
    return null;
  }

  Future<http.Response> _sendHttp(
    Future<http.Response> Function() request, {
    required String operation,
  }) async {
    try {
      return await request().timeout(_httpTimeout);
    } on TimeoutException catch (error) {
      throw AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: '$operation超时，请检查网络后重试。',
        technicalDetail: 'timeout',
        cause: error,
      );
    } on SocketException catch (error) {
      throw AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: '网络连接中断，无法$operation，请检查网络后重试。',
        technicalDetail: SanitizedLogger.sanitize(error.message),
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: '网络连接失败，无法$operation，请检查网络后重试。',
        technicalDetail: SanitizedLogger.sanitize(error.message),
        cause: error,
      );
    }
  }

  Future<String> _fetchGoogleEmail(String accessToken) async {
    final response = await _sendHttp(
      () => _httpClient.get(
        Uri.parse(googleUserInfoEndpoint),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      operation: '验证 Google 登录账号',
    );
    if (response.statusCode != 200) {
      _logger.warn('OAuthPkce', 'Google userinfo HTTP ${response.statusCode}');
      throw AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: '无法验证 Google 登录账号（HTTP ${response.statusCode}），请重试。',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'Google 返回的账号信息格式不正确，无法确认登录账户。',
      );
    }
    final email = (decoded['email'] as String?)?.trim();
    if (email == null || email.isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'Google 未返回账号邮箱，无法确认登录的是正确账户。',
      );
    }
    if (decoded['email_verified'] != true) {
      throw const AuthFailure(
        reason: AuthFailureReason.oauthWrongAccount,
        userMessage:
            'Google 未确认该邮箱已完成验证（email_verified 不为 true），'
            '已拒绝本次登录。请在 Google 账号中验证邮箱后重试。',
      );
    }
    return email;
  }

  /// Provider-aware email equivalence used by the service and the setup
  /// wizard. Only Google's documented gmail.com/googlemail.com alias pair is
  /// treated as equivalent; Microsoft domains and custom domains stay exact.
  static bool emailsMatchForProvider(
    MailProviderType providerType,
    String expected,
    String actual,
  ) {
    if (providerType == MailProviderType.gmail) {
      final expectedCanonical = _canonicalGoogleEmail(expected);
      final actualCanonical = _canonicalGoogleEmail(actual);
      if (expectedCanonical != null && actualCanonical != null) {
        return expectedCanonical == actualCanonical;
      }
    }
    return expected.trim().toLowerCase() == actual.trim().toLowerCase();
  }

  void _ensureSameGoogleEmail(String expected, String actual) {
    if (emailsMatchForProvider(MailProviderType.gmail, expected, actual)) {
      return;
    }
    _ensureSameEmail(expected, actual);
  }

  static String? _canonicalGoogleEmail(String value) {
    final lower = value.trim().toLowerCase();
    final at = lower.indexOf('@');
    if (at <= 0 || at != lower.lastIndexOf('@') || at == lower.length - 1) {
      return null;
    }
    var domain = lower.substring(at + 1);
    // Google documents gmail.com and googlemail.com as equivalent domains; do
    // not strip dots or plus tags because those are not generally equivalent.
    if (domain == 'googlemail.com') domain = 'gmail.com';
    return '${lower.substring(0, at)}@$domain';
  }

  void _ensureSameEmail(
    String expected,
    String actual, {
    String providerName = 'Google',
  }) {
    if (expected.trim().toLowerCase() != actual.trim().toLowerCase()) {
      throw AuthFailure(
        reason: AuthFailureReason.oauthWrongAccount,
        userMessage:
            '登录的 $providerName 账号（$actual）与填写的邮箱（$expected）不一致。'
            '请点击重新登录并选择该邮箱对应的账户；如果使用了邮件别名，请填写登录页显示的主邮箱地址。',
      );
    }
  }

  AuthFailure _mapGooglePlatformError(
    PlatformException error,
    String expectedEmail,
  ) {
    final details = _parseGoogleErrorDetails(error.details);
    final statusCode = details.statusCode;
    final numeric = statusCode == null ? '' : '（错误码 $statusCode）';
    final detail = _googleDiagnosticDetail(error, details);
    _logger.warn('OAuthPkce', 'Google authorization failure: $detail');
    return switch (error.code) {
      'gms_unavailable' => AuthFailure(
        reason: AuthFailureReason.oauthDeviceUnavailable,
        userMessage:
            '此设备未安装或未启用 Google Play 服务，无法使用 Google 账号登录。'
            '请安装/启用 Google Play 服务后重试。',
        technicalDetail: detail,
        cause: error,
      ),
      'account_not_found' || 'sign_in_required' => AuthFailure(
        reason: AuthFailureReason.oauthWrongAccount,
        userMessage:
            '设备上没有找到 $expectedEmail 对应的 Google 账户$numeric。'
            '请先在系统设置中添加该 Google 账户，或点击“使用 Google 登录”选择正确账户。',
        technicalDetail: detail,
        cause: error,
      ),
      'developer_error' => AuthFailure(
        reason: AuthFailureReason.oauthNotConfigured,
        userMessage:
            'Google 登录配置未生效$numeric：请核对 Google Cloud 中 Android OAuth 客户端是否使用'
            '包名 com.localmail.local_mail_client 和当前安装包的签名 SHA-1。'
            '更换签名或安装来源后需要同步更新注册。',
        technicalDetail: detail,
        cause: error,
      ),
      'network_error' || 'timeout' => AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: '网络或 Google Play 服务暂时不可用$numeric，请检查网络后重试。',
        technicalDetail: detail,
        cause: error,
      ),
      'interaction_required' => AuthFailure(
        reason: AuthFailureReason.oauthTokenExpired,
        userMessage: 'Google 授权已失效$numeric，需要重新登录该账户。请在账户管理中重新授权。',
        technicalDetail: detail,
        cause: error,
      ),
      'authorization_in_progress' => AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: '已有 Google 授权正在进行，请稍候再试。',
        technicalDetail: detail,
        cause: error,
      ),
      'cancelled' => AuthFailure(
        reason: AuthFailureReason.oauthCancelled,
        userMessage: 'Google 授权已取消或未完成$numeric。',
        technicalDetail: detail,
        cause: error,
      ),
      'no_result' => AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage:
            'Google 授权未完成：未收到授权结果。'
            '如果不是你主动关闭授权页，请检查 Google Cloud 中 Android OAuth 客户端'
            '（包名 + 签名 SHA-1）是否已注册，以及 Google Play 服务与网络是否正常后重试。',
        technicalDetail: detail,
        cause: error,
      ),
      'interrupted' => AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'Google 授权被中断$numeric，请重试。',
        technicalDetail: detail,
        cause: error,
      ),
      _ => AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'Google 登录失败$numeric，请重试。',
        technicalDetail: detail,
        cause: error,
      ),
    };
  }

  /// Codes and stages currently emitted by the Android bridge. Anything else
  /// is treated as unknown so an arbitrary string can never reach diagnostics.
  static const Set<String> _googleErrorCodes = {
    'gms_unavailable',
    'invalid_argument',
    'authorization_in_progress',
    'interaction_required',
    'auth_failed',
    'no_result',
    'interrupted',
    'developer_error',
    'sign_in_required',
    'cancelled',
    'network_error',
    'timeout',
  };

  static const Set<String> _googleErrorStages = {
    'authorize_call',
    'interactive_resolution',
    'start_resolution',
    'authorization_result',
    'activity_result',
    'activity_destroyed',
  };

  /// Reads the non-sensitive diagnostics sent by the Android bridge. Native
  /// code sends only integer status fields and known stage strings; malformed
  /// values and any other keys are ignored.
  static ({int? statusCode, String? stage, int? resultCode})
  _parseGoogleErrorDetails(Object? raw) {
    if (raw is! Map) {
      return (statusCode: null, stage: null, resultCode: null);
    }
    int? readInt(Object? value) => value is int ? value : null;

    final stage = raw['stage'];
    return (
      statusCode: readInt(raw['statusCode']),
      stage:
          stage is String && _googleErrorStages.contains(stage) ? stage : null,
      resultCode: readInt(raw['resultCode']),
    );
  }

  /// The native message is deliberately excluded: sanitising arbitrary text
  /// does not reliably redact bare emails or tokens. Only fixed fields from the
  /// current bridge are logged.
  static String _googleDiagnosticDetail(
    PlatformException error,
    ({int? statusCode, String? stage, int? resultCode}) details,
  ) {
    final code = _googleErrorCodes.contains(error.code) ? error.code : 'unknown';
    final parts = <String>[
      // Avoid the `code=` key so SanitizedLogger does not redact the fixed
      // native error name as an OAuth authorization code.
      'native_error=$code',
      if (details.statusCode != null) 'status_code=${details.statusCode}',
      if (details.stage != null) 'stage=${details.stage}',
      if (details.resultCode != null) 'result_code=${details.resultCode}',
    ];
    return parts.join('; ');
  }

  static String _googleIosRedirectUri(String clientId) {
    const suffix = '.apps.googleusercontent.com';
    final prefix = clientId.endsWith(suffix)
        ? clientId.substring(0, clientId.length - suffix.length)
        : clientId;
    return 'com.googleusercontent.apps.$prefix:/oauth2redirect';
  }

  static String? _nonEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
