import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/core/security/secure_storage_service.dart';
import 'package:local_mail_client/features/auth/data/account_credential_resolver.dart';

import '../../core/support/fake_imap_session.dart';
import 'support/fakes.dart';

OAuthTokenBundle _bundle({
  required String accessToken,
  required DateTime expiresAt,
  String refreshToken = 'refresh-token',
}) {
  return OAuthTokenBundle(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: expiresAt,
    clientId: 'client-id',
    tokenEndpoint: 'https://oauth2.googleapis.com/token',
    scopes: const ['https://mail.google.com/'],
  );
}

OAuthTokenBundle _deviceBundle({
  required String email,
  required String accessToken,
  DateTime? expiresAt,
}) {
  return OAuthTokenBundle(
    accessToken: accessToken,
    refreshToken: null,
    expiresAt:
        expiresAt ??
        DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
    clientId: '',
    tokenEndpoint: '',
    scopes: const ['https://mail.google.com/'],
    accountEmail: email,
    deviceAuthorization: true,
  );
}

void main() {
  group('AccountCredentialResolver', () {
    test('reads password authorization codes just-in-time', () async {
      final storage = InMemorySecureStorageService();
      final resolver = AccountCredentialResolver(
        secureStorage: storage,
        oauthPkceService: FakeOAuthPkceService(),
      );
      final account = buildTestAccount(email: 'carol@163.com');
      await storage.savePasswordSecret(account.id, 'auth-code-123');

      final credential = await resolver(account);

      expect(credential, isA<PasswordCredential>());
      expect((credential as PasswordCredential).secret, 'auth-code-123');
    });

    test('missing authorization code is a typed AuthFailure', () async {
      final resolver = AccountCredentialResolver(
        secureStorage: InMemorySecureStorageService(),
        oauthPkceService: FakeOAuthPkceService(),
      );

      await expectLater(
        resolver(buildTestAccount(email: 'carol@163.com')),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.reason,
            'reason',
            AuthFailureReason.authorizationCodeRequired,
          ),
        ),
      );
    });

    test('does not refresh an OAuth token that is still valid', () async {
      final storage = InMemorySecureStorageService();
      final oauth = FakeOAuthPkceService();
      final resolver = AccountCredentialResolver(
        secureStorage: storage,
        oauthPkceService: oauth,
      );
      final account = buildTestAccount(email: 'alice@gmail.com')
          .copyWith(authType: MailAuthType.oauth2Pkce);
      await storage.saveOAuthTokens(
        account.id,
        _bundle(
          accessToken: 'valid-token',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );

      final credential = await resolver(account);

      expect(credential, isA<OAuthCredential>());
      expect((credential as OAuthCredential).accessToken, 'valid-token');
      expect(oauth.refreshCount, 0);
    });

    test('two concurrent resolutions of an expiring token perform exactly one refresh', () async {
      final storage = InMemorySecureStorageService();
      final oauth = FakeOAuthPkceService(
        refreshDelay: const Duration(milliseconds: 25),
      );
      final resolver = AccountCredentialResolver(
        secureStorage: storage,
        oauthPkceService: oauth,
      );
      final account = buildTestAccount(email: 'alice@gmail.com')
          .copyWith(authType: MailAuthType.oauth2Pkce);
      await storage.saveOAuthTokens(
        account.id,
        _bundle(
          accessToken: 'expired-token',
          expiresAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 5),
          ),
        ),
      );

      final results = await Future.wait([resolver(account), resolver(account)]);

      expect(oauth.refreshCount, 1, reason: 'refresh must be serialized');
      final tokens = results
          .map((credential) => (credential as OAuthCredential).accessToken)
          .toList();
      expect(tokens, everyElement('refreshed-access-token-1'));

      final persisted = storage.oauthBundles[account.id];
      expect(persisted, isNotNull);
      expect(persisted!.accessToken, 'refreshed-access-token-1');
      expect(persisted.expiresAt.isAfter(DateTime.now().toUtc()), isTrue);
    });

    test('OAuth account without tokens surfaces oauthRequired', () async {
      final resolver = AccountCredentialResolver(
        secureStorage: InMemorySecureStorageService(),
        oauthPkceService: FakeOAuthPkceService(),
      );
      final account = buildTestAccount(email: 'alice@gmail.com')
          .copyWith(authType: MailAuthType.oauth2Pkce);

      await expectLater(
        resolver(account),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.reason,
            'reason',
            AuthFailureReason.oauthRequired,
          ),
        ),
      );
    });

    test(
      'expired device authorization renews through the platform and persists',
      () async {
        final storage = InMemorySecureStorageService();
        final oauth = FakeOAuthPkceService();
        final resolver = AccountCredentialResolver(
          secureStorage: storage,
          oauthPkceService: oauth,
        );
        final account = buildTestAccount(email: 'alice@gmail.com')
            .copyWith(authType: MailAuthType.oauth2Pkce);
        await storage.saveOAuthTokens(
          account.id,
          _deviceBundle(
            email: 'alice@gmail.com',
            accessToken: 'expired-device',
          ),
        );

        final credential = await resolver(account) as OAuthCredential;

        expect(credential.accessToken, 'device-refreshed-token-1');
        expect(oauth.deviceRefreshCount, 1);
        expect(oauth.refreshCount, 0);
        expect(oauth.deviceRefreshEmails, ['alice@gmail.com']);
        final persisted = storage.oauthBundles[account.id]!;
        expect(persisted.deviceAuthorization, isTrue);
        expect(persisted.accountEmail, 'alice@gmail.com');
      },
    );

    test('each Google account renews with its own bound email', () async {
      final storage = InMemorySecureStorageService();
      final oauth = FakeOAuthPkceService();
      final resolver = AccountCredentialResolver(
        secureStorage: storage,
        oauthPkceService: oauth,
      );
      final alice = buildTestAccount(
        id: 'acc-alice',
        email: 'alice@gmail.com',
      ).copyWith(authType: MailAuthType.oauth2Pkce);
      final bob = buildTestAccount(
        id: 'acc-bob',
        email: 'bob@gmail.com',
      ).copyWith(authType: MailAuthType.oauth2Pkce);
      await storage.saveOAuthTokens(
        alice.id,
        _deviceBundle(email: alice.email, accessToken: 'alice-expired'),
      );
      await storage.saveOAuthTokens(
        bob.id,
        _deviceBundle(email: bob.email, accessToken: 'bob-expired'),
      );

      await Future.wait([resolver(alice), resolver(bob)]);

      expect(
        oauth.deviceRefreshEmails,
        containsAll(['alice@gmail.com', 'bob@gmail.com']),
      );
      expect(
        storage.oauthBundles[alice.id]!.accessToken,
        'device-refreshed-token-1',
      );
      expect(
        storage.oauthBundles[bob.id]!.accessToken,
        'device-refreshed-token-2',
      );
    });
  });
}
