import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/datasources/outbox_local_datasource.dart';
import 'package:local_mail_client/features/mail/data/repositories/outbox_repository_impl.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';

void main() {
  late AppDatabase db;
  late OutboxRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: db),
    );
  });

  tearDown(() => db.close());

  test('draft save, streams, queue and failure transitions', () async {
    final account = MailAccount(
      id: 'a',
      email: 'a@example.com',
      displayName: 'A',
      providerType: MailProviderType.gmail,
      authType: MailAuthType.passwordOrAuthCode,
      colorValue: 1,
      imapHost: 'imap',
      imapPort: 993,
      imapImplicitTls: true,
      smtpHost: 'smtp',
      smtpPort: 465,
      smtpImplicitTls: true,
      createdAt: DateTime.utc(2026),
    );
    await db.into(db.dbAccounts).insert(
          DbAccountsCompanion.insert(
            id: account.id,
            email: account.email,
            displayName: account.displayName,
            providerType: account.providerType.storageKey,
            authType: account.authType.storageKey,
            colorValue: 1,
            imapHost: 'imap',
            imapPort: 993,
            imapImplicitTls: true,
            smtpHost: 'smtp',
            smtpPort: 465,
            smtpImplicitTls: true,
            createdAt: 1,
          ),
        );

    final draft = ComposeDraft(
      accountId: account.id,
      mode: ComposeMode.newMail,
      to: const [EmailAddressEntry(email: 'bob@example.com')],
      cc: const [],
      bcc: const [],
      subject: 'Draft',
      plainBody: 'body',
      attachments: const [],
    );
    final saved = await repository.saveDraft(draft: draft);
    expect(saved.status, OutboxStatus.draft);
    expect((await repository.watchDrafts().first).single.id, saved.id);
    expect((await repository.watchCounts().first).drafts, 1);

    await repository.enqueue(saved.id);
    await repository.markSending(saved.id);
    var row = (await repository.getById(saved.id))!;
    expect(row.status, OutboxStatus.sending);
    await repository.resetStuckSending();
    row = (await repository.getById(saved.id))!;
    expect(row.status, OutboxStatus.uncertain);
    expect(row.retryable, isFalse);

    await repository.markFailed(
      saved.id,
      error: 'access_token=abc123',
      retryable: true,
      retryCount: 1,
      nextRetryAt: DateTime.now().toUtc().add(const Duration(seconds: 30)),
    );
    final failed = (await repository.getById(saved.id))!;
    expect(failed.status, OutboxStatus.failed);
    expect(failed.lastError, isNot(contains('abc123')));
    expect((await repository.getRetryable()).single.id, saved.id);

    await repository.markSent(saved.id);
    final sent = (await repository.getById(saved.id))!;
    expect(sent.status, OutboxStatus.sent);
    expect(sent.sentAt, isNotNull);

    await repository.delete(saved.id);
    expect(await repository.getById(saved.id), isNull);
  });

  test('sent/sending/uncertain rows reject draft overwrite and enqueue',
      () async {
    final account = MailAccount(
      id: 'b',
      email: 'b@example.com',
      displayName: 'B',
      providerType: MailProviderType.gmail,
      authType: MailAuthType.passwordOrAuthCode,
      colorValue: 1,
      imapHost: 'imap',
      imapPort: 993,
      imapImplicitTls: true,
      smtpHost: 'smtp',
      smtpPort: 465,
      smtpImplicitTls: true,
      createdAt: DateTime.utc(2026),
    );
    await db.into(db.dbAccounts).insert(
          DbAccountsCompanion.insert(
            id: account.id,
            email: account.email,
            displayName: account.displayName,
            providerType: account.providerType.storageKey,
            authType: account.authType.storageKey,
            colorValue: 1,
            imapHost: 'imap',
            imapPort: 993,
            imapImplicitTls: true,
            smtpHost: 'smtp',
            smtpPort: 465,
            smtpImplicitTls: true,
            createdAt: 1,
          ),
        );
    final draft = ComposeDraft(
      accountId: account.id,
      mode: ComposeMode.newMail,
      to: const [EmailAddressEntry(email: 'bob@example.com')],
      cc: const [],
      bcc: const [],
      subject: 'Once',
      plainBody: 'body',
      attachments: const [],
    );
    final saved = await repository.saveDraft(draft: draft);
    expect(saved.outgoingMessageId, isNotNull);

    await repository.markSent(saved.id);
    await expectLater(
      repository.saveDraft(draft: draft, id: saved.id),
      throwsA(isA<StorageFailure>()),
    );
    await expectLater(
      repository.enqueue(saved.id),
      throwsA(isA<StorageFailure>()),
    );

    final second = await repository.saveDraft(
      draft: draft.copyWith(subject: 'Second'),
    );
    await repository.markUncertain(second.id, error: 'ambiguous');
    expect((await repository.getById(second.id))!.status, OutboxStatus.uncertain);
    await expectLater(
      repository.saveDraft(draft: draft, id: second.id),
      throwsA(isA<StorageFailure>()),
    );
    await expectLater(
      repository.enqueue(second.id),
      throwsA(isA<StorageFailure>()),
    );
    await repository.confirmResend(second.id);
    expect((await repository.getById(second.id))!.status, OutboxStatus.queued);
    expect((await repository.getMessages()).length, 2);
  });
}
