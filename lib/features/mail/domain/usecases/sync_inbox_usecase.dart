import '../../../auth/domain/entities/mail_account.dart';
import '../../data/repositories/mail_local_repository.dart';
import '../../data/repositories/mail_remote_repository.dart';
import '../entities/mail_folder.dart';

/// Lists mailboxes and synchronizes the INBOX folder on the persistent IDLE
/// socket. Folder discovery uses the same socket; no extra connection is opened.
class SyncInboxUseCase {
  const SyncInboxUseCase({
    required this._localRepository,
    required this._remoteRepository,
  });

  final MailLocalRepository _localRepository;
  final MailRemoteRepository _remoteRepository;

  Future<MailFolder?> call(MailAccount account) async {
    final mailboxes = await _remoteRepository.listMailboxes(account);
    final folders = await _localRepository.upsertMailboxes(
      accountId: account.id,
      mailboxes: mailboxes,
    );

    MailFolder? inbox;
    for (final folder in folders) {
      if (folder.role == FolderRole.inbox) {
        inbox = folder;
        break;
      }
    }
    inbox ??= await _localRepository.getFolderByRole(
      account.id,
      FolderRole.inbox,
    );
    if (inbox == null) return null;

    final maxUid = await _localRepository.getMaxUid(inbox.id);
    final result = await _remoteRepository.syncFolder(
      account: account,
      folder: inbox,
      localMaxUid: maxUid,
    );
    await _localRepository.applyFolderSync(
      account: account,
      folder: inbox,
      result: result,
    );

    return await _localRepository.getFolderById(inbox.id) ?? inbox;
  }
}
