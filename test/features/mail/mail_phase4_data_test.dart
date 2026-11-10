import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/datasources/mail_local_datasource.dart';
import 'package:local_mail_client/features/mail/data/repositories/mail_local_repository.dart';
import 'package:local_mail_client/features/mail/data/repositories/trusted_senders_repository_impl.dart';
import 'package:local_mail_client/features/mail/domain/entities/mail_sync_result.dart';
import 'package:local_mail_client/features/mail/domain/repositories/trusted_senders_repository.dart';

Future<void> _insertAccount(AppDatabase db) {
  return db
      .into(db.dbAccounts)
      .insert(
        DbAccountsCompanion.insert(
          id: 'a',
          email: 'a@example.com',
          displayName: 'A',
          providerType: 'gmail',
          authType: 'password',
          colorValue: 1,
          imapHost: 'imap.example.com',
          imapPort: 993,
          imapImplicitTls: true,
          smtpHost: 'smtp.example.com',
          smtpPort: 465,
          smtpImplicitTls: true,
          createdAt: 1,
        ),
      );
}

Future<void> _insertFolder(AppDatabase db) {
  return db
      .into(db.dbFolders)
      .insert(
        DbFoldersCompanion.insert(
          id: 'f',
          accountId: 'a',
          remoteName: 'INBOX',
          displayName: 'INBOX',
          role: 'inbox',
        ),
      );
}

Future<int> _insertEmail(AppDatabase db, {int flags = 0}) {
  return db
      .into(db.dbEmails)
      .insert(
        DbEmailsCompanion.insert(
          accountId: 'a',
          folderId: 'f',
          uid: 1,
          subject: 'Unread message',
          fromName: 'Sender',
          fromAddress: 'sender@example.com',
          toRecipientsJson: '[]',
          ccJson: '[]',
          snippet: 'snippet',
          sentAt: 2,
          flagsBitmask: Value(flags),
          bodyDownloaded: const Value(true),
          plainBody: const Value('plain body'),
        ),
      );
}

