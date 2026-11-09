import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/auth/data/account_credential_resolver.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/datasources/outbox_local_datasource.dart';
import 'package:local_mail_client/features/mail/data/datasources/smtp_session.dart';
import 'package:local_mail_client/features/mail/data/repositories/outbox_repository_impl.dart';
import 'package:local_mail_client/features/mail/data/services/outbox_queue_service.dart';
import 'package:local_mail_client/features/mail/domain/entities/mail_attachment.dart';
import 'package:local_mail_client/features/mail/domain/entities/mail_folder.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';
import 'package:local_mail_client/features/mail/domain/services/attachment_picker.dart';
import 'package:local_mail_client/features/mail/domain/usecases/outbox_usecases.dart';
import 'package:local_mail_client/features/mail/presentation/pages/compose_email_page.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';

import '../auth/support/fakes.dart';
import 'support/mail_fixture.dart';

class _FakeAttachmentPicker implements AttachmentPicker {
  _FakeAttachmentPicker(this.path);

  final String path;

  @override
  Future<List<PickedAttachment>> pickAttachments() async {
    return [
      PickedAttachment(
        path: path,
        fileName: 'note.txt',
        sizeBytes: 4,
        mimeType: 'text/plain',
      ),
    ];
  }
}

class _FakeLiveSmtpSession implements SmtpSession {
  Object? sendError;
  int sendCount = 0;
  bool connected = false;

  @override
  bool get isConnected => connected;

  @override
  Future<void> connectAndAuthenticate({
    required MailAccount account,
    required ResolvedAccountCredential credential,
  }) async {
    connected = true;
  }

  @override
  Future<void> send(OutgoingMailEnvelope envelope) async {
    sendCount++;
    final error = sendError;
    if (error != null) throw error;
  }

  @override
  Future<void> quitAndDisconnect({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    connected = false;
  }

  @override
  Future<void> forceClose() async {
    connected = false;
  }
}

class _LiveSmtpFactory implements SmtpSessionFactory {
  _LiveSmtpFactory(this.session);
  final _FakeLiveSmtpSession session;

  @override
  SmtpSession createSession() => session;
}

class _StaticCredentialResolver implements AccountCredentialResolver {
  @override
  Future<ResolvedAccountCredential> call(MailAccount account) async {
    return const PasswordCredential('test-code');
  }
}

class _ComposeHost extends StatelessWidget {
  const _ComposeHost({
    required this.account,
    this.draft,
    this.draftId,
    this.originEmail,
    this.mode = ComposeMode.newMail,
  });

  final MailAccount account;
  final ComposeDraft? draft;
  final String? draftId;
  final UnifiedEmail? originEmail;
  final ComposeMode mode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            key: const Key('open-compose-host'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ComposeEmailPage(
                  account: account,
                  draft: draft,
                  draftId: draftId,
                  originEmail: originEmail,
                  mode: mode,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

class _BlockingSend implements QueueAndSendEmailUseCase {
  final Completer<OutboxMessage> completer = Completer<OutboxMessage>();
  ComposeDraft? capturedDraft;

  @override
  Future<OutboxMessage> call({
    required ComposeDraft draft,
    String? id,
  }) {
    capturedDraft = draft;
    return completer.future;
  }
}

class _AlwaysFailEnqueueQueue extends OutboxQueueService {
  _AlwaysFailEnqueueQueue({
    required super.repository,
    required super.sessionFactory,
    required super.credentialResolver,
    required super.authRepository,
  });

  int attempts = 0;

  @override
  Future<void> enqueueAndSend(String id) async {
    attempts++;
    throw StateError('queue start failed');
  }
}

UnifiedEmail _forwardOrigin({
  required MailAccount account,
  required MailFolder folder,
  List<MailAttachment> attachments = const [],
}) {
  return UnifiedEmail(
    localId: 1,
    accountId: account.id,
    accountEmail: account.email,
    accountDisplayName: account.displayName,
    accountColorValue: account.colorValue,
    folderId: folder.id,
    folderRole: FolderRole.inbox,
    uid: 1,
    messageId: '<origin@example.com>',
    subject: 'Original',
    fromName: 'Sender',
    fromAddress: 'sender@example.com',
    toAddresses: const [EmailAddressEntry(email: 'alice@example.com')],
    ccAddresses: const [],
    snippet: 'snippet',
    plainBody: 'plain original',
    htmlBody: '<p>html original</p>',
    sentAt: DateTime.utc(2026),
    isRead: true,
    isFlagged: false,
    isAnswered: false,
    hasAttachments: attachments.isNotEmpty,
    bodyDownloaded: true,
    attachments: attachments,
  );
}

class _FakeSend implements QueueAndSendEmailUseCase {
  _FakeSend(this.result);

  final OutboxMessage result;
  ComposeDraft? capturedDraft;

  @override
  Future<OutboxMessage> call({required ComposeDraft draft, String? id}) async {
    capturedDraft = draft;
    return result;
  }
}

void main() {
  testWidgets('rejects empty recipients and keeps a saved draft', (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final repo = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: fixture.database),
    );
    final account = fixture.account;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([account]),
          ),
          outboxRepositoryProvider.overrideWithValue(repo),
          saveDraftUseCaseProvider.overrideWithValue(
            SaveDraftUseCase(repository: repo),
          ),
        ],
        child: MaterialApp(
          home: ComposeEmailPage(account: account),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('compose-send')));
    await tester.pumpAndSettle();
    expect(find.text('请至少填写一个有效的收件人地址。'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('compose-to-input')),
      'bob@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('compose-subject')),
      'Saved subject',
    );
    await tester.enterText(
      find.byKey(const Key('compose-body')),
      'Saved body',
    );
    await tester.tap(find.byKey(const Key('compose-save-draft')));
    await tester.pumpAndSettle();

