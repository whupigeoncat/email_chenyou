import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/core/network/account_connection_slot.dart';
import 'package:local_mail_client/core/network/connection_pool.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/datasources/mail_remote_datasource.dart';
import 'package:local_mail_client/features/mail/data/datasources/mail_local_datasource.dart';
import 'package:local_mail_client/features/mail/data/repositories/mail_local_repository.dart';
import 'package:local_mail_client/features/mail/data/repositories/mail_remote_repository.dart';
import 'package:local_mail_client/features/mail/data/services/inbox_sync_coordinator.dart';
import 'package:local_mail_client/features/mail/domain/entities/mail_folder.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';
import 'package:local_mail_client/features/mail/domain/usecases/download_attachment_usecase.dart';
import 'package:local_mail_client/features/mail/domain/usecases/fetch_message_body_usecase.dart';
import 'package:local_mail_client/features/mail/domain/usecases/poll_folder_usecase.dart';
import 'package:local_mail_client/features/mail/domain/usecases/sync_inbox_usecase.dart';
import 'package:local_mail_client/features/mail/domain/usecases/update_email_flags_usecase.dart';
import 'package:path/path.dart' as p;

import '../../core/support/fake_imap_session.dart';

const RemoteMailboxInfo _inboxInfo = RemoteMailboxInfo(
  remoteName: 'INBOX',
  displayName: 'INBOX',
  attributes: <String>['inbox'],
);
const RemoteMailboxInfo _sentInfo = RemoteMailboxInfo(
  remoteName: 'Sent',
  displayName: '已发送',
  attributes: <String>['sent'],
);

RemoteFetchedMessage _header(
  int uid, {
  String subject = 'Message',
  List<String> flags = const [],
  List<RemoteAttachmentMeta> attachments = const [],
}) {
  return RemoteFetchedMessage(
    uid: uid,
    subject: subject,
    fromName: 'Sender',
    fromAddress: 'sender@example.com',
    sentAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: uid)),
    flags: flags,
    attachments: attachments,
  );
}

Future<int> _insertEmail(
  AppDatabase db, {
  required String accountId,
  required String folderId,
  required int uid,
  int flagsBitmask = 0,
  bool bodyDownloaded = false,
}) {
  return db
      .into(db.dbEmails)
      .insert(
        DbEmailsCompanion.insert(
          accountId: accountId,
          folderId: folderId,
          uid: uid,
          subject: 'Subject $uid',
          fromName: 'Sender',
          fromAddress: 'sender@example.com',
          toRecipientsJson: '[]',
          ccJson: '[]',
          snippet: 'Snippet $uid',
          sentAt: 1700000000 + uid,
          flagsBitmask: Value(flagsBitmask),
          bodyDownloaded: Value(bodyDownloaded),
        ),
      );
}

Future<MailFolder> _insertFolder(
  AppDatabase db, {
  required String accountId,
  required String id,
  String remoteName = 'INBOX',
  FolderRole role = FolderRole.inbox,
  int? uidValidity,
}) async {
  await db
      .into(db.dbFolders)
      .insert(
        DbFoldersCompanion.insert(
          id: id,
          accountId: accountId,
          remoteName: remoteName,
          displayName: remoteName,
          role: role.storageKey,
          uidValidity: Value(uidValidity),
        ),
      );
  return MailFolder(
    id: id,
    accountId: accountId,
    remoteName: remoteName,
    displayName: remoteName,
    role: role,
    uidValidity: uidValidity,
  );
}

