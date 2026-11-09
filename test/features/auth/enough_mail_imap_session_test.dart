import 'dart:async';

import 'package:enough_mail/enough_mail.dart' hide MailAccount;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/logging/sanitized_logger.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/mail/data/datasources/enough_mail_imap_session.dart';

import '../../core/support/fake_imap_session.dart';
import 'support/fakes.dart';

void main() {
  group('NetEase RFC 2971 ID protocol order', () {
    test(
      '163 executes auth -> ID -> selectInbox in exactly that order',
      () async {
        final client = FakeImapClient();
        final session = EnoughMailImapSession(client: client);
        final account = buildTestAccount(id: 'netease', email: 'carol@163.com');

        await session.connectAndAuthenticate(
          account: account,
          credential: const PasswordCredential('163-auth-code'),
        );
        await session.selectFolder('INBOX');

        expect(client.protocol, <String>[
          'connect',
          'login',
          'id',
          'selectInbox',
        ], reason: 'ID must be sent after auth and before SELECT INBOX');
        expect(client.lastClientId, isNotNull);
        expect(client.lastClientId!.name, 'LocalMailClient');

        await session.logoutAndDisconnect();
        expect(client.protocol, contains('logout'));
        expect(client.protocol.last, 'disconnect');
        expect(client.isConnected, isFalse);
      },
    );

    test(
      '126 and yeah.net use the same NetEase preset and ID sequence',
      () async {
        for (final email in <String>['carol@126.com', 'carol@yeah.net']) {
          final client = FakeImapClient();
          final session = EnoughMailImapSession(client: client);
          final account = buildTestAccount(id: email, email: email);

          expect(account.preset.requiresImapIdCommand, isTrue);
          await session.connectAndAuthenticate(
            account: account,
            credential: const PasswordCredential('auth-code'),
          );
          await session.selectFolder('INBOX');

          expect(client.protocol, <String>[
            'connect',
            'login',
            'id',
            'selectInbox',
          ], reason: '$email must send ID before SELECT');
          await session.logoutAndDisconnect();
        }
      },
    );

    test('Gmail does not send an unnecessary ID command', () async {
      final client = FakeImapClient();
      final session = EnoughMailImapSession(client: client);
      final account = buildTestAccount(email: 'alice@gmail.com');

      await session.connectAndAuthenticate(
        account: account,
        credential: const PasswordCredential('app-password'),
      );
      await session.selectFolder('INBOX');

      expect(client.protocol, <String>['connect', 'login', 'selectInbox']);
      await session.logoutAndDisconnect();
    });

    test('OAuth accounts authenticate with XOAUTH2 instead of LOGIN', () async {
      final client = FakeImapClient();
      final session = EnoughMailImapSession(client: client);
      final account = buildTestAccount(email: 'alice@gmail.com')
          .copyWith(authType: MailAuthType.oauth2Pkce);

      await session.connectAndAuthenticate(
        account: account,
        credential: OAuthCredential(
          accessToken: 'oauth-access-token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      expect(client.protocol, <String>['connect', 'oauth']);
      await session.logoutAndDisconnect();
    });
  });

  group('STARTTLS upgrade order', () {
    test('non-implicit TLS runs STARTTLS before LOGIN', () async {
      final client = FakeImapClient(startTlsSupported: true);
      final session = EnoughMailImapSession(client: client);
      final account = buildTestAccount(email: 'alice@gmail.com')
          .copyWith(imapImplicitTls: false);

      await session.connectAndAuthenticate(
        account: account,
        credential: const PasswordCredential('app-password'),
      );

      expect(client.protocol, <String>['connect', 'capability', 'startTls', 'login']);
      await session.logoutAndDisconnect();
    });

    test('non-implicit TLS fails closed when STARTTLS is not advertised',
        () async {
      final client = FakeImapClient(startTlsSupported: false);
      final session = EnoughMailImapSession(client: client);
      final account = buildTestAccount(email: 'alice@gmail.com')
          .copyWith(imapImplicitTls: false);

      await expectLater(
        session.connectAndAuthenticate(
          account: account,
          credential: const PasswordCredential('must-not-be-sent'),
        ),
        throwsA(isA<ImapProtocolFailure>()),
      );
      expect(client.protocol, contains('capability'));
      expect(client.protocol, isNot(contains('login')));
      expect(client.protocol, isNot(contains('oauth')));
    });

    test('implicit TLS never sends STARTTLS', () async {
      final client = FakeImapClient(startTlsSupported: true);
      final session = EnoughMailImapSession(client: client);
      final account = buildTestAccount(email: 'alice@gmail.com');

      await session.connectAndAuthenticate(
        account: account,
        credential: const PasswordCredential('app-password'),
      );

      expect(client.protocol, <String>['connect', 'login']);
      expect(client.protocol, isNot(contains('startTls')));
      await session.logoutAndDisconnect();
    });
  });

  group('ImapException Chinese failure mapping', () {
    late FakeImapClient client;

    setUp(() {
      client = FakeImapClient();
    });

    test('Unsafe Login maps to the RFC 2971 insertion failure', () {
      final failure = mapImapExceptionToFailure(
        ImapException(client, 'Unsafe Login. Please contact kefu@188.com'),
      );
      expect(failure, isA<ImapProtocolFailure>());
      expect(
        (failure as ImapProtocolFailure).reason,
        ImapFailureReason.unsafeLoginMissingId,
      );
      expect(failure.userMessage, contains('Unsafe Login'));
    });

    test('connection quota maps to tooManyConnections', () {
      final failure = mapImapExceptionToFailure(
        ImapException(client, 'Too many simultaneous connections'),
      );
      expect(
        (failure as ImapProtocolFailure).reason,
        ImapFailureReason.tooManyConnections,
      );
      expect(failure.userMessage, contains('同时连接数'));
    });

    test(
      'bad auth code maps to invalidCredentials with authorization-code hint',
      () {
        final failure = mapImapExceptionToFailure(
          ImapException(client, 'LOGIN failed: invalid credentials'),
          authType: MailAuthType.passwordOrAuthCode,
        );
        expect(failure, isA<AuthFailure>());
        expect(
          (failure as AuthFailure).reason,
          AuthFailureReason.invalidCredentials,
        );
        expect(failure.userMessage, contains('授权码'));
      },
    );

    test('OAuth rejection maps to oauthTokenExpired', () {
      final failure = mapImapExceptionToFailure(
        ImapException(client, 'AUTHENTICATE failed: invalid token'),
        authType: MailAuthType.oauth2Pkce,
      );
      expect(
        (failure as AuthFailure).reason,
        AuthFailureReason.oauthTokenExpired,
      );
      expect(failure.userMessage, contains('重新授权'));
    });

    test('disabled IMAP maps to imapDisabled', () {
      final failure = mapImapExceptionToFailure(
        ImapException(client, 'IMAP access is disabled for this account'),
      );
      expect((failure as AuthFailure).reason, AuthFailureReason.imapDisabled);
      expect(failure.userMessage, contains('IMAP'));
    });

    test('timeout and closed socket map to typed protocol failures', () {
      final timeout = mapImapExceptionToFailure(
        TimeoutException('connection timed out'),
      );
      expect(
        (timeout as ImapProtocolFailure).reason,
        ImapFailureReason.timeout,
      );

      final closed = mapImapExceptionToFailure(
        ImapException(client, 'Connection closed by remote host'),
      );
      expect(
        (closed as ImapProtocolFailure).reason,
        ImapFailureReason.connectionClosed,
      );
    });
  });

  group('sanitized wire logging', () {
    test('SanitizedImapClient never forwards raw LOGIN secrets', () {
      final logger = SanitizedLogger.instance;
      logger.clear();
      final client = SanitizedImapClient(logger: logger, isLogEnabled: true);

      client.log('A1 LOGIN alice@163.com super-secret-auth-code');

      final joined = logger.recentEntries.join('\n');
      expect(joined, isNot(contains('super-secret-auth-code')));
      expect(joined, contains('[REDACTED_SECRET]'));
    });
  });

  test('supportsIdle reflects advertised capability', () async {
    final withoutIdle = FakeImapClient();
    final sessionWithout = EnoughMailImapSession(client: withoutIdle);
    await sessionWithout.connectAndAuthenticate(
      account: buildTestAccount(email: 'carol@163.com'),
      credential: const PasswordCredential('auth-code'),
    );
    expect(sessionWithout.supportsIdle, isFalse);
    await expectLater(
      sessionWithout.startIdle(),
      throwsA(
        isA<ImapProtocolFailure>().having(
          (failure) => failure.userMessage,
          'userMessage',
          contains('轮询模式'),
        ),
      ),
    );
    await sessionWithout.logoutAndDisconnect();

    final withIdle = FakeImapClient(supportsIdle: true);
    final sessionWith = EnoughMailImapSession(client: withIdle);
    await sessionWith.connectAndAuthenticate(
      account: buildTestAccount(email: 'alice@gmail.com'),
      credential: const PasswordCredential('app-password'),
    );
    expect(sessionWith.supportsIdle, isTrue);
    await sessionWith.logoutAndDisconnect();
  });

}
