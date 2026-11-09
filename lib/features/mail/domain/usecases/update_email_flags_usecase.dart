import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/mail_account.dart';
import '../../data/repositories/mail_local_repository.dart';
import '../../data/repositories/mail_remote_repository.dart';
import '../entities/unified_email.dart';

/// Optimistically updates local flags, then applies the delta on the server.
/// Any remote failure rolls the local bitmask back to its previous value.
class UpdateEmailFlagsUseCase {
  const UpdateEmailFlagsUseCase({
    required this._localRepository,
    required this._remoteRepository,
  });

  final MailLocalRepository _localRepository;
  final MailRemoteRepository _remoteRepository;

  Future<UnifiedEmail> call({
    required MailAccount account,
    required int emailLocalId,
    bool? isRead,
    bool? isFlagged,
    bool? isAnswered,
  }) async {
    final cached = await _localRepository.getEmail(emailLocalId);
    if (cached == null) {
      throw StateError('Local email $emailLocalId no longer exists');
    }
    return _localRepository.runFolderSync(
      cached.folderId,
      () => _perform(
        account: account,
        emailLocalId: emailLocalId,
        isRead: isRead,
        isFlagged: isFlagged,
        isAnswered: isAnswered,
      ),
    );
  }

  Future<UnifiedEmail> _perform({
    required MailAccount account,
    required int emailLocalId,
    bool? isRead,
    bool? isFlagged,
    bool? isAnswered,
  }) async {
    final email = await _localRepository.getEmail(emailLocalId);
    if (email == null) {
      throw StateError('Local email $emailLocalId no longer exists');
    }
    if (account.id != email.accountId) {
      throw const StorageFailure(userMessage: '邮件不属于当前账户，操作已阻止。');
    }
    final folder = await _localRepository.getFolderById(email.folderId);
    if (folder == null) {
      throw StateError('Folder ${email.folderId} no longer exists');
    }

    final oldMask = email.flagsBitmask;
    var newMask = oldMask;
    final toAdd = <String>[];
    final toRemove = <String>[];

    void apply(int flag, String remoteName, bool? desired) {
      if (desired == null) return;
      final currentlySet = (oldMask & flag) != 0;
      if (desired == currentlySet) return;
      if (desired) {
        newMask |= flag;
        toAdd.add(remoteName);
      } else {
        newMask &= ~flag;
        toRemove.add(remoteName);
      }
    }

    apply(UnifiedEmail.flagSeen, r'\Seen', isRead);
    apply(UnifiedEmail.flagFlagged, r'\Flagged', isFlagged);
    apply(UnifiedEmail.flagAnswered, r'\Answered', isAnswered);

    if (newMask == oldMask) return email;

    // Optimistic local write: the UI updates immediately, and this is the
    // exact value restored if the server rejects the STORE.
    await _localRepository.updateFlags(emailLocalId, newMask);
    await _localRepository.refreshFolderUnreadCount(folder.id);

    try {
      await _remoteRepository.updateFlags(
        account: account,
        folder: folder,
        uid: email.uid,
        add: toAdd,
        remove: toRemove,
      );
    } catch (_) {
      await _localRepository.updateFlags(emailLocalId, oldMask);
      await _localRepository.refreshFolderUnreadCount(folder.id);
      rethrow;
    }

    return (await _localRepository.getEmail(emailLocalId)) ?? email;
  }
}
