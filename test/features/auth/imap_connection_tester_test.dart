import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/auth/data/imap_connection_tester.dart';
import 'package:local_mail_client/features/mail/data/datasources/enough_mail_imap_session.dart';

import '../../core/support/fake_imap_session.dart';
import 'support/fakes.dart';

void main() {
  group('ImapConnectionTester', () {
    test(
      'tests 163 draft as connect -> auth -> ID -> INBOX -> LOGOUT',
      () async {
        final client = FakeImapClient();
        final tester = ImapConnectionTester(
          sessionFactory: EnoughMailImapSessionFactory(
            clientFactory: () => client,
          ),
        );
        final account = buildTestAccount(
          id: 'netease-draft',
          email: 'carol@163.com',
        );

        final result = await tester.testConnection(
          account: account,
          credential: const PasswordCredential('auth-code'),
        );

        expect(result.selectedFolder, 'INBOX');
        expect(client.protocol, <String>[
          'connect',
          'login',
          'id',
          'selectInbox',
          'logout',
          'disconnect',
        ]);
        expect(client.isConnected, isFalse);
      },
    );

    test('success always sends LOGOUT and disconnects in finally', () async {
      final client = FakeImapClient();
      final tester = ImapConnectionTester(
        sessionFactory: EnoughMailImapSessionFactory(
          clientFactory: () => client,
        ),
      );

      await tester.testConnection(
        account: buildTestAccount(email: 'alice@gmail.com'),
        credential: const PasswordCredential('app-password'),
      );

      expect(client.protocol.where((step) => step == 'logout'), hasLength(1));
      expect(
        client.protocol.where((step) => step == 'disconnect'),
        hasLength(1),
      );
      expect(client.isConnected, isFalse);
    });

    test(
      'failure after authentication still sends LOGOUT and disconnects',
      () async {
        final client = FakeImapClient(failOnSelect: true);
        final tester = ImapConnectionTester(
          sessionFactory: EnoughMailImapSessionFactory(
            clientFactory: () => client,
          ),
        );

        await expectLater(
          tester.testConnection(
            account: buildTestAccount(email: 'carol@163.com'),
            credential: const PasswordCredential('auth-code'),
          ),
          throwsA(isA<ImapProtocolFailure>()),
        );

        expect(client.protocol, contains('login'));
        expect(client.protocol, contains('logout'));
        expect(client.protocol, contains('disconnect'));
        expect(client.isConnected, isFalse);
      },
    );

    test('connect failure still tears the socket down in finally', () async {
      final client = FakeImapClient(failOnConnect: true);
      final tester = ImapConnectionTester(
        sessionFactory: EnoughMailImapSessionFactory(
          clientFactory: () => client,
        ),
      );

      await expectLater(
        tester.testConnection(
          account: buildTestAccount(email: 'carol@163.com'),
          credential: const PasswordCredential('auth-code'),
        ),
        throwsA(isA<ImapProtocolFailure>()),
      );

      expect(client.protocol, contains('disconnect'));
      expect(client.isConnected, isFalse);
    });

    test('uses the draft parameters without persisting an account', () async {
      final client = FakeImapClient();
      final tester = ImapConnectionTester(
        sessionFactory: EnoughMailImapSessionFactory(
          clientFactory: () => client,
        ),
      );
      final account = buildTestAccount(
        id: 'draft-only',
        email: 'dave@qq.com',
      ).copyWith(imapHost: 'imap.qq.com', imapPort: 993);

      await tester.testConnection(
        account: account,
        credential: const PasswordCredential('qq-auth-code'),
      );

      expect(account.id, 'draft-only');
      expect(client.protocol.first, 'connect');
      expect(client.protocol, contains('logout'));
    });
  });
}