void main() {
  test(
    'real v1 database upgrades to current schema, keeps rows and FTS search',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (database) {
            database.execute('''
            CREATE TABLE db_accounts (
              id TEXT NOT NULL PRIMARY KEY,
              email TEXT NOT NULL,
              display_name TEXT NOT NULL,
              provider_type TEXT NOT NULL,
              auth_type TEXT NOT NULL,
              color_value INTEGER NOT NULL,
              imap_host TEXT NOT NULL,
              imap_port INTEGER NOT NULL,
              imap_implicit_tls INTEGER NOT NULL,
              smtp_host TEXT NOT NULL,
              smtp_port INTEGER NOT NULL,
              smtp_implicit_tls INTEGER NOT NULL,
              is_enabled INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL
            );
            CREATE TABLE db_folders (
              id TEXT NOT NULL PRIMARY KEY,
              account_id TEXT NOT NULL REFERENCES db_accounts(id) ON DELETE CASCADE,
              remote_name TEXT NOT NULL,
              display_name TEXT NOT NULL,
              role TEXT NOT NULL,
              uid_validity INTEGER,
              highest_mod_seq INTEGER,
              unread_count INTEGER NOT NULL DEFAULT 0,
              last_sync_at INTEGER
            );
            CREATE TABLE db_emails (
              local_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              account_id TEXT NOT NULL REFERENCES db_accounts(id) ON DELETE CASCADE,
              folder_id TEXT NOT NULL REFERENCES db_folders(id) ON DELETE CASCADE,
              uid INTEGER NOT NULL,
              message_id TEXT,
              subject TEXT NOT NULL,
              from_name TEXT NOT NULL,
              from_address TEXT NOT NULL,
              to_json TEXT NOT NULL,
              cc_json TEXT NOT NULL,
              snippet TEXT NOT NULL,
              plain_body TEXT,
              html_body TEXT,
              sent_at INTEGER NOT NULL,
              flags_bitmask INTEGER NOT NULL DEFAULT 0,
              has_attachments INTEGER NOT NULL DEFAULT 0,
              body_downloaded INTEGER NOT NULL DEFAULT 0,
              UNIQUE(folder_id, uid)
            );
            CREATE TABLE db_attachments (
              id TEXT NOT NULL PRIMARY KEY,
              email_local_id INTEGER NOT NULL REFERENCES db_emails(local_id) ON DELETE CASCADE,
              part_id TEXT NOT NULL,
              content_id TEXT,
              filename TEXT NOT NULL,
              mime_type TEXT NOT NULL,
              size_bytes INTEGER NOT NULL,
              local_cache_path TEXT,
              is_inline INTEGER NOT NULL DEFAULT 0
            );
            CREATE INDEX idx_emails_folder_sent ON db_emails(folder_id, sent_at);
            CREATE INDEX idx_emails_sent_at ON db_emails(sent_at);
            CREATE INDEX idx_emails_account_sent ON db_emails(account_id, sent_at);
            CREATE INDEX idx_attachments_email ON db_attachments(email_local_id);
            CREATE VIRTUAL TABLE emails_fts USING fts5(
              subject, from_name, from_address, plain_body,
              content='db_emails', content_rowid='local_id',
              tokenize='trigram'
            );
            CREATE TRIGGER db_emails_ai AFTER INSERT ON db_emails BEGIN
              INSERT INTO emails_fts(rowid, subject, from_name, from_address, plain_body)
              VALUES (new.local_id, new.subject, new.from_name, new.from_address,
                COALESCE(new.plain_body, new.snippet, ''));
            END;
            CREATE TRIGGER db_emails_ad AFTER DELETE ON db_emails BEGIN
              INSERT INTO emails_fts(emails_fts, rowid, subject, from_name, from_address, plain_body)
              VALUES ('delete', old.local_id, old.subject, old.from_name, old.from_address,
                COALESCE(old.plain_body, old.snippet, ''));
            END;
            CREATE TRIGGER db_emails_au AFTER UPDATE ON db_emails BEGIN
              INSERT INTO emails_fts(emails_fts, rowid, subject, from_name, from_address, plain_body)
              VALUES ('delete', old.local_id, old.subject, old.from_name, old.from_address,
                COALESCE(old.plain_body, old.snippet, ''));
              INSERT INTO emails_fts(rowid, subject, from_name, from_address, plain_body)
              VALUES (new.local_id, new.subject, new.from_name, new.from_address,
                COALESCE(new.plain_body, new.snippet, ''));
            END;
          ''');
            database.execute('''
            INSERT INTO db_accounts VALUES
              ('a', 'a@example.com', 'A', 'gmail', 'password', 1,
               'imap.example.com', 993, 1, 'smtp.example.com', 465, 1, 1, 1);
            INSERT INTO db_folders VALUES
              ('f', 'a', 'INBOX', 'INBOX', 'inbox', 1, NULL, 0, NULL);
            INSERT INTO db_emails VALUES
              (1, 'a', 'f', 1, '<old@example.com>', 'Old report', 'Sender',
               'sender@example.com', '[]', '[]', 'old snippet',
               'Quarterly report', NULL, 1700000000, 0, 0, 1);
            INSERT INTO db_attachments VALUES
              ('att-old', 1, '2', NULL, 'old.pdf', 'application/pdf', 10, NULL, 0);
          ''');
            database.execute('PRAGMA user_version = 1');
          },
        ),
      );
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 7);
      expect(db.schemaVersion, 7);
      expect(
        (await db.select(db.dbAccounts).get()).single.email,
        'a@example.com',
      );
      expect((await db.select(db.dbFolders).get()).single.role, 'inbox');
      expect((await db.select(db.dbEmails).get()).single.subject, 'Old report');
      expect(
        (await db.select(db.dbAttachments).get()).single.filename,
        'old.pdf',
      );
      await db
          .into(db.dbTrustedSenders)
          .insert(
            DbTrustedSendersCompanion.insert(
              senderEmail: 'trusted@example.com',
              createdAt: 1700000001,
            ),
          );
      expect(await db.select(db.dbTrustedSenders).get(), hasLength(1));
      await db
          .into(db.dbOutboxMessages)
          .insert(
            DbOutboxMessagesCompanion.insert(
              id: 'outbox-old-db',
              accountId: 'a',
              mode: 'newMail',
              toRecipientsJson: '[]',
              ccJson: '[]',
              bccJson: '[]',
              subject: 'Migrated draft',
              plainBody: 'hello',
              attachmentsJson: '[]',
              status: 'draft',
              createdAt: 1700000002,
              updatedAt: 1700000002,
            ),
          );
      expect(
        (await db.select(db.dbOutboxMessages).getSingle()).subject,
        'Migrated draft',
      );

      final fts = await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM emails_fts WHERE emails_fts MATCH 'report'",
          )
          .getSingle();
      expect(fts.read<int>('c'), 1);
    },
  );

  test('trusted sender repository normalizes and persists addresses', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final TrustedSendersRepository repository = TrustedSendersRepositoryImpl(
      database: db,
    );

    await repository.trustSender('  Alice@Example.com ');
    expect(await repository.isTrusted('alice@example.com'), isTrue);
    expect(await repository.isTrusted('ALICE@EXAMPLE.COM'), isTrue);
    final trusted = await repository.getTrustedSenders();
    expect(trusted.single.normalizedEmail, 'alice@example.com');

    await repository.untrustSender('ALICE@example.com');
    expect(await repository.isTrusted('alice@example.com'), isFalse);
  });

  test(
    'unified unread filter, folder stream and email attachment refresh',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertAccount(db);
      await _insertFolder(db);
      final emailLocalId = await _insertEmail(db);
      await db
          .into(db.dbEmails)
          .insert(
            DbEmailsCompanion.insert(
              accountId: 'a',
              folderId: 'f',
              uid: 2,
              subject: 'Read message',
              fromName: 'Sender',
              fromAddress: 'sender@example.com',
              toRecipientsJson: '[]',
              ccJson: '[]',
              snippet: 'snippet',
              sentAt: 1,
              flagsBitmask: const Value(1),
              bodyDownloaded: const Value(true),
            ),
          );

      final repository = MailLocalRepository(
        dataSource: MailLocalDataSource(database: db),
      );

      final unread = await repository.watchUnifiedInbox(unreadOnly: true).first;
      expect(unread.map((email) => email.subject), <String>['Unread message']);
      final folderEmails = await repository.watchFolderEmails('f').first;
      expect(folderEmails, hasLength(2));

      final events = <int>[];
      final subscription = repository
          .watchEmail(emailLocalId)
          .listen((email) => events.add(email?.attachments.length ?? -1));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await db
          .into(db.dbAttachments)
          .insert(
            DbAttachmentsCompanion.insert(
              id: 'att-1',
              emailLocalId: emailLocalId,
              partId: '2',
              filename: 'image.png',
              mimeType: 'image/png',
              sizeBytes: 4,
              contentId: const Value('logo@cid'),
              isInline: const Value(true),
            ),
          );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await subscription.cancel();

      expect(events.first, 0);
      expect(events.last, 1);
    },
  );

  test(
    'disabling or deleting an account removes its emails from the stream',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertAccount(db);
      await _insertFolder(db);
      await _insertEmail(db);
      final repository = MailLocalRepository(
        dataSource: MailLocalDataSource(database: db),
      );
      final counts = <int>[];
      final subscription = repository.watchUnifiedInbox().listen(
        (emails) => counts.add(emails.length),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(counts.last, 1);

      await (db.update(db.dbAccounts)..where((table) => table.id.equals('a')))
          .write(const DbAccountsCompanion(isEnabled: Value(false)));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(counts.last, 0);

      await (db.delete(
        db.dbAccounts,
      )..where((table) => table.id.equals('a'))).go();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(counts.last, 0);
      await subscription.cancel();
    },
  );

  test('empty remote folder clears stale local emails', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _insertAccount(db);
    await _insertFolder(db);
    await _insertEmail(db);
    final repository = MailLocalRepository(
      dataSource: MailLocalDataSource(database: db),
    );
    final folder = (await repository.getFolderById('f'))!;
    final account = MailAccount(
      id: 'a',
      email: 'a@example.com',
      displayName: 'A',
      providerType: MailProviderType.gmail,
      authType: MailAuthType.passwordOrAuthCode,
      colorValue: 1,
      imapHost: 'imap.example.com',
      imapPort: 993,
      imapImplicitTls: true,
      smtpHost: 'smtp.example.com',
      smtpPort: 465,
      smtpImplicitTls: true,
      createdAt: DateTime.utc(2026),
    );

    await repository.applyFolderSync(
      account: account,
      folder: folder,
      result: const MailFolderSyncResult(
        status: RemoteMailboxStatus(
          remoteName: 'INBOX',
          uidValidity: 1,
          messagesExists: 0,
        ),
        messages: <RemoteFetchedMessage>[],
        uidValidityChanged: false,
        isFullSnapshot: false,
      ),
    );

    expect(await db.select(db.dbEmails).get(), isEmpty);
  });
}
