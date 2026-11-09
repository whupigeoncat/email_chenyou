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
    bool loadOlder = false,
  }) async {
    return _localRepository.runFolderSync(folder.id, () async {
      final current = await _localRepository.getFolderById(folder.id) ?? folder;
      final uids = await _localRepository.getUids(folder.id);
      final maxUid = uids.isEmpty ? null : uids.reduce((a, b) => a > b ? a : b);
      final minUid = uids.isEmpty ? null : uids.reduce((a, b) => a < b ? a : b);
      final result = await _remoteRepository.syncFolder(
        account: account,
        folder: current,
        localMaxUid: maxUid,
        localUids: uids,
        olderThanUid: loadOlder ? minUid : null,
      );
      await _localRepository.applyFolderSync(
        account: account,
        folder: current,
        result: result,
      );
      return await _localRepository.getFolderById(folder.id) ?? current;
    });
  }
}
