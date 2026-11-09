import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/outbox_message.dart';

class OutboxLocalDataSource {
  OutboxLocalDataSource({required this.database});

  final AppDatabase database;

  Stream<List<DbOutboxMessage>> watchMessages({String? accountId}) {
    final query = database.select(database.dbOutboxMessages)
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    if (accountId != null) {
      query.where((table) => table.accountId.equals(accountId));
    }
    return query.watch();
  }

  Future<List<DbOutboxMessage>> getMessages({
    String? accountId,
    Set<String>? statuses,
  }) async {
    final query = database.select(database.dbOutboxMessages)
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    if (accountId != null) {
      query.where((table) => table.accountId.equals(accountId));
    }
    if (statuses != null && statuses.isNotEmpty) {
      query.where((table) => table.status.isIn(statuses));
    }
    return query.get();
  }

  Future<DbOutboxMessage?> getById(String id) {
    return (database.select(database.dbOutboxMessages)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> insert(DbOutboxMessagesCompanion row) {
    return database.into(database.dbOutboxMessages).insert(row);
  }

  Future<void> update(
    String id,
    DbOutboxMessagesCompanion values,
  ) {
    return (database.update(database.dbOutboxMessages)
          ..where((table) => table.id.equals(id)))
        .write(values);
  }

  /// Atomic CAS: only a queued row or a retryable failed row may enter the
  /// sending state. Returns false for draft/sending/uncertain/sent and for
  /// non-retryable failures.
  Future<bool> markSendingIfSendable(String id) async {
    final updated =
        await (database.update(database.dbOutboxMessages)
              ..where(
                (table) =>
                    table.id.equals(id) &
                    (table.status.equals(OutboxStatus.queued.storageKey) |
                        (table.status.equals(OutboxStatus.failed.storageKey) &
                            table.retryable.equals(true))),
              ))
            .write(
              DbOutboxMessagesCompanion(
                status: Value(OutboxStatus.sending.storageKey),
                updatedAt: Value(
                  DateTime.now().toUtc().millisecondsSinceEpoch,
                ),
              ),
            );
    return updated > 0;
  }

  Future<void> delete(String id) {
    return (database.delete(database.dbOutboxMessages)
          ..where((table) => table.id.equals(id)))
        .go();
  }

  /// Atomically deletes only when the row is not in `sending`.
  Future<int> deleteNonSending(String id) {
    return (database.delete(database.dbOutboxMessages)
          ..where(
            (table) =>
                table.id.equals(id) &
                table.status.isNotValue(OutboxStatus.sending.storageKey),
          ))
        .go();
  }

  /// A leftover `sending` row means the process died inside the SMTP
  /// submission window. Never auto-resend: move it to `uncertain`.
  Future<void> resetStuckSending() {
    return (database.update(database.dbOutboxMessages)
          ..where((table) => table.status.equals(OutboxStatus.sending.storageKey)))
        .write(
      DbOutboxMessagesCompanion(
        status: Value(OutboxStatus.uncertain.storageKey),
        retryable: const Value(false),
        nextRetryAt: const Value(null),
        lastError: const Value(
          '上次发送在投递过程中意外中断，服务器可能已接收该邮件。'
          '已暂停自动重试，请核对后选择确认重发或标记为已发送。',
        ),
        updatedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  Future<List<DbOutboxMessage>> getRetryable() {
    final query = database.select(database.dbOutboxMessages)
      ..where(
        (table) =>
            table.status.isIn(<String>[
              OutboxStatus.queued.storageKey,
              OutboxStatus.failed.storageKey,
            ]) &
            table.retryable.equals(true),
      )
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);
    return query.get();
  }

  Future<List<DbOutboxMessage>> getSendable() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final query = database.select(database.dbOutboxMessages)
      ..where(
        (table) =>
            table.status.isIn(<String>[
              OutboxStatus.queued.storageKey,
              OutboxStatus.failed.storageKey,
            ]) &
            table.retryable.equals(true) &
            (table.nextRetryAt.isNull() | table.nextRetryAt.isSmallerOrEqualValue(now)),
      )
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);
    return query.get();
  }
}
