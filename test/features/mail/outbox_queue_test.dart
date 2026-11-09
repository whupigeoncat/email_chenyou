import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/logging/sanitized_logger.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/auth/data/account_credential_resolver.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/datasources/outbox_local_datasource.dart';
import 'package:local_mail_client/features/mail/data/datasources/smtp_session.dart';
import 'package:local_mail_client/features/mail/data/repositories/outbox_repository_impl.dart';
import 'package:local_mail_client/features/mail/data/services/outbox_queue_service.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';
import 'package:local_mail_client/features/mail/domain/services/attachment_picker.dart';
import 'package:local_mail_client/features/mail/domain/usecases/outbox_usecases.dart';

import '../auth/support/fakes.dart';
import 'support/mail_fixture.dart';

class _FakeCredentialResolver implements AccountCredentialResolver {
  @override
  Future<ResolvedAccountCredential> call(MailAccount account) async {
    return const PasswordCredential('fake-password');
  }
}

class _FakeSmtpSession implements SmtpSession {
  Object? sendError;
  Completer<void>? sendGate;
  int connectCount = 0;
  int sendCount = 0;
  int quitCount = 0;
  int inFlight = 0;
  int maxInFlight = 0;
  String? lastMessageId;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connectAndAuthenticate({
    required MailAccount account,
    required ResolvedAccountCredential credential,
  }) async {
    connectCount++;
    _connected = true;
  }

  @override
  Future<void> send(OutgoingMailEnvelope envelope) async {
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      lastMessageId = envelope.messageId;
      final gate = sendGate;
      if (gate != null) await gate.future;
      sendCount++;
      final error = sendError;
      if (error != null) throw error;
    } finally {
      inFlight--;
    }
  }

  @override
  Future<void> quitAndDisconnect({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    quitCount++;
    _connected = false;
  }

  @override
  Future<void> forceClose() async {
    _connected = false;
  }
}

class _FakeSmtpFactory implements SmtpSessionFactory {
  _FakeSmtpFactory(this.session);

  final _FakeSmtpSession session;

  @override
  SmtpSession createSession() => session;
}

ComposeDraft _draft(MailAccount account) {
  return ComposeDraft(
    accountId: account.id,
    mode: ComposeMode.reply,
    originEmailLocalId: 1,
    inReplyTo: '<original@example.com>',
    referencesHeader: '<original@example.com>',
    to: const [EmailAddressEntry(email: 'bob@example.com')],
    cc: const [],
    bcc: const [],
    subject: 'Re: hello',
    plainBody: 'body',
    attachments: const [],
  );
}

