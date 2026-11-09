import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/auth/data/account_credential_resolver.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/datasources/smtp_session.dart';
import 'package:local_mail_client/features/mail/data/services/outbox_queue_service.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';
import 'package:local_mail_client/features/mail/domain/repositories/outbox_repository.dart';
import 'package:local_mail_client/features/mail/domain/usecases/outbox_usecases.dart';

import '../auth/support/fakes.dart';
import '../../core/support/fake_imap_session.dart';

class _FakeCredentialResolver implements AccountCredentialResolver {
  @override
  Future<ResolvedAccountCredential> call(MailAccount account) async =>
      const PasswordCredential('code');
}

class _FakeSmtpSession implements SmtpSession {
  int sendCount = 0;
  Object? error;
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
    final currentError = error;
    if (currentError != null) throw currentError;
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

class _FakeSmtpFactory implements SmtpSessionFactory {
  _FakeSmtpFactory(this.session);
  final _FakeSmtpSession session;

  @override
  SmtpSession createSession() => session;
}

class _MemoryOutboxRepository implements OutboxRepository {
  _MemoryOutboxRepository(this.message);

  OutboxMessage message;

  @override
  Future<OutboxMessage?> getById(String id) async =>
      id == message.id ? message : null;

  @override
  Future<List<OutboxMessage>> getRetryable() async =>
      message.retryable ? [message] : const [];

  @override
  Future<List<OutboxMessage>> getSendable() => getRetryable();

  @override
  Future<bool> markSending(String id) async {
    message = message.copyWith(status: OutboxStatus.sending);
    return true;
  }

  @override
  Future<void> recordSentCopy(
    String id, {
    required bool saved,
    String? error,
  }) async {
    message = message.copyWith(sentCopySaved: saved, lastError: error);
  }

