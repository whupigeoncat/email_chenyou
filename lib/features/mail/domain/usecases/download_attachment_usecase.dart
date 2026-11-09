import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/mail_account.dart';
import '../../data/repositories/mail_local_repository.dart';
import '../../data/repositories/mail_remote_repository.dart';

/// Downloads one attachment part on demand and stores it under
/// `<temp>/mail_attachments/<accountId>/<emailLocalId>/<partId>/<filename>`.
///
/// File names are reduced to a single sanitized path segment, so a malicious
/// `../../foo` name can never escape the cache root.
class DownloadAttachmentUseCase {
  DownloadAttachmentUseCase({
    required this._localRepository,
    required this._remoteRepository,
    Future<Directory> Function()? temporaryDirectoryProvider,
  }) : _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory;

  final MailLocalRepository _localRepository;
  final MailRemoteRepository _remoteRepository;
  final Future<Directory> Function() _temporaryDirectoryProvider;

  Future<String> call({
    required MailAccount account,
    required int emailLocalId,
    required String partId,
  }) async {
    final attachment = await _localRepository.getAttachment(
      emailLocalId,
      partId,
    );
    if (attachment == null) {
      throw StateError('Attachment $partId does not exist locally');
    }

    final email = await _localRepository.getEmail(emailLocalId);
    if (email == null) {
      throw StateError('Local email $emailLocalId no longer exists');
    }
    if (account.id != email.accountId) {
      throw const StorageFailure(userMessage: '邮件不属于当前账户，操作已阻止。');
    }
    final cachedPath = attachment.localCachePath;
    if (cachedPath != null && cachedPath.isNotEmpty) {
      final cachedFile = File(cachedPath);
      if (await cachedFile.exists()) return cachedPath;
    }

    final folder = await _localRepository.getFolderById(email.folderId);
    if (folder == null) {
      throw StateError('Folder ${email.folderId} no longer exists');
    }

    final bytes = await _remoteRepository.fetchAttachmentPart(
      account: account,
      folder: folder,
      uid: email.uid,
      partId: partId,
    );
    if (bytes == null) {
      throw StateError('Server returned no bytes for attachment $partId');
    }

    final tempRoot = await _temporaryDirectoryProvider();
    final safePartId = _sanitizePathSegment(partId);
    final safeFileName = sanitizeAttachmentFileName(attachment.filename);
    final directory = Directory(
      p.normalize(
        p.join(
          tempRoot.path,
          'mail_attachments',
          _sanitizePathSegment(account.id),
          '$emailLocalId',
          safePartId,
        ),
      ),
    );
    await directory.create(recursive: true);

    final targetPath = p.normalize(p.join(directory.path, safeFileName));
    if (!p.isWithin(tempRoot.path, targetPath)) {
      throw StateError('Refusing to write attachment outside the cache root');
    }

    final file = File(targetPath);
    await file.writeAsBytes(bytes, flush: true);
    await _localRepository.updateAttachmentCachePath(
      attachmentId: attachment.id,
      localCachePath: file.path,
    );
    return file.path;
  }

  /// Removes directory traversal, control characters and Windows-reserved
  /// characters while preserving a usable extension.
  static String sanitizeAttachmentFileName(String input) {
    var name = input.replaceAll('\\', '/');
    final lastSlash = name.lastIndexOf('/');
    if (lastSlash != -1) name = name.substring(lastSlash + 1);
    name = name.replaceAll(RegExp(r'[\u0000-\u001f<>:"|?*]'), '_').trim();
    name = name.replaceAll(RegExp(r'^\.+'), '');

    if (name.isEmpty || name == '.' || name == '..') {
      return 'attachment.bin';
    }
    if (name.length > 180) {
      final dot = name.lastIndexOf('.');
      final extension = dot > 0 && name.length - dot <= 10
          ? name.substring(dot)
          : '';
      final baseLength = 180 - extension.length;
      name = '${name.substring(0, baseLength.clamp(1, name.length))}$extension';
    }
    return name;
  }

  static String _sanitizePathSegment(String input) {
    var segment = input.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    segment = segment.replaceAll(RegExp(r'^\.+'), '');
    if (segment.isEmpty || segment == '.' || segment == '..') {
      return 'part';
    }
    return segment;
  }
}
