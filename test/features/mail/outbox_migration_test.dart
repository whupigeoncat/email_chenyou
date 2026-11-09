import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:path/path.dart' as p;

String _baseSchema({
  required bool withTrusted,
  required bool withOutbox,
  bool outboxHasOutgoingId = false,
}) {
  return '''
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
    ${withTrusted ? '''
      CREATE TABLE db_trusted_senders (
        sender_email TEXT NOT NULL PRIMARY KEY,
        created_at INTEGER NOT NULL
      );
      INSERT INTO db_trusted_senders VALUES ('trusted@example.com', 1700000001);
    ''' : ''}
    ${withOutbox ? '''
      CREATE TABLE db_outbox_messages (
        id TEXT NOT NULL PRIMARY KEY,
        account_id TEXT NOT NULL REFERENCES db_accounts(id) ON DELETE CASCADE,
        mode TEXT NOT NULL,
        origin_email_local_id INTEGER,
        in_reply_to TEXT,
        references_header TEXT,
        to_json TEXT NOT NULL,
        cc_json TEXT NOT NULL,
        bcc_json TEXT NOT NULL,
        subject TEXT NOT NULL,
        ${outboxHasOutgoingId ? 'outgoing_message_id TEXT,' : ''}
        plain_body TEXT NOT NULL,
        html_body TEXT,
        attachments_json TEXT NOT NULL,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        retryable INTEGER NOT NULL DEFAULT 1,
        next_retry_at INTEGER,
        last_error TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sent_at INTEGER
      );
      CREATE INDEX idx_outbox_account ON db_outbox_messages(account_id);
      CREATE INDEX idx_outbox_status ON db_outbox_messages(status);
      CREATE INDEX idx_outbox_updated ON db_outbox_messages(updated_at);
      INSERT INTO db_outbox_messages
        (id, account_id, mode, to_json, cc_json, bcc_json, subject,
         plain_body, attachments_json, status, created_at, updated_at)
      VALUES
        ('old-outbox', 'a', 'newMail', '[]', '[]', '[]', 'v3 draft',
         'body', '[]', 'draft', 1700000002, 1700000002);
    ''' : ''}
  ''';
}

NativeDatabase _fixtureDatabase(File file, int version, String sql) {
  return NativeDatabase(
    file,
    setup: (database) {
      if (database.userVersion != 0) return;
      database.execute(sql);
      database.userVersion = version;
    },
  );
}

void main() {
  test(
    'real v2 database upgrades to v6, keeps rows/FTS and adds outbox',
    () async {
      final dir = Directory.systemTemp.createTempSync('outbox_migration_v2_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'mail.sqlite'));

      final db = AppDatabase.forTesting(
        _fixtureDatabase(
          file,
          2,
          _baseSchema(withTrusted: true, withOutbox: false),
        ),
      );
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 6);
      expect(db.schemaVersion, 6);
      expect((await db.select(db.dbEmails).get()).single.subject, 'Old report');
      expect(
        (await db.select(db.dbTrustedSenders).get()).single.senderEmail,
        'trusted@example.com',
      );
      final fts = await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM emails_fts WHERE emails_fts MATCH 'report'",
          )
          .getSingle();
      expect(fts.read<int>('c'), 1);

      await db
          .into(db.dbOutboxMessages)
          .insert(
            DbOutboxMessagesCompanion.insert(
              id: 'o',
              accountId: 'a',
              mode: 'newMail',
              outgoingMessageId: const Value('<stable@local-mail.local>'),
              toRecipientsJson: '[]',
              ccJson: '[]',
              bccJson: '[]',
              subject: 'new outbox',
              plainBody: 'body',
              attachmentsJson: '[]',
              status: 'draft',
              createdAt: 2,
              updatedAt: 2,
            ),
          );
      expect(
        (await db.select(db.dbOutboxMessages).getSingle()).outgoingMessageId,
        '<stable@local-mail.local>',
      );

      await (db.delete(
        db.dbAccounts,
      )..where((table) => table.id.equals('a'))).go();
      expect(await db.select(db.dbOutboxMessages).get(), isEmpty);
    },
  );

  test('real v3 database upgrades to v6 without losing outbox rows', () async {
    final dir = Directory.systemTemp.createTempSync('outbox_migration_v3_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'mail.sqlite'));

    final db = AppDatabase.forTesting(
      _fixtureDatabase(
        file,
        3,
        _baseSchema(withTrusted: true, withOutbox: true),
      ),
    );
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 6);
    final outbox = await db.select(db.dbOutboxMessages).getSingle();
    expect(outbox.subject, 'v3 draft');
    expect(outbox.outgoingMessageId, null);

    // The migration added the idempotency column; a repository write can fill
    // it for the existing row.
    await (db.update(
      db.dbOutboxMessages,
    )..where((table) => table.id.equals('old-outbox'))).write(
      const DbOutboxMessagesCompanion(
        outgoingMessageId: Value('<backfilled@local-mail.local>'),
      ),
    );
    expect(
      (await db.select(db.dbOutboxMessages).getSingle()).outgoingMessageId,
      '<backfilled@local-mail.local>',
    );
  });

  test(
    'real v4 database upgrades to v6 with indexes and data preserved',
    () async {
      final dir = Directory.systemTemp.createTempSync('outbox_migration_v4_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'mail.sqlite'));

      final db = AppDatabase.forTesting(
        _fixtureDatabase(
          file,
          4,
          _baseSchema(
            withTrusted: true,
            withOutbox: true,
            outboxHasOutgoingId: true,
          ),
        ),
      );
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 6);
      expect(db.schemaVersion, 6);
      final outbox = await db.select(db.dbOutboxMessages).getSingle();
      expect(outbox.subject, 'v3 draft');
      expect(outbox.outgoingMessageId, null);
      expect((await db.select(db.dbEmails).get()).single.subject, 'Old report');

      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name IN "
            "('idx_emails_folder_sent_uid', 'idx_folders_role_account')",
          )
          .get();
      expect(indexes.map((row) => row.read<String>('name')).toSet(), {
        'idx_emails_folder_sent_uid',
        'idx_folders_role_account',
      });
    },
  );

  test('v5 upgrades archive policy and pending copies, then reopens safely', () async {
    final dir = Directory.systemTemp.createTempSync('outbox_migration_v5_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'mail.sqlite'));
    final db = AppDatabase.forTesting(
      _fixtureDatabase(
        file,
        5,
        "${_baseSchema(withTrusted: true, withOutbox: true, outboxHasOutgoingId: true)}UPDATE db_accounts SET provider_type = 'custom'; UPDATE db_outbox_messages SET status = 'sent';",
      ),
    );
    expect((await db.select(db.dbAccounts).getSingle()).saveSentCopy, isTrue);
    expect(
      (await db.select(db.dbOutboxMessages).getSingle()).sentCopySaved,
      isFalse,
    );
    expect(
      (await db.select(db.dbEmails).getSingle()).plainBody,
      'Quarterly report',
    );
    await db.close();
    final reopened = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(reopened.close);
    expect(
      (await reopened.select(reopened.dbAccounts).getSingle()).saveSentCopy,
      isTrue,
    );
    expect(
      (await reopened.select(reopened.dbOutboxMessages).getSingle()).status,
      'sent',
    );
    expect(
      (await reopened.customSelect('PRAGMA foreign_key_check').get()),
      isEmpty,
    );
  });
}