  @override
  Future<void> markSent(String id) async {
    message = message.copyWith(
      status: OutboxStatus.sent,
      retryable: false,
      sentAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> confirmResend(String id) => markQueued(id);

  @override
  Future<void> markUncertain(String id, {required String error}) async {
    message = message.copyWith(
      status: OutboxStatus.uncertain,
      retryable: false,
      lastError: error,
    );
  }

  @override
  Future<void> markQueued(String id) async {
    message = message.copyWith(status: OutboxStatus.queued, retryable: true);
  }

  @override
  Future<void> markFailed(
    String id, {
    required String error,
    required bool retryable,
    required int retryCount,
    DateTime? nextRetryAt,
  }) async {
    message = message.copyWith(
      status: OutboxStatus.failed,
      retryable: retryable,
      retryCount: retryCount,
      nextRetryAt: nextRetryAt,
      clearNextRetryAt: nextRetryAt == null,
      lastError: error,
    );
  }

  @override
  Future<void> enqueue(String id) => markQueued(id);

  @override
  Future<void> resetStuckSending() async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<OutboxMessage> saveDraft({
    required ComposeDraft draft,
    String? id,
  }) async {
    message = message.copyWith(
      id: id ?? message.id,
      status: OutboxStatus.draft,
      retryable: true,
      clearNextRetryAt: true,
      subject: draft.subject,
      plainBody: draft.plainBody,
      attachments: draft.attachments,
    );
    return message;
  }

  @override
  Future<List<OutboxMessage>> getMessages({
    String? accountId,
    Set<OutboxStatus>? statuses,
  }) => throw UnimplementedError();

  @override
  Stream<OutboxCounts> watchCounts({String? accountId}) =>
      throw UnimplementedError();

  @override
  Stream<List<OutboxMessage>> watchDrafts({String? accountId}) =>
      throw UnimplementedError();

  @override
  Stream<List<OutboxMessage>> watchMessages({String? accountId}) =>
      throw UnimplementedError();
}

class _FlipToDraftRepository extends _MemoryOutboxRepository {
  _FlipToDraftRepository(super.message);

  int _reads = 0;

  @override
  Future<OutboxMessage?> getById(String id) async {
    _reads++;
    if (_reads >= 2) {
      message = message.copyWith(status: OutboxStatus.draft);
    }
    return super.getById(id);
  }
}

OutboxMessage _message({
  String id = 'retry-base',
  OutboxStatus status = OutboxStatus.queued,
  bool retryable = true,
}) {
  final now = DateTime.utc(2026);
  return OutboxMessage(
    id: id,
    accountId: 'acc-1',
    mode: ComposeMode.newMail,
    to: const [EmailAddressEntry(email: 'bob@example.com')],
    cc: const [],
    bcc: const [],
    subject: 'retry',
    plainBody: 'body',
    attachments: const [],
    status: status,
    retryCount: 0,
    retryable: retryable,
    createdAt: now,
    updatedAt: now,
  );
}

ComposeDraft _draft() {
  return const ComposeDraft(
    accountId: 'acc-1',
    mode: ComposeMode.newMail,
    to: [EmailAddressEntry(email: 'bob@example.com')],
    cc: [],
    bcc: [],
    subject: 'draft',
    plainBody: 'body',
  );
}

OutboxQueueService _buildQueue(
  _MemoryOutboxRepository repository,
  _FakeSmtpSession smtp,
  FakeAuthRepository auth,
) {
  return OutboxQueueService(
    repository: repository,
    sessionFactory: _FakeSmtpFactory(smtp),
    credentialResolver: _FakeCredentialResolver(),
    authRepository: auth,
    maxRetries: 3,
  );
}

void main() {
  test('retry timer uses exponential backoff under fake_async', () {
    fakeAsync((async) {
      final now = DateTime.utc(2026);
      final message = OutboxMessage(
        id: 'retry-1',
        accountId: 'acc-1',
        mode: ComposeMode.newMail,
        to: const [EmailAddressEntry(email: 'bob@example.com')],
        cc: const [],
        bcc: const [],
        subject: 'retry',
        plainBody: 'body',
        attachments: const [],
        status: OutboxStatus.queued,
        retryCount: 0,
        retryable: true,
        createdAt: now,
        updatedAt: now,
      );
      final repository = _MemoryOutboxRepository(message);
      final smtp = _FakeSmtpSession()
        ..error = const SmtpFailure(
          reason: SmtpFailureReason.protocolError,
          retryable: true,
          userMessage: 'temporary',
        );
      final account = buildTestAccount(id: 'acc-1');
      final auth = FakeAuthRepository()..accounts.add(account);
      final queue = OutboxQueueService(
        repository: repository,
        sessionFactory: _FakeSmtpFactory(smtp),
        credentialResolver: _FakeCredentialResolver(),
        authRepository: auth,
        maxRetries: 3,
      );

      unawaited(queue.scheduleNow(message.id));
      async.flushMicrotasks();
      expect(repository.message.status, OutboxStatus.failed);
      expect(repository.message.retryCount, 1);
      expect(repository.message.nextRetryAt, isNotNull);

      smtp.error = null;
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(smtp.sendCount, 2);
      expect(repository.message.status, OutboxStatus.sent);

      unawaited(queue.dispose());
      async.flushMicrotasks();
    });
  });

  test('retry delays reach 2m/10m and stop at maxRetries', () {
    fakeAsync((async) {
      final now = DateTime.utc(2026);
      final message = OutboxMessage(
        id: 'retry-2',
        accountId: 'acc-1',
        mode: ComposeMode.newMail,
        to: const [EmailAddressEntry(email: 'bob@example.com')],
        cc: const [],
        bcc: const [],
        subject: 'retry',
        plainBody: 'body',
        attachments: const [],
        status: OutboxStatus.queued,
        retryCount: 0,
        retryable: true,
        createdAt: now,
        updatedAt: now,
      );
      final repository = _MemoryOutboxRepository(message);
      final smtp = _FakeSmtpSession()
        ..error = const SmtpFailure(
          reason: SmtpFailureReason.protocolError,
          retryable: true,
          userMessage: 'temporary',
        );
      final account = buildTestAccount(id: 'acc-1');
      final auth = FakeAuthRepository()..accounts.add(account);
      final queue = OutboxQueueService(
        repository: repository,
        sessionFactory: _FakeSmtpFactory(smtp),
        credentialResolver: _FakeCredentialResolver(),
        authRepository: auth,
        maxRetries: 4,
      );

      unawaited(queue.scheduleNow(message.id));
      async.flushMicrotasks();
      expect(repository.message.retryCount, 1);
      final firstDelay = repository.message.nextRetryAt!.difference(
        DateTime.now().toUtc(),
      );
      expect(firstDelay.inSeconds, closeTo(30, 2));

      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(repository.message.retryCount, 2);
      final secondDelay = repository.message.nextRetryAt!.difference(
        DateTime.now().toUtc(),
      );
      expect(secondDelay.inMinutes, closeTo(2, 1));

      async.elapse(const Duration(minutes: 2));
      async.flushMicrotasks();
      expect(repository.message.retryCount, 3);
      final thirdDelay = repository.message.nextRetryAt!.difference(
        DateTime.now().toUtc(),
      );
      expect(thirdDelay.inMinutes, closeTo(10, 1));

      async.elapse(const Duration(minutes: 10));
      async.flushMicrotasks();
      expect(repository.message.retryCount, 4);
      expect(repository.message.retryable, isFalse);
      expect(repository.message.nextRetryAt, null);
      expect(smtp.sendCount, 4);

      async.elapse(const Duration(hours: 1));
      async.flushMicrotasks();
      expect(smtp.sendCount, 4, reason: 'maxRetries exhausted');
      unawaited(queue.dispose());
      async.flushMicrotasks();
    });
  });

  test('dispose cancels pending retry timers', () {
    fakeAsync((async) {
      final now = DateTime.utc(2026);
      final message = OutboxMessage(
        id: 'retry-dispose',
        accountId: 'acc-1',
        mode: ComposeMode.newMail,
        to: const [EmailAddressEntry(email: 'bob@example.com')],
        cc: const [],
        bcc: const [],
        subject: 'retry',
        plainBody: 'body',
        attachments: const [],
        status: OutboxStatus.queued,
        retryCount: 0,
        retryable: true,
        createdAt: now,
        updatedAt: now,
      );
      final repository = _MemoryOutboxRepository(message);
      final smtp = _FakeSmtpSession()
        ..error = const SmtpFailure(
          reason: SmtpFailureReason.protocolError,
          retryable: true,
          userMessage: 'temporary',
        );
      final account = buildTestAccount(id: 'acc-1');
      final auth = FakeAuthRepository()..accounts.add(account);
      final queue = OutboxQueueService(
        repository: repository,
        sessionFactory: _FakeSmtpFactory(smtp),
        credentialResolver: _FakeCredentialResolver(),
        authRepository: auth,
      );

      unawaited(queue.scheduleNow(message.id));
      async.flushMicrotasks();
      expect(async.pendingTimers, isNotEmpty);

      unawaited(queue.dispose());
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty);

      async.elapse(const Duration(minutes: 30));
      async.flushMicrotasks();
      expect(smtp.sendCount, 1);
    });
  });

  test('saving a failed row as draft cancels the pending retry timer', () {
    fakeAsync((async) {
      final repository = _MemoryOutboxRepository(_message());
      final smtp = _FakeSmtpSession()
        ..error = const SmtpFailure(
          reason: SmtpFailureReason.protocolError,
          retryable: true,
          userMessage: 'temporary',
        );
      final auth = FakeAuthRepository()
        ..accounts.add(buildTestAccount(id: 'acc-1'));
      final queue = _buildQueue(repository, smtp, auth);

      unawaited(queue.scheduleNow(repository.message.id));
      async.flushMicrotasks();
      expect(repository.message.status, OutboxStatus.failed);
      expect(async.pendingTimers, isNotEmpty);

      final save = SaveDraftUseCase(repository: repository, queue: queue);
      unawaited(save.call(draft: _draft(), id: repository.message.id));
      async.flushMicrotasks();
      expect(repository.message.status, OutboxStatus.draft);

      async.elapse(const Duration(seconds: 30));
      async.elapse(const Duration(minutes: 30));
      async.flushMicrotasks();
      expect(repository.message.status, OutboxStatus.draft);
      expect(smtp.sendCount, 1);

      unawaited(queue.dispose());
      async.flushMicrotasks();
    });
  });

  test('cancelRetry stops an already scheduled retry timer', () {
    fakeAsync((async) {
      final repository = _MemoryOutboxRepository(_message());
      final smtp = _FakeSmtpSession()
        ..error = const SmtpFailure(
          reason: SmtpFailureReason.protocolError,
          retryable: true,
          userMessage: 'temporary',
        );
      final auth = FakeAuthRepository()
        ..accounts.add(buildTestAccount(id: 'acc-1'));
      final queue = _buildQueue(repository, smtp, auth);

      unawaited(queue.scheduleNow(repository.message.id));
      async.flushMicrotasks();
      expect(smtp.sendCount, 1);

      smtp.error = null;
      queue.cancelRetry(repository.message.id);
      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();
      expect(smtp.sendCount, 1);

      unawaited(queue.dispose());
      async.flushMicrotasks();
    });
  });

  test(
    'scheduleNow and _process refuse draft and non-retryable failed rows',
    () {
      fakeAsync((async) {
        final draftRepo = _MemoryOutboxRepository(
          _message(status: OutboxStatus.draft),
        );
        final draftSmtp = _FakeSmtpSession();
        final draftAuth = FakeAuthRepository()
          ..accounts.add(buildTestAccount(id: 'acc-1'));
        final draftQueue = _buildQueue(draftRepo, draftSmtp, draftAuth);
        unawaited(draftQueue.scheduleNow(draftRepo.message.id));
        async.flushMicrotasks();
        expect(draftSmtp.sendCount, 0);

        final failedRepo = _MemoryOutboxRepository(
          _message(status: OutboxStatus.failed, retryable: false),
        );
        final failedSmtp = _FakeSmtpSession();
        final failedAuth = FakeAuthRepository()
          ..accounts.add(buildTestAccount(id: 'acc-1'));
        final failedQueue = _buildQueue(failedRepo, failedSmtp, failedAuth);
        unawaited(failedQueue.scheduleNow(failedRepo.message.id));
        async.flushMicrotasks();
        expect(failedSmtp.sendCount, 0);

        unawaited(draftQueue.dispose());
        unawaited(failedQueue.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test('concurrent draft flip before _process is rejected', () {
    fakeAsync((async) {
      final repository = _FlipToDraftRepository(_message());
      final smtp = _FakeSmtpSession();
      final auth = FakeAuthRepository()
        ..accounts.add(buildTestAccount(id: 'acc-1'));
      final queue = _buildQueue(repository, smtp, auth);

      unawaited(queue.scheduleNow(repository.message.id));
      async.flushMicrotasks();
      expect(smtp.sendCount, 0);
      expect(repository.message.status, OutboxStatus.draft);

      unawaited(queue.dispose());
      async.flushMicrotasks();
    });
  });

  test(
    'manual retry after a failed timer resends once and clears old timer',
    () {
      fakeAsync((async) {
        final repository = _MemoryOutboxRepository(_message());
        final smtp = _FakeSmtpSession()
          ..error = const SmtpFailure(
            reason: SmtpFailureReason.protocolError,
            retryable: true,
            userMessage: 'temporary',
          );
        final auth = FakeAuthRepository()
          ..accounts.add(buildTestAccount(id: 'acc-1'));
        final queue = _buildQueue(repository, smtp, auth);

        unawaited(queue.scheduleNow(repository.message.id));
        async.flushMicrotasks();
        expect(smtp.sendCount, 1);
        expect(repository.message.status, OutboxStatus.failed);

        smtp.error = null;
        unawaited(queue.retryNow(repository.message.id));
        async.flushMicrotasks();
        expect(smtp.sendCount, 2);
        expect(repository.message.status, OutboxStatus.sent);

        async.elapse(const Duration(seconds: 30));
        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();
        expect(smtp.sendCount, 2);

        unawaited(queue.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test('post-send hook failure never requeues an already sent message', () {
    fakeAsync((async) {
      final repository = _MemoryOutboxRepository(_message());
      final smtp = _FakeSmtpSession();
      final auth = FakeAuthRepository()
        ..accounts.add(buildTestAccount(id: 'acc-1'));
      final queue = OutboxQueueService(
        repository: repository,
        sessionFactory: _FakeSmtpFactory(smtp),
        credentialResolver: _FakeCredentialResolver(),
        authRepository: auth,
        postSendDelay: Duration.zero,
        postSendTimeout: const Duration(milliseconds: 10),
        postSendHook: (message, account) async {
          throw StateError('post-send hook failed');
        },
      );

      unawaited(queue.scheduleNow(repository.message.id));
      async.flushMicrotasks();
      expect(repository.message.status, OutboxStatus.sent);
      expect(smtp.sendCount, 1);

      unawaited(queue.retryPending(ignoreDelay: true));
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 30));
      async.flushMicrotasks();
      expect(repository.message.status, OutboxStatus.sent);
      expect(smtp.sendCount, 1);

      unawaited(queue.dispose());
      async.flushMicrotasks();
    });
  });
}
