import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/logging/sanitized_logger.dart';
import 'package:local_mail_client/core/security/oauth_pkce_service.dart';
import 'package:local_mail_client/core/security/secure_storage_service.dart';

class _FakeGoogleAuth implements GoogleAuthPlatform {
  _FakeGoogleAuth({this.token, this.error, this.delay = Duration.zero});

  GoogleAuthToken? token;
  Object? error;
  final Duration delay;
  int activeCalls = 0;
  int maxActiveCalls = 0;
  final List<
    ({
      String email,
      bool interactive,
      String? previousToken,
      List<String> scopes,
    })
  >
  calls = [];

  @override
  Future<GoogleAuthToken> authorize({
    required String email,
    required List<String> scopes,
    required bool interactive,
    String? previousAccessToken,
  }) async {
    calls.add((
      email: email,
      interactive: interactive,
      previousToken: previousAccessToken,
      scopes: scopes,
    ));
    activeCalls++;
    if (activeCalls > maxActiveCalls) maxActiveCalls = activeCalls;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    activeCalls--;
    final failure = error;
    if (failure != null) throw failure;
    return token ??
        GoogleAuthToken(
          accessToken: 'google-access-token',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          grantedScopes: const [
            'https://mail.google.com/',
            'openid',
            'https://www.googleapis.com/auth/userinfo.email',
          ],
        );
  }
}

class _RecordingBrowserLauncher extends OAuthBrowserLauncher {
  _RecordingBrowserLauncher(this.callbackBuilder);

  final Uri Function(Uri authUri) callbackBuilder;
  Uri? lastAuthUri;
  String? lastCallbackScheme;

  @override
  Future<Uri> authenticate({
    required Uri authUri,
    required String callbackScheme,
  }) async {
    lastAuthUri = authUri;
    lastCallbackScheme = callbackScheme;
    return callbackBuilder(authUri);
  }
}

String _base64UrlJson(Map<String, dynamic> value) {
  return base64UrlEncode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
}

String _outlookIdToken({
  required String clientId,
  required String nonce,
  String email = 'bob@outlook.com',
  String? tokenNonce,
  int? expiresAt,
  String? audience,
  String issuer = 'https://login.microsoftonline.com/9188040d-6c67-4c5b-b112-36a304b66dad/v2.0',
}) {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  return [
    _base64UrlJson({'alg': 'none', 'typ': 'JWT'}),
    _base64UrlJson({
      'aud': audience ?? clientId,
      'iss': issuer,
      'exp': expiresAt ?? now + 3600,
      'nonce': tokenNonce ?? nonce,
      'email': email,
      'preferred_username': email,
    }),
    'signature-not-checked-over-tls',
  ].join('.');
}

OAuthTokenBundle _deviceBundle({
  String email = 'alice@gmail.com',
  String accessToken = 'old-device-token',
}) {
  return OAuthTokenBundle(
    accessToken: accessToken,
    refreshToken: null,
    expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
    clientId: '',
    tokenEndpoint: '',
    scopes: const ['https://mail.google.com/', 'openid', 'email'],
    accountEmail: email,
    deviceAuthorization: true,
  );
}

