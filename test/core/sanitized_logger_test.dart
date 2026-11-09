import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/logging/sanitized_logger.dart';

void main() {
  final logger = SanitizedLogger.instance;

  setUp(logger.clear);
  tearDown(logger.clear);

  group('SanitizedLogger.sanitize', () {
    test('redacts IMAP LOGIN users and secrets (quoted and atom forms)', () {
      const secret = 'S3cr3t-Passw0rd!';
      const user = 'alice@example.com';
      final inputs = <String>[
        'A1 LOGIN $user $secret',
        'A2 LOGIN "$user" "$secret"',
        'C: a3 login $user $secret',
      ];

      for (final raw in inputs) {
        final output = SanitizedLogger.sanitize(raw);
        expect(output, isNot(contains(secret)), reason: raw);
        expect(output, contains('[REDACTED_SECRET]'), reason: raw);
        expect(output, isNot(contains(user)), reason: raw);
        expect(output, contains('[REDACTED_USER]'), reason: raw);
      }
    });

    test('redacts AUTHENTICATE XOAUTH2 and AUTH PLAIN/LOGIN blobs', () {
      const oauthToken = 'ya29.a0AfH6SMBx9Kq7_token-value';
      const plainBlob = 'AHVzZXIAcGFzc3dvcmQ=';
      const loginUserBlob = 'dXNlcg==';
      const loginPasswordBlob = 'cGFzcw==';

      final oauth = SanitizedLogger.sanitize(
        'A4 AUTHENTICATE XOAUTH2 $oauthToken',
      );
      expect(oauth, isNot(contains(oauthToken)));
      expect(oauth, contains('[REDACTED_TOKEN]'));

      final plain = SanitizedLogger.sanitize('A5 AUTH PLAIN $plainBlob');
      expect(plain, isNot(contains(plainBlob)));
      expect(plain, contains('[REDACTED_TOKEN]'));

      final login = SanitizedLogger.sanitize(
        'A6 AUTH LOGIN $loginUserBlob $loginPasswordBlob',
      );
      expect(login, isNot(contains(loginUserBlob)));
      expect(login, isNot(contains(loginPasswordBlob)));
      expect(login, contains('[REDACTED_SECRET]'));
    });

    test('redacts Authorization Bearer and Basic headers', () {
      const bearer =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature';
      const basic = 'YWxpY2U6czNjcjN0';

      final bearerOutput = SanitizedLogger.sanitize(
        'Authorization: Bearer $bearer',
      );
      expect(bearerOutput, isNot(contains(bearer)));
      expect(bearerOutput, contains('[REDACTED_AUTH]'));

      final basicOutput = SanitizedLogger.sanitize(
        'Authorization: Basic $basic',
      );
      expect(basicOutput, isNot(contains(basic)));
      expect(basicOutput, contains('[REDACTED_AUTH]'));
    });

    test('redacts JSON secrets but keeps benign OAuth metadata', () {
      const oauthToken = 'ya29.json-access-token';
      const refreshToken = 'refresh-token-value';
      const clientSecret = 'client-secret-value';
      const password = 'password-value';
      const genericToken = 'generic-token-value';

      final payload = jsonEncode(<String, Object>{
        'access_token': oauthToken,
        'refresh_token': refreshToken,
        'client_secret': clientSecret,
        'password': password,
        'token': genericToken,
        'token_type': 'Bearer',
        'expires_in': 3599,
      });

      final output = SanitizedLogger.sanitize(payload);
      for (final secret in <String>[
        oauthToken,
        refreshToken,
        clientSecret,
        password,
        genericToken,
      ]) {
        expect(output, isNot(contains(secret)), reason: secret);
      }
      expect(output, contains('"token_type":"Bearer"'));
      expect(output, contains('"expires_in":3599'));
    });

    test('redacts camelCase JSON token fields', () {
      const accessToken = 'camel-access-token';
      const refreshToken = 'camel-refresh-token';
      const clientSecret = 'camel-client-secret';

      final payload = jsonEncode(<String, Object>{
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'clientSecret': clientSecret,
        'expiresAt': '2026-11-08T00:00:00Z',
      });

      final output = SanitizedLogger.sanitize(payload);
      expect(output, isNot(contains(accessToken)));
      expect(output, isNot(contains(refreshToken)));
      expect(output, isNot(contains(clientSecret)));
      expect(output, contains('"expiresAt":"2026-11-08T00:00:00Z"'));
    });

    test('redacts URL query / form-urlencoded secrets', () {
      const url = 'https://example.test/callback'
          '?code=auth-code-value'
          '&state=state-ok'
          '&access_token=ya29.url-access-token'
          '&refresh_token=url-refresh-token'
          '&client_secret=url-client-secret'
          '&password=url-password'
          '&token=url-generic-token'
          '&token_type=Bearer';

      final output = SanitizedLogger.sanitize(url);
      for (final secret in <String>[
        'auth-code-value',
        'ya29.url-access-token',
        'url-refresh-token',
        'url-client-secret',
        'url-password',
        'url-generic-token',
      ]) {
        expect(output, isNot(contains(secret)), reason: secret);
      }
      expect(output, contains('state=state-ok'));
      expect(output, contains('token_type=Bearer'));
    });

    test('leaves non-secret diagnostics intact', () {
      const benign =
          'IMAP IDLE active for alice@example.com; token_type=Bearer; '
          'folder=INBOX';
      expect(SanitizedLogger.sanitize(benign), benign);
    });
  });

  group('SanitizedLogger buffer', () {
    test('never retains raw credentials in recentEntries', () {
      const loginSecret = 'buffer-login-secret';
      const oauthToken = 'buffer-oauth-token';
      const refreshToken = 'buffer-refresh-token';
      const clientSecret = 'buffer-client-secret';

      logger.info('Imap', 'A1 LOGIN alice@example.com $loginSecret');
      logger.warn('OAuth', 'Authorization: Bearer $oauthToken');
      logger.error(
        'OAuth',
        'token response {"refresh_token":"$refreshToken",'
            '"client_secret":"$clientSecret"}',
      );

      final buffer = logger.recentEntries.join('\n');
      expect(logger.recentEntries, hasLength(3));
      for (final secret in <String>[
        loginSecret,
        oauthToken,
        refreshToken,
        clientSecret,
      ]) {
        expect(buffer, isNot(contains(secret)), reason: secret);
      }
      expect(buffer, contains('[REDACTED_SECRET]'));
      expect(buffer, contains('[REDACTED_AUTH]'));
      expect(buffer, contains('"client_secret":"[REDACTED]"'));
    });

    test('clear() drops all diagnostic entries', () {
      logger.info('Imap', 'A1 LOGIN alice@example.com secret-value');
      expect(logger.recentEntries, isNotEmpty);
      logger.clear();
      expect(logger.recentEntries, isEmpty);
    });
  });
}
