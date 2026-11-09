import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/logging/sanitized_logger.dart';
import '../../../../core/network/imap_session.dart';
import '../datasources/mail_local_datasource.dart';
import '../../../auth/domain/entities/mail_account.dart';
import '../../domain/entities/mail_attachment.dart';
import '../../domain/entities/mail_folder.dart';
import '../../domain/entities/local_cache_stats.dart';
import '../../domain/entities/mail_sync_result.dart';
import '../../domain/entities/unified_email.dart';

/// Local cache repository for folders, email headers, bodies and attachments.
///
/// Critical invariants:
/// - Header upserts never overwrite downloaded bodies (`plain_body`,
///   `html_body`, `body_downloaded`) or cached attachment paths.
/// - All writes for one sync pass run in a single Drift transaction, so the
///   FTS5 triggers and foreign-key cascades stay consistent.
/// - Search uses FTS5 trigram for >= 3 characters and an escaped LIKE query
///   for 1-2 character CJK/ASCII terms.
class MailLocalRepository {
  MailLocalRepository({required this._dataSource, SanitizedLogger? logger})
    : _logger = logger ?? SanitizedLogger.instance;

  final MailLocalDataSource _dataSource;
  final SanitizedLogger _logger;

  AppDatabase get _database => _dataSource.database;
  final Map<String, Future<void>> _folderSyncs = {};

