import '../../../../core/network/imap_session.dart';

/// Result of one remote folder synchronization pass.
class MailFolderSyncResult {
  const MailFolderSyncResult({
    required this.status,
    required this.messages,
    required this.uidValidityChanged,
    required this.isFullSnapshot,
    this.recentWindowMinUid,
    this.recentWindowMaxUid,
  });

  final RemoteMailboxStatus status;

  /// Header rows fetched in this pass (incremental + recent flag window).
  final List<RemoteFetchedMessage> messages;

  /// The server's UIDVALIDITY differs from the locally cached one. The local
  /// folder cache must be discarded and rebuilt.
  final bool uidValidityChanged;

  /// This pass fetched the initial recent window rather than an incremental
  /// `maxUid + 1:*` range.
  final bool isFullSnapshot;

  /// UID bounds of the recent window used for flag / deletion reconciliation.
  final int? recentWindowMinUid;
  final int? recentWindowMaxUid;
}
