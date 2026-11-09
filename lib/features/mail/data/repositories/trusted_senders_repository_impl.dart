// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/trusted_sender.dart';
import '../../domain/repositories/trusted_senders_repository.dart';

/// Drift-backed trusted sender list used by the HTML remote-content policy.
class TrustedSendersRepositoryImpl implements TrustedSendersRepository {
  TrustedSendersRepositoryImpl({required AppDatabase database})
      : _database = database;

  final AppDatabase _database;

  @override
  Stream<Set<TrustedSender>> watchTrustedSenders() {
    final query = _database.select(_database.dbTrustedSenders)
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);
    return query.watch().map(_toSet);
  }

  @override
  Future<Set<TrustedSender>> getTrustedSenders() async {
    final rows = await _database.select(_database.dbTrustedSenders).get();
    return _toSet(rows);
  }

  @override
  Future<bool> isTrusted(String senderEmail) async {
    final normalized = _normalize(senderEmail);
    if (normalized.isEmpty) return false;
    final row = await (_database.select(_database.dbTrustedSenders)
          ..where((table) => table.senderEmail.equals(normalized)))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> trustSender(String senderEmail) async {
    final normalized = _normalize(senderEmail);
    if (normalized.isEmpty) return;
    await _database.into(_database.dbTrustedSenders).insertOnConflictUpdate(
          DbTrustedSendersCompanion.insert(
            senderEmail: normalized,
            createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<void> untrustSender(String senderEmail) async {
    final normalized = _normalize(senderEmail);
    if (normalized.isEmpty) return;
    await (_database.delete(_database.dbTrustedSenders)
          ..where((table) => table.senderEmail.equals(normalized)))
        .go();
  }

  static String _normalize(String email) => email.trim().toLowerCase();

  static Set<TrustedSender> _toSet(List<DbTrustedSender> rows) {
    return rows
        .map(
          (row) => TrustedSender(
            senderEmail: row.senderEmail,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row.createdAt,
              isUtc: true,
            ),
          ),
        )
        .toSet();
  }
}