  Future<T> runFolderSync<T>(String folderId, Future<T> Function() action) {
    final previous = _folderSyncs[folderId] ?? Future<void>.value();
    final operation = previous.catchError((_) {}).then((_) => action());
    late final Future<void> tail;
    tail = operation
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          if (identical(_folderSyncs[folderId], tail)) {
            _folderSyncs.remove(folderId);
          }
        });
    _folderSyncs[folderId] = tail;
    return operation;
  }

  // ---------------------------------------------------------------------------
  // Folder cache
  // ---------------------------------------------------------------------------

  Future<List<MailFolder>> getFolders(String accountId) async {
    final rows = await _dataSource.getFolders(accountId);
    return rows.map(_folderFromRow).toList(growable: false);
  }

  Stream<List<MailFolder>> watchFolders(String accountId) {
    return _dataSource
        .watchFolders(accountId)
        .map((rows) => rows.map(_folderFromRow).toList(growable: false));
  }

  Future<MailFolder?> getFolderById(String folderId) async {
    final row = await _dataSource.getFolderById(folderId);
    return row == null ? null : _folderFromRow(row);
  }

  Future<MailFolder?> getFolderByRole(String accountId, FolderRole role) async {
    final row = await _dataSource.getFolderByRole(accountId, role.storageKey);
    return row == null ? null : _folderFromRow(row);
  }

  /// Upserts the remote mailbox list. Existing folder IDs are preserved because
  /// `db_emails.folder_id` references them.
  Future<List<MailFolder>> upsertMailboxes({
    required String accountId,
    required List<RemoteMailboxInfo> mailboxes,
  }) async {
    final deduped = <String, RemoteMailboxInfo>{};
    for (final mailbox in mailboxes) {
      if (!mailbox.isSelectable && !mailbox.isInbox) continue;
      deduped.putIfAbsent(mailbox.remoteName, () => mailbox);
    }

    return _dataSource.transaction(() async {
      final existingRows = await (_database.select(
        _database.dbFolders,
      )..where((table) => table.accountId.equals(accountId))).get();
      final existingByRemote = <String, DbFolder>{
        for (final row in existingRows) row.remoteName: row,
      };

      final result = <MailFolder>[];
      for (final info in deduped.values) {
        final existing = existingByRemote[info.remoteName];
        final id = existing?.id ?? _folderId(accountId, info.remoteName);
        final role = _inferRole(info, existing?.role);
        final displayName = info.displayName.trim().isEmpty
            ? info.remoteName
            : info.displayName.trim();
        // LIST is not authoritative for UIDVALIDITY/UIDNEXT: only SELECT is.
        // Keep the cached value so syncFolder can detect a real UIDVALIDITY
        // reset instead of having it silently overwritten before comparison.
        final uidValidity = existing != null
            ? existing.uidValidity
            : info.uidValidity;
        final highestModSeq = existing != null
            ? existing.highestModSeq
            : info.highestModSeq;

        if (existing == null) {
          await _database
              .into(_database.dbFolders)
              .insert(
                DbFoldersCompanion.insert(
                  id: id,
                  accountId: accountId,
                  remoteName: info.remoteName,
                  displayName: displayName,
                  role: role.storageKey,
                  uidValidity: Value(uidValidity),
                  highestModSeq: Value(highestModSeq),
                  unreadCount: Value(info.messagesUnseen),
                ),
              );
        } else {
          await (_database.update(
            _database.dbFolders,
          )..where((table) => table.id.equals(id))).write(
            DbFoldersCompanion(
              displayName: Value(displayName),
              role: Value(role.storageKey),
              uidValidity: Value(uidValidity),
              highestModSeq: Value(highestModSeq),
            ),
          );
        }

        result.add(
          MailFolder(
            id: id,
            accountId: accountId,
            remoteName: info.remoteName,
            displayName: displayName,
            role: role,
            uidValidity: uidValidity,
            highestModSeq: highestModSeq,
            unreadCount: existing?.unreadCount ?? info.messagesUnseen,
            lastSyncAt: existing?.lastSyncAt == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    existing!.lastSyncAt!,
                    isUtc: true,
                  ),
          ),
        );
      }
      return result;
    });
  }

  Future<LocalCacheStats> readLocalCacheStats() => _dataSource.readCacheStats();

  Future<int?> getMaxUid(String folderId) => _dataSource.getMaxUid(folderId);

  Future<Set<int>> getUids(String folderId) => _dataSource.getUids(folderId);

  Future<int> clearFolderEmails(String folderId) =>
      _dataSource.clearFolderEmails(folderId);

  /// Deletes local rows in [minUid]..[maxUid] that were absent from the latest
  /// recent-window snapshot (server-side deletion reconciliation).
  Future<int> pruneMissingUids({
    required String folderId,
    required int minUid,
    required int maxUid,
    required Set<int> keepUids,
  }) {
    return _dataSource.pruneMissingUids(
      folderId: folderId,
      minUid: minUid,
      maxUid: maxUid,
      keepUids: keepUids,
    );
  }

  // ---------------------------------------------------------------------------
  // Message cache
  // ---------------------------------------------------------------------------

  /// Applies one remote sync pass transactionally.
  ///
  /// Existing bodies and attachment cache paths are preserved for every UID
  /// that is already present locally.
  Future<void> applyFolderSync({
    required MailAccount account,
    required MailFolder folder,
    required MailFolderSyncResult result,
  }) async {
    final messagesByUid = <int, RemoteFetchedMessage>{
      for (final message in result.messages) message.uid: message,
    };
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    var newCount = 0;
    var updatedCount = 0;
    var vanishedCount = 0;

    await _dataSource.transaction(() async {
      final previousMaxUid = result.uidValidityChanged
          ? null
          : await _dataSource.getMaxUid(folder.id);
      await (_database.update(
        _database.dbFolders,
      )..where((table) => table.id.equals(folder.id))).write(
        DbFoldersCompanion(
          uidValidity: Value(result.status.uidValidity ?? folder.uidValidity),
          highestModSeq: Value(
            result.status.highestModSeq ?? folder.highestModSeq,
          ),
          lastSyncAt: Value(now),
        ),
      );

      if (result.uidValidityChanged ||
          (!result.uidValidityChanged && result.status.messagesExists == 0)) {
        vanishedCount += await clearFolderEmails(folder.id);
      }

      final headerRows = await _dataSource.getEmailHeadersByUids(
        folderId: folder.id,
        uids: messagesByUid.keys,
      );
      final existingByUid = <int, EmailHeaderProjection>{
        for (final row in headerRows) row.uid: row,
      };
      final existingAttachments = await _dataSource.getAttachmentsForEmails(
        existingByUid.values.map((row) => row.localId),
      );

      for (final remote in messagesByUid.values) {
        final existing = existingByUid[remote.uid];
        final toJson = _encodeAddresses(remote.toAddresses);
        final ccJson = _encodeAddresses(remote.ccAddresses);
        final flags = _flagsToMask(remote.flags);

        final int emailLocalId;
        if (existing == null) {
          newCount++;
          emailLocalId = await _database
              .into(_database.dbEmails)
              .insert(
                DbEmailsCompanion.insert(
                  accountId: account.id,
                  folderId: folder.id,
                  uid: remote.uid,
                  subject: remote.subject,
                  fromName: remote.fromName,
                  fromAddress: remote.fromAddress,
                  toRecipientsJson: toJson,
                  ccJson: ccJson,
                  snippet: remote.snippet.isNotEmpty
                      ? remote.snippet
                      : remote.subject,
                  plainBody: Value(remote.plainBody),
                  htmlBody: Value(remote.htmlBody),
                  sentAt: remote.sentAt.toUtc().millisecondsSinceEpoch,
                  messageId: Value(remote.messageId),
                  flagsBitmask: Value(flags),
                  hasAttachments: Value(remote.attachments.isNotEmpty),
                  bodyDownloaded: Value(
                    remote.plainBody != null || remote.htmlBody != null,
                  ),
                ),
              );
        } else {
          updatedCount++;
          emailLocalId = existing.localId;
          await (_database.update(
            _database.dbEmails,
          )..where((table) => table.localId.equals(emailLocalId))).write(
            DbEmailsCompanion(
              subject: Value(remote.subject),
              fromName: Value(remote.fromName),
              fromAddress: Value(remote.fromAddress),
              toRecipientsJson: Value(toJson),
              ccJson: Value(ccJson),
              messageId: Value(remote.messageId),
              sentAt: Value(remote.sentAt.toUtc().millisecondsSinceEpoch),
              flagsBitmask: Value(flags),
              hasAttachments: Value(remote.attachments.isNotEmpty),
              snippet: Value(
                existing.bodyDownloaded
                    ? existing.snippet
                    : (remote.snippet.isNotEmpty
                          ? remote.snippet
                          : remote.subject),
              ),
              // plainBody / htmlBody / bodyDownloaded intentionally omitted.
            ),
          );
        }

        await _upsertAttachments(
          emailLocalId,
          remote.attachments,
          existingRows: existing == null
              ? const <DbAttachment>[]
              : (existingAttachments[emailLocalId] ?? const <DbAttachment>[]),
        );
      }

      if (!result.uidValidityChanged && result.recentWindowMinUid != null) {
        final minUid = result.recentWindowMinUid!;
        final recentMaxUid = result.recentWindowMaxUid ?? minUid;
        // A deleted highest UID is not present in the returned window, so
        // extend reconciliation up to the UID the local cache knew about.
        final upperUid = previousMaxUid != null && previousMaxUid > recentMaxUid
            ? previousMaxUid
            : recentMaxUid;
        final keepUids = messagesByUid.keys
            .where((uid) => uid >= minUid && uid <= upperUid)
            .toSet();
        vanishedCount += await pruneMissingUids(
          folderId: folder.id,
          minUid: minUid,
          maxUid: upperUid,
          keepUids: keepUids,
        );
      }

      if (!result.uidValidityChanged && result.reconciledUids.isNotEmpty) {
        final uids = result.reconciledUids.toList();
        for (var start = 0; start < uids.length; start += 500) {
          final end = start + 500 < uids.length ? start + 500 : uids.length;
          final chunk = uids.sublist(start, end);
          final vanished = chunk.where(
            (uid) => !result.reconciledFlags.containsKey(uid),
          );
          vanishedCount +=
              await (_database.delete(_database.dbEmails)..where(
                    (table) =>
                        table.folderId.equals(folder.id) &
                        table.uid.isIn(vanished),
                  ))
                  .go();
          await _database.batch((batch) {
            for (final uid in chunk) {
              final flags = result.reconciledFlags[uid];
              if (flags == null) continue;
              batch.update(
                _database.dbEmails,
                DbEmailsCompanion(flagsBitmask: Value(_flagsToMask(flags))),
                where: (table) =>
                    table.folderId.equals(folder.id) & table.uid.equals(uid),
              );
            }
          });
        }
      }
      await _refreshUnreadCount(folder.id);
    });

    _logger.info(
      'MailLocalRepository',
      'Applied sync: folder=${folder.role.storageKey} new=$newCount '
          'updated=$updatedCount vanished=$vanishedCount',
    );
  }

  /// Persists a downloaded full message. Always sets `body_downloaded = true`
  /// so a second detail open never hits the network again.
  Future<UnifiedEmail> saveFullMessage({
    required int localId,
    required RemoteFetchedMessage message,
  }) async {
    await _dataSource.transaction(() async {
      final existing = await (_database.select(
        _database.dbEmails,
      )..where((table) => table.localId.equals(localId))).getSingleOrNull();
      if (existing == null) {
        throw StateError('Local email $localId no longer exists');
      }

      final snippet = message.snippet.isNotEmpty
          ? message.snippet
          : _buildSnippet(message.plainBody, message.htmlBody);
      await (_database.update(
        _database.dbEmails,
      )..where((table) => table.localId.equals(localId))).write(
        DbEmailsCompanion(
          subject: Value(message.subject),
          fromName: Value(message.fromName),
          fromAddress: Value(message.fromAddress),
          toRecipientsJson: Value(_encodeAddresses(message.toAddresses)),
          ccJson: Value(_encodeAddresses(message.ccAddresses)),
          messageId: Value(message.messageId),
          sentAt: Value(message.sentAt.toUtc().millisecondsSinceEpoch),
          flagsBitmask: Value(_flagsToMask(message.flags)),
          snippet: Value(snippet.isEmpty ? existing.snippet : snippet),
          plainBody: Value(message.plainBody),
          htmlBody: Value(message.htmlBody),
          bodyDownloaded: const Value(true),
          hasAttachments: Value(message.attachments.isNotEmpty),
        ),
      );
      await _upsertAttachments(localId, message.attachments);
    });

    final updated = await getEmail(localId);
    if (updated == null) {
      throw StateError('Local email $localId disappeared after body save');
    }
    return updated;
  }

  Future<void> refreshFolderUnreadCount(String folderId) {
    return _refreshUnreadCount(folderId);
  }

  Future<void> updateFlags(int localId, int flagsBitmask) async {
    final updated =
        await (_database.update(_database.dbEmails)
              ..where((table) => table.localId.equals(localId)))
            .write(DbEmailsCompanion(flagsBitmask: Value(flagsBitmask)));
    if (updated == 0) {
      throw StateError('Local email $localId no longer exists');
    }
  }

  Future<UnifiedEmail?> getEmail(int localId) async {
    final rows = await _dataSource.getEmailRows(localId);
    if (rows.isEmpty) return null;
    final email = _mapJoinedEmail(rows.single);
    final attachments = await getAttachments(localId);
    return email.copyWith(attachments: attachments);
  }

  Future<UnifiedEmail?> getEmailByUid(String folderId, int uid) async {
    final rows = await _dataSource.getEmailRowsByUid(folderId, uid);
    if (rows.isEmpty) return null;
    final email = _mapJoinedEmail(rows.single);
    final attachments = await getAttachments(email.localId!);
    return email.copyWith(attachments: attachments);
  }

  Future<List<MailAttachment>> getAttachments(int emailLocalId) async {
    final rows = await _dataSource.getAttachments(emailLocalId);
    return rows.map(_attachmentFromRow).toList(growable: false);
  }

  Future<MailAttachment?> getAttachment(int emailLocalId, String partId) async {
    final row = await _dataSource.getAttachment(emailLocalId, partId);
    return row == null ? null : _attachmentFromRow(row);
  }

  Future<void> updateAttachmentCachePath({
    required String attachmentId,
    required String localCachePath,
  }) async {
    final updated =
        await (_database.update(
          _database.dbAttachments,
        )..where((table) => table.id.equals(attachmentId))).write(
          DbAttachmentsCompanion(localCachePath: Value(localCachePath)),
        );
    if (updated == 0) {
      throw StateError('Attachment $attachmentId no longer exists');
    }
  }

  // ---------------------------------------------------------------------------
  // Unified inbox + search
  // ---------------------------------------------------------------------------

  Stream<List<UnifiedEmail>> watchUnifiedInbox({
    int limit = 200,
    String? accountId,
    bool unreadOnly = false,
  }) {
    return _dataSource
        .watchUnifiedInboxRows(
          limit: limit,
          accountId: accountId,
          unreadOnly: unreadOnly,
        )
        .map((rows) => rows.map(_mapJoinedEmail).toList(growable: false));
  }

  /// Watches one folder's cached emails in reverse chronological order.
  Stream<List<UnifiedEmail>> watchFolderEmails(
    String folderId, {
    int limit = 200,
    bool unreadOnly = false,
  }) {
    return _dataSource
        .watchFolderEmailsRows(
          folderId: folderId,
          limit: limit,
          unreadOnly: unreadOnly,
        )
        .map((rows) => rows.map(_mapJoinedEmail).toList(growable: false));
  }

  /// Reactive single-email stream. Attachments are loaded from the same
  /// emission so inline CID paths update without a second manual refresh.
  Stream<UnifiedEmail?> watchEmail(int localId) {
    return _dataSource.watchEmailRows(localId).asyncMap((rows) async {
      if (rows.isEmpty) return null;
      final email = _mapJoinedEmail(rows.single);
      final attachments = await getAttachments(localId);
      return email.copyWith(attachments: attachments);
    });
  }

  Future<List<UnifiedEmail>> searchEmails({
    required String query,
    String? accountId,
    bool unreadOnly = false,
    int limit = 100,
  }) async {
    final term = query.trim();
    if (term.isEmpty || limit <= 0) return const [];

    final compact = term.replaceAll(RegExp(r'\s+'), '');
    if (compact.length >= 3) {
      try {
        final rows = await _dataSource.searchFtsRows(
          term: term,
          accountId: accountId,
          unreadOnly: unreadOnly,
          limit: limit,
        );
        return rows.map(_mapSearchRow).toList(growable: false);
      } on Exception {
        // Malformed FTS syntax must never crash the UI; fall through to LIKE.
      }
    }
    final rows = await _dataSource.searchLikeRows(
      term: term,
      accountId: accountId,
      unreadOnly: unreadOnly,
      limit: limit,
    );
    return rows.map(_mapSearchRow).toList(growable: false);
  }

  UnifiedEmail _mapJoinedEmail(TypedResult row) {
    final email = row.readTable(_database.dbEmails);
    final folder = row.readTable(_database.dbFolders);
    final account = row.readTable(_database.dbAccounts);
    return _emailFromParts(
      email: email,
      folderRole: folder.role,
      accountEmail: account.email,
      accountDisplayName: account.displayName,
      accountColorValue: account.colorValue,
    );
  }

  UnifiedEmail _mapSearchRow(QueryRow row) {
    final email = DbEmail(
      localId: row.read<int>('local_id'),
      accountId: row.read<String>('account_id'),
      folderId: row.read<String>('folder_id'),
      uid: row.read<int>('uid'),
      messageId: row.read<String?>('message_id'),
      subject: row.read<String>('subject'),
      fromName: row.read<String>('from_name'),
      fromAddress: row.read<String>('from_address'),
      toRecipientsJson: row.read<String>('to_json'),
      ccJson: row.read<String>('cc_json'),
      snippet: row.read<String>('snippet'),
      plainBody: row.read<String?>('plain_body'),
      htmlBody: row.read<String?>('html_body'),
      sentAt: row.read<int>('sent_at'),
      flagsBitmask: row.read<int>('flags_bitmask'),
      hasAttachments: row.read<int>('has_attachments') != 0,
      bodyDownloaded: row.read<int>('body_downloaded') != 0,
    );
    return _emailFromParts(
      email: email,
      folderRole: row.read<String>('folder_role'),
      accountEmail: row.read<String>('account_email'),
      accountDisplayName: row.read<String>('account_display_name'),
      accountColorValue: row.read<int>('account_color_value'),
    );
  }

  UnifiedEmail _emailFromParts({
    required DbEmail email,
    required String folderRole,
    required String accountEmail,
    required String accountDisplayName,
    required int accountColorValue,
  }) {
    return UnifiedEmail(
      localId: email.localId,
      accountId: email.accountId,
      accountEmail: accountEmail,
      accountDisplayName: accountDisplayName,
      accountColorValue: accountColorValue,
      folderId: email.folderId,
      folderRole: FolderRole.fromStorageKey(folderRole),
      uid: email.uid,
      messageId: email.messageId,
      subject: email.subject,
      fromName: email.fromName,
      fromAddress: email.fromAddress,
      toAddresses: _decodeAddresses(email.toRecipientsJson),
      ccAddresses: _decodeAddresses(email.ccJson),
      snippet: email.snippet,
      plainBody: email.plainBody,
      htmlBody: email.htmlBody,
      sentAt: DateTime.fromMillisecondsSinceEpoch(email.sentAt, isUtc: true),
      isRead: (email.flagsBitmask & UnifiedEmail.flagSeen) != 0,
      isFlagged: (email.flagsBitmask & UnifiedEmail.flagFlagged) != 0,
      isAnswered: (email.flagsBitmask & UnifiedEmail.flagAnswered) != 0,
      hasAttachments: email.hasAttachments,
      bodyDownloaded: email.bodyDownloaded,
    );
  }

  // ---------------------------------------------------------------------------
  // Small conversion helpers
  // ---------------------------------------------------------------------------

  MailFolder _folderFromRow(DbFolder row) {
    return MailFolder(
      id: row.id,
      accountId: row.accountId,
      remoteName: row.remoteName,
      displayName: row.displayName,
      role: FolderRole.fromStorageKey(row.role),
      uidValidity: row.uidValidity,
      highestModSeq: row.highestModSeq,
      unreadCount: row.unreadCount,
      lastSyncAt: row.lastSyncAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.lastSyncAt!, isUtc: true),
    );
  }

  MailAttachment _attachmentFromRow(DbAttachment row) {
    return MailAttachment(
      id: row.id,
      emailLocalId: row.emailLocalId,
      partId: row.partId,
      contentId: row.contentId,
      filename: row.filename,
      mimeType: row.mimeType,
      sizeBytes: row.sizeBytes,
      localCachePath: row.localCachePath,
      isInline: row.isInline,
    );
  }

  Future<void> _upsertAttachments(
    int emailLocalId,
    List<RemoteAttachmentMeta> attachments, {
    List<DbAttachment>? existingRows,
  }) async {
    final localRows =
        existingRows ??
        await (_database.select(
          _database.dbAttachments,
        )..where((table) => table.emailLocalId.equals(emailLocalId))).get();
    final existingByPart = <String, DbAttachment>{
      for (final row in localRows) row.partId: row,
    };
    final remoteParts = <String>{};

    for (final remote in attachments) {
      remoteParts.add(remote.partId);
      final existing = existingByPart[remote.partId];
      if (existing == null) {
        await _database
            .into(_database.dbAttachments)
            .insert(
              DbAttachmentsCompanion.insert(
                id: '$emailLocalId::${remote.partId}',
                emailLocalId: emailLocalId,
                partId: remote.partId,
                contentId: Value(remote.contentId),
                filename: remote.filename,
                mimeType: remote.mimeType,
                sizeBytes: remote.sizeBytes,
                isInline: Value(remote.isInline),
              ),
            );
      } else {
        await (_database.update(
          _database.dbAttachments,
        )..where((table) => table.id.equals(existing.id))).write(
          DbAttachmentsCompanion(
            contentId: Value(remote.contentId),
            filename: Value(remote.filename),
            mimeType: Value(remote.mimeType),
            sizeBytes: Value(remote.sizeBytes),
            isInline: Value(remote.isInline),
            // localCachePath intentionally preserved.
          ),
        );
      }
    }

    final staleIds = localRows
        .where((row) => !remoteParts.contains(row.partId))
        .map((row) => row.id)
        .toList(growable: false);
    if (staleIds.isNotEmpty) {
      await (_database.delete(
        _database.dbAttachments,
      )..where((table) => table.id.isIn(staleIds))).go();
    }
  }

  Future<void> _refreshUnreadCount(String folderId) async {
    final row = await _database
        .customSelect(
          'SELECT COUNT(*) AS c FROM db_emails '
          'WHERE folder_id = ? AND (flags_bitmask & 1) = 0',
          variables: <Variable<Object>>[Variable.withString(folderId)],
        )
        .getSingle();
    final unread = (row.data['c'] as int?) ?? 0;
    await (_database.update(_database.dbFolders)
          ..where((table) => table.id.equals(folderId)))
        .write(DbFoldersCompanion(unreadCount: Value(unread)));
  }

  static String _folderId(String accountId, String remoteName) {
    return '$accountId::${Uri.encodeComponent(remoteName)}';
  }

  static FolderRole _inferRole(RemoteMailboxInfo info, String? existingRole) {
    if (info.isInbox) return FolderRole.inbox;
    if (info.isSent) return FolderRole.sent;
    if (info.isDrafts) return FolderRole.drafts;
    if (info.isTrash) return FolderRole.trash;
    if (info.isJunk) return FolderRole.junk;
    if (info.isArchive) return FolderRole.archive;

    final haystack = '${info.remoteName} ${info.displayName}'.toLowerCase();
    bool hasAny(List<String> needles) =>
        needles.any((needle) => haystack.contains(needle));

    if (hasAny(const ['sent', '已发送', '已寄出'])) return FolderRole.sent;
    if (hasAny(const ['draft', '草稿'])) return FolderRole.drafts;
    if (hasAny(const ['trash', 'deleted', '已删除', '废件箱'])) {
      return FolderRole.trash;
    }
    if (hasAny(const ['junk', 'spam', '垃圾', '广告邮件'])) {
      return FolderRole.junk;
    }
    if (hasAny(const ['archive', '归档', '存档'])) {
      return FolderRole.archive;
    }

    if (existingRole != null && existingRole.isNotEmpty) {
      final existing = FolderRole.fromStorageKey(existingRole);
      if (existing != FolderRole.custom) return existing;
    }
    return FolderRole.custom;
  }

  static int _flagsToMask(List<String> flags) {
    var mask = 0;
    for (final flag in flags) {
      switch (flag.toLowerCase()) {
        case r'\seen':
          mask |= UnifiedEmail.flagSeen;
        case r'\flagged':
          mask |= UnifiedEmail.flagFlagged;
        case r'\answered':
          mask |= UnifiedEmail.flagAnswered;
      }
    }
    return mask;
  }

  static String _encodeAddresses(List<RemoteMailAddress> addresses) {
    return jsonEncode(
      addresses
          .map((address) => {'name': address.name, 'email': address.email})
          .toList(growable: false),
    );
  }

  static List<EmailAddressEntry> _decodeAddresses(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(EmailAddressEntry.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static String _buildSnippet(String? plain, String? html) {
    var text = plain?.trim() ?? '';
    if (text.isEmpty && html != null) {
      try {
        // The local layer does not depend on an HTML parser; a conservative
        // tag strip is enough for search previews.
        text = html
            .replaceAll(
              RegExp(
                r'<(script|style)[^>]*>.*?</\1>',
                caseSensitive: false,
                dotAll: true,
              ),
              ' ',
            )
            .replaceAll(RegExp('<[^>]+>'), ' ');
      } catch (_) {
        text = html;
      }
    }
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > 180) return '${text.substring(0, 180)}…';
    return text;
  }
}
