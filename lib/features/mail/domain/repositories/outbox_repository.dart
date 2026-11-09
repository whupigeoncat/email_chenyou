import '../entities/outbox_message.dart';

/// Persistence contract for compose drafts and the send queue.
abstract interface class OutboxRepository {
  Stream<List<OutboxMessage>> watchMessages({String? accountId});

  Stream<List<OutboxMessage>> watchDrafts({String? accountId});

  Stream<OutboxCounts> watchCounts({String? accountId});

  Future<List<OutboxMessage>> getMessages({
    String? accountId,
    Set<OutboxStatus>? statuses,
  });

  Future<OutboxMessage?> getById(String id);

  Future<OutboxMessage> saveDraft({
    required ComposeDraft draft,
    String? id,
  });

  Future<void> enqueue(String id);

  /// Explicit user action: move an `uncertain` row back to the queue.
  Future<void> confirmResend(String id);

  Future<bool> markSending(String id);

  Future<void> markSent(String id);

  Future<void> markQueued(String id);

  Future<void> markFailed(
    String id, {
    required String error,
    required bool retryable,
    required int retryCount,
    DateTime? nextRetryAt,
  });

  /// Marks an ambiguous submission as awaiting manual confirmation. This is
  /// deliberately non-retryable: the server may already have accepted `DATA`.
  Future<void> markUncertain(String id, {required String error});

  Future<void> delete(String id);

  Future<void> resetStuckSending();

  Future<List<OutboxMessage>> getSendable();

  Future<List<OutboxMessage>> getRetryable();
}
