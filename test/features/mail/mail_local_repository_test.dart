import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/datasources/mail_local_datasource.dart';
import 'package:local_mail_client/features/mail/data/repositories/mail_local_repository.dart';
import 'package:local_mail_client/features/mail/domain/entities/mail_folder.dart';
import 'package:local_mail_client/features/mail/domain/entities/mail_sync_result.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';

Future<void> _insertAccount(
  AppDatabase db, {
  required String id,
  required String email,
  required int colorValue,
  bool isEnabled = true,
}) {
  return db
      .into(db.dbAccounts)
      .insert(
        DbAccountsCompanion.insert(
          id: id,
          email: email,
          displayName: 'Account $id',
          providerType: 'gmail',
          authType: 'password',
          colorValue: colorValue,
          imapHost: 'imap.gmail.com',
          imapPort: 993,
          imapImplicitTls: true,
          smtpHost: 'smtp.gmail.com',
          smtpPort: 465,
          smtpImplicitTls: true,
          isEnabled: Value(isEnabled),
          createdAt: 1700000000,
        ),
      );
}

Future<void> _insertFolder(
  AppDatabase db, {
  required String id,
  required String accountId,
  String remoteName = 'INBOX',
  String role = 'inbox',
}) {
  return db
      .into(db.dbFolders)
      .insert(
        DbFoldersCompanion.insert(
          id: id,
          accountId: accountId,
          remoteName: remoteName,
          displayName: remoteName,
          role: role,
        ),
      );
}

Future<int> _insertEmail(
  AppDatabase db, {
  required String accountId,
  required String folderId,
  required int uid,
  required String subject,
  required int sentAt,
  String? plainBody,
  String? htmlBody,
  String snippet = '',
  bool bodyDownloaded = false,
  int flagsBitmask = 0,
}) {
  return db
      .into(db.dbEmails)
      .insert(
        DbEmailsCompanion.insert(
          accountId: accountId,
          folderId: folderId,
          uid: uid,
          subject: subject,
          fromName: 'Sender',
          fromAddress: 'sender@example.com',
          toRecipientsJson: '[]',
          ccJson: '[]',
          snippet: snippet,
          plainBody: Value(plainBody),
          htmlBody: Value(htmlBody),
          sentAt: sentAt,
          flagsBitmask: Value(flagsBitmask),
          bodyDownloaded: Value(bodyDownloaded),
        ),
      );
}

MailAccount _toMailAccount(DbAccount row) {
  return MailAccount(
    id: row.id,
    email: row.email,
    displayName: row.displayName,
    providerType: MailProviderType.fromStorageKey(row.providerType),
    authType: MailAuthType.fromStorageKey(row.authType),
    colorValue: row.colorValue,
    imapHost: row.imapHost,
    imapPort: row.imapPort,
    imapImplicitTls: row.imapImplicitTls,
    smtpHost: row.smtpHost,
    smtpPort: row.smtpPort,
    smtpImplicitTls: row.smtpImplicitTls,
    isEnabled: row.isEnabled,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
  );
}

RemoteFetchedMessage _remoteMessage({
  required int uid,
  String subject = 'Updated subject',
  List<String> flags = const [],
  List<RemoteAttachmentMeta> attachments = const [],
}) {
  return RemoteFetchedMessage(
    uid: uid,
    subject: subject,
    fromName: 'Sender',
    fromAddress: 'sender@example.com',
    sentAt: DateTime.utc(2026, 1, 1),
    flags: flags,
    attachments: attachments,
  );
}

