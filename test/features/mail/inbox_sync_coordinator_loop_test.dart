import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/network/connection_pool.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/mail/data/services/inbox_sync_coordinator.dart';

import '../../core/support/fake_imap_session.dart';

void main() {
  test('self-generated EXISTS during sync does not start a sync loop', () async {
    final factory = FakeImapSessionFactory();
    final account = buildTestAccount(id: 'loop-account');
    final pool = ConnectionPool(
      sessionFactory: factory,
      credentialResolver: fakeCredentialResolver,
    );
    await pool.syncAccounts(<MailAccount>[account]);
    await pool.connectAccount(account.id);
    final session = factory.sessions.first;
    var syncCount = 0;
    final coordinator = InboxSyncCoordinator(
      connectionPool: pool,
      debounce: const Duration(milliseconds: 10),
      syncAccount: (accountId) async {
        syncCount++;
        session.emit(
          ImapMailboxMessagesAdded(existsCount: syncCount),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      },
    );
    addTearDown(() async {
      await coordinator.dispose();
      await pool.dispose();
    });
    coordinator.start();

    session.emit(const ImapMailboxMessagesAdded(existsCount: 1));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(syncCount, 1, reason: 'sync-generated EXISTS must be ignored');
  });
}
