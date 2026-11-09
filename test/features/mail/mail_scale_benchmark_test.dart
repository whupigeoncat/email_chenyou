import 'dart:io';

import 'package:drift/drift.dart';
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
import 'package:path/path.dart' as p;

const _chineseSubject = '季度财务报表与发票归档通知';
const _englishSubject = 'Quarterly report and invoice archive';
const _bodyZh =
    '这是用于性能基准测试的中英文混合正文。季度财务报表已经生成，'
    '请查收附件并核对发票号码与金额。Thank you for your review.';
const _bodyEn =
    'This is a realistic mixed-language benchmark body. The quarterly report '
    'contains invoices, statements and account summaries for review.';

void main() {
  test('10k mailbox scale benchmarks', () async {
    final dir = Directory.systemTemp.createTempSync('mail_scale_db_');
    final file = File(p.join(dir.path, 'scale.sqlite'));
    final db = AppDatabase.forTesting(NativeDatabase(file));
    final dataSource = MailLocalDataSource(database: db);
    final repository = MailLocalRepository(dataSource: dataSource);
    final accounts = <MailAccount>[];
    final inboxes = <MailAccount, MailFolder>{};

    try {
      final now = DateTime.utc(2026, 1, 1);
      for (var a = 0; a < 3; a++) {
        final account = MailAccount(
          id: 'scale-acc-$a',
          email: 'scale$a@example.com',
          displayName: 'Scale $a',
          providerType: MailProviderType.gmail,
          authType: MailAuthType.passwordOrAuthCode,
          colorValue: 0xFF000000 + a,
          imapHost: 'imap.example.com',
          imapPort: 993,
          imapImplicitTls: true,
          smtpHost: 'smtp.example.com',
          smtpPort: 465,
          smtpImplicitTls: true,
          createdAt: now,
        );
        accounts.add(account);
        await db.into(db.dbAccounts).insert(
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
                createdAt: account.createdAt.millisecondsSinceEpoch,
              ),
            );
        final inbox = MailFolder(
          id: '${account.id}::INBOX',
          accountId: account.id,
          remoteName: 'INBOX',
          displayName: 'INBOX',
          role: FolderRole.inbox,
          uidValidity: 1,
        );
        inboxes[account] = inbox;
        await db.into(db.dbFolders).insert(
              DbFoldersCompanion.insert(
                id: inbox.id,
                accountId: account.id,
                remoteName: 'INBOX',
                displayName: 'INBOX',
                role: FolderRole.inbox.storageKey,
                uidValidity: const Value(1),
              ),
            );
        await db.into(db.dbFolders).insert(
              DbFoldersCompanion.insert(
                id: '${account.id}::Archive',
                accountId: account.id,
                remoteName: 'Archive',
                displayName: 'Archive',
                role: FolderRole.archive.storageKey,
              ),
            );
      }

      final emailRows = <DbEmailsCompanion>[];
      for (var i = 0; i < 10000; i++) {
        final account = accounts[i % accounts.length];
        final inbox = inboxes[account]!;
        final chinese = i.isEven;
        final subject = chinese
            ? (_containsFinanceSample(i) ? _chineseSubject : '日常邮件 $i')
            : (_containsEnglishSample(i) ? _englishSubject : 'Daily mail $i');
        final body = chinese ? _bodyZh : _bodyEn;
        emailRows.add(
          DbEmailsCompanion.insert(
            accountId: account.id,
            folderId: inbox.id,
            uid: i ~/ accounts.length + 1,
            subject: subject,
            fromName: chinese ? '发件人 $i' : 'Sender $i',
            fromAddress: 'sender$i@example.com',
            toRecipientsJson:
                '[{"name":"Scale","email":"${account.email}"}]',
            ccJson: '[]',
            snippet: chinese ? '季度财务报表 发票 $i' : 'Quarterly invoice $i',
            plainBody: Value(body),
            htmlBody: Value('<p>$body</p>'),
            bodyDownloaded: const Value(true),
            sentAt:
                now.subtract(Duration(minutes: i)).millisecondsSinceEpoch,
            flagsBitmask: Value(i % 3 == 0 ? 1 : 0),
          ),
        );
      }
      await db.batch((batch) => batch.insertAll(db.dbEmails, emailRows));

      final attachmentTargets = await (db.selectOnly(db.dbEmails)
            ..addColumns([db.dbEmails.localId])
            ..limit(500))
          .get();
      await db.batch((batch) {
        for (final row in attachmentTargets) {
          final id = row.read(db.dbEmails.localId)!;
          batch.insert(
            db.dbAttachments,
            DbAttachmentsCompanion.insert(
              id: '$id::2',
              emailLocalId: id,
              partId: '2',
              filename: 'report-$id.pdf',
              mimeType: 'application/pdf',
              sizeBytes: 128 * 1024,
            ),
          );
        }
      });

      // Benchmark 1: aggregated inbox first 200 mixed rows.
      final inboxWatch = Stopwatch()..start();
      final firstPage = await repository.watchUnifiedInbox(limit: 200).first;
      inboxWatch.stop();
      // ignore: avoid_print
      print('[benchmark] inbox first 200: ${inboxWatch.elapsedMilliseconds}ms');
      expect(firstPage, hasLength(200));
      expect(inboxWatch.elapsedMilliseconds, lessThan(150));

      // Benchmark 2: one incremental sync of 50 new headers.
      final account = accounts.first;
      final inbox = inboxes[account]!;
      final newMessages = List<RemoteFetchedMessage>.generate(50, (i) {
        return RemoteFetchedMessage(
          uid: 100000 + i,
          subject: 'Incremental $i',
          fromName: 'Sender',
          fromAddress: 'incremental$i@example.com',
          sentAt: now.add(Duration(minutes: i)),
          snippet: 'incremental snippet $i',
          attachments: i % 10 == 0
              ? [
                  RemoteAttachmentMeta(
                    partId: '2',
                    filename: 'incremental-$i.pdf',
                    mimeType: 'application/pdf',
                    sizeBytes: 1024,
                  ),
                ]
              : const [],
        );
      });
      final syncWatch = Stopwatch()..start();
      await repository.applyFolderSync(
        account: account,
        folder: inbox,
        result: MailFolderSyncResult(
          status: RemoteMailboxStatus(
            remoteName: 'INBOX',
            uidValidity: 1,
            messagesExists: 3390,
            messagesUnseen: 100,
            uidNext: 100050,
          ),
          messages: newMessages,
          uidValidityChanged: false,
          isFullSnapshot: false,
        ),
      );
      syncWatch.stop();
      // ignore: avoid_print
      print('[benchmark] 50-mail applyFolderSync: '
          '${syncWatch.elapsedMilliseconds}ms');
      expect(syncWatch.elapsedMilliseconds, lessThan(300));

      final inserted = await (db.select(db.dbEmails)
            ..where((table) => table.uid.isBiggerOrEqualValue(100000))
            ..orderBy([(table) => OrderingTerm.asc(table.uid)]))
          .get();
      expect(inserted, hasLength(50));
      expect(inserted.every((row) => row.bodyDownloaded == false), isTrue);
      final existing = await (db.select(db.dbEmails)
            ..where(
              (table) =>
                  table.folderId.equals(inbox.id) & table.uid.equals(1),
            ))
          .getSingle();
      expect(existing.bodyDownloaded, isTrue);
      expect(existing.plainBody, isNot(null));

      // Benchmark 3: >=3-character trigram FTS.
      final ftsWatch = Stopwatch()..start();
      final ftsRows = await dataSource.searchFtsRows(
        term: '季度财务报表',
        limit: 100,
      );
      ftsWatch.stop();
      // ignore: avoid_print
      print('[benchmark] FTS 季度财务报表: ${ftsWatch.elapsedMilliseconds}ms');
      expect(ftsRows, isNotEmpty);
      expect(ftsWatch.elapsedMilliseconds, lessThan(100));

      final englishWatch = Stopwatch()..start();
      final englishRows = await dataSource.searchFtsRows(
        term: 'Quarterly',
        limit: 100,
      );
      englishWatch.stop();
      // ignore: avoid_print
      print('[benchmark] FTS Quarterly: ${englishWatch.elapsedMilliseconds}ms');
      expect(englishRows, isNotEmpty);
      expect(englishWatch.elapsedMilliseconds, lessThan(100));

      // Benchmark 4: 1-2 character CJK baseline (LIKE fallback path).
      final shortWatch = Stopwatch()..start();
      final shortRows = await dataSource.searchLikeRows(term: '发票', limit: 100);
      shortWatch.stop();
      // ignore: avoid_print
      print('[benchmark] short-term 发票 baseline: '
          '${shortWatch.elapsedMilliseconds}ms (${shortRows.length} hits)');
      expect(shortRows, isNotEmpty);
    } finally {
      await db.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });
}

bool _containsFinanceSample(int index) => index % 100 == 0;

bool _containsEnglishSample(int index) => index % 40 == 0;
