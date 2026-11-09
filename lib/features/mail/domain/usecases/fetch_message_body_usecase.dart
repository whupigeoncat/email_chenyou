import '../../../auth/domain/entities/mail_account.dart';
import '../../data/repositories/mail_local_repository.dart';
import '../../data/repositories/mail_remote_repository.dart';
import '../entities/unified_email.dart';

/// Downloads a full message body on demand and marks it as downloaded.
///
/// The second open returns the cached local body without any IMAP request.
class FetchMessageBodyUseCase {
  const FetchMessageBodyUseCase({
    required this._localRepository,
    required this._remoteRepository,
  });

  final MailLocalRepository _localRepository;
  final MailRemoteRepository _remoteRepository;

  Future<UnifiedEmail> call({
    required MailAccount account,
    required int emailLocalId,
  }) async {
    final email = await _localRepository.getEmail(emailLocalId);
    if (email == null) {
      throw StateError('Local email $emailLocalId no longer exists');
    }
    if (email.bodyDownloaded) return email;

    final folder = await _localRepository.getFolderById(email.folderId);
    if (folder == null) {
      throw StateError('Folder ${email.folderId} no longer exists');
    }

    final message = await _remoteRepository.fetchFullMessage(
      account: account,
      folder: folder,
      uid: email.uid,
    );
    if (message == null) {
      throw StateError('Server did not return UID ${email.uid}');
    }

    return _localRepository.saveFullMessage(
      localId: emailLocalId,
      message: message,
    );
  }
}
