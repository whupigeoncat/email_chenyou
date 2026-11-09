import '../../../auth/domain/entities/mail_account.dart';
import '../../data/repositories/mail_local_repository.dart';
import '../../data/repositories/mail_remote_repository.dart';
import '../entities/mail_folder.dart';

/// Synchronizes a non-INBOX folder through a serialized transient connection
/// that is LOGOUTed by `ConnectionPool.runTransientFolderTask` in `finally`.
class PollFolderUseCase {
  const PollFolderUseCase({
    required this._localRepository,
    required this._remoteRepository,
  });

  final MailLocalRepository _localRepository;
  final MailRemoteRepository _remoteRepository;

  Future<MailFolder> call({
    required MailAccount account,
    required MailFolder folder,
  }) async {
    final maxUid = await _localRepository.getMaxUid(folder.id);
    final result = await _remoteRepository.syncFolder(
      account: account,
      folder: folder,
      localMaxUid: maxUid,
    );
    await _localRepository.applyFolderSync(
      account: account,
      folder: folder,
      result: result,
    );
    return await _localRepository.getFolderById(folder.id) ?? folder;
  }
}
