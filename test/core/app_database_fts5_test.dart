import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/database/app_database.dart';

Future<void> _insertAccount(
  AppDatabase db, {
  String id = 'acc-1',
  String email = 'alice@example.com',
}) async {
  await db.into(db.dbAccounts).insert(
        DbAccountsCompanion.insert(
          id: id,
          email: email,
          displayName: 'Alice',
          providerType: 'gmail',
          authType: 'password',
          colorValue: 0xFFEA4335,
          imapHost: 'imap.gmail.com',
          imapPort: 993,
          imapImplicitTls: true,
          smtpHost: 'smtp.gmail.com',
          smtpPort: 465,
          smtpImplicitTls: true,
          createdAt: 1700000000,
        ),
      );
}

Future<void> _insertFolder(
  AppDatabase db, {
  String id = 'fld-1',
  String accountId = 'acc-1',
}) async {
  await db.into(db.dbFolders).insert(
        DbFoldersCompanion.insert(
          id: id,
          accountId: accountId,
          remoteName: 'INBOX',
          displayName: 'Inbox',
          role: 'inbox',
        ),
      );
}

Future<int> _insertEmail(
  AppDatabase db, {
  String accountId = 'acc-1',
  String folderId = 'fld-1',
  int uid = 1,
  String subject = 'Quarterly Report 2026',
  String? plainBody = 'Hello world from the finance team. 请查收本季度财务报表。',
  String snippet = 'Hello world',
}) {
  return db.into(db.dbEmails).insert(
        DbEmailsCompanion.insert(
          accountId: accountId,
          folderId: folderId,
          uid: uid,
          subject: subject,
          fromName: 'Alice',
          fromAddress: 'alice@example.com',
          toRecipientsJson: '["bob@example.com"]',
          ccJson: '[]',
          snippet: snippet,
          plainBody: Value(plainBody),
          sentAt: 1700000001,
        ),
      );
}

Future<int> _ftsHits(AppDatabase db, String term) async {
  final row = await db.customSelect(
    'SELECT COUNT(*) AS hit_count FROM emails_fts WHERE emails_fts MATCH ?',
    variables: <Variable<Object>>[Variable.withString(term)],
  ).getSingle();
  return row.read<int>('hit_count');
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('no table contains password/token/secret columns', () async {
    for (final table in <String>[
      'db_accounts',
      'db_folders',
      'db_emails',
      'db_attachments',
    ]) {
      final columns = await db.customSelect('PRAGMA table_info($table)').get();
      expect(columns, isNotEmpty, reason: '$table should exist');

      for (final row in columns) {
        final name = row.read<String>('name').toLowerCase();
        expect(
          name.contains('password') ||
              name.contains('passwd') ||
              name.contains('token') ||
              name.contains('secret'),
          isFalse,
          reason: '$table.$name must never store credentials',
        );
      }
    }
  });

  test('FTS5 trigram virtual table and sync triggers are created', () async {
    final schema = await db.customSelect(
      "SELECT name, type, sql FROM sqlite_master "
      "WHERE name IN ('emails_fts', 'db_emails_ai', 'db_emails_ad', "
      "'db_emails_au')",
    ).get();

    expect(schema, hasLength(4));

    final fts = schema.firstWhere((row) => row.read<String>('name') == 'emails_fts');
    expect(fts.read<String>('type'), 'table');
    final ftsSql = fts.read<String>('sql');
    expect(ftsSql, contains("content='db_emails'"));
    expect(ftsSql, contains("content_rowid='local_id'"));
    expect(ftsSql, contains("tokenize='trigram'"));

    final triggerNames = schema
        .where((row) => row.read<String>('type') == 'trigger')
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(
      triggerNames,
      containsAll(<String>[
        'db_emails_ai',
        'db_emails_ad',
        'db_emails_au',
      ]),
    );
  });

  test('insert/update/delete triggers keep FTS5 in sync', () async {
    await _insertAccount(db);
    await _insertFolder(db);
    final localId = await _insertEmail(db);

    expect(await _ftsHits(db, 'report'), 1);
    expect(await _ftsHits(db, 'port'), 1, reason: 'English substring match');
    expect(await _ftsHits(db, 'world'), 1);
    expect(
      await _ftsHits(db, '财务报'),
      1,
      reason: '3-character CJK substring match',
    );
    expect(await _ftsHits(db, 'zzzznotfound'), 0);

    await (db.update(db.dbEmails)..where((t) => t.localId.equals(localId)))
        .write(
      const DbEmailsCompanion(
        subject: Value<String>('Updated Newsletter'),
        plainBody: Value<String>('Fresh content about gardening and plants.'),
      ),
    );

    expect(await _ftsHits(db, 'report'), 0);
    expect(await _ftsHits(db, '财务报表'), 0);
    expect(await _ftsHits(db, 'newsletter'), 1);
    expect(await _ftsHits(db, 'garden'), 1);

    // When plain_body is cleared the trigger must fall back to snippet.
    await (db.update(db.dbEmails)..where((t) => t.localId.equals(localId)))
        .write(
      const DbEmailsCompanion(
        plainBody: Value<String?>(null),
        snippet: Value<String>('Fallback snippet about orchids'),
      ),
    );
    expect(await _ftsHits(db, 'orchid'), 1);
    expect(await _ftsHits(db, 'garden'), 0);

    await (db.delete(db.dbEmails)..where((t) => t.localId.equals(localId))).go();
    expect(await _ftsHits(db, 'orchid'), 0);
    expect(await db.select(db.dbEmails).get(), isEmpty);
  });

  test('foreign key cascades remove children and FTS rows', () async {
    await _insertAccount(db);
    await _insertFolder(db);
    final emailId = await _insertEmail(db);

    await db.into(db.dbAttachments).insert(
          DbAttachmentsCompanion.insert(
            id: 'att-1',
            emailLocalId: emailId,
            partId: '1.2',
            filename: 'invoice.pdf',
            mimeType: 'application/pdf',
            sizeBytes: 1234,
          ),
        );

    expect(await _ftsHits(db, 'report'), 1);
    expect(await db.select(db.dbAttachments).get(), hasLength(1));

    await (db.delete(db.dbAccounts)..where((t) => t.id.equals('acc-1'))).go();

    expect(await db.select(db.dbAccounts).get(), isEmpty);
    expect(await db.select(db.dbFolders).get(), isEmpty);
    expect(await db.select(db.dbEmails).get(), isEmpty);
    expect(await db.select(db.dbAttachments).get(), isEmpty);
    expect(await _ftsHits(db, 'report'), 0);

    final ftsRows = await db
        .customSelect('SELECT COUNT(*) AS c FROM emails_fts')
        .getSingle();
    expect(ftsRows.read<int>('c'), 0);
  });
}
