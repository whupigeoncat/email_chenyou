// ignore_for_file: prefer_initializing_formals

import '../../../../core/error/failures.dart';
import '../../data/services/outbox_queue_service.dart';
import '../entities/outbox_message.dart';
import '../repositories/outbox_repository.dart';

class SaveDraftUseCase {
  const SaveDraftUseCase({
    required OutboxRepository repository,
    OutboxQueueService? queue,
  })  : _repository = repository,
        _queue = queue;

  final OutboxRepository _repository;
  final OutboxQueueService? _queue;

  Future<OutboxMessage> call({
    required ComposeDraft draft,
    String? id,
  }) async {
    if (id != null) _queue?.cancelRetry(id);
    final saved = await _repository.saveDraft(draft: draft, id: id);
    _queue?.cancelRetry(saved.id);
    return saved;
  }
}

class OutboxSendException implements Exception {
  const OutboxSendException({
    required this.persistedMessage,
    required this.cause,
  });

  final OutboxMessage persistedMessage;
  final Object cause;

  String get userMessage => cause is AppFailure
      ? (cause as AppFailure).userMessage
      : '邮件已保存，但发送队列启动失败：$cause';

  @override
  String toString() => 'OutboxSendException($userMessage)';
}

class QueueAndSendEmailUseCase {
  const QueueAndSendEmailUseCase({
    required OutboxRepository repository,
    required OutboxQueueService queue,
  })  : _repository = repository,
        _queue = queue;

  final OutboxRepository _repository;
  final OutboxQueueService _queue;

  Future<OutboxMessage> call({
    required ComposeDraft draft,
    String? id,
  }) async {
    final message = await _repository.saveDraft(draft: draft, id: id);
    if (message.status == OutboxStatus.sent ||
        message.status == OutboxStatus.sending ||
        message.status == OutboxStatus.uncertain) {
      return message;
    }
    try {
      await _queue.enqueueAndSend(message.id);
    } catch (error) {
      final persisted = (await _repository.getById(message.id)) ?? message;
      throw OutboxSendException(persistedMessage: persisted, cause: error);
    }
    return (await _repository.getById(message.id)) ?? message;
  }
}

class RetryOutboxMessageUseCase {
  const RetryOutboxMessageUseCase({required OutboxQueueService queue})
      : _queue = queue;

  final OutboxQueueService _queue;

  Future<void> call(String id) => _queue.retryNow(id);
}

class MarkOutboxMessageSentUseCase {
  const MarkOutboxMessageSentUseCase({required OutboxRepository repository})
      : _repository = repository;

  final OutboxRepository _repository;

  Future<void> call(String id) => _repository.markSent(id);
}

class DeleteOutboxMessageUseCase {
  const DeleteOutboxMessageUseCase({
    required OutboxRepository repository,
    OutboxQueueService? queue,
  })  : _repository = repository,
        _queue = queue;

  final OutboxRepository _repository;
  final OutboxQueueService? _queue;

  Future<void> call(String id) async {
    await _repository.delete(id);
    _queue?.cancelRetry(id);
  }
}
