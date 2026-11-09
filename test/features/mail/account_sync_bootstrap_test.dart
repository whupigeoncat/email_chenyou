import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/network/connection_pool.dart';
import 'package:local_mail_client/features/mail/data/services/account_sync_bootstrap.dart';
import 'package:local_mail_client/features/mail/data/services/inbox_sync_coordinator.dart';
import 'package:local_mail_client/features/auth/domain/entities/account_setup_draft.dart';

import '../../core/support/fake_imap_session.dart';
import '../auth/support/fakes.dart';

void main() {
  test('bootstrap syncs existing enabled accounts once and new accounts after',
      () async {
    final auth = FakeAuthRepository();
    final existing = buildTestAccount(id: 'existing');
    auth.accounts.add(existing);
    final pool = ConnectionPool(
      sessionFactory: FakeImapSessionFactory(),
      credentialResolver: fakeCredentialResolver,
    );
    final synced = <String>[];
    final coordinator = InboxSyncCoordinator(
      connectionPool: pool,
      syncAccount: (accountId) async => synced.add(accountId),
    );
    final bootstrap = AccountSyncBootstrap(
      authRepository: auth,
      syncCoordinator: coordinator,
    );
    addTearDown(() async {
      await bootstrap.dispose();
      await coordinator.dispose();
      await pool.dispose();
      await auth.dispose();
    });

    await bootstrap.start();
    expect(synced, <String>['existing']);

    final added = await auth.addAccount(
      draft: buildDraft(email: 'new@163.com'),
      credential: const PasswordAccountCredential('code'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(synced, contains(added.id));
  });
}
