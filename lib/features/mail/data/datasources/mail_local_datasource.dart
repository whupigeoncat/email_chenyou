import 'dart:async';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/local_cache_stats.dart';

/// Raw Drift access for the mail cache.
///
/// The repository owns domain mapping / sync policy; this datasource owns the
/// database connection, row queries and FTS5/LIKE query construction.
/// Lightweight projection used during header sync. Deliberately excludes the
/// potentially huge `plain_body` / `html_body` columns.
class EmailHeaderProjection {
  const EmailHeaderProjection({
    required this.localId,
    required this.uid,
    required this.bodyDownloaded,
    required this.snippet,
  });

  final int localId;
  final int uid;
  final bool bodyDownloaded;
  final String snippet;
}

class MailLocalDataSource {
  MailLocalDataSource({required this.database});

  static const int syncChunkSize = 500;

  final AppDatabase database;

  Future<T> transaction<T>(Future<T> Function() action) {
    return database.transaction(action);
  }

  Future<List<DbFolder>> getFolders(String accountId) {
    final query = database.select(database.dbFolders)
      ..where((table) => table.accountId.equals(accountId))
      ..orderBy([(table) => OrderingTerm.asc(table.remoteName)]);
    return query.get();
  }

  Stream<List<DbFolder>> watchFolders(String accountId) {
    final query = database.select(database.dbFolders)
      ..where((table) => table.accountId.equals(accountId))
      ..orderBy([(table) => OrderingTerm.asc(table.remoteName)]);
    return query.watch();
  }

  Future<DbFolder?> getFolderById(String folderId) {
    return (database.select(
      database.dbFolders,
    )..where((table) => table.id.equals(folderId))).getSingleOrNull();
  }

