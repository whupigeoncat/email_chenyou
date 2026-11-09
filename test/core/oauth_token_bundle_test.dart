import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/security/secure_storage_service.dart';

void main() {
  group('OAuthTokenBundle storage compatibility', () {
    test(
      'reads the legacy JSON written before device authorization existed',
      () {
        final legacy = jsonDecode(
          jsonEncode({
            'accessToken': 'legacy-access',
            'refreshToken': 'legacy-refresh',
            'expiresAt': '2030-01-01T00:00:00.000Z',
            'clientId': 'legacy-client',
            'tokenEndpoint': 'https://oauth.example.invalid/token',
            'scopes': ['mail'],
          }),
        ) as Map<String, dynamic>;

        final bundle = OAuthTokenBundle.fromJson(legacy);

        expect(bundle.accessToken, 'legacy-access');
        expect(bundle.refreshToken, 'legacy-refresh');
        expect(bundle.clientId, 'legacy-client');
        expect(bundle.accountEmail, isNull);
        expect(bundle.deviceAuthorization, isFalse);
      },
    );

    test('round-trips device authorization fields', () {
      final original = OAuthTokenBundle(
        accessToken: 'device-access',
        refreshToken: null,
        expiresAt: DateTime.utc(2030, 1, 1),
        clientId: '',
        tokenEndpoint: '',
        scopes: const ['https://mail.google.com/'],
        accountEmail: 'alice@gmail.com',
        deviceAuthorization: true,
      );

      final restored = OAuthTokenBundle.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored.accountEmail, 'alice@gmail.com');
      expect(restored.deviceAuthorization, isTrue);
      expect(restored.refreshToken, isNull);
    });
  });
}