    final drafts = await repo.getMessages(statuses: {OutboxStatus.draft});
    expect(drafts, hasLength(1));
    expect(drafts.single.subject, 'Saved subject');
    expect(drafts.single.to.single.email, 'bob@example.com');
  });

  testWidgets('attachment pick and remove updates staged attachment list',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final temp = Directory.systemTemp.createTempSync('compose_pick_');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}/note.txt');
    source.writeAsStringSync('data');
    final repo = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: fixture.database),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          outboxRepositoryProvider.overrideWithValue(repo),
          attachmentPickerProvider.overrideWithValue(
            _FakeAttachmentPicker(source.path),
          ),
          attachmentStoreProvider.overrideWithValue(
            AttachmentStore(rootProvider: () async => temp),
          ),
        ],
        child: MaterialApp(
          home: ComposeEmailPage(account: fixture.account),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('compose-attach')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('note.txt'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('note.txt'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('remove-attachment-note.txt')),
    );
    await tester.pumpAndSettle();
    expect(find.text('note.txt'), findsNothing);
  });

  testWidgets('closing a dirty compose page asks save/discard/continue',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final repo = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: fixture.database),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          outboxRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: ComposeEmailPage(account: fixture.account),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('compose-subject')),
      'Dirty draft',
    );
    await tester.tap(find.byKey(const Key('compose-close')));
    await tester.pumpAndSettle();

    expect(find.text('有未保存的更改'), findsOneWidget);
    expect(find.byKey(const Key('compose-continue-editing')), findsOneWidget);
    expect(find.byKey(const Key('compose-discard-changes')), findsOneWidget);
    await tester.tap(find.byKey(const Key('compose-continue-editing')));
    await tester.pumpAndSettle();
  });

  testWidgets('send passes the edited draft and keeps page on failure',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final failed = OutboxMessage(
      id: 'send-1',
      accountId: fixture.account.id,
      mode: ComposeMode.newMail,
      to: const [EmailAddressEntry(email: 'bob@example.com')],
      cc: const [],
      bcc: const [],
      subject: 'Failure subject',
      plainBody: 'Failure body',
      attachments: const [],
      status: OutboxStatus.failed,
      retryCount: 1,
      retryable: true,
      lastError: 'SMTP 认证失败：请检查授权码',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final send = _FakeSend(failed);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          queueAndSendEmailUseCaseProvider.overrideWithValue(send),
        ],
        child: MaterialApp(
          home: ComposeEmailPage(account: fixture.account),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('compose-to-input')),
      'bob@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('compose-subject')),
      'Failure subject',
    );
    await tester.enterText(
      find.byKey(const Key('compose-body')),
      'Failure body',
    );
    await tester.tap(find.byKey(const Key('compose-send')));
    await tester.pumpAndSettle();

    expect(find.text('SMTP 认证失败：请检查授权码'), findsOneWidget);
    expect(find.byKey(const Key('compose-send')), findsOneWidget);
    expect(send.capturedDraft?.to.single.email, 'bob@example.com');
    expect(send.capturedDraft?.subject, 'Failure subject');
    expect(send.capturedDraft?.plainBody, 'Failure body');
  });

  testWidgets('send success persists sent row and pops the page', (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final repo = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: fixture.database),
    );
    final smtp = _FakeLiveSmtpSession();
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final queue = OutboxQueueService(
      repository: repo,
      sessionFactory: _LiveSmtpFactory(smtp),
      credentialResolver: _StaticCredentialResolver(),
      authRepository: auth,
    );
    addTearDown(queue.dispose);
    final useCase = QueueAndSendEmailUseCase(repository: repo, queue: queue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          outboxRepositoryProvider.overrideWithValue(repo),
          queueAndSendEmailUseCaseProvider.overrideWithValue(useCase),
        ],
        child: MaterialApp(home: _ComposeHost(account: fixture.account)),
      ),
    );
    await tester.tap(find.byKey(const Key('open-compose-host')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('compose-to-input')),
      'bob@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('compose-subject')),
      'Sent subject',
    );
    await tester.tap(find.byKey(const Key('compose-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('compose-send')), findsNothing);
    final rows = await repo.getMessages();
    expect(rows, hasLength(1));
    expect(rows.single.status, OutboxStatus.sent);
    expect(rows.single.outgoingMessageId, isNotNull);
    expect(smtp.sendCount, 1);
  });

  testWidgets(
      'failed send keeps one row and a second send reuses the same id',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final repo = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: fixture.database),
    );
    final smtp = _FakeLiveSmtpSession()
      ..sendError = const SmtpFailure(
        reason: SmtpFailureReason.protocolError,
        retryable: true,
        userMessage: 'temporary rejection',
      );
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final queue = OutboxQueueService(
      repository: repo,
      sessionFactory: _LiveSmtpFactory(smtp),
      credentialResolver: _StaticCredentialResolver(),
      authRepository: auth,
    );
    addTearDown(queue.dispose);
    final useCase = QueueAndSendEmailUseCase(repository: repo, queue: queue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          outboxRepositoryProvider.overrideWithValue(repo),
          queueAndSendEmailUseCaseProvider.overrideWithValue(useCase),
        ],
        child: MaterialApp(home: _ComposeHost(account: fixture.account)),
      ),
    );
    await tester.tap(find.byKey(const Key('open-compose-host')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('compose-to-input')),
      'bob@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('compose-subject')),
      'Retry subject',
    );
    await tester.tap(find.byKey(const Key('compose-send')));
    await tester.pumpAndSettle();

    expect(find.text('temporary rejection'), findsOneWidget);
    var rows = await repo.getMessages();
    expect(rows, hasLength(1));
    final firstId = rows.single.id;
    expect(rows.single.status, OutboxStatus.failed);
    expect(smtp.sendCount, 1);

    smtp.sendError = null;
    await tester.tap(find.byKey(const Key('compose-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('compose-send')), findsNothing);
    rows = await repo.getMessages();
    expect(rows, hasLength(1), reason: 'must update the same outbox row');
    expect(rows.single.id, firstId);
    expect(rows.single.status, OutboxStatus.sent);
    expect(smtp.sendCount, 2);
  });

  testWidgets('discard keeps a saved draft row and its persisted attachment',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final temp = Directory.systemTemp.createTempSync('draft_attachment_');
    addTearDown(() => temp.delete(recursive: true));
    final attachmentFile = File('${temp.path}/persisted.pdf');
    attachmentFile.writeAsBytesSync(<int>[1, 2, 3]);
    final repo = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: fixture.database),
    );
    final saved = await repo.saveDraft(
      draft: ComposeDraft(
        accountId: fixture.account.id,
        mode: ComposeMode.newMail,
        to: const [EmailAddressEntry(email: 'bob@example.com')],
        cc: const [],
        bcc: const [],
        subject: 'Persisted attachment',
        plainBody: 'body',
        attachments: [
          OutgoingAttachment(
            fileName: 'persisted.pdf',
            mimeType: 'application/pdf',
            localPath: attachmentFile.path,
            sizeBytes: 3,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          outboxRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: _ComposeHost(
            account: fixture.account,
            draft: saved.toComposeDraft(),
            draftId: saved.id,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-compose-host')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('remove-attachment-persisted.pdf')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const Key('remove-attachment-persisted.pdf')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose-discard-changes')));
    await tester.pumpAndSettle();

    final stored = await repo.getById(saved.id);
    expect(stored, isNotNull);
    expect(stored!.attachments.single.localPath, attachmentFile.path);
    expect(attachmentFile.existsSync(), isTrue);
  });

  testWidgets('discard removes newly staged unsaved attachments',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final temp = Directory.systemTemp.createTempSync('new_attachment_');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}/new.txt');
    source.writeAsStringSync('new');
    final store = AttachmentStore(
      rootProvider: () async => temp,
      idGenerator: () => 'unsaved',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          attachmentPickerProvider.overrideWithValue(
            _FakeAttachmentPicker(source.path),
          ),
          attachmentStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(home: _ComposeHost(account: fixture.account)),
      ),
    );
    await tester.tap(find.byKey(const Key('open-compose-host')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose-attach')));
    await tester.pumpAndSettle();
    final stagedFiles = Directory('${temp.path}/mail_outbox_attachments')
        .listSync(recursive: true)
        .whereType<File>()
        .toList();
    expect(stagedFiles, hasLength(1));

    await tester.tap(find.byKey(const Key('compose-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose-discard-changes')));
    await tester.pumpAndSettle();

    expect(stagedFiles.single.existsSync(), isFalse);
  });

  testWidgets('unsubmitted recipient text triggers unsaved-changes dialog',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
        ],
        child: MaterialApp(home: _ComposeHost(account: fixture.account)),
      ),
    );
    await tester.tap(find.byKey(const Key('open-compose-host')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('compose-to-input')),
      'typed@example.com',
    );
    await tester.tap(find.byKey(const Key('compose-close')));
    await tester.pumpAndSettle();

    expect(find.text('有未保存的更改'), findsOneWidget);
    await tester.tap(find.byKey(const Key('compose-continue-editing')));
    await tester.pumpAndSettle();
  });

  testWidgets('account dropdown switch is used for the saved draft',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final second = MailAccount(
      id: 'acc-2',
      email: 'second@example.com',
      displayName: 'Second',
      providerType: fixture.account.providerType,
      authType: fixture.account.authType,
      colorValue: fixture.account.colorValue,
      imapHost: fixture.account.imapHost,
      imapPort: fixture.account.imapPort,
      imapImplicitTls: fixture.account.imapImplicitTls,
      smtpHost: fixture.account.smtpHost,
      smtpPort: fixture.account.smtpPort,
      smtpImplicitTls: fixture.account.smtpImplicitTls,
      createdAt: fixture.account.createdAt,
    );
    final repo = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: fixture.database),
    );
    await fixture.database.into(fixture.database.dbAccounts).insert(
          DbAccountsCompanion.insert(
            id: second.id,
            email: second.email,
            displayName: second.displayName,
            providerType: second.providerType.storageKey,
            authType: second.authType.storageKey,
            colorValue: second.colorValue,
            imapHost: second.imapHost,
            imapPort: second.imapPort,
            imapImplicitTls: second.imapImplicitTls,
            smtpHost: second.smtpHost,
            smtpPort: second.smtpPort,
            smtpImplicitTls: second.smtpImplicitTls,
            createdAt: second.createdAt.millisecondsSinceEpoch,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value(
              [fixture.account, second],
            ),
          ),
          outboxRepositoryProvider.overrideWithValue(repo),
          saveDraftUseCaseProvider.overrideWithValue(
            SaveDraftUseCase(repository: repo),
          ),
        ],
        child: MaterialApp(home: _ComposeHost(account: fixture.account)),
      ),
    );
    await tester.tap(find.byKey(const Key('open-compose-host')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('second@example.com').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('compose-to-input')),
      'bob@example.com',
    );
    await tester.tap(find.byKey(const Key('compose-save-draft')));
    await tester.pumpAndSettle();

    final rows = await repo.getMessages();
    expect(rows.single.accountId, 'acc-2');
  });

  testWidgets('compose page has no overflow at 960/500/360/320', (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    for (final width in <double>[960, 500, 360, 320]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsProvider.overrideWith(
              (ref) => Stream<List<MailAccount>>.value([fixture.account]),
            ),
          ],
          child: MaterialApp(
            home: ComposeEmailPage(account: fixture.account),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
      if (width <= 360) {
        await tester.enterText(
          find.byKey(const Key('compose-subject')),
          'dirty',
        );
        await tester.tap(find.byKey(const Key('compose-close')));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'close dialog width $width',
        );
        await tester.tap(find.byKey(const Key('compose-continue-editing')));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('reply banner has no overflow at 320', (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = UnifiedEmail(
      localId: 1,
      accountId: fixture.account.id,
      accountEmail: fixture.account.email,
      accountDisplayName: fixture.account.displayName,
      accountColorValue: fixture.account.colorValue,
      folderId: fixture.folder.id,
      folderRole: FolderRole.inbox,
      uid: 1,
      messageId: '<original@example.com>',
      subject: 'Original',
      fromName: 'Sender',
      fromAddress: 'sender@example.com',
      toAddresses: const [
        EmailAddressEntry(email: 'alice@example.com', name: 'Alice'),
      ],
      ccAddresses: const [],
      snippet: 'snippet',
      plainBody: 'body',
      sentAt: DateTime.utc(2026),
      isRead: true,
      isFlagged: false,
      isAnswered: false,
      hasAttachments: false,
      bodyDownloaded: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
        ],
        child: MaterialApp(
          home: ComposeEmailPage(
            account: fixture.account,
            originEmail: original,
            mode: ComposeMode.reply,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('回复内容已填入原邮件引用。'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });


  testWidgets('busy send disables close, system back and discard cleanup',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final temp = Directory.systemTemp.createTempSync('busy_send_');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}/source.txt');
    source.writeAsStringSync('data');
    final store = AttachmentStore(
      rootProvider: () async => temp,
      idGenerator: () => 'busy',
    );
    final send = _BlockingSend();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          attachmentPickerProvider.overrideWithValue(
            _FakeAttachmentPicker(source.path),
          ),
          attachmentStoreProvider.overrideWithValue(store),
          queueAndSendEmailUseCaseProvider.overrideWithValue(send),
        ],
        child: MaterialApp(home: _ComposeHost(account: fixture.account)),
      ),
    );
    await tester.tap(find.byKey(const Key('open-compose-host')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose-attach')));
    await tester.pumpAndSettle();
    final staged = Directory('${temp.path}/mail_outbox_attachments')
        .listSync(recursive: true)
        .whereType<File>()
        .toList();
    expect(staged, hasLength(1));
    await tester.enterText(
      find.byKey(const Key('compose-to-input')),
      'bob@example.com',
    );
    await tester.tap(find.byKey(const Key('compose-send')));
    await tester.pump();

    final close = tester.widget<IconButton>(
      find.byKey(const Key('compose-close')),
    );
    expect(close.onPressed, isNull);
    expect(find.text('有未保存的更改'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('有未保存的更改'), findsNothing);
    expect(find.byKey(const Key('compose-close')), findsOneWidget);
    expect(staged.single.existsSync(), isTrue);

    send.completer.complete(
      OutboxMessage(
        id: 'busy-send',
        accountId: fixture.account.id,
        mode: ComposeMode.newMail,
        to: const [EmailAddressEntry(email: 'bob@example.com')],
        cc: const [],
        bcc: const [],
        subject: '',
        plainBody: '',
        attachments: const [],
        status: OutboxStatus.failed,
        retryCount: 1,
        retryable: true,
        lastError: 'blocked send failed',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('rich forward layout has no overflow at 360/320', (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final temp = Directory.systemTemp.createTempSync('rich_forward_');
    addTearDown(() => temp.delete(recursive: true));
    final cached = File('${temp.path}/cached.txt');
    cached.writeAsStringSync('cached');
    final origin = _forwardOrigin(
      account: fixture.account,
      folder: fixture.folder,
      attachments: [
        MailAttachment(
          id: 'a',
          emailLocalId: 1,
          partId: '2',
          filename: 'cached.txt',
          mimeType: 'text/plain',
          sizeBytes: 6,
          localCachePath: cached.path,
        ),
        const MailAttachment(
          id: 'b',
          emailLocalId: 1,
          partId: '3',
          filename: 'missing.txt',
          mimeType: 'text/plain',
          sizeBytes: 8,
        ),
      ],
    );
    final store = AttachmentStore(rootProvider: () async => temp);

    for (final width in <double>[360, 320]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsProvider.overrideWith(
              (ref) => Stream<List<MailAccount>>.value([fixture.account]),
            ),
            attachmentStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp(
            home: ComposeEmailPage(
              account: fixture.account,
              originEmail: origin,
              mode: ComposeMode.forward,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('转发邮件已填入原邮件内容。'), findsOneWidget);
      expect(find.textContaining('尚未缓存'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('compose-to-input')),
        'bob@example.com',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('compose-cc-input')),
        'carol@example.com',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(find.text('富文本'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('compose-cc-input')),
        'broken-address',
      );
      await tester.tap(find.byKey(const Key('compose-save-draft')));
      await tester.pumpAndSettle();
      expect(find.textContaining('收件人格式错误'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('cached.txt'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('cached.txt'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('discard keeps persisted A and removes newly staged B',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final temp = Directory.systemTemp.createTempSync('mixed_attachments_');
    addTearDown(() => temp.delete(recursive: true));
    final persistedFile = File('${temp.path}/persisted-A.pdf');
    persistedFile.writeAsBytesSync(<int>[1, 2, 3]);
    final newSource = File('${temp.path}/new-B.txt');
    newSource.writeAsStringSync('B');
    final repo = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: fixture.database),
    );
    final saved = await repo.saveDraft(
      draft: ComposeDraft(
        accountId: fixture.account.id,
        mode: ComposeMode.newMail,
        to: const [EmailAddressEntry(email: 'bob@example.com')],
        cc: const [],
        bcc: const [],
        subject: 'Mixed attachments',
        plainBody: 'body',
        attachments: [
          OutgoingAttachment(
            fileName: 'persisted-A.pdf',
            mimeType: 'application/pdf',
            localPath: persistedFile.path,
            sizeBytes: 3,
          ),
        ],
      ),
    );
    final store = AttachmentStore(
      rootProvider: () async => temp,
      idGenerator: () => 'new-B',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          outboxRepositoryProvider.overrideWithValue(repo),
          attachmentPickerProvider.overrideWithValue(
            _FakeAttachmentPicker(newSource.path),
          ),
          attachmentStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          home: _ComposeHost(
            account: fixture.account,
            draft: saved.toComposeDraft(),
            draftId: saved.id,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-compose-host')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose-attach')));
    await tester.pumpAndSettle();
    final stagedB = Directory('${temp.path}/mail_outbox_attachments')
        .listSync(recursive: true)
        .whereType<File>()
        .toList();
    expect(stagedB, hasLength(1));

    await tester.tap(find.byKey(const Key('compose-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose-discard-changes')));
    await tester.pumpAndSettle();

    final stored = await repo.getById(saved.id);
    expect(stored!.attachments.single.localPath, persistedFile.path);
    expect(persistedFile.existsSync(), isTrue);
    expect(stagedB.single.existsSync(), isFalse);
  });

  testWidgets('fallback forward staging marks dirty and discard cleans copy',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final temp = Directory.systemTemp.createTempSync('fallback_forward_');
    addTearDown(() => temp.delete(recursive: true));
    final cached = File('${temp.path}/received.txt');
    cached.writeAsStringSync('received');
    final origin = _forwardOrigin(
      account: fixture.account,
      folder: fixture.folder,
      attachments: [
        MailAttachment(
          id: 'a',
          emailLocalId: 1,
          partId: '2',
          filename: 'received.txt',
          mimeType: 'text/plain',
          sizeBytes: 8,
          localCachePath: cached.path,
        ),
      ],
    );
    final store = AttachmentStore(
      rootProvider: () async => temp,
      idGenerator: () => 'forward-copy',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          attachmentStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          home: _ComposeHost(
            account: fixture.account,
            originEmail: origin,
            mode: ComposeMode.forward,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-compose-host')));
    await tester.pumpAndSettle();
    final staged = Directory('${temp.path}/mail_outbox_attachments')
        .listSync(recursive: true)
        .whereType<File>()
        .toList();
    expect(staged, hasLength(1));

    await tester.tap(find.byKey(const Key('compose-close')));
    await tester.pumpAndSettle();
    expect(find.text('有未保存的更改'), findsOneWidget);
    await tester.tap(find.byKey(const Key('compose-discard-changes')));
    await tester.pumpAndSettle();

    expect(staged.single.existsSync(), isFalse);
    expect(cached.existsSync(), isTrue);
  });

  testWidgets('fallback forward staging is included when sending', (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final temp = Directory.systemTemp.createTempSync('fallback_send_');
    addTearDown(() => temp.delete(recursive: true));
    final cached = File('${temp.path}/send-me.txt');
    cached.writeAsStringSync('send me');
    final origin = _forwardOrigin(
      account: fixture.account,
      folder: fixture.folder,
      attachments: [
        MailAttachment(
          id: 'a',
          emailLocalId: 1,
          partId: '2',
          filename: 'send-me.txt',
          mimeType: 'text/plain',
          sizeBytes: 7,
          localCachePath: cached.path,
        ),
      ],
    );
    final store = AttachmentStore(
      rootProvider: () async => temp,
      idGenerator: () => 'forward-send',
    );
    final send = _FakeSend(
      OutboxMessage(
        id: 'forward-send',
        accountId: fixture.account.id,
        mode: ComposeMode.forward,
        to: const [EmailAddressEntry(email: 'bob@example.com')],
        cc: const [],
        bcc: const [],
        subject: 'Fwd: Original',
        plainBody: 'body',
        attachments: const [],
        status: OutboxStatus.failed,
        retryCount: 1,
        retryable: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          attachmentStoreProvider.overrideWithValue(store),
          queueAndSendEmailUseCaseProvider.overrideWithValue(send),
        ],
        child: MaterialApp(
          home: _ComposeHost(
            account: fixture.account,
            originEmail: origin,
            mode: ComposeMode.forward,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-compose-host')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('compose-to-input')),
      'bob@example.com',
    );
    await tester.tap(find.byKey(const Key('compose-send')));
    await tester.pumpAndSettle();

    expect(send.capturedDraft?.attachments, hasLength(1));
    final staged = send.capturedDraft!.attachments.single;
    expect(staged.localPath, isNot(cached.path));
    expect(File(staged.localPath).existsSync(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('send queue failure keeps id and attachments on retry/discard',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final temp = Directory.systemTemp.createTempSync('queue_failure_');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}/queue-fail.txt');
    source.writeAsStringSync('payload');
    final store = AttachmentStore(
      rootProvider: () async => temp,
      idGenerator: () => 'queue-fail',
    );
    final repo = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: fixture.database),
    );
    final smtp = _FakeLiveSmtpSession();
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final failingQueue = _AlwaysFailEnqueueQueue(
      repository: repo,
      sessionFactory: _LiveSmtpFactory(smtp),
      credentialResolver: _StaticCredentialResolver(),
      authRepository: auth,
    );
    addTearDown(failingQueue.dispose);
    final useCase = QueueAndSendEmailUseCase(
      repository: repo,
      queue: failingQueue,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          outboxRepositoryProvider.overrideWithValue(repo),
          attachmentPickerProvider.overrideWithValue(
            _FakeAttachmentPicker(source.path),
          ),
          attachmentStoreProvider.overrideWithValue(store),
          queueAndSendEmailUseCaseProvider.overrideWithValue(useCase),
        ],
        child: MaterialApp(home: _ComposeHost(account: fixture.account)),
      ),
    );
    await tester.tap(find.byKey(const Key('open-compose-host')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose-attach')));
    await tester.pumpAndSettle();
    final staged = Directory('${temp.path}/mail_outbox_attachments')
        .listSync(recursive: true)
        .whereType<File>()
        .single;
    await tester.enterText(
      find.byKey(const Key('compose-to-input')),
      'bob@example.com',
    );
    await tester.tap(find.byKey(const Key('compose-send')));
    await tester.pumpAndSettle();

    expect(find.textContaining('发送队列启动失败'), findsOneWidget);
    var rows = await repo.getMessages();
    expect(rows, hasLength(1));
    final savedId = rows.single.id;
    expect(rows.single.status, OutboxStatus.draft);
    expect(staged.existsSync(), isTrue);

    await tester.tap(find.byKey(const Key('compose-send')));
    await tester.pumpAndSettle();
    rows = await repo.getMessages();
    expect(rows, hasLength(1));
    expect(rows.single.id, savedId);
    expect(failingQueue.attempts, 2);
    expect(staged.existsSync(), isTrue);

    await tester.enterText(
      find.byKey(const Key('compose-subject')),
      'changed',
    );
    await tester.tap(find.byKey(const Key('compose-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose-discard-changes')));
    await tester.pumpAndSettle();

    rows = await repo.getMessages();
    expect(rows, hasLength(1));
    expect(rows.single.id, savedId);
    expect(staged.existsSync(), isTrue);
  });

}