void main() {
  late MailFixture fixture;
  late OutboxRepositoryImpl repository;
  late FakeAuthRepository auth;
  late _FakeSmtpSession smtp;
  late OutboxQueueService queue;

  Future<OutboxMessage> queuedDraft() async {
    final saved = await repository.saveDraft(draft: _draft(fixture.account));
    await repository.enqueue(saved.id);
    return (await repository.getById(saved.id))!;
  }

  setUp(() async {
    fixture = await MailFixture.create();
    repository = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: fixture.database),
    );
    auth = FakeAuthRepository()..accounts.add(fixture.account);
    smtp = _FakeSmtpSession();
    queue = OutboxQueueService(
      repository: repository,
      sessionFactory: _FakeSmtpFactory(smtp),
      credentialResolver: _FakeCredentialResolver(),
      authRepository: auth,
      maxRetries: 3,
    );
  });

  tearDown(() async {
    await queue.dispose();
    await auth.dispose();
    await fixture.dispose();
  });

  test('success marks sent before best-effort post action', () async {
    final message = await queuedDraft();
    OutboxStatus? statusAtHook;
    final hookCalled = Completer<void>();
    final hookQueue = OutboxQueueService(
      repository: repository,
      sessionFactory: _FakeSmtpFactory(smtp),
      credentialResolver: _FakeCredentialResolver(),
      authRepository: auth,
      postSendDelay: const Duration(milliseconds: 10),
      postSendTimeout: const Duration(milliseconds: 100),
      postSendHook: (message, account) async {
        statusAtHook = (await repository.getById(message.id))!.status;
        hookCalled.complete();
        throw StateError('IMAP failure must not resend');
      },
    );
    addTearDown(hookQueue.dispose);

    await hookQueue.scheduleNow(message.id);

    expect(smtp.sendCount, 1);
    expect(smtp.quitCount, 1);
    expect(statusAtHook, isNull, reason: 'hook must run in background');
    expect((await repository.getById(message.id))!.status, OutboxStatus.sent);

    await hookCalled.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(statusAtHook, OutboxStatus.sent);
    await expectLater(
      queue.retryNow(message.id),
      throwsA(isA<StorageFailure>()),
    );
    expect(smtp.sendCount, 1);
  });

  test('non-completing post-send hook cannot block sending or resend',
      () async {
    final message = await queuedDraft();
    final hookStarted = Completer<void>();
    final logger = SanitizedLogger.instance;
    logger.clear();
    addTearDown(logger.clear);
    final hookQueue = OutboxQueueService(
      repository: repository,
      sessionFactory: _FakeSmtpFactory(smtp),
      credentialResolver: _FakeCredentialResolver(),
      authRepository: auth,
      postSendDelay: Duration.zero,
      postSendTimeout: const Duration(milliseconds: 40),
      postSendHook: (message, account) {
        hookStarted.complete();
        return Completer<void>().future;
      },
    );
    addTearDown(hookQueue.dispose);

    final stopwatch = Stopwatch()..start();
    await hookQueue.scheduleNow(message.id);
    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    expect((await repository.getById(message.id))!.status, OutboxStatus.sent);
    expect(smtp.sendCount, 1);
    expect(smtp.quitCount, 1);

    await hookStarted.future;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(
      logger.recentEntries.join('\n'),
      contains('message remains sent'),
    );
    await hookQueue.retryPending(ignoreDelay: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(smtp.sendCount, 1, reason: 'hook failure must never resend');
  });

  test('throwing hook does not stop the next queued message', () async {
    final hookQueue = OutboxQueueService(
      repository: repository,
      sessionFactory: _FakeSmtpFactory(smtp),
      credentialResolver: _FakeCredentialResolver(),
      authRepository: auth,
      postSendDelay: Duration.zero,
      postSendTimeout: const Duration(milliseconds: 50),
      postSendHook: (message, account) async {
        throw StateError('hook failed');
      },
    );
    addTearDown(hookQueue.dispose);
    final first = await queuedDraft();
    final second = await queuedDraft();

    await Future.wait(<Future<void>>[
      hookQueue.scheduleNow(first.id),
      hookQueue.scheduleNow(second.id),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect((await repository.getById(first.id))!.status, OutboxStatus.sent);
    expect((await repository.getById(second.id))!.status, OutboxStatus.sent);
    expect(smtp.sendCount, 2);
  });

  test('retryable failure backs off and manual retry sends again', () async {
    final message = await queuedDraft();
    smtp.sendError = const SmtpFailure(
      reason: SmtpFailureReason.protocolError,
      retryable: true,
      userMessage: 'temporary rejection',
    );
    await queue.scheduleNow(message.id);
    var stored = (await repository.getById(message.id))!;
    expect(stored.status, OutboxStatus.failed);
    expect(stored.retryable, isTrue);
    expect(stored.retryCount, 1);
    expect(stored.nextRetryAt, isNotNull);
    expect(smtp.sendCount, 1);
    expect(smtp.quitCount, 1);
    final firstMessageId = smtp.lastMessageId;
    expect(firstMessageId, isNotNull);

    smtp.sendError = null;
    await queue.retryNow(message.id);
    stored = (await repository.getById(message.id))!;
    expect(stored.status, OutboxStatus.sent);
    expect(smtp.sendCount, 2);
    expect(smtp.lastMessageId, firstMessageId,
        reason: 'retry must reuse the persisted Message-ID');
  });

  test('authentication failure is not retryable', () async {
    final message = await queuedDraft();
    smtp.sendError = const AuthFailure(
      reason: AuthFailureReason.invalidCredentials,
      userMessage: 'auth failed',
    );
    await queue.scheduleNow(message.id);
    final stored = (await repository.getById(message.id))!;
    expect(stored.status, OutboxStatus.failed);
    expect(stored.retryable, isFalse);
    expect(stored.nextRetryAt, isNull);
  });

  test('startup moves orphaned sending rows to uncertain without sending',
      () async {
    final message = await queuedDraft();
    await repository.markSending(message.id);
    await queue.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final stored = (await repository.getById(message.id))!;
    expect(stored.status, OutboxStatus.uncertain);
    expect(stored.retryable, isFalse);
    expect(stored.lastError, contains('意外中断'));
    expect(smtp.sendCount, 0);
  });

  test('timeout during session.send becomes uncertain with no auto retry',
      () async {
    final message = await queuedDraft();
    smtp.sendError = TimeoutException('DATA timeout');
    await queue.scheduleNow(message.id);
    var stored = (await repository.getById(message.id))!;
    expect(stored.status, OutboxStatus.uncertain);
    expect(stored.retryable, isFalse);
    expect(stored.nextRetryAt, null);
    expect(smtp.sendCount, 1);
    expect(smtp.quitCount, 1);

    await queue.retryPending(ignoreDelay: true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    stored = (await repository.getById(message.id))!;
    expect(stored.status, OutboxStatus.uncertain);
    expect(smtp.sendCount, 1, reason: 'must not resend automatically');
  });

  test('unexpected connection loss during send becomes uncertain', () async {
    final message = await queuedDraft();
    smtp.sendError = const NetworkFailure(
      userMessage: 'connection lost',
    );
    await queue.scheduleNow(message.id);
    final stored = (await repository.getById(message.id))!;
    expect(stored.status, OutboxStatus.uncertain);
    expect(stored.retryable, isFalse);
    expect(smtp.sendCount, 1);
  });

  test('accepted mail whose markSent fails becomes uncertain, never resent',
      () async {
    final message = await queuedDraft();
    var failedOnce = false;
    final failingRepository = _MarkSentFailsOnce(
      dataSource: OutboxLocalDataSource(database: fixture.database),
      onFailure: () => failedOnce = true,
    );
    final failingQueue = OutboxQueueService(
      repository: failingRepository,
      sessionFactory: _FakeSmtpFactory(smtp),
      credentialResolver: _FakeCredentialResolver(),
      authRepository: auth,
    );
    addTearDown(failingQueue.dispose);

    await failingQueue.scheduleNow(message.id);
    expect(failedOnce, isTrue);
    final stored = (await failingRepository.getById(message.id))!;
    expect(stored.status, OutboxStatus.uncertain);
    expect(stored.retryable, isFalse);
    expect(smtp.sendCount, 1);

    await failingQueue.retryPending(ignoreDelay: true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(smtp.sendCount, 1);
  });

  test('same account sends are serialized', () async {
    final first = await queuedDraft();
    final second = await queuedDraft();
    final gate = Completer<void>();
    smtp.sendGate = gate;

    final firstFuture = queue.scheduleNow(first.id);
    await Future<void>.delayed(Duration.zero);
    final secondFuture = queue.scheduleNow(second.id);
    await Future<void>.delayed(Duration.zero);

    expect(smtp.maxInFlight, 1);
    gate.complete();
    await Future.wait(<Future<void>>[firstFuture, secondFuture]);
    expect(smtp.maxInFlight, 1);
    expect(smtp.sendCount, 2);
  });

  test('network restored retries a failed retryable message', () async {
    final message = await queuedDraft();
    final network = StreamController<void>.broadcast();
    addTearDown(network.close);
    await queue.start(networkRestored: network.stream);
    // start() already schedules the queued message and it succeeds.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect((await repository.getById(message.id))!.status, OutboxStatus.sent);
    smtp.sendError = const SmtpFailure(
      reason: SmtpFailureReason.protocolError,
      retryable: true,
      userMessage: 'temporary rejection',
    );
    final second = await queuedDraft();
    await queue.scheduleNow(second.id);
    expect((await repository.getById(second.id))!.status, OutboxStatus.failed);
    smtp.sendError = null;
    network.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect((await repository.getById(second.id))!.status, OutboxStatus.sent);
  });

  test('explicit retry after uncertain confirmation resends once', () async {
    final message = await queuedDraft();
    smtp.sendError = TimeoutException('DATA timeout');
    await queue.scheduleNow(message.id);
    expect((await repository.getById(message.id))!.status, OutboxStatus.uncertain);
    expect(smtp.sendCount, 1);

    smtp.sendError = null;
    await queue.retryNow(message.id);
    final stored = (await repository.getById(message.id))!;
    expect(stored.status, OutboxStatus.sent);
    expect(smtp.sendCount, 2);
  });

  test('markUncertain persistence failure is swallowed and never retried',
      () async {
    final message = await queuedDraft();
    var markFailedCalled = false;
    final failingRepository = _MarkUncertainFails(
      dataSource: OutboxLocalDataSource(database: fixture.database),
      onMarkFailed: () => markFailedCalled = true,
    );
    final failingQueue = OutboxQueueService(
      repository: failingRepository,
      sessionFactory: _FakeSmtpFactory(smtp),
      credentialResolver: _FakeCredentialResolver(),
      authRepository: auth,
    );
    addTearDown(failingQueue.dispose);

    smtp.sendError = TimeoutException('DATA timeout');
    await failingQueue.scheduleNow(message.id);
    expect(smtp.sendCount, 1);
    expect(markFailedCalled, isFalse);
    expect(
      (await failingRepository.getById(message.id))!.status,
      OutboxStatus.sending,
    );

    await failingQueue.retryPending(ignoreDelay: true);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(smtp.sendCount, 1);
  });

  test('repository refuses to delete a sending row and keeps attachments',
      () async {
    final temp = Directory.systemTemp.createTempSync('delete_sending_');
    addTearDown(() => temp.delete(recursive: true));
    final attachment = File('${temp.path}/mail_outbox_attachments/note.txt');
    attachment.parent.createSync(recursive: true);
    attachment.writeAsStringSync('keep me');
    final storeRepository = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: fixture.database),
      attachmentStore: AttachmentStore(rootProvider: () async => temp),
    );
    final saved = await storeRepository.saveDraft(
      draft: ComposeDraft(
        accountId: fixture.account.id,
        mode: ComposeMode.newMail,
        to: const [EmailAddressEntry(email: 'bob@example.com')],
        cc: const [],
        bcc: const [],
        subject: 'sending delete',
        plainBody: 'body',
        attachments: [
          OutgoingAttachment(
            fileName: 'note.txt',
            mimeType: 'text/plain',
            localPath: attachment.path,
            sizeBytes: 7,
          ),
        ],
      ),
    );
    await storeRepository.enqueue(saved.id);
    await storeRepository.markSending(saved.id);

    await expectLater(
      storeRepository.delete(saved.id),
      throwsA(
        isA<StorageFailure>().having(
          (failure) => failure.userMessage,
          'userMessage',
          contains('发送中'),
        ),
      ),
    );
    expect(await storeRepository.getById(saved.id), isNotNull);
    expect(attachment.existsSync(), isTrue);
  });

  test('queued delete and markSendingIfSendable are mutually exclusive',
      () async {
    final dataSource = OutboxLocalDataSource(database: fixture.database);
    for (var i = 0; i < 20; i++) {
      final saved = await repository.saveDraft(
        draft: ComposeDraft(
          accountId: fixture.account.id,
          mode: ComposeMode.newMail,
          to: const [EmailAddressEntry(email: 'bob@example.com')],
          cc: const [],
          bcc: const [],
          subject: 'race $i',
          plainBody: 'body',
        ),
      );
      await repository.enqueue(saved.id);

      final results = await Future.wait<Object>([
        dataSource.deleteNonSending(saved.id),
        dataSource.markSendingIfSendable(saved.id),
      ]);
      final deleted = results[0] as int;
      final marked = results[1] as bool;
      expect(
        deleted + (marked ? 1 : 0),
        1,
        reason: 'exactly one side may win the CAS',
      );
      final row = await dataSource.getById(saved.id);
      if (marked) {
        expect(row?.status, OutboxStatus.sending.storageKey);
      } else {
        expect(row, null);
      }
    }
  });

  test('DeleteOutboxMessageUseCase cancels retry after successful delete',
      () async {
    final saved = await repository.saveDraft(
      draft: ComposeDraft(
        accountId: fixture.account.id,
        mode: ComposeMode.newMail,
        to: const [EmailAddressEntry(email: 'bob@example.com')],
        cc: const [],
        bcc: const [],
        subject: 'delete cancel',
        plainBody: 'body',
      ),
    );
    final cancelQueue = _RecordingCancelQueue(
      repository: repository,
      sessionFactory: _FakeSmtpFactory(smtp),
      credentialResolver: _FakeCredentialResolver(),
      authRepository: auth,
    );
    addTearDown(cancelQueue.dispose);
    final useCase = DeleteOutboxMessageUseCase(
      repository: repository,
      queue: cancelQueue,
    );

    await useCase(saved.id);

    expect(cancelQueue.cancelledIds, <String>[saved.id]);
    expect(await repository.getById(saved.id), null);
  });
}





class _MarkSentFailsOnce extends OutboxRepositoryImpl {
  _MarkSentFailsOnce({
    required super.dataSource,
    required this.onFailure,
  });

  final void Function() onFailure;
  bool _failed = false;

  @override
  Future<void> markSent(String id) async {
    if (!_failed) {
      _failed = true;
      onFailure();
      throw StateError('simulated local sent persistence failure');
    }
    return super.markSent(id);
  }
}


class _MarkUncertainFails extends OutboxRepositoryImpl {
  _MarkUncertainFails({
    required super.dataSource,
    required this.onMarkFailed,
  });

  final void Function() onMarkFailed;

  @override
  Future<void> markFailed(
    String id, {
    required String error,
    required bool retryable,
    required int retryCount,
    DateTime? nextRetryAt,
  }) {
    onMarkFailed();
    return super.markFailed(
      id,
      error: error,
      retryable: retryable,
      retryCount: retryCount,
      nextRetryAt: nextRetryAt,
    );
  }

  @override
  Future<void> markUncertain(String id, {required String error}) async {
    throw StateError('simulated uncertain persistence failure');
  }
}


class _RecordingCancelQueue extends OutboxQueueService {
  _RecordingCancelQueue({
    required super.repository,
    required super.sessionFactory,
    required super.credentialResolver,
    required super.authRepository,
  });

  final List<String> cancelledIds = <String>[];

  @override
  void cancelRetry(String messageId) {
    cancelledIds.add(messageId);
    super.cancelRetry(messageId);
  }
}
