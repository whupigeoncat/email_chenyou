// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import '../../../../core/error/failures.dart';
import '../../../../core/logging/sanitized_logger.dart';
import '../../../auth/data/account_credential_resolver.dart';
import '../../../auth/domain/entities/mail_account.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/entities/outbox_message.dart';
import '../../domain/repositories/outbox_repository.dart';
import '../datasources/smtp_session.dart';

typedef OutboxPostSendHook = Future<void> Function(
  OutboxMessage message,
  MailAccount account,
);

/// Serial per-account SMTP queue with exponential retry and best-effort IMAP
/// post-send work. SMTP sockets are always transient and never touch the IMAP
/// connection pool.
class OutboxQueueService {
  OutboxQueueService({
    required OutboxRepository repository,
    required SmtpSessionFactory sessionFactory,
    required AccountCredentialResolver credentialResolver,
    required AuthRepository authRepository,
    this.postSendHook,
    this.postSendDelay = const Duration(seconds: 3),
    this.postSendTimeout = const Duration(seconds: 10),
    this.maxRetries = 3,
    this.retryDelays = const <Duration>[
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 10),
    ],
    this.smtpTimeout = const Duration(seconds: 30),
    SanitizedLogger? logger,
  })  : _repository = repository,
        _sessionFactory = sessionFactory,
        _credentialResolver = credentialResolver,
        _authRepository = authRepository,
        _logger = logger ?? SanitizedLogger.instance;

  final OutboxRepository _repository;
  final SmtpSessionFactory _sessionFactory;
  final AccountCredentialResolver _credentialResolver;
  final AuthRepository _authRepository;
  final OutboxPostSendHook? postSendHook;
  final Duration postSendDelay;
  final Duration postSendTimeout;
  final int maxRetries;
  final List<Duration> retryDelays;
  final Duration smtpTimeout;
  final SanitizedLogger _logger;

  final Map<String, Future<void>> _accountChains = <String, Future<void>>{};
  final Map<String, Timer> _retryTimers = <String, Timer>{};
  StreamSubscription<void>? _networkSubscription;
  bool _started = false;
  bool _disposed = false;

  Future<void> start({Stream<void>? networkRestored}) async {
    if (_started || _disposed) return;
    _started = true;
    await _repository.resetStuckSending();
    _networkSubscription = networkRestored?.listen(
      (_) => unawaited(retryPending(ignoreDelay: true)),
      onError: (Object error, StackTrace stack) {
        _logger.warn('OutboxQueue', 'Network restored stream error', error);
      },
    );
    await retryPending();
  }

  Future<void> enqueueAndSend(String id) async {
    _cancelRetryTimer(id);
    await _repository.enqueue(id);
    await scheduleNow(id);
  }

  /// Automatic scheduling is only valid for a queued row or a retryable
  /// failed row. Drafts, in-flight, uncertain and sent rows must never be
  /// picked up by a stale retry timer.
  bool _canAutoSend(OutboxMessage? message) {
    if (message == null) return false;
    return switch (message.status) {
      OutboxStatus.queued => true,
      OutboxStatus.failed => message.retryable,
      OutboxStatus.draft ||
      OutboxStatus.sending ||
      OutboxStatus.uncertain ||
      OutboxStatus.sent =>
        false,
    };
  }

  /// Forces a queued/failed message to run immediately, respecting the
  /// account-level serial lock.
  Future<void> scheduleNow(String id) {
    _cancelRetryTimer(id);
    final messageFuture = _repository.getById(id);
    return messageFuture.then((message) {
      if (!_canAutoSend(message)) {
        return Future<void>.value();
      }
      return _enqueueAccount(message!.accountId, id);
    });
  }

  /// Explicit manual retry. An `uncertain` row is only requeued here after
  /// the user confirmed the send; it never happens through automatic paths.
  Future<void> retryNow(String id) async {
    _cancelRetryTimer(id);
    final row = await _repository.getById(id);
    if (row == null) return;
    if (row.status == OutboxStatus.sent ||
        row.status == OutboxStatus.sending ||
        row.status == OutboxStatus.draft) {
      throw const StorageFailure(userMessage: '当前邮件状态不允许重复发送。');
    }
    if (row.status == OutboxStatus.uncertain) {
      await _repository.confirmResend(id);
    } else {
      await _repository.markQueued(id);
    }
    await scheduleNow(id);
  }

  Future<void> retryPending({bool ignoreDelay = false}) async {
    final messages = await _repository.getRetryable();
    for (final message in messages) {
      if (!message.retryable || message.status == OutboxStatus.sent) continue;
      if (!ignoreDelay &&
          message.nextRetryAt != null &&
          message.nextRetryAt!.isAfter(DateTime.now().toUtc())) {
        _scheduleRetryTimer(message);
        continue;
      }
      unawaited(scheduleNow(message.id));
    }
  }

  Future<void> _enqueueAccount(String accountId, String messageId) {
    final previous = _accountChains[accountId] ?? Future<void>.value();
    late final Future<void> next;
    next = previous
        .catchError((_) {})
        .then((_) => _process(messageId))
        .whenComplete(() {
      if (identical(_accountChains[accountId], next)) {
        _accountChains.remove(accountId);
      }
    });
    _accountChains[accountId] = next;
    return next;
  }

  Future<void> _process(String messageId) async {
    if (_disposed) return;
    final message = await _repository.getById(messageId);
    if (!_canAutoSend(message)) return;
    final account = await _authRepository.getAccount(message!.accountId);
    if (account == null || !account.isEnabled) {
      await _repository.markFailed(
        messageId,
        error: '账户不存在或已停用',
        retryable: false,
        retryCount: message.retryCount,
      );
      return;
    }

    // Re-check immediately before entering the SMTP submission window: a
    // concurrent edit/save may have moved the row back to draft.
    final fresh = await _repository.getById(messageId);
    if (!_canAutoSend(fresh)) return;
    final marked = await _repository.markSending(messageId);
    if (!marked) return;
    final activeMessage = await _repository.getById(messageId) ?? message;
    SmtpSession? session;
    var acceptedByServer = false;
    try {
      session = _sessionFactory.createSession();
      try {
        final credential = await _credentialResolver(account);
        await session
            .connectAndAuthenticate(account: account, credential: credential)
            .timeout(smtpTimeout);
      } catch (error, stackTrace) {
        // Failure before DATA submission is deterministic: safe to retry.
        await _handleFailure(message, error, stackTrace);
        return;
      }

      try {
        await session
            .send(
              OutgoingMailEnvelope.fromComposeDraft(
                activeMessage.toComposeDraft(),
                account,
                messageId: activeMessage.outgoingMessageId,
              ),
            )
            .timeout(smtpTimeout);
      } catch (error, stackTrace) {
        if (_isAmbiguousSendFailure(error)) {
          await _markUncertain(message, error);
        } else {
          // Deterministic SMTP rejection / local validation failure.
          await _handleFailure(message, error, stackTrace);
        }
        return;
      }

      acceptedByServer = true;
      try {
        // Persist "sent" before any best-effort IMAP side effect. This is the
        // duplicate-send barrier: once SMTP accepted, IMAP failures never
        // cause a second SMTP attempt.
        await _repository.markSent(messageId);
      } catch (error) {
        await _markSentPersistenceFailure(message, error);
        return;
      }
      _schedulePostSendHook(activeMessage, account, messageId);
    } catch (error, stackTrace) {
      if (acceptedByServer) {
        // Do not retry SMTP after server acceptance, even if the local
        // "sent" write or a post-send action failed.
        await _markSentPersistenceFailure(message, error);
        return;
      }
      await _handleFailure(message, error, stackTrace);
    } finally {
      if (session != null) {
        try {
          await session.quitAndDisconnect(
            timeout: const Duration(seconds: 5),
          );
        } catch (error) {
          _logger.warn(
            'OutboxQueue',
            'SMTP cleanup failed for $messageId',
            error,
          );
          try {
            await session.forceClose();
          } catch (_) {
            // Already closed.
          }
        }
      }
    }
  }

  void _schedulePostSendHook(
    OutboxMessage message,
    MailAccount account,
    String messageId,
  ) {
    final hook = postSendHook;
    if (hook == null || _disposed) return;
    unawaited(() async {
      try {
        // Let the SMTP socket close before opening the transient IMAP socket.
        await Future<void>.delayed(postSendDelay);
        if (_disposed) return;
        await hook(message, account).timeout(postSendTimeout);
        _logger.debug(
          'OutboxQueue',
          'Post-send IMAP action completed for $messageId',
        );
      } catch (error, stackTrace) {
        _logger.warn(
          'OutboxQueue',
          'Post-send IMAP action failed for $messageId; message remains sent',
          error,
        );
        _logger.debug(
          'OutboxQueue',
          SanitizedLogger.sanitize(stackTrace.toString()),
        );
      }
    }());
  }

  /// A timeout or unexpected connection loss during `session.send` leaves the
  /// SMTP `DATA` outcome unknown. Re-sending could create a duplicate, so the
  /// row must pause in `uncertain` until the user explicitly confirms.
  bool _isAmbiguousSendFailure(Object error) {
    if (error is TimeoutException || error is NetworkFailure) return true;
    if (error is SocketException) return true;
    if (error is SmtpFailure && error.reason == SmtpFailureReason.timeout) {
      return true;
    }
    return false;
  }

  Future<void> _markUncertain(OutboxMessage message, Object error) async {
    final detail = error is AppFailure ? error.userMessage : error.toString();
    _logger.warn(
      'OutboxQueue',
      'Ambiguous SMTP submission for ${message.id}; pausing automatic retry',
      SanitizedLogger.sanitize(detail),
    );
    try {
      await _repository.markUncertain(
        message.id,
        error:
            '邮件在投递阶段发生超时或连接中断，服务器可能已接收该邮件。'
            '为防止重复发信，已暂停自动重试，请核对后确认重发或标记为已发送。',
      );
    } catch (persistError, persistStack) {
      _logger.error(
        'OutboxQueue',
        'Failed to persist uncertain state for ${message.id}; '
            'suppressing automatic retry anyway',
        persistError,
        persistStack,
      );
    }
  }

  Future<void> _markSentPersistenceFailure(
    OutboxMessage message,
    Object error,
  ) async {
    _logger.error(
      'OutboxQueue',
      'SMTP accepted ${message.id} but local sent persistence failed',
      error,
    );
    try {
      await _repository.markUncertain(
        message.id,
        error:
            '邮件已被服务器接受，但本地已发送状态写入失败：${SanitizedLogger.sanitize(error.toString())}。'
            '为防止重复发信，已暂停自动重试，请人工核对。',
      );
    } catch (_) {
      // No further automatic send attempt is safe.
    }
  }

  Future<void> _handleFailure(
    OutboxMessage message,
    Object error,
    StackTrace stackTrace,
  ) async {
    final retryable = isRetryableOutboxFailure(error) &&
        message.retryCount + 1 < maxRetries;
    final nextCount = message.retryCount + 1;
    final nextRetryAt = retryable
        ? DateTime.now().toUtc().add(_delayForRetry(nextCount))
        : null;
    final userMessage = error is AppFailure ? error.userMessage : 'SMTP 发送失败';
    _logger.warn(
      'OutboxQueue',
      'SMTP send failed for ${message.id} (retryable=$retryable)',
      error,
    );
    await _repository.markFailed(
      message.id,
      error: userMessage,
      retryable: retryable,
      retryCount: nextCount,
      nextRetryAt: nextRetryAt,
    );
    if (retryable) {
      final updated = await _repository.getById(message.id);
      if (updated != null) _scheduleRetryTimer(updated);
    } else {
      _logger.debug(
        'OutboxQueue',
        SanitizedLogger.sanitize(stackTrace.toString()),
      );
    }
  }

  Duration _delayForRetry(int retryCount) {
    if (retryCount <= 0) return retryDelays.first;
    if (retryCount > retryDelays.length) return retryDelays.last;
    return retryDelays[retryCount - 1];
  }

  void _cancelRetryTimer(String messageId) {
    _retryTimers.remove(messageId)?.cancel();
  }

  /// Public entry for edit/delete flows that must stop an already scheduled
  /// retry before the row changes state.
  void cancelRetry(String messageId) => _cancelRetryTimer(messageId);

  void _scheduleRetryTimer(OutboxMessage message) {
    if (_disposed ||
        !message.retryable ||
        message.status == OutboxStatus.uncertain ||
        message.nextRetryAt == null) {
      return;
    }
    _retryTimers[message.id]?.cancel();
    final delay = message.nextRetryAt!.difference(DateTime.now().toUtc());
    _retryTimers[message.id] = Timer(
      delay.isNegative ? Duration.zero : delay,
      () {
        _retryTimers.remove(message.id);
        if (!_disposed) unawaited(scheduleNow(message.id));
      },
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    await _networkSubscription?.cancel();
    _networkSubscription = null;
    _accountChains.clear();
  }
}
