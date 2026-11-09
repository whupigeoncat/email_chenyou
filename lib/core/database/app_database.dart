import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Account metadata table.
/// Strictly NO passwords, authorization codes, or OAuth tokens stored here.
class DbAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text()();
  TextColumn get providerType => text()();
  TextColumn get authType => text()();
  IntColumn get colorValue => integer()();
  TextColumn get imapHost => text()();
  IntColumn get imapPort => integer()();
  BoolColumn get imapImplicitTls => boolean()();
  TextColumn get smtpHost => text()();
  IntColumn get smtpPort => integer()();
  BoolColumn get smtpImplicitTls => boolean()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_folders_role_account', columns: {#role, #accountId})
class DbFolders extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(DbAccounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get remoteName => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text()();
  IntColumn get uidValidity => integer().nullable()();
  IntColumn get highestModSeq => integer().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  IntColumn get lastSyncAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_emails_folder_sent', columns: {#folderId, #sentAt})
@TableIndex(name: 'idx_emails_sent_at', columns: {#sentAt})
@TableIndex(name: 'idx_emails_account_sent', columns: {#accountId, #sentAt})
@TableIndex(
  name: 'idx_emails_folder_sent_uid',
  columns: {#folderId, #sentAt, #uid},
)
class DbEmails extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get accountId =>
      text().references(DbAccounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get folderId =>
      text().references(DbFolders, #id, onDelete: KeyAction.cascade)();
  IntColumn get uid => integer()();
  TextColumn get messageId => text().nullable()();
  TextColumn get subject => text()();
  TextColumn get fromName => text()();
  TextColumn get fromAddress => text()();
  // NOTE: Named `toRecipientsJson` in Dart because Drift's generated data class
  // already exposes a `toJson()` method; the physical column stays `to_json`.
  TextColumn get toRecipientsJson => text().named('to_json')();
  TextColumn get ccJson => text()();
  TextColumn get snippet => text()();
  TextColumn get plainBody => text().nullable()();
  TextColumn get htmlBody => text().nullable()();
  IntColumn get sentAt => integer()();
  IntColumn get flagsBitmask => integer().withDefault(const Constant(0))();
  BoolColumn get hasAttachments => boolean().withDefault(const Constant(false))();
  BoolColumn get bodyDownloaded => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {folderId, uid},
      ];
}

@TableIndex(name: 'idx_attachments_email', columns: {#emailLocalId})
class DbAttachments extends Table {
  TextColumn get id => text()();
  IntColumn get emailLocalId =>
      integer().references(DbEmails, #localId, onDelete: KeyAction.cascade)();
  TextColumn get partId => text()();
  TextColumn get contentId => text().nullable()();
  TextColumn get filename => text()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer()();
  TextColumn get localCachePath => text().nullable()();
  BoolColumn get isInline => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Sender addresses explicitly trusted by the user for remote-image loading.
/// Only the address and trust time are stored; no message content or secrets.
class DbTrustedSenders extends Table {
  TextColumn get senderEmail => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {senderEmail};
}

@TableIndex(name: 'idx_outbox_account', columns: {#accountId})
@TableIndex(name: 'idx_outbox_status', columns: {#status})
@TableIndex(name: 'idx_outbox_updated', columns: {#updatedAt})
class DbOutboxMessages extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(DbAccounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get mode => text()();
  IntColumn get originEmailLocalId => integer().nullable()();
  TextColumn get inReplyTo => text().nullable()();
  TextColumn get referencesHeader => text().nullable()();
  // Named `toRecipientsJson` in Dart because Drift's generated data class
  // already exposes `toJson()`; the physical outbox column stays `to_json`.
  TextColumn get toRecipientsJson => text().named('to_json')();
  TextColumn get ccJson => text()();
  TextColumn get bccJson => text()();
  TextColumn get subject => text()();
  // Stable RFC 5322 Message-ID used as the idempotency key for retries.
  TextColumn get outgoingMessageId => text().nullable()();
  TextColumn get plainBody => text()();
  TextColumn get htmlBody => text().nullable()();
  TextColumn get attachmentsJson => text()();
  TextColumn get status => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  BoolColumn get retryable => boolean().withDefault(const Constant(true))();
  IntColumn get nextRetryAt => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get sentAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    DbAccounts,
    DbFolders,
    DbEmails,
    DbAttachments,
    DbTrustedSenders,
    DbOutboxMessages,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createFts5Schema();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(dbTrustedSenders);
          }
          if (from < 3) {
            await m.createTable(dbOutboxMessages);
          } else if (from < 4) {
            await m.addColumn(
              dbOutboxMessages,
              dbOutboxMessages.outgoingMessageId,
            );
          }
          if (from < 5) {
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_folders_role_account '
              'ON db_folders(role, account_id)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_emails_folder_sent_uid '
              'ON db_emails(folder_id, sent_at, uid)',
            );
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA synchronous = NORMAL');
        },
      );

  Future<void> _createFts5Schema() async {
    // Use SQLite FTS5 trigram tokenizer for full-text substring matching across
    // both English words and CJK characters without requiring external tokenizers.
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS emails_fts USING fts5(
        subject,
        from_name,
        from_address,
        plain_body,
        content='db_emails',
        content_rowid='local_id',
        tokenize='trigram'
      );
    ''');

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS db_emails_ai AFTER INSERT ON db_emails BEGIN
        INSERT INTO emails_fts(rowid, subject, from_name, from_address, plain_body)
        VALUES (
          new.local_id,
          new.subject,
          new.from_name,
          new.from_address,
          COALESCE(new.plain_body, new.snippet, '')
        );
      END;
    ''');

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS db_emails_ad AFTER DELETE ON db_emails BEGIN
        INSERT INTO emails_fts(emails_fts, rowid, subject, from_name, from_address, plain_body)
        VALUES (
          'delete',
          old.local_id,
          old.subject,
          old.from_name,
          old.from_address,
          COALESCE(old.plain_body, old.snippet, '')
        );
      END;
    ''');

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS db_emails_au AFTER UPDATE ON db_emails BEGIN
        INSERT INTO emails_fts(emails_fts, rowid, subject, from_name, from_address, plain_body)
        VALUES (
          'delete',
          old.local_id,
          old.subject,
          old.from_name,
          old.from_address,
          COALESCE(old.plain_body, old.snippet, '')
        );
        INSERT INTO emails_fts(rowid, subject, from_name, from_address, plain_body)
        VALUES (
          new.local_id,
          new.subject,
          new.from_name,
          new.from_address,
          COALESCE(new.plain_body, new.snippet, '')
        );
      END;
    ''');
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final dbFile = File(p.join(dir.path, 'local_mail_client.sqlite'));
      return NativeDatabase.createInBackground(dbFile);
    });
  }
}
