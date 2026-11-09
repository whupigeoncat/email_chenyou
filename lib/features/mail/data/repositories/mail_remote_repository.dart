import 'dart:typed_data';

import '../../../../core/network/imap_session.dart';
import '../../../auth/domain/entities/mail_account.dart';
import '../../data/datasources/mail_remote_datasource.dart';
import '../../domain/entities/mail_folder.dart';
import '../../domain/entities/mail_sync_result.dart';

/// Remote IMAP data access.
///
/// SECURITY / POOL RULE: this class never creates an `ImapClient` or socket.
/// Every operation goes through [MailRemoteDataSource]:
/// - INBOX (and `LIST`) reuse the single persistent IDLE connection.
/// - Non-INBOX folders use a serialized transient connection that LOGOUTs in
///   `AccountConnectionSlot.runTransientFolderTask`'s `finally`.
class MailRemoteRepository {
  MailRemoteRepository({
    required this._dataSource,
    this.initialSyncLimit = 50,
    this.recentWindowLimit = 50,
    this.incrementalLimit = 0,
  });

  final MailRemoteDataSource _dataSource;
  final int initialSyncLimit;
  final int recentWindowLimit;
  final int incrementalLimit;

  /// Lists mailboxes on the existing INBOX socket. IMAP `LIST` does not change
  /// the selected mailbox, so the IDLE connection is paused and reused rather
  /// than opening another socket.
  Future<List<RemoteMailboxInfo>> listMailboxes(MailAccount account) {
    return _dataSource.listMailboxes(account);
  }

  /// Synchronizes one folder.
  ///
  /// First sync / UIDVALIDITY change: fetches the most recent
  /// [initialSyncLimit] messages.
  ///
  /// Incremental sync: fetches `maxUid + 1:*` and strictly discards any UID
  /// `<= maxUid` (the RFC 3501 `n:*` range echoes the last message when no
  /// newer UID exists). A recent window is also fetched to reconcile flags and
  /// server-side deletions.
  Future<MailFolderSyncResult> syncFolder({
    required MailAccount account,
    required MailFolder folder,
    required int? localMaxUid,
    Set<int> localUids = const {},
    int? olderThanUid,
  }) {
    return _dataSource.withFolder(
      account: account,
      folder: folder,
      action: (session, status) async {
        final uidValidityChanged =
            folder.uidValidity != null &&
            status.uidValidity != null &&
            folder.uidValidity != status.uidValidity;
        final isFullSnapshot = localMaxUid == null || uidValidityChanged;

        final merged = <int, RemoteFetchedMessage>{};

        if (!isFullSnapshot) {
          final incremental = await session.uidFetchMessageHeaders(
            fromUid: localMaxUid + 1,
            limit: incrementalLimit,
          );
          for (final message in incremental) {
            if (message.uid > localMaxUid) {
              merged[message.uid] = message;
            }
          }
        }

        final recent = await session.fetchMessageHeaders(
          limit: isFullSnapshot ? initialSyncLimit : recentWindowLimit,
        );
        var recentMinUid = recent.isEmpty ? null : recent.first.uid;
        var recentMaxUid = recent.isEmpty ? null : recent.first.uid;
        for (final message in recent) {
          if (recentMinUid == null || message.uid < recentMinUid) {
            recentMinUid = message.uid;
          }
          if (recentMaxUid == null || message.uid > recentMaxUid) {
            recentMaxUid = message.uid;
          }
          merged.putIfAbsent(message.uid, () => message);
        }

        if (!uidValidityChanged && olderThanUid != null) {
          final older = await session.fetchOlderMessageHeaders(
            beforeUid: olderThanUid,
          );
          for (final message in older) {
            if (message.uid < olderThanUid) merged[message.uid] = message;
          }
        }
        final flags = <int, List<String>>{};
        final checked = isFullSnapshot ? <int>[] : localUids.toList();
        for (var start = 0; start < checked.length; start += 500) {
          final end = start + 500 < checked.length
              ? start + 500
              : checked.length;
          flags.addAll(
            await session.uidFetchFlags(checked.sublist(start, end)),
          );
        }

        final messages = merged.values.toList(growable: false)
          ..sort((a, b) => a.uid.compareTo(b.uid));

        return MailFolderSyncResult(
          status: status,
          reconciledUids: checked.toSet(),
          reconciledFlags: flags,
          messages: messages,
          uidValidityChanged: uidValidityChanged,
          isFullSnapshot: isFullSnapshot,
          recentWindowMinUid: recentMinUid,
          recentWindowMaxUid: recentMaxUid,
        );
      },
    );
  }

  Future<bool> saveSentCopy({
    required MailAccount account,
    required MailFolder folder,
    required String messageId,
    required Future<String> Function() buildMimeText,
    DateTime? sentAt,
  }) {
    return _dataSource.withFolder(
      account: account,
      folder: folder,
      action: (session, _) async {
        if (await session.containsMessageId(messageId)) return true;
        if (!account.saveSentCopy) return false;
        await session.appendSentMessage(await buildMimeText(), sentAt: sentAt);
        return true;
      },
    );
  }

  Future<RemoteFetchedMessage?> fetchFullMessage({
    required MailAccount account,
    required MailFolder folder,
    required int uid,
  }) {
    return _dataSource.withFolder(
      account: account,
      folder: folder,
      checkUidValidity: true,
      action: (session, _) => session.uidFetchFullMessage(uid),
    );
  }

  Future<Uint8List?> fetchAttachmentPart({
    required MailAccount account,
    required MailFolder folder,
    required int uid,
    required String partId,
  }) {
    return _dataSource.withFolder(
      account: account,
      folder: folder,
      checkUidValidity: true,
      action: (session, _) =>
          session.uidFetchAttachmentPart(uid: uid, partId: partId),
    );
  }

  Future<void> updateFlags({
    required MailAccount account,
    required MailFolder folder,
    required int uid,
    List<String> add = const [],
    List<String> remove = const [],
  }) {
    return _dataSource.withFolder(
      account: account,
      folder: folder,
      checkUidValidity: true,
      action: (session, _) async {
        if (add.isNotEmpty) {
          await session.uidStoreFlags(uid: uid, flags: add, add: true);
        }
        if (remove.isNotEmpty) {
          await session.uidStoreFlags(uid: uid, flags: remove, add: false);
        }
      },
    );
  }
}