void main() {
  group('configuration', () {
    test(
      'Android Gmail is configured through Play Services without a client ID',
      () {
        final service = OAuthPkceService(
          platformOverride: TargetPlatform.android,
          isWebOverride: false,
          gmailDesktopClientId: '',
          outlookClientId: '',
        );
        expect(service.isConfiguredFor(MailProviderType.gmail), isTrue);
        expect(service.clientIdFor(MailProviderType.gmail), isNull);
      },
    );

    test('desktop and iOS Gmail need their own platform client ID', () {
      final desktopEmpty = OAuthPkceService(
        platformOverride: TargetPlatform.macOS,
        isWebOverride: false,
        gmailDesktopClientId: '',
      );
      expect(desktopEmpty.isConfiguredFor(MailProviderType.gmail), isFalse);

      final desktop = OAuthPkceService(
        platformOverride: TargetPlatform.macOS,
        isWebOverride: false,
        gmailDesktopClientId: 'desktop-id.apps.googleusercontent.com',
      );
      expect(desktop.isConfiguredFor(MailProviderType.gmail), isTrue);

      final ios = OAuthPkceService(
        platformOverride: TargetPlatform.iOS,
        isWebOverride: false,
        gmailIosClientId: 'ios-id.apps.googleusercontent.com',
      );
      expect(ios.isConfiguredFor(MailProviderType.gmail), isTrue);
      expect(
        ios.clientIdFor(MailProviderType.gmail),
        'ios-id.apps.googleusercontent.com',
      );
    });

    test(
      'Microsoft login is unavailable until a public client ID is built in',
      () async {
        final service = OAuthPkceService(
          platformOverride: TargetPlatform.android,
          isWebOverride: false,
          outlookClientId: '',
        );
        expect(service.isConfiguredFor(MailProviderType.outlook), isFalse);
        await expectLater(
          service.authorize(
            providerType: MailProviderType.outlook,
            expectedEmail: 'bob@outlook.com',
          ),
          throwsA(
            isA<AuthFailure>()
                .having(
                  (e) => e.reason,
                  'reason',
                  AuthFailureReason.oauthNotConfigured,
                )
                .having(
                  (e) => e.userMessage,
                  'message',
                  contains('未配置 Microsoft 登录'),
                ),
          ),
        );
      },
    );
  });

  group('Android Gmail device authorization', () {
    test(
      'returns an access token bundle and verifies the account email',
      () async {
        final google = _FakeGoogleAuth();
        final userInfoCalls = <http.Request>[];
        final service = OAuthPkceService(
          platformOverride: TargetPlatform.android,
          isWebOverride: false,
          googleAuthPlatform: google,
          httpClient: MockClient((request) async {
            userInfoCalls.add(request);
            return http.Response(
              '{"email":"alice@gmail.com","email_verified":true}',
              200,
            );
          }),
        );

        final bundle = await service.authorize(
          providerType: MailProviderType.gmail,
          expectedEmail: 'alice@gmail.com',
        );

        expect(bundle.accessToken, 'google-access-token');
        expect(bundle.refreshToken, isNull);
        expect(bundle.deviceAuthorization, isTrue);
        expect(bundle.clientId, isEmpty);
        expect(bundle.accountEmail, 'alice@gmail.com');
        expect(google.calls.single.email, 'alice@gmail.com');
        expect(google.calls.single.interactive, isTrue);
        expect(
          google.calls.single.scopes,
          contains('https://mail.google.com/'),
        );
        expect(
          userInfoCalls.single.headers['Authorization'],
          'Bearer google-access-token',
        );
      },
    );

    test(
      'rejects a token that belongs to a different Google account',
      () async {
        final service = OAuthPkceService(
          platformOverride: TargetPlatform.android,
          isWebOverride: false,
          googleAuthPlatform: _FakeGoogleAuth(),
          httpClient: MockClient(
            (_) async => http.Response(
              '{"email":"other@gmail.com","email_verified":true}',
              200,
            ),
          ),
        );

        await expectLater(
          service.authorize(
            providerType: MailProviderType.gmail,
            expectedEmail: 'alice@gmail.com',
          ),
          throwsA(
            isA<AuthFailure>()
                .having(
                  (e) => e.reason,
                  'reason',
                  AuthFailureReason.oauthWrongAccount,
                )
                .having((e) => e.userMessage, 'message', contains('不一致')),
          ),
        );
      },
    );

    test('silent renewal binds the stored account and never prompts', () async {
      final google = _FakeGoogleAuth(
        token: GoogleAuthToken(
          accessToken: 'new-device-token',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 50)),
          grantedScopes: const ['https://mail.google.com/', 'openid'],
        ),
      );
      var httpCalls = 0;
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        googleAuthPlatform: google,
        httpClient: MockClient((_) async {
          httpCalls++;
          return http.Response(
            '{"email":"alice@gmail.com","email_verified":true}',
            200,
          );
        }),
      );

      final bundle = await service.refreshDeviceAuthorization(
        providerType: MailProviderType.gmail,
        current: _deviceBundle(),
      );

      expect(bundle.accessToken, 'new-device-token');
      expect(bundle.deviceAuthorization, isTrue);
      expect(bundle.accountEmail, 'alice@gmail.com');
      expect(google.calls.single.interactive, isFalse);
      expect(google.calls.single.email, 'alice@gmail.com');
      expect(google.calls.single.previousToken, 'old-device-token');
      expect(
        httpCalls,
        0,
        reason: 'silent renewal must not call userinfo again',
      );
    });

    test(
      'missing Google Play services maps to a recoverable failure',
      () async {
        final service = OAuthPkceService(
          platformOverride: TargetPlatform.android,
          isWebOverride: false,
          googleAuthPlatform: _FakeGoogleAuth(
            error: PlatformException(code: 'gms_unavailable'),
          ),
        );

        await expectLater(
          service.authorize(
            providerType: MailProviderType.gmail,
            expectedEmail: 'alice@gmail.com',
          ),
          throwsA(
            isA<AuthFailure>().having(
              (e) => e.reason,
              'reason',
              AuthFailureReason.oauthDeviceUnavailable,
            ),
          ),
        );
      },
    );

    test(
      'silent renewal never opens UI when interaction is required',
      () async {
        final service = OAuthPkceService(
          platformOverride: TargetPlatform.android,
          isWebOverride: false,
          googleAuthPlatform: _FakeGoogleAuth(
            error: PlatformException(code: 'interaction_required'),
          ),
        );

        await expectLater(
          service.refreshDeviceAuthorization(
            providerType: MailProviderType.gmail,
            current: _deviceBundle(),
          ),
          throwsA(
            isA<AuthFailure>()
                .having(
                  (e) => e.reason,
                  'reason',
                  AuthFailureReason.oauthTokenExpired,
                )
                .having((e) => e.userMessage, 'message', contains('重新登录')),
          ),
        );
      },
    );
  });

  group('Android Gmail account binding extras', () {
    test('accepts the documented googlemail.com alias and binds the primary account', () async {
      final google = _FakeGoogleAuth();
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        googleAuthPlatform: google,
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'sub': '123',
              'email': 'alice@gmail.com',
              'email_verified': true,
              'name': 'Alice',
            }),
            200,
          ),
        ),
      );

      final bundle = await service.authorize(
        providerType: MailProviderType.gmail,
        expectedEmail: 'alice@googlemail.com',
      );

      expect(bundle.accountEmail, 'alice@gmail.com');
      expect(google.calls.single.email, 'alice@gmail.com');
    });

    test('rejects an unverified Google email', () async {
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        googleAuthPlatform: _FakeGoogleAuth(),
        httpClient: MockClient(
          (_) async => http.Response(
            '{"email":"alice@gmail.com","email_verified":false}',
            200,
          ),
        ),
      );

      await expectLater(
        service.authorize(
          providerType: MailProviderType.gmail,
          expectedEmail: 'alice@gmail.com',
        ),
        throwsA(
          isA<AuthFailure>()
              .having(
                (e) => e.reason,
                'reason',
                AuthFailureReason.oauthWrongAccount,
              )
              .having((e) => e.userMessage, 'message', contains('未确认该邮箱')),
        ),
      );
    });

    test(
      'queues simultaneous silent renewals from different Google accounts',
      () async {
        final google = _FakeGoogleAuth(
          delay: const Duration(milliseconds: 25),
          token: GoogleAuthToken(
            accessToken: 'queued-token',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 50)),
            grantedScopes: const ['https://mail.google.com/'],
          ),
        );
        final service = OAuthPkceService(
          platformOverride: TargetPlatform.android,
          isWebOverride: false,
          googleAuthPlatform: google,
        );

        final results = await Future.wait([
          service.refreshDeviceAuthorization(
            providerType: MailProviderType.gmail,
            current: _deviceBundle(email: 'alice@gmail.com'),
          ),
          service.refreshDeviceAuthorization(
            providerType: MailProviderType.gmail,
            current: _deviceBundle(email: 'bob@gmail.com'),
          ),
        ]);

        expect(
          google.maxActiveCalls,
          1,
          reason: 'Play Services must be globally serialized',
        );
        expect(
          results.map((bundle) => bundle.accountEmail),
          containsAll(<String>['alice@gmail.com', 'bob@gmail.com']),
        );
      },
    );

    test('userinfo timeout is recoverable instead of hanging in the login busy state', () async {
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        googleAuthPlatform: _FakeGoogleAuth(),
        httpTimeout: const Duration(milliseconds: 10),
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response(
            '{"email":"alice@gmail.com","email_verified":true}',
            200,
          );
        }),
      );

      await expectLater(
        service.authorize(
          providerType: MailProviderType.gmail,
          expectedEmail: 'alice@gmail.com',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.userMessage,
            'message',
            contains('超时'),
          ),
        ),
      );
    });
  });

  group('Android Google failure classification', () {
    Future<AuthFailure> captureFailure(Object error) async {
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        googleAuthPlatform: _FakeGoogleAuth(error: error),
      );
      try {
        await service.authorize(
          providerType: MailProviderType.gmail,
          expectedEmail: 'alice@gmail.com',
        );
      } on AuthFailure catch (failure) {
        return failure;
      }
      fail('Expected an AuthFailure');
    }

    test('keeps the native DEVELOPER_ERROR status instead of cancelling', () async {
      final failure = await captureFailure(
        PlatformException(
          code: 'developer_error',
          message: 'Google authorization is not configured for this app (status 10).',
          details: const {
            'statusCode': 10,
            'stage': 'activity_result',
            'resultCode': 0,
          },
        ),
      );

      expect(failure.reason, AuthFailureReason.oauthNotConfigured);
      expect(failure.userMessage, contains('错误码 10'));
      expect(failure.technicalDetail, contains('native_error=developer_error'));
      expect(failure.technicalDetail, contains('status_code=10'));
      expect(failure.technicalDetail, contains('stage=activity_result'));
      expect(failure.technicalDetail, contains('result_code=0'));
    });

    test('maps network and timeout statuses as retryable diagnostics', () async {
      for (final (code, status) in [('network_error', 7), ('timeout', 15)]) {
        final failure = await captureFailure(
          PlatformException(
            code: code,
            details: {'statusCode': status, 'stage': 'authorize_call'},
          ),
        );
        expect(failure.reason, AuthFailureReason.unknown);
        expect(failure.userMessage, contains('错误码 $status'));
        expect(failure.userMessage, contains('检查网络'));
        expect(failure.technicalDetail, contains('status_code=$status'));
      }
    });

    test('keeps a real SDK CANCELED as cancelled', () async {
      final failure = await captureFailure(
        PlatformException(
          code: 'cancelled',
          details: const {'statusCode': 16, 'stage': 'activity_result'},
        ),
      );

      expect(failure.reason, AuthFailureReason.oauthCancelled);
      expect(failure.userMessage, contains('已取消或未完成'));
      expect(failure.userMessage, contains('错误码 16'));
    });

    test('does not turn missing results or teardown into cancellation', () async {
      final noResult = await captureFailure(
        PlatformException(
          code: 'no_result',
          details: const {
            'stage': 'activity_result',
            'resultCode': 0,
          },
        ),
      );
      expect(noResult.reason, AuthFailureReason.unknown);
      expect(noResult.userMessage, contains('未收到授权结果'));
      expect(noResult.userMessage, contains('Google Cloud'));
      expect(noResult.userMessage, isNot(contains('resultCode')));
      expect(noResult.userMessage, isNot(contains('已取消')));

      final interrupted = await captureFailure(
        PlatformException(
          code: 'interrupted',
          details: const {'stage': 'activity_destroyed'},
        ),
      );
      expect(interrupted.reason, AuthFailureReason.unknown);
      expect(interrupted.userMessage, contains('中断'));
      expect(interrupted.userMessage, isNot(contains('已取消')));
    });

    test('unknown errors stay unknown and expose their numeric status', () async {
      final failure = await captureFailure(
        PlatformException(
          code: 'auth_failed',
          details: const {
            'statusCode': 13,
            'stage': 'activity_result',
            'resultCode': 0,
          },
        ),
      );

      expect(failure.reason, AuthFailureReason.unknown);
      expect(failure.userMessage, contains('错误码 13'));
      expect(failure.userMessage, isNot(contains('已取消')));
    });

    test('method-channel details are parsed and secrets stay redacted', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SanitizedLogger.instance.clear();
      const channel = MethodChannel('com.localmail.local_mail_client/google_auth');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'developer_error',
          message: 'Authorization: Bearer ya29.message-secret',
          details: const {
            'statusCode': 10,
            'stage': 'activity_result',
            'resultCode': 0,
            'accessToken': 'ya29.details-secret',
            'email': 'should-not-leak@example.com',
          },
        );
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(channel, null),
      );

      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
      );
      AuthFailure? failure;
      try {
        await service.authorize(
          providerType: MailProviderType.gmail,
          expectedEmail: 'alice@gmail.com',
        );
      } on AuthFailure catch (error) {
        failure = error;
      }
      expect(failure, isNotNull);
      expect(failure!.reason, AuthFailureReason.oauthNotConfigured);
      expect(failure.technicalDetail, contains('native_error=developer_error'));
      expect(failure.technicalDetail, contains('status_code=10'));
      expect(failure.technicalDetail, contains('stage=activity_result'));
      expect(failure.technicalDetail, isNot(contains('ya29')));
      expect(failure.technicalDetail, isNot(contains('should-not-leak')));

      final logs = SanitizedLogger.instance.recentEntries.join('\n');
      expect(logs, contains('native_error=developer_error'));
      expect(logs, isNot(contains('ya29')));
      expect(logs, isNot(contains('should-not-leak')));
    });

    test('foreign or malformed detail fields cannot leak or crash', () async {
      SanitizedLogger.instance.clear();
      final foreign = await captureFailure(
        PlatformException(
          code: 'developer_error ya29.code-secret should-not-leak@example.com',
          message: 'Bearer ya29.message-secret should-not-leak@example.com',
          details: {
            'statusCode': 10.5,
            'stage': 'activity_result ya29.stage-secret',
            'resultCode': '0',
            'accessToken': 'ya29.details-secret',
            'email': 'should-not-leak@example.com',
          },
        ),
      );
      expect(foreign.reason, AuthFailureReason.unknown);
      expect(foreign.technicalDetail, 'native_error=unknown');

      final malformed = await captureFailure(
        PlatformException(
          code: 'no_result',
          message: 'ya29.message-secret should-not-leak@example.com',
          details: 'ya29.details-secret should-not-leak@example.com',
        ),
      );
      expect(malformed.reason, AuthFailureReason.unknown);
      expect(malformed.userMessage, contains('未收到授权结果'));
      expect(malformed.technicalDetail, 'native_error=no_result');

      final logs = SanitizedLogger.instance.recentEntries.join('\n');
      expect(logs, contains('native_error=no_result'));
      for (final secret in [
        'ya29',
        'should-not-leak',
        'message-secret',
        'details-secret',
      ]) {
        expect(foreign.technicalDetail, isNot(contains(secret)));
        expect(malformed.technicalDetail, isNot(contains(secret)));
        expect(logs, isNot(contains(secret)));
      }
    });
  });

  group('browser PKCE flow', () {
    test(
      'sends S256 PKCE, matches state and validates the Google email',
      () async {
        late Map<String, String> tokenForm;
        final launcher = _RecordingBrowserLauncher(
          (auth) => Uri.parse(OAuthPkceService.mobileRedirectUri).replace(
            queryParameters: {
              'code': 'auth-code',
              'state': auth.queryParameters['state']!,
            },
          ),
        );
        final service = OAuthPkceService(
          platformOverride: TargetPlatform.android,
          isWebOverride: false,
          outlookClientId: 'outlook-client-id',
          browserLauncher: launcher,
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/token')) {
              tokenForm = Uri.splitQueryString(request.body);
              final nonce = launcher.lastAuthUri!.queryParameters['nonce']!;
              return http.Response(
                jsonEncode({
                  'access_token': 'outlook-access-token',
                  'refresh_token': 'outlook-refresh-token',
                  'expires_in': 3600,
                  'scope':
                      'https://outlook.office.com/IMAP.AccessAsUser.All '
                      'https://outlook.office.com/SMTP.Send openid email '
                      'offline_access',
                  'id_token': _outlookIdToken(
                    clientId: 'outlook-client-id',
                    nonce: nonce,
                  ),
                }),
                200,
              );
            }
            return http.Response('', 404);
          }),
        );

        final bundle = await service.authorize(
          providerType: MailProviderType.outlook,
          expectedEmail: 'bob@outlook.com',
          loginHintEmail: 'bob@outlook.com',
        );

        final authUri = launcher.lastAuthUri!;
        expect(authUri.queryParameters['client_id'], 'outlook-client-id');
        expect(
          authUri.queryParameters['redirect_uri'],
          OAuthPkceService.mobileRedirectUri,
        );
        expect(authUri.queryParameters['code_challenge_method'], 'S256');
        expect(authUri.queryParameters['login_hint'], 'bob@outlook.com');
        expect(
          authUri.queryParameters['scope'],
          contains('IMAP.AccessAsUser.All'),
        );
        expect(
          launcher.lastCallbackScheme,
          OAuthPkceService.mobileCallbackScheme,
        );

        final verifier = tokenForm['code_verifier']!;
        final expectedChallenge = base64UrlEncode(
          sha256.convert(ascii.encode(verifier)).bytes,
        ).replaceAll('=', '');
        expect(authUri.queryParameters['code_challenge'], expectedChallenge);

        expect(bundle.accessToken, 'outlook-access-token');
        expect(bundle.refreshToken, 'outlook-refresh-token');
        expect(bundle.deviceAuthorization, isFalse);
        expect(bundle.accountEmail, 'bob@outlook.com');
      },
    );

    test(
      'a callback with the wrong state is rejected before token exchange',
      () async {
        var tokenCalls = 0;
        final launcher = _RecordingBrowserLauncher(
          (auth) => Uri.parse(OAuthPkceService.mobileRedirectUri).replace(
            queryParameters: {'code': 'auth-code', 'state': 'not-the-state'},
          ),
        );
        final service = OAuthPkceService(
          platformOverride: TargetPlatform.android,
          isWebOverride: false,
          outlookClientId: 'outlook-client-id',
          browserLauncher: launcher,
          httpClient: MockClient((_) async {
            tokenCalls++;
            return http.Response('{}', 200);
          }),
        );

        await expectLater(
          service.authorize(
            providerType: MailProviderType.outlook,
            expectedEmail: 'bob@outlook.com',
          ),
          throwsA(
            isA<AuthFailure>().having(
              (e) => e.userMessage,
              'message',
              contains('状态校验失败'),
            ),
          ),
        );
        expect(tokenCalls, 0);
      },
    );

    test('access_denied from the provider maps to a cancellation', () async {
      final launcher = _RecordingBrowserLauncher(
        (auth) => Uri.parse(OAuthPkceService.mobileRedirectUri).replace(
          queryParameters: {
            'error': 'access_denied',
            'state': auth.queryParameters['state']!,
          },
        ),
      );
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        outlookClientId: 'outlook-client-id',
        browserLauncher: launcher,
      );

      await expectLater(
        service.authorize(
          providerType: MailProviderType.outlook,
          expectedEmail: 'bob@outlook.com',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.reason,
            'reason',
            AuthFailureReason.oauthCancelled,
          ),
        ),
      );
    });

    test('a browser launch failure maps to a cancellation', () async {
      final launcher = _RecordingBrowserLauncher(
        (_) => throw StateError('browser unavailable'),
      );
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        outlookClientId: 'outlook-client-id',
        browserLauncher: launcher,
      );

      await expectLater(
        service.authorize(
          providerType: MailProviderType.outlook,
          expectedEmail: 'bob@outlook.com',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.reason,
            'reason',
            AuthFailureReason.oauthCancelled,
          ),
        ),
      );
    });

    test('Google browser flow rejects a different account email', () async {
      final launcher = _RecordingBrowserLauncher(
        (auth) => Uri.parse(auth.queryParameters['redirect_uri']!).replace(
          queryParameters: {
            'code': 'auth-code',
            'state': auth.queryParameters['state']!,
          },
        ),
      );
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.iOS,
        isWebOverride: false,
        gmailIosClientId: '123-abc.apps.googleusercontent.com',
        browserLauncher: launcher,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/token')) {
            return http.Response(
              jsonEncode({
                'access_token': 'google-access-token',
                'refresh_token': 'google-refresh-token',
                'expires_in': 3600,
                'scope':
                    'https://mail.google.com/ openid '
                    'https://www.googleapis.com/auth/userinfo.email',
              }),
              200,
            );
          }
          return http.Response(
            '{"email":"wrong@gmail.com","email_verified":true}',
            200,
          );
        }),
      );

      await expectLater(
        service.authorize(
          providerType: MailProviderType.gmail,
          expectedEmail: 'alice@gmail.com',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.reason,
            'reason',
            AuthFailureReason.oauthWrongAccount,
          ),
        ),
      );
    });

    test('iOS Gmail uses the reversed client ID URL scheme', () async {
      final launcher = _RecordingBrowserLauncher(
        (auth) => Uri.parse(auth.queryParameters['redirect_uri']!).replace(
          queryParameters: {
            'code': 'auth-code',
            'state': auth.queryParameters['state']!,
          },
        ),
      );
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.iOS,
        isWebOverride: false,
        gmailIosClientId: '123-abc.apps.googleusercontent.com',
        browserLauncher: launcher,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/token')) {
            return http.Response(
              jsonEncode({
                'access_token': 'google-access-token',
                'refresh_token': 'google-refresh-token',
                'scope':
                    'https://mail.google.com/ openid '
                    'https://www.googleapis.com/auth/userinfo.email',
              }),
              200,
            );
          }
          return http.Response(
            '{"email":"alice@gmail.com","email_verified":true}',
            200,
          );
        }),
      );

      await service.authorize(
        providerType: MailProviderType.gmail,
        expectedEmail: 'alice@gmail.com',
      );

      expect(
        launcher.lastAuthUri!.queryParameters['redirect_uri'],
        'com.googleusercontent.apps.123-abc:/oauth2redirect',
      );
      expect(launcher.lastCallbackScheme, 'com.googleusercontent.apps.123-abc');
    });

    test(
      'accepts the same mobile callback with a trailing root slash',
      () async {
        final launcher = _RecordingBrowserLauncher(
          (auth) => Uri.parse('${OAuthPkceService.mobileRedirectUri}/').replace(
            queryParameters: {
              'code': 'auth-code',
              'state': auth.queryParameters['state']!,
            },
          ),
        );
        final service = OAuthPkceService(
          platformOverride: TargetPlatform.android,
          isWebOverride: false,
          outlookClientId: 'outlook-client-id',
          browserLauncher: launcher,
          httpClient: MockClient((request) async {
            final nonce = launcher.lastAuthUri!.queryParameters['nonce']!;
            return http.Response(
              jsonEncode({
                'access_token': 'outlook-access-token',
                'refresh_token': 'outlook-refresh-token',
                'scope':
                    'https://outlook.office.com/IMAP.AccessAsUser.All '
                    'https://outlook.office.com/SMTP.Send openid email offline_access',
                'id_token': _outlookIdToken(
                  clientId: 'outlook-client-id',
                  nonce: nonce,
                ),
              }),
              200,
            );
          }),
        );

        final bundle = await service.authorize(
          providerType: MailProviderType.outlook,
          expectedEmail: 'bob@outlook.com',
        );
        expect(bundle.accessToken, 'outlook-access-token');
      },
    );

    test(
      'browser flows reject a token response without a refresh token',
      () async {
        final launcher = _RecordingBrowserLauncher(
          (auth) => Uri.parse(OAuthPkceService.mobileRedirectUri).replace(
            queryParameters: {
              'code': 'auth-code',
              'state': auth.queryParameters['state']!,
            },
          ),
        );
        final service = OAuthPkceService(
          platformOverride: TargetPlatform.android,
          isWebOverride: false,
          outlookClientId: 'outlook-client-id',
          browserLauncher: launcher,
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'access_token': 'outlook-access-token',
                'scope':
                    'https://outlook.office.com/IMAP.AccessAsUser.All '
                    'https://outlook.office.com/SMTP.Send openid email offline_access',
              }),
              200,
            ),
          ),
        );

        await expectLater(
          service.authorize(
            providerType: MailProviderType.outlook,
            expectedEmail: 'bob@outlook.com',
          ),
          throwsA(
            isA<AuthFailure>().having(
              (e) => e.userMessage,
              'message',
              contains('刷新令牌'),
            ),
          ),
        );
      },
    );

    test('Outlook rejects a different Microsoft account, including hotmail aliases', () async {
      final launcher = _RecordingBrowserLauncher(
        (auth) => Uri.parse(OAuthPkceService.mobileRedirectUri).replace(
          queryParameters: {
            'code': 'auth-code',
            'state': auth.queryParameters['state']!,
          },
        ),
      );
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        outlookClientId: 'outlook-client-id',
        browserLauncher: launcher,
        httpClient: MockClient((request) async {
          final nonce = launcher.lastAuthUri!.queryParameters['nonce']!;
          return http.Response(
            jsonEncode({
              'access_token': 'outlook-access-token',
              'refresh_token': 'outlook-refresh-token',
              'scope':
                  'https://outlook.office.com/IMAP.AccessAsUser.All '
                  'https://outlook.office.com/SMTP.Send openid email offline_access',
              'id_token': _outlookIdToken(
                clientId: 'outlook-client-id',
                nonce: nonce,
                email: 'bob@hotmail.com',
              ),
            }),
            200,
          );
        }),
      );

      await expectLater(
        service.authorize(
          providerType: MailProviderType.outlook,
          expectedEmail: 'bob@outlook.com',
        ),
        throwsA(
          isA<AuthFailure>()
              .having(
                (e) => e.reason,
                'reason',
                AuthFailureReason.oauthWrongAccount,
              )
              .having((e) => e.userMessage, 'message', contains('不一致')),
        ),
      );
    });

    test('Outlook rejects an ID token with the wrong nonce', () async {
      final launcher = _RecordingBrowserLauncher(
        (auth) => Uri.parse(OAuthPkceService.mobileRedirectUri).replace(
          queryParameters: {
            'code': 'auth-code',
            'state': auth.queryParameters['state']!,
          },
        ),
      );
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        outlookClientId: 'outlook-client-id',
        browserLauncher: launcher,
        httpClient: MockClient((request) async {
          final nonce = launcher.lastAuthUri!.queryParameters['nonce']!;
          return http.Response(
            jsonEncode({
              'access_token': 'outlook-access-token',
              'refresh_token': 'outlook-refresh-token',
              'scope':
                  'https://outlook.office.com/IMAP.AccessAsUser.All '
                  'https://outlook.office.com/SMTP.Send openid email offline_access',
              'id_token': _outlookIdToken(
                clientId: 'outlook-client-id',
                nonce: nonce,
                tokenNonce: 'different-nonce',
              ),
            }),
            200,
          );
        }),
      );

      await expectLater(
        service.authorize(
          providerType: MailProviderType.outlook,
          expectedEmail: 'bob@outlook.com',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.userMessage,
            'message',
            contains('nonce'),
          ),
        ),
      );
    });

    test('Outlook accepts short scope spellings but persists canonical resource scopes', () async {
      final launcher = _RecordingBrowserLauncher(
        (auth) => Uri.parse(OAuthPkceService.mobileRedirectUri).replace(
          queryParameters: {
            'code': 'auth-code',
            'state': auth.queryParameters['state']!,
          },
        ),
      );
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        outlookClientId: 'outlook-client-id',
        browserLauncher: launcher,
        httpClient: MockClient((request) async {
          final nonce = launcher.lastAuthUri!.queryParameters['nonce']!;
          return http.Response(
            jsonEncode({
              'access_token': 'outlook-access-token',
              'refresh_token': 'outlook-refresh-token',
              'scope':
                  'IMAP.AccessAsUser.All SMTP.Send offline_access openid email',
              'id_token': _outlookIdToken(
                clientId: 'outlook-client-id',
                nonce: nonce,
              ),
            }),
            200,
          );
        }),
      );

      final bundle = await service.authorize(
        providerType: MailProviderType.outlook,
        expectedEmail: 'bob@outlook.com',
      );

      expect(bundle.scopes, OAuthProviderConfig.outlook.scopes);
      expect(
        bundle.scopes,
        contains('https://outlook.office.com/IMAP.AccessAsUser.All'),
      );
      expect(bundle.scopes, contains('https://outlook.office.com/SMTP.Send'));
    });

    test('Outlook rejects Graph or unknown-resource scopes', () async {
      final launcher = _RecordingBrowserLauncher(
        (auth) => Uri.parse(OAuthPkceService.mobileRedirectUri).replace(
          queryParameters: {
            'code': 'auth-code',
            'state': auth.queryParameters['state']!,
          },
        ),
      );
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        outlookClientId: 'outlook-client-id',
        browserLauncher: launcher,
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'access_token': 'outlook-access-token',
              'refresh_token': 'outlook-refresh-token',
              'scope':
                  'https://graph.microsoft.com/Mail.Read '
                  'https://graph.microsoft.com/Mail.Send',
            }),
            200,
          ),
        ),
      );

      await expectLater(
        service.authorize(
          providerType: MailProviderType.outlook,
          expectedEmail: 'bob@outlook.com',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.reason,
            'reason',
            AuthFailureReason.oauthRequired,
          ),
        ),
      );
    });

    test('a callback for a different scheme/host/path is rejected', () async {
      final launcher = _RecordingBrowserLauncher(
        (auth) => Uri.parse('com.localmail.client://evil/callback').replace(
          queryParameters: {
            'code': 'auth-code',
            'state': auth.queryParameters['state']!,
          },
        ),
      );
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        outlookClientId: 'outlook-client-id',
        browserLauncher: launcher,
      );

      await expectLater(
        service.authorize(
          providerType: MailProviderType.outlook,
          expectedEmail: 'bob@outlook.com',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.userMessage,
            'message',
            contains('回调地址不匹配'),
          ),
        ),
      );
    });

    test('refresh keeps canonical Outlook scopes in the request and bundle', () async {
      late Map<String, String> refreshForm;
      final service = OAuthPkceService(
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
        httpClient: MockClient((request) async {
          refreshForm = Uri.splitQueryString(request.body);
          return http.Response(
            jsonEncode({
              'access_token': 'new-outlook-token',
              'refresh_token': 'new-refresh-token',
              'scope':
                  'IMAP.AccessAsUser.All SMTP.Send offline_access openid email',
            }),
            200,
          );
        }),
      );
      final current = OAuthTokenBundle(
        accessToken: 'old-outlook-token',
        refreshToken: 'old-refresh-token',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        clientId: 'outlook-client-id',
        tokenEndpoint:
            'https://login.microsoftonline.com/common/oauth2/v2.0/token',
        scopes: OAuthProviderConfig.outlook.scopes,
      );

      final refreshed = await service.refreshToken(current);

      expect(
        refreshForm['scope'],
        contains('https://outlook.office.com/IMAP.AccessAsUser.All'),
      );
      expect(
        refreshForm['scope'],
        contains('https://outlook.office.com/SMTP.Send'),
      );
      expect(refreshed.scopes, OAuthProviderConfig.outlook.scopes);
    });
  });
}