void main() {
  late AppDatabase db;
  late MailLocalRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = MailLocalRepository(
      dataSource: MailLocalDataSource(database: db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'unified inbox mixes enabled accounts by sentAt and carries colors',
    () async {
      await _insertAccount(
        db,
        id: 'a',
        email: 'a@gmail.com',
        colorValue: 0xFF000001,
      );
      await _insertAccount(
        db,
        id: 'b',
        email: 'b@gmail.com',
        colorValue: 0xFF000002,
      );
      await _insertAccount(
        db,
        id: 'c',
        email: 'c@gmail.com',
        colorValue: 0xFF000003,
        isEnabled: false,
      );
      await _insertFolder(db, id: 'fa', accountId: 'a');
      await _insertFolder(db, id: 'fb', accountId: 'b');
      await _insertFolder(db, id: 'fc', accountId: 'c');
      await _insertFolder(
        db,
        id: 'fa-sent',
        accountId: 'a',
        remoteName: 'Sent',
        role: 'sent',
      );

      await _insertEmail(
        db,
        accountId: 'a',
        folderId: 'fa',
        uid: 2,
        subject: 'A-2000',
        sentAt: 2000,
      );
      await _insertEmail(
        db,
        accountId: 'a',
        folderId: 'fa',
        uid: 1,
        subject: 'A-1000',
        sentAt: 1000,
      );
      await _insertEmail(
        db,
        accountId: 'b',
        folderId: 'fb',
        uid: 3,
        subject: 'B-3000',
        sentAt: 3000,
      );
      await _insertEmail(
        db,
        accountId: 'c',
        folderId: 'fc',
        uid: 4,
        subject: 'C-4000',
        sentAt: 4000,
      );
      await _insertEmail(
        db,
        accountId: 'a',
        folderId: 'fa-sent',
        uid: 5,
        subject: 'Sent-5000',
        sentAt: 5000,
      );

      final rows = await repository.watchUnifiedInbox().first;

      expect(rows.map((row) => row.subject), <String>[
        'B-3000',
        'A-2000',
        'A-1000',
      ]);
      expect(rows.map((row) => row.accountColorValue), <int>[
        0xFF000002,
        0xFF000001,
        0xFF000001,
      ]);
      expect(rows.every((row) => row.folderRole == FolderRole.inbox), isTrue);
      expect(rows.map((row) => row.accountId), isNot(contains('c')));
    },
  );

  test(
    'header upsert keeps bodies, bodyDownloaded and attachment cache path',
    () async {
      await _insertAccount(
        db,
        id: 'a',
        email: 'a@gmail.com',
        colorValue: 0xFF112233,
      );
      await _insertFolder(db, id: 'fa', accountId: 'a');
      final localId = await _insertEmail(
        db,
        accountId: 'a',
        folderId: 'fa',
        uid: 10,
        subject: 'Old subject',
        sentAt: 1000,
        plainBody: 'Cached plain body',
        htmlBody: '<p>Cached html</p>',
        snippet: 'Cached snippet',
        bodyDownloaded: true,
      );
      await db
          .into(db.dbAttachments)
          .insert(
            DbAttachmentsCompanion.insert(
              id: 'att-1',
              emailLocalId: localId,
              partId: '2',
              filename: 'invoice.pdf',
              mimeType: 'application/pdf',
              sizeBytes: 99,
              contentId: const Value('cid-1'),
              localCachePath: const Value('/tmp/cached-invoice.pdf'),
            ),
          );

      final folder = (await repository.getFolderById('fa'))!;
      final account = _toMailAccount(
        await db.select(db.dbAccounts).getSingle(),
      );
      await repository.applyFolderSync(
        account: account,
        folder: folder,
        result: MailFolderSyncResult(
          status: const RemoteMailboxStatus(
            remoteName: 'INBOX',
            uidValidity: 1,
            messagesExists: 1,
          ),
          messages: <RemoteFetchedMessage>[
            _remoteMessage(
              uid: 10,
              subject: 'New subject',
              flags: const <String>[r'\Seen'],
              attachments: const <RemoteAttachmentMeta>[
                RemoteAttachmentMeta(
                  partId: '2',
                  filename: 'invoice.pdf',
                  mimeType: 'application/pdf',
                  sizeBytes: 100,
                  contentId: 'cid-1',
                ),
              ],
            ),
          ],
          uidValidityChanged: false,
          isFullSnapshot: true,
          recentWindowMinUid: 10,
          recentWindowMaxUid: 10,
        ),
      );

      final updated = await repository.getEmail(localId);
      expect(updated, isNotNull);
      expect(updated!.subject, 'New subject');
      expect(updated.plainBody, 'Cached plain body');
      expect(updated.htmlBody, '<p>Cached html</p>');
      expect(updated.bodyDownloaded, isTrue);
      expect(updated.snippet, 'Cached snippet');
      expect(updated.isRead, isTrue);
      expect(updated.attachments, hasLength(1));
      expect(
        updated.attachments.single.localCachePath,
        '/tmp/cached-invoice.pdf',
      );
    },
  );

  test('mailbox upsert maps special-use and Chinese folder names', () async {
    await _insertAccount(
      db,
      id: 'a',
      email: 'a@gmail.com',
      colorValue: 0xFF112233,
    );

    final mailboxes = <RemoteMailboxInfo>[
      const RemoteMailboxInfo(
        remoteName: 'INBOX',
        displayName: 'INBOX',
        attributes: <String>['inbox'],
      ),
      const RemoteMailboxInfo(
        remoteName: 'Sent',
        displayName: 'Sent',
        attributes: <String>['sent'],
      ),
      const RemoteMailboxInfo(remoteName: '已发送', displayName: '已发送'),
      const RemoteMailboxInfo(remoteName: '草稿箱', displayName: '草稿箱'),
      const RemoteMailboxInfo(remoteName: '已删除', displayName: '已删除'),
      const RemoteMailboxInfo(remoteName: '垃圾邮件', displayName: '垃圾邮件'),
      const RemoteMailboxInfo(remoteName: '归档', displayName: '归档'),
    ];

    final first = await repository.upsertMailboxes(
      accountId: 'a',
      mailboxes: mailboxes,
    );
    final roles = <String, FolderRole>{
      for (final folder in first) folder.remoteName: folder.role,
    };
    expect(roles['INBOX'], FolderRole.inbox);
    expect(roles['Sent'], FolderRole.sent);
    expect(roles['已发送'], FolderRole.sent);
    expect(roles['草稿箱'], FolderRole.drafts);
    expect(roles['已删除'], FolderRole.trash);
    expect(roles['垃圾邮件'], FolderRole.junk);
    expect(roles['归档'], FolderRole.archive);

    final idsBefore = {
      for (final folder in first) folder.remoteName: folder.id,
    };
    final second = await repository.upsertMailboxes(
      accountId: 'a',
      mailboxes: mailboxes,
    );
    final idsAfter = {
      for (final folder in second) folder.remoteName: folder.id,
    };
    expect(idsAfter, idsBefore);
  });

  test('UIDVALIDITY change clears old cache and rebuilds', () async {
    await _insertAccount(
      db,
      id: 'a',
      email: 'a@gmail.com',
      colorValue: 0xFF112233,
    );
    await _insertFolder(db, id: 'fa', accountId: 'a');
    await _insertEmail(
      db,
      accountId: 'a',
      folderId: 'fa',
      uid: 10,
      subject: 'Old cached',
      sentAt: 1000,
    );
    final folder = (await repository.getFolderById('fa'))!;
    final account = _toMailAccount(await db.select(db.dbAccounts).getSingle());

    await repository.applyFolderSync(
      account: account,
      folder: folder,
      result: MailFolderSyncResult(
        status: const RemoteMailboxStatus(
          remoteName: 'INBOX',
          uidValidity: 2,
          messagesExists: 1,
        ),
        messages: <RemoteFetchedMessage>[
          _remoteMessage(uid: 20, subject: 'Fresh message'),
        ],
        uidValidityChanged: true,
        isFullSnapshot: true,
        recentWindowMinUid: 20,
        recentWindowMaxUid: 20,
      ),
    );

    final emails = await db.select(db.dbEmails).get();
    expect(emails.map((row) => row.uid), <int>[20]);
    final refreshed = await repository.getFolderById('fa');
    expect(refreshed!.uidValidity, 2);
  });

  test(
    'search supports English/3+ CJK FTS and 1-2 CJK LIKE fallback',
    () async {
      await _insertAccount(
        db,
        id: 'a',
        email: 'a@gmail.com',
        colorValue: 0xFF112233,
      );
      await _insertAccount(
        db,
        id: 'b',
        email: 'b@gmail.com',
        colorValue: 0xFF445566,
      );
      await _insertFolder(db, id: 'fa', accountId: 'a');
      await _insertFolder(db, id: 'fb', accountId: 'b');

      await _insertEmail(
        db,
        accountId: 'a',
        folderId: 'fa',
        uid: 1,
        subject: 'Quarterly Report 2026',
        sentAt: 2000,
        plainBody: 'Hello world 财务报表分析 发票 a-b "c"',
        bodyDownloaded: true,
      );
      await _insertEmail(
        db,
        accountId: 'b',
        folderId: 'fb',
        uid: 2,
        subject: 'Invoice 发票号码',
        sentAt: 3000,
        plainBody: 'Payment due soon',
        flagsBitmask: UnifiedEmail.flagSeen,
        bodyDownloaded: true,
      );

      expect(
        (await repository.searchEmails(query: 'report')).map((e) => e.uid),
        <int>[1],
      );
      expect(
        (await repository.searchEmails(query: '财务报')).map((e) => e.uid),
        <int>[1],
      );
      expect(
        (await repository.searchEmails(query: '发票')).map((e) => e.uid),
        containsAll(<int>[1, 2]),
        reason: 'two-character CJK must use the LIKE fallback',
      );
      expect(
        (await repository.searchEmails(
          query: '发票',
          unreadOnly: true,
        )).map((e) => e.uid),
        <int>[1],
      );
      expect(
        await repository.searchEmails(query: 'report', accountId: 'b'),
        isEmpty,
      );

      // Punctuation / quotes must be escaped for FTS5 and never throw.
      final special = await repository.searchEmails(query: 'a-b "c"');
      expect(special, isA<List<UnifiedEmail>>());
    },
  );
}
