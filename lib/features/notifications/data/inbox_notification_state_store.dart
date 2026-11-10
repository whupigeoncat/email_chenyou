import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class InboxNotificationCheckpoint {
  const InboxNotificationCheckpoint({
    required this.accountId,
    required this.uidValidity,
    required this.lastNotifiedUid,
    required this.baselineEstablished,
    required this.failureCount,
    required this.nextRetryAt,
    required this.lastErrorKind,
  });

  final String accountId;
  final int? uidValidity;
  final int lastNotifiedUid;
  final bool baselineEstablished;
  final int failureCount;
  final DateTime? nextRetryAt;
  final String? lastErrorKind;
}

/// Persistent UIDVALIDITY + UID watermark used to avoid duplicate notices.
///
/// The watermark is monotonic within one UIDVALIDITY. A local cache prune or a
/// stale foreground read cannot move it backwards; only a UIDVALIDITY change
/// may reset it.
class InboxNotificationStateStore {
  InboxNotificationStateStore({required this.database});

  final AppDatabase database;

  Future<InboxNotificationCheckpoint?> get(String accountId) async {
    final row = await (database.select(
      database.dbInboxNotificationStates,
    )..where((table) => table.accountId.equals(accountId))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// First run / UIDVALIDITY reset: remember every existing message as old.
  Future<void> saveBaseline({
    required String accountId,
    required int? uidValidity,
    required int lastUid,
  }) {
    return _upsert(
      accountId: accountId,
      uidValidity: uidValidity,
      lastNotifiedUid: lastUid,
      baselineEstablished: true,
    );
  }

  /// Foreground sync has already shown these messages in the app.
  Future<void> markForegroundSynced({
    required String accountId,
    required int? uidValidity,
    required int lastUid,
  }) {
    return _upsert(
      accountId: accountId,
      uidValidity: uidValidity,
      lastNotifiedUid: lastUid,
      baselineEstablished: true,
    );
  }

  Future<void> recordSuccess({
    required String accountId,
    required int? uidValidity,
    required int lastNotifiedUid,
  }) {
    return _upsert(
      accountId: accountId,
      uidValidity: uidValidity,
      lastNotifiedUid: lastNotifiedUid,
      baselineEstablished: true,
    );
  }

  Future<void> recordFailure({
    required String accountId,
    required String kind,
    required DateTime nextRetryAt,
    required int failureCount,
  }) async {
    final existing = await get(accountId);
    await database
        .into(database.dbInboxNotificationStates)
        .insertOnConflictUpdate(
          DbInboxNotificationStatesCompanion.insert(
            accountId: accountId,
            uidValidity: Value(existing?.uidValidity),
            lastNotifiedUid: Value(existing?.lastNotifiedUid ?? 0),
            baselineEstablished: Value(existing?.baselineEstablished ?? false),
            lastCheckedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
            failureCount: Value(failureCount),
            nextRetryAt: Value(nextRetryAt.toUtc().millisecondsSinceEpoch),
            lastErrorKind: Value(kind),
          ),
        );
  }

  Future<void> reset(String accountId) async {
    await (database.delete(
      database.dbInboxNotificationStates,
    )..where((table) => table.accountId.equals(accountId))).go();
  }

  /// Used when the user turns background checks back on. The next check must
  /// establish a fresh baseline instead of notifying mail accumulated while off.
  Future<void> resetAll() async {
    await database.delete(database.dbInboxNotificationStates).go();
  }

  Future<void> _upsert({
    required String accountId,
    required int? uidValidity,
    required int lastNotifiedUid,
    required bool baselineEstablished,
  }) async {
    final existing = await get(accountId);
    var nextUid = lastNotifiedUid;
    var nextBaseline = baselineEstablished;
    var nextValidity = uidValidity;
    if (existing != null) {
      final sameIdentity = existing.uidValidity == uidValidity;
      final unknownIdentity =
          existing.uidValidity == null || uidValidity == null;
      if (sameIdentity || unknownIdentity) {
        // Same (or not yet provable) mailbox identity: never move backwards.
        // A null UIDVALIDITY is not a valid new identity and must not reset a
        // known watermark.
        nextUid = existing.lastNotifiedUid > nextUid
            ? existing.lastNotifiedUid
            : nextUid;
        nextBaseline = existing.baselineEstablished || nextBaseline;
        nextValidity = existing.uidValidity ?? uidValidity;
      }
    }
    await database
        .into(database.dbInboxNotificationStates)
        .insertOnConflictUpdate(
          DbInboxNotificationStatesCompanion.insert(
            accountId: accountId,
            uidValidity: Value(nextValidity),
            lastNotifiedUid: Value(nextUid),
            baselineEstablished: Value(nextBaseline),
            lastCheckedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
            failureCount: const Value(0),
            nextRetryAt: const Value(null),
            lastErrorKind: const Value(null),
          ),
        );
  }

  InboxNotificationCheckpoint _fromRow(DbInboxNotificationState row) {
    final next = row.nextRetryAt;
    return InboxNotificationCheckpoint(
      accountId: row.accountId,
      uidValidity: row.uidValidity,
      lastNotifiedUid: row.lastNotifiedUid,
      baselineEstablished: row.baselineEstablished,
      failureCount: row.failureCount,
      nextRetryAt: next == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(next, isUtc: true),
      lastErrorKind: row.lastErrorKind,
    );
  }
}
