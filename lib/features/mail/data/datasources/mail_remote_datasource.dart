import '../../../../core/error/failures.dart';
import '../../../../core/network/connection_pool.dart';
import '../../../../core/network/imap_session.dart';
import '../../../auth/domain/entities/mail_account.dart';
import '../../domain/entities/mail_folder.dart';

/// Raw IMAP transport gateway.
///
/// This is the only mail-layer class allowed to talk to [ConnectionPool]. It
/// never creates an `ImapClient`/socket itself:
/// - INBOX operations reuse the single persistent IDLE connection.
/// - Non-INBOX operations use the serialized transient connection which always
///   LOGOUTs in `AccountConnectionSlot.runTransientFolderTask`'s `finally`.
class MailRemoteDataSource {
  MailRemoteDataSource({required this._connectionPool});

  final ConnectionPool _connectionPool;

  Future<List<RemoteMailboxInfo>> listMailboxes(MailAccount account) {
    return _connectionPool.runOnInbox(
      account.id,
      (session) => session.listMailboxes(),
    );
  }

  /// Runs [action] with the correct socket type and a freshly selected folder.
  ///
  /// INBOX uses `runOnInbox`; every other folder uses `runTransientFolderTask`
  /// so the socket is released immediately after the action completes.
  Future<T> withFolder<T>({
    required MailAccount account,
    required MailFolder folder,
    bool checkUidValidity = false,
    required Future<T> Function(ImapSession session, RemoteMailboxStatus status)
    action,
  }) {
    if (account.id != folder.accountId) {
      return Future.error(
        const StorageFailure(userMessage: '邮件文件夹不属于当前账户，操作已阻止。'),
      );
    }
    Future<T> run(ImapSession session) async {
      final status = await session.selectFolderWithStatus(folder.remoteName);
      if (checkUidValidity &&
          folder.uidValidity != null &&
          folder.uidValidity != status.uidValidity) {
        throw const ImapProtocolFailure(
          reason: ImapFailureReason.uidValidityChanged,
          userMessage: '服务器已重建邮件索引，请刷新邮箱后重试，已阻止操作旧邮件。',
        );
      }
      return action(session, status);
    }

    final isInbox =
        folder.role == FolderRole.inbox ||
        folder.remoteName.toUpperCase() == 'INBOX';
    if (isInbox) {
      return _connectionPool.runOnInbox(account.id, run);
    }
    return _connectionPool.runTransientFolderTask(
      accountId: account.id,
      remoteFolderName: folder.remoteName,
      action: run,
    );
  }
}
