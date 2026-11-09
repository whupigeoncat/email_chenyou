import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/core/network/connection_pool.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/mail/data/datasources/mail_remote_datasource.dart';
import 'package:local_mail_client/features/mail/data/repositories/mail_remote_repository.dart';
import 'package:local_mail_client/features/mail/domain/usecases/sync_inbox_usecase.dart';
import 'package:local_mail_client/features/mail/domain/usecases/poll_folder_usecase.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/features/mail/domain/usecases/download_attachment_usecase.dart';
import 'package:local_mail_client/features/mail/domain/usecases/fetch_message_body_usecase.dart';
import 'package:local_mail_client/features/mail/domain/usecases/update_email_flags_usecase.dart';

import '../../core/support/fake_imap_session.dart';
import 'support/mail_fixture.dart';

RemoteFetchedMessage msg(
  int uid, {
  List<String> flags = const [],
  String? plainBody,
}) => RemoteFetchedMessage(
  uid: uid,
  subject: 'Remote $uid',
  fromName: 'Sender',
  fromAddress: 'sender@example.com',
  sentAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: uid)),
  flags: flags,
  plainBody: plainBody,
);

void main() {
  late MailFixture fixture;
  late FakeImapSessionFactory factory;
  late ConnectionPool pool;
  late MailRemoteRepository remote;
  late SyncInboxUseCase sync;
  setUp(() async {
    fixture = await MailFixture.create(bodyDownloaded: false);
    factory = FakeImapSessionFactory(
      mailboxes: const [
        RemoteMailboxInfo(
          remoteName: 'INBOX',
          displayName: 'INBOX',
          attributes: ['inbox'],
        ),
      ],
    );
    pool = ConnectionPool(
      sessionFactory: factory,
      credentialResolver: fakeCredentialResolver,
    );
    await pool.syncAccounts([fixture.account]);
    await pool.connectAccount(fixture.account.id);
    remote = MailRemoteRepository(
      dataSource: MailRemoteDataSource(connectionPool: pool),
    );
    sync = SyncInboxUseCase(
      localRepository: fixture.localRepository,
      remoteRepository: remote,
    );
    await fixture.database
        .update(fixture.database.dbFolders)
        .write(const DbFoldersCompanion(uidValidity: Value(1)));
  });
  tearDown(() async {
    await pool.dispose();
    await fixture.dispose();
  });
  void server(List<RemoteFetchedMessage> messages, {int validity = 1}) {
    factory.headers['INBOX'] = messages;
    factory.statuses['INBOX'] = RemoteMailboxStatus(
      remoteName: 'INBOX',
      uidValidity: validity,
      messagesExists: messages.length,
    );
  }

  test(
    'history: load older downloads server messages beyond initial window',
    () async {
      await fixture.localRepository.clearFolderEmails(fixture.folder.id);
      server([for (var uid = 1; uid <= 100; uid++) msg(uid)]);
      await sync(fixture.account);
      expect(
        (await fixture.database.select(fixture.database.dbEmails).get()).length,
        50,
      );
      await PollFolderUseCase(
        localRepository: fixture.localRepository,
        remoteRepository: remote,
      )(account: fixture.account, folder: fixture.folder, loadOlder: true);
      final rows = await fixture.database
          .select(fixture.database.dbEmails)
          .get();
      expect(
        rows.length,
        100,
        reason:
            'All 100 exist remotely; only 50 are cached and no backfill exists',
      );
    },
  );
  Future<void> seed100() async {
    await fixture.localRepository.clearFolderEmails(fixture.folder.id);
    server([for (var uid = 1; uid <= 50; uid++) msg(uid)]);
    await sync(fixture.account);
    server([for (var uid = 1; uid <= 100; uid++) msg(uid)]);
    await sync(fixture.account);
  }

  test('other device read of old message should reconcile', () async {
    await seed100();
    server([
      for (var uid = 1; uid <= 100; uid++)
        msg(uid, flags: uid == 10 ? [r'\Seen'] : []),
    ]);
    await sync(fixture.account);
    expect(
      (await fixture.localRepository.getEmailByUid(
        fixture.folder.id,
        10,
      ))!.isRead,
      isTrue,
    );
  });
  test('other device deletion of old message should reconcile', () async {
    await seed100();
    server([
      for (var uid = 1; uid <= 100; uid++)
        if (uid != 11) msg(uid),
    ]);
    await sync(fixture.account);
    expect(
      await fixture.localRepository.getEmailByUid(fixture.folder.id, 11),
      isNull,
    );
  });
  test(
    'UIDVALIDITY reset must not overwrite old local email with reused UID',
    () async {
      server([
        msg(1, plainBody: 'Different message after UID reset'),
      ], validity: 2);
      factory.fullMessages[1] = msg(
        1,
        plainBody: 'Different message after UID reset',
      );
      final old = await fixture.localRepository.getEmail(fixture.emailLocalId);
      await expectLater(
        FetchMessageBodyUseCase(
          localRepository: fixture.localRepository,
          remoteRepository: remote,
        )(account: fixture.account, emailLocalId: fixture.emailLocalId),
        throwsA(
          isA<ImapProtocolFailure>().having(
            (error) => error.reason,
            'reason',
            ImapFailureReason.uidValidityChanged,
          ),
        ),
      );
      expect(factory.uidFetchFullCalls, 0);
      final after = await fixture.localRepository.getEmail(
        fixture.emailLocalId,
      );
      expect(
        after?.subject,
        old!.subject,
        reason: 'A stale UID must trigger resync, not fetch a different message into the old row',
      );
    },
  );
  test('reply from different sender account must not STORE on that account mailbox', () async {
    final wrongAccount = buildTestAccount(
      id: 'other-account',
      email: 'other@gmail.com',
    );
    await pool.syncAccounts([fixture.account, wrongAccount]);
    await pool.connectAccount(wrongAccount.id);
    await expectLater(
      UpdateEmailFlagsUseCase(
        localRepository: fixture.localRepository,
        remoteRepository: remote,
      )(
        account: wrongAccount,
        emailLocalId: fixture.emailLocalId,
        isAnswered: true,
      ),
      throwsA(isA<StorageFailure>()),
    );
    final wrongSession = factory.sessions.last;
    expect(
      factory.protocolLog.where(
        (line) => line.startsWith('flags:${wrongSession.index}:'),
      ),
      isEmpty,
      reason:
          'Post-send hook passes sender B for an origin email belonging to A',
    );
  });
  test('UID reset blocks attachment fetch and remote flag writes', () async {
    server([msg(1)], validity: 2);
    await fixture.database
        .into(fixture.database.dbAttachments)
        .insert(
          DbAttachmentsCompanion.insert(
            id: 'attachment',
            emailLocalId: fixture.emailLocalId,
            partId: '2',
            filename: 'test.txt',
            mimeType: 'text/plain',
            sizeBytes: 10,
          ),
        );
    await expectLater(
      DownloadAttachmentUseCase(
        localRepository: fixture.localRepository,
        remoteRepository: remote,
      )(
        account: fixture.account,
        emailLocalId: fixture.emailLocalId,
        partId: '2',
      ),
      throwsA(isA<ImapProtocolFailure>()),
    );
    await expectLater(
      UpdateEmailFlagsUseCase(
        localRepository: fixture.localRepository,
        remoteRepository: remote,
      )(
        account: fixture.account,
        emailLocalId: fixture.emailLocalId,
        isRead: true,
      ),
      throwsA(isA<ImapProtocolFailure>()),
    );
    expect(factory.attachmentFetchCalls, 0);
    expect(factory.flagStoreCalls, 0);
    expect(
      (await fixture.localRepository.getEmail(fixture.emailLocalId))!.isRead,
      isFalse,
    );
  });

  test(
    'full cache reconciliation batches requests to at most 500 UIDs',
    () async {
      final uids = {for (var uid = 1; uid <= 1201; uid++) uid};
      server([for (final uid in uids) msg(uid)]);
      final result = await remote.syncFolder(
        account: fixture.account,
        folder: fixture.folder.copyWith(uidValidity: 1),
        localMaxUid: 1201,
        localUids: uids,
      );
      expect(factory.flagFetchBatchSizes, [500, 500, 201]);
      expect(result.reconciledFlags.length, 1201);
    },
  );

  test(
    'UID reset while loading history rebuilds instead of merging generations',
    () async {
      await seed100();
      server([msg(1), msg(2)], validity: 2);
      await PollFolderUseCase(
        localRepository: fixture.localRepository,
        remoteRepository: remote,
      )(account: fixture.account, folder: fixture.folder, loadOlder: true);
      final rows = await fixture.database
          .select(fixture.database.dbEmails)
          .get();
      expect(rows.map((row) => row.uid), [1, 2]);
    },
  );
  test('concurrent flag changes preserve independent bits', () async {
    server([msg(1)]);
    final update = UpdateEmailFlagsUseCase(
      localRepository: fixture.localRepository,
      remoteRepository: remote,
    );
    await Future.wait([
      update(
        account: fixture.account,
        emailLocalId: fixture.emailLocalId,
        isRead: true,
      ),
      update(
        account: fixture.account,
        emailLocalId: fixture.emailLocalId,
        isFlagged: true,
      ),
    ]);
    final email = (await fixture.localRepository.getEmail(
      fixture.emailLocalId,
    ))!;
    expect(email.isRead, isTrue);
    expect(email.isFlagged, isTrue);
    expect(factory.flagStores.map((entry) => entry.$2.single), [
      r'\Seen',
      r'\Flagged',
    ]);
  });
}