void main() {
  late AppDatabase db;
  late MailLocalRepository localRepository;
  late MailAccount account;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    localRepository = MailLocalRepository(
      dataSource: MailLocalDataSource(database: db),
    );
    account = buildTestAccount(id: 'acc-1', email: 'alice@gmail.com');
    await db
        .into(db.dbAccounts)
        .insert(
          DbAccountsCompanion.insert(
            id: account.id,
            email: account.email,
            displayName: account.displayName,
            providerType: account.providerType.storageKey,
            authType: account.authType.storageKey,
            colorValue: account.colorValue,
            imapHost: account.imapHost,
            imapPort: account.imapPort,
            imapImplicitTls: account.imapImplicitTls,
            smtpHost: account.smtpHost,
            smtpPort: account.smtpPort,
            smtpImplicitTls: account.smtpImplicitTls,
            isEnabled: Value(account.isEnabled),
            createdAt: account.createdAt.millisecondsSinceEpoch,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Future<(FakeImapSessionFactory, ConnectionPool, AccountConnectionSlot)>
  connectPool() async {
    final factory = FakeImapSessionFactory();
    final pool = ConnectionPool(
      sessionFactory: factory,
      credentialResolver: fakeCredentialResolver,
    );
    addTearDown(() async {
      await pool.dispose();
    });
    await pool.syncAccounts(<MailAccount>[account]);
    await pool.connectAccount(account.id);
    final slot = pool.slotFor(account.id);
    expect(slot, isNotNull);
    return (factory, pool, slot!);
  }

  MailRemoteRepository remoteRepository(ConnectionPool pool) =>
      MailRemoteRepository(
        dataSource: MailRemoteDataSource(connectionPool: pool),
      );

  test('UIDVALIDITY change clears the cached folder and re-pulls', () async {
    final (factory, pool, slot) = await connectPool();
    await _insertFolder(db, accountId: account.id, id: 'fa', uidValidity: 1);
    await _insertEmail(db, accountId: account.id, folderId: 'fa', uid: 10);

    factory.mailboxes = <RemoteMailboxInfo>[_inboxInfo];
    factory.statuses['INBOX'] = const RemoteMailboxStatus(
      remoteName: 'INBOX',
      uidValidity: 2,
      messagesExists: 1,
    );
    factory.headers['INBOX'] = <RemoteFetchedMessage>[
      _header(20, subject: 'Fresh message'),
    ];

    final useCase = SyncInboxUseCase(
      localRepository: localRepository,
      remoteRepository: remoteRepository(pool),
    );
    await useCase.call(account);

    final emails = await db.select(db.dbEmails).get();
    expect(emails.map((row) => row.uid), <int>[20]);
    final folder = await localRepository.getFolderById('fa');
    expect(folder!.uidValidity, 2);
    expect(
      factory.createdCount,
      1,
      reason: 'INBOX sync must reuse the IDLE socket',
    );
    expect(slot.persistentConnectCount, 1);
    expect(factory.listMailboxesCalls, 1);
  });

  test(
    'maxUid + 1:* echo of maxUid is discarded and not re-inserted',
    () async {
      final (factory, pool, _) = await connectPool();
      await _insertFolder(db, accountId: account.id, id: 'fa', uidValidity: 7);
      for (final uid in <int>[10, 11, 12]) {
        await _insertEmail(db, accountId: account.id, folderId: 'fa', uid: uid);
      }

      factory.mailboxes = <RemoteMailboxInfo>[_inboxInfo];
      factory.statuses['INBOX'] = const RemoteMailboxStatus(
        remoteName: 'INBOX',
        uidValidity: 7,
        messagesExists: 4,
      );
      factory.headers['INBOX'] = <RemoteFetchedMessage>[];
      factory.flagFetchResponse = {10: [], 11: [], 12: []};
      factory.uidFetchResponse = <RemoteFetchedMessage>[
        _header(12, subject: 'Echoed last message', flags: <String>[r'\Seen']),
        _header(13, subject: 'Brand new message'),
      ];

      final useCase = SyncInboxUseCase(
        localRepository: localRepository,
        remoteRepository: remoteRepository(pool),
      );
      await useCase.call(account);

      final emails = await db.select(db.dbEmails).get();
      emails.sort((a, b) => a.uid.compareTo(b.uid));
      expect(emails.map((row) => row.uid), <int>[10, 11, 12, 13]);
      final echoed = emails.firstWhere((row) => row.uid == 12);
      expect(
        echoed.flagsBitmask,
        0,
        reason: 'uid <= maxUid echo must be filtered before the local upsert',
      );
      expect(factory.uidFetchHeaderCalls, 1);
    },
  );

  test(
    'recent window reconciles flags and removes a deleted highest UID',
    () async {
      final (factory, pool, _) = await connectPool();
      await _insertFolder(db, accountId: account.id, id: 'fa', uidValidity: 1);
      await _insertEmail(db, accountId: account.id, folderId: 'fa', uid: 5);
      await _insertEmail(db, accountId: account.id, folderId: 'fa', uid: 6);

      factory.mailboxes = <RemoteMailboxInfo>[_inboxInfo];
      factory.statuses['INBOX'] = const RemoteMailboxStatus(
        remoteName: 'INBOX',
        uidValidity: 1,
        messagesExists: 1,
      );
      factory.headers['INBOX'] = <RemoteFetchedMessage>[
        _header(5, flags: <String>[r'\Seen']),
      ];
      factory.uidFetchResponse = <RemoteFetchedMessage>[];

      final useCase = SyncInboxUseCase(
        localRepository: localRepository,
        remoteRepository: remoteRepository(pool),
      );
      await useCase.call(account);

      final emails = await db.select(db.dbEmails).get();
      expect(emails.map((row) => row.uid), <int>[5]);
      expect(emails.single.flagsBitmask & UnifiedEmail.flagSeen, isNot(0));
    },
  );

  test(
    'non-INBOX polling uses a transient socket and LOGOUTs in finally',
    () async {
      final (factory, pool, slot) = await connectPool();
      final folders = await localRepository.upsertMailboxes(
        accountId: account.id,
        mailboxes: <RemoteMailboxInfo>[_sentInfo],
      );
      final sentFolder = folders.single;

      factory.statuses['Sent'] = const RemoteMailboxStatus(
        remoteName: 'Sent',
        uidValidity: 3,
        messagesExists: 1,
      );
      factory.headers['Sent'] = <RemoteFetchedMessage>[
        _header(5, subject: 'Sent item'),
      ];

      final useCase = PollFolderUseCase(
        localRepository: localRepository,
        remoteRepository: remoteRepository(pool),
      );
      await useCase.call(account: account, folder: sentFolder);

      expect(factory.createdCount, 3);
      expect(slot.activeTransientCount, 0);
      expect(slot.activePersistentCount, 1);
      final transient = factory.sessions[1];
      expect(transient.logoutCount, 1);
      expect(transient.isConnected, isFalse);
      expect(factory.sessions[2].isIdle, isTrue);
      expect(slot.transientConnectCount, 1);
      expect(slot.logoutSentCount, 2);
      expect(factory.maxConcurrentActiveCount, 1);
      final log = factory.protocolLog;
      expect(log.indexOf('logout:1') < log.indexOf('connect:2'), isTrue);
      expect(log.indexOf('logout:2') < log.indexOf('connect:3'), isTrue);
      expect(
        log.indexOf('logout:2'),
        greaterThan(log.indexOf('select:2:Sent')),
      );

      final sentEmails = await (db.select(
        db.dbEmails,
      )..where((table) => table.folderId.equals(sentFolder.id))).get();
      expect(sentEmails.map((row) => row.uid), <int>[5]);
    },
  );

  test(
    'body fetch downloads once, marks bodyDownloaded and reuses cache',
    () async {
      final (factory, pool, slot) = await connectPool();
      await _insertFolder(db, accountId: account.id, id: 'fa');
      final localId = await _insertEmail(
        db,
        accountId: account.id,
        folderId: 'fa',
        uid: 5,
      );

      factory.statuses['INBOX'] = const RemoteMailboxStatus(
        remoteName: 'INBOX',
        uidValidity: 1,
        messagesExists: 1,
      );
      factory.fullMessages[5] = RemoteFetchedMessage(
        uid: 5,
        subject: 'Subject 5',
        fromName: 'Sender',
        fromAddress: 'sender@example.com',
        sentAt: DateTime.utc(2026, 1, 2),
        flags: const <String>[],
        snippet: 'Full body snippet',
        plainBody: 'Full plain body',
        htmlBody: '<p>Full html body</p>',
      );

      final useCase = FetchMessageBodyUseCase(
        localRepository: localRepository,
        remoteRepository: remoteRepository(pool),
      );
      final first = await useCase.call(account: account, emailLocalId: localId);
      expect(first.bodyDownloaded, isTrue);
      expect(first.plainBody, 'Full plain body');
      expect(first.htmlBody, '<p>Full html body</p>');
      expect(factory.uidFetchFullCalls, 1);
      expect(slot.activeTransientCount, 0);
      expect(factory.createdCount, 1);
      expect(
        (await localRepository.searchEmails(query: 'plain'))
            .map((e) => e.localId),
        contains(localId),
        reason: 'body save must feed the FTS5 update trigger',
      );

      final second = await useCase.call(
        account: account,
        emailLocalId: localId,
      );
      expect(second.bodyDownloaded, isTrue);
      expect(factory.uidFetchFullCalls, 1, reason: 'second open is local-only');
    },
  );

  test(
    'attachment filename traversal is sanitized and cache hit skips network',
    () async {
      final (factory, pool, _) = await connectPool();
      await _insertFolder(db, accountId: account.id, id: 'fa');
      final localId = await _insertEmail(
        db,
        accountId: account.id,
        folderId: 'fa',
        uid: 7,
        bodyDownloaded: true,
      );
      await db
          .into(db.dbAttachments)
          .insert(
            DbAttachmentsCompanion.insert(
              id: 'att-1',
              emailLocalId: localId,
              partId: '1.2',
              filename: '../../evil name.pdf',
              mimeType: 'application/pdf',
              sizeBytes: 4,
            ),
          );

      factory.statuses['INBOX'] = const RemoteMailboxStatus(
        remoteName: 'INBOX',
        uidValidity: 1,
        messagesExists: 1,
      );
      factory.attachmentParts['7:1.2'] = Uint8List.fromList(<int>[1, 2, 3, 4]);

      final temp = await Directory.systemTemp.createTemp('mail_att_test_');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      final useCase = DownloadAttachmentUseCase(
        localRepository: localRepository,
        remoteRepository: remoteRepository(pool),
        temporaryDirectoryProvider: () async => temp,
      );

      final path = await useCase.call(
        account: account,
        emailLocalId: localId,
        partId: '1.2',
      );

      expect(path, isNot(contains('..')));
      expect(p.basename(path), 'evil name.pdf');
      expect(
        p.isWithin(
          p.join(temp.path, 'mail_attachments', account.id, '$localId', '1.2'),
          path,
        ),
        isTrue,
      );
      expect(await File(path).readAsBytes(), <int>[1, 2, 3, 4]);
      expect(factory.attachmentFetchCalls, 1);

      final secondPath = await useCase.call(
        account: account,
        emailLocalId: localId,
        partId: '1.2',
      );
      expect(secondPath, path);
      expect(factory.attachmentFetchCalls, 1);
      final cached = await localRepository.getAttachment(localId, '1.2');
      expect(cached!.localCachePath, path);
    },
  );

  test(
    'flag update rolls back the local bitmask when the remote STORE fails',
    () async {
      final (factory, pool, slot) = await connectPool();
      await _insertFolder(db, accountId: account.id, id: 'fa');
      final localId = await _insertEmail(
        db,
        accountId: account.id,
        folderId: 'fa',
        uid: 8,
      );
      factory.statuses['INBOX'] = const RemoteMailboxStatus(
        remoteName: 'INBOX',
        uidValidity: 1,
        messagesExists: 1,
      );

      final useCase = UpdateEmailFlagsUseCase(
        localRepository: localRepository,
        remoteRepository: remoteRepository(pool),
      );

      factory.failFlagStore = true;
      await expectLater(
        useCase.call(account: account, emailLocalId: localId, isRead: true),
        throwsA(isA<StateError>()),
      );
      var email = await localRepository.getEmail(localId);
      expect(email!.isRead, isFalse, reason: 'local flags must be rolled back');

      factory.failFlagStore = false;
      email = await useCase.call(
        account: account,
        emailLocalId: localId,
        isRead: true,
      );
      expect(email.isRead, isTrue);
      final lastStore = factory.flagStores.last;
      expect(lastStore.$1, 8);
      expect(lastStore.$2, const <String>[r'\Seen']);
      expect(lastStore.$3, isTrue);
      expect(factory.flagStoreCalls, 2);
      expect(slot.activeTransientCount, 0);
    },
  );

  test(
    'InboxSyncCoordinator debounces EXISTS events into one sync per account',
    () async {
      final (factory, pool, _) = await connectPool();

      var syncCount = 0;
      final syncedAccountIds = <String>[];
      final coordinator = InboxSyncCoordinator(
        connectionPool: pool,
        syncAccount: (String accountId) async {
          syncCount++;
          syncedAccountIds.add(accountId);
        },
        debounce: const Duration(milliseconds: 50),
      );
      addTearDown(coordinator.dispose);
      coordinator.start();

      final session = factory.sessions.first;
      session.emit(const ImapMailboxMessagesAdded(existsCount: 1));
      session.emit(const ImapMailboxMessagesAdded(existsCount: 2));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      session.emit(const ImapMailboxMessagesAdded(existsCount: 3));

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(syncCount, 1);
      expect(syncedAccountIds, <String>[account.id]);

      session.emit(const ImapMailboxMessagesAdded(existsCount: 4));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(syncCount, 2);
    },
  );
}