  Future<DbFolder?> getFolderByRole(String accountId, String role) {
    return (database.select(database.dbFolders)
          ..where(
            (table) =>
                table.accountId.equals(accountId) & table.role.equals(role),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<DbAttachment>> getAttachments(int emailLocalId) {
    final query = database.select(database.dbAttachments)
      ..where((table) => table.emailLocalId.equals(emailLocalId))
      ..orderBy([(table) => OrderingTerm.asc(table.partId)]);
    return query.get();
  }

  Future<DbAttachment?> getAttachment(int emailLocalId, String partId) {
    return (database.select(database.dbAttachments)..where(
          (table) =>
              table.emailLocalId.equals(emailLocalId) &
              table.partId.equals(partId),
        ))
        .getSingleOrNull();
  }

  Future<List<EmailHeaderProjection>> getEmailHeadersByUids({
    required String folderId,
    required Iterable<int> uids,
    int chunkSize = syncChunkSize,
  }) async {
    final allUids = uids.toList(growable: false);
    final result = <EmailHeaderProjection>[];
    final safeChunk = chunkSize.clamp(1, syncChunkSize);
    for (var start = 0; start < allUids.length; start += safeChunk) {
      final end = (start + safeChunk < allUids.length)
          ? start + safeChunk
          : allUids.length;
      final chunk = allUids.sublist(start, end);
      final query = database.selectOnly(database.dbEmails)
        ..addColumns([
          database.dbEmails.localId,
          database.dbEmails.uid,
          database.dbEmails.bodyDownloaded,
          database.dbEmails.snippet,
        ])
        ..where(
          database.dbEmails.folderId.equals(folderId) &
              database.dbEmails.uid.isIn(chunk),
        );
      final rows = await query.get();
      result.addAll(
        rows.map(
          (row) => EmailHeaderProjection(
            localId: row.read(database.dbEmails.localId)!,
            uid: row.read(database.dbEmails.uid)!,
            bodyDownloaded: row.read(database.dbEmails.bodyDownloaded)!,
            snippet: row.read(database.dbEmails.snippet)!,
          ),
        ),
      );
    }
    return result;
  }

  Future<Map<int, List<DbAttachment>>> getAttachmentsForEmails(
    Iterable<int> emailLocalIds, {
    int chunkSize = syncChunkSize,
  }) async {
    final ids = emailLocalIds.toSet().toList(growable: false);
    final result = <int, List<DbAttachment>>{};
    final safeChunk = chunkSize.clamp(1, syncChunkSize);
    for (var start = 0; start < ids.length; start += safeChunk) {
      final end =
          (start + safeChunk < ids.length) ? start + safeChunk : ids.length;
      final chunk = ids.sublist(start, end);
      final rows = await (database.select(database.dbAttachments)
            ..where((table) => table.emailLocalId.isIn(chunk))
            ..orderBy([(table) => OrderingTerm.asc(table.partId)]))
          .get();
      for (final row in rows) {
        result.putIfAbsent(row.emailLocalId, () => <DbAttachment>[]).add(row);
      }
    }
    return result;
  }

  Future<int?> getMaxUid(String folderId) async {
    final row = await database
        .customSelect(
          'SELECT MAX(uid) AS max_uid FROM db_emails WHERE folder_id = ?',
          variables: <Variable<Object>>[Variable.withString(folderId)],
        )
        .getSingle();
    return row.data['max_uid'] as int?;
  }

  Future<Set<int>> getUids(String folderId) async {
    final rows =
        await (database.selectOnly(database.dbEmails)
              ..addColumns([database.dbEmails.uid])
              ..where(database.dbEmails.folderId.equals(folderId)))
            .get();
    return rows
        .map((row) => row.read(database.dbEmails.uid))
        .whereType<int>()
        .toSet();
  }

  Future<LocalCacheStats> readCacheStats() async {
    final row = await database
        .customSelect(
          'SELECT '
          '(SELECT COUNT(*) FROM db_folders) AS folders, '
          '(SELECT COUNT(*) FROM db_emails) AS emails, '
          '(SELECT COUNT(*) FROM db_emails '
          'WHERE (flags_bitmask & 1) = 0) AS unread, '
          '(SELECT MAX(last_sync_at) FROM db_folders) AS last_sync_at',
        )
        .getSingle();
    final lastSyncMs = row.data['last_sync_at'] as int?;
    return LocalCacheStats(
      folders: (row.data['folders'] as int?) ?? 0,
      emails: (row.data['emails'] as int?) ?? 0,
      unread: (row.data['unread'] as int?) ?? 0,
      lastSyncedAt: lastSyncMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastSyncMs, isUtc: true),
    );
  }

  Future<int> clearFolderEmails(String folderId) {
    return (database.delete(
      database.dbEmails,
    )..where((table) => table.folderId.equals(folderId))).go();
  }

  Future<int> pruneMissingUids({
    required String folderId,
    required int minUid,
    required int maxUid,
    required Set<int> keepUids,
  }) async {
    if (maxUid < minUid) return 0;
    var predicate =
        database.dbEmails.folderId.equals(folderId) &
        database.dbEmails.uid.isBetweenValues(minUid, maxUid);
    if (keepUids.isNotEmpty) {
      predicate = predicate & database.dbEmails.uid.isNotIn(keepUids);
    }
    return (database.delete(
      database.dbEmails,
    )..where((table) => predicate)).go();
  }

  Stream<List<TypedResult>> watchUnifiedInboxRows({
    int limit = 200,
    String? accountId,
    bool unreadOnly = false,
  }) {
    final query = _joinedEmailSelect();
    var predicate =
        database.dbFolders.role.equals('inbox') &
        database.dbAccounts.isEnabled.equals(true);
    if (accountId != null) {
      predicate = predicate & database.dbEmails.accountId.equals(accountId);
    }
    if (unreadOnly) {
      predicate = predicate &
          database.dbEmails.flagsBitmask.bitwiseAnd(const Constant(1)).equals(0);
    }
    query
      ..where(predicate)
      ..orderBy([
        OrderingTerm.desc(database.dbEmails.sentAt),
        OrderingTerm.desc(database.dbEmails.uid),
      ])
      ..limit(limit);
    return query.watch();
  }

  Stream<List<TypedResult>> watchFolderEmailsRows({
    required String folderId,
    int limit = 200,
    bool unreadOnly = false,
  }) {
    final query = _joinedEmailSelect();
    var predicate =
        database.dbEmails.folderId.equals(folderId) &
        database.dbAccounts.isEnabled.equals(true);
    if (unreadOnly) {
      predicate = predicate &
          database.dbEmails.flagsBitmask.bitwiseAnd(const Constant(1)).equals(0);
    }
    query
      ..where(predicate)
      ..orderBy([
        OrderingTerm.desc(database.dbEmails.sentAt),
        OrderingTerm.desc(database.dbEmails.uid),
      ])
      ..limit(limit);
    return query.watch();
  }

  /// Alias for callers that use the domain-facing method name.
  Stream<List<TypedResult>> watchFolderEmails(
    String folderId, {
    int limit = 200,
    bool unreadOnly = false,
  }) {
    return watchFolderEmailsRows(
      folderId: folderId,
      limit: limit,
      unreadOnly: unreadOnly,
    );
  }

  /// Watches one email and re-runs the query whenever its joined email row or
  /// an attachment row changes. The attachment query is observed separately
  /// because it is not part of the joined email projection.
  Stream<List<TypedResult>> watchEmailRows(int localId) {
    final emailQuery = _joinedEmailSelect()
      ..where(database.dbEmails.localId.equals(localId));
    final attachmentQuery = database.select(database.dbAttachments)
      ..where((table) => table.emailLocalId.equals(localId));

    late StreamController<List<TypedResult>> controller;
    StreamSubscription<List<TypedResult>>? emailSub;
    StreamSubscription<List<DbAttachment>>? attachmentSub;
    var closed = false;

    Future<void> emit() async {
      if (closed) return;
      final rows = await getEmailRows(localId);
      if (!closed) controller.add(rows);
    }

    controller = StreamController<List<TypedResult>>(
      onListen: () {
        emailSub = emailQuery.watch().listen((_) => unawaited(emit()));
        attachmentSub =
            attachmentQuery.watch().listen((_) => unawaited(emit()));
        unawaited(emit());
      },
      onCancel: () {
        closed = true;
        final email = emailSub;
        final attachment = attachmentSub;
        emailSub = null;
        attachmentSub = null;
        if (email != null) unawaited(email.cancel());
        if (attachment != null) unawaited(attachment.cancel());
      },
    );
    return controller.stream;
  }

  /// Alias for the domain-facing single-email stream name.
  Stream<List<TypedResult>> watchEmail(int localId) => watchEmailRows(localId);

  Future<List<TypedResult>> getEmailRows(int localId) {
    final query = _joinedEmailSelect()
      ..where(database.dbEmails.localId.equals(localId));
    return query.get();
  }

  Future<List<TypedResult>> getEmailRowsByUid(String folderId, int uid) {
    final query = _joinedEmailSelect()
      ..where(
        database.dbEmails.folderId.equals(folderId) &
            database.dbEmails.uid.equals(uid),
      );
    return query.get();
  }

  Future<List<QueryRow>> searchFtsRows({
    required String term,
    String? accountId,
    bool unreadOnly = false,
    int limit = 100,
  }) {
    final variables = <Variable<Object>>[Variable.withString(_ftsPhrase(term))];
    final buffer = StringBuffer()
      ..write(
        'SELECT $_emailProjection FROM db_emails e '
        'JOIN db_folders f ON f.id = e.folder_id '
        'JOIN db_accounts a ON a.id = e.account_id '
        'JOIN emails_fts ON emails_fts.rowid = e.local_id '
        'WHERE emails_fts MATCH ? AND a.is_enabled = 1 ',
      );
    if (accountId != null) {
      buffer.write('AND e.account_id = ? ');
      variables.add(Variable.withString(accountId));
    }
    if (unreadOnly) {
      buffer.write('AND (e.flags_bitmask & 1) = 0 ');
    }
    buffer.write('ORDER BY e.sent_at DESC, e.uid DESC LIMIT ?');
    variables.add(Variable.withInt(limit));
    return database.customSelect(buffer.toString(), variables: variables).get();
  }

  Future<List<QueryRow>> searchLikeRows({
    required String term,
    String? accountId,
    bool unreadOnly = false,
    int limit = 100,
  }) {
    final pattern = '%${_escapeLike(term)}%';
    final variables = <Variable<Object>>[
      for (var i = 0; i < 5; i++) Variable.withString(pattern),
    ];
    final buffer = StringBuffer()
      ..write(
        'SELECT $_emailProjection FROM db_emails e '
        'JOIN db_folders f ON f.id = e.folder_id '
        'JOIN db_accounts a ON a.id = e.account_id '
        'WHERE a.is_enabled = 1 AND ('
        "e.subject LIKE ? ESCAPE '\\' "
        "OR e.from_name LIKE ? ESCAPE '\\' "
        "OR e.from_address LIKE ? ESCAPE '\\' "
        "OR COALESCE(e.plain_body, '') LIKE ? ESCAPE '\\' "
        "OR e.snippet LIKE ? ESCAPE '\\'"
        ') ',
      );
    if (accountId != null) {
      buffer.write('AND e.account_id = ? ');
      variables.add(Variable.withString(accountId));
    }
    if (unreadOnly) {
      buffer.write('AND (e.flags_bitmask & 1) = 0 ');
    }
    buffer.write('ORDER BY e.sent_at DESC, e.uid DESC LIMIT ?');
    variables.add(Variable.withInt(limit));
    return database.customSelect(buffer.toString(), variables: variables).get();
  }

  JoinedSelectStatement<HasResultSet, dynamic> _joinedEmailSelect() {
    return database.select(database.dbEmails).join([
      innerJoin(
        database.dbFolders,
        database.dbFolders.id.equalsExp(database.dbEmails.folderId),
      ),
      innerJoin(
        database.dbAccounts,
        database.dbAccounts.id.equalsExp(database.dbEmails.accountId),
      ),
    ]);
  }

  static const String _emailProjection = '''
    e.local_id AS local_id,
    e.account_id AS account_id,
    e.folder_id AS folder_id,
    e.uid AS uid,
    e.message_id AS message_id,
    e.subject AS subject,
    e.from_name AS from_name,
    e.from_address AS from_address,
    e.to_json AS to_json,
    e.cc_json AS cc_json,
    e.snippet AS snippet,
    e.plain_body AS plain_body,
    e.html_body AS html_body,
    e.sent_at AS sent_at,
    e.flags_bitmask AS flags_bitmask,
    e.has_attachments AS has_attachments,
    e.body_downloaded AS body_downloaded,
    f.role AS folder_role,
    a.email AS account_email,
    a.display_name AS account_display_name,
    a.color_value AS account_color_value
  ''';

  static String _ftsPhrase(String term) {
    final sanitized = term
        .replaceAll(RegExp(r'[\u0000-\u001f]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // FTS5 quoted-string escaping: a double quote is represented by "".
    return '"${sanitized.replaceAll('"', '""')}"';
  }

  static String _escapeLike(String term) {
    return term
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
