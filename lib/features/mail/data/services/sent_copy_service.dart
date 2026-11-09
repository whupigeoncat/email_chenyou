import '../../../../core/error/failures.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/entities/mail_folder.dart';
import '../../domain/entities/outbox_message.dart';
import '../../domain/repositories/outbox_repository.dart';
import '../../domain/usecases/poll_folder_usecase.dart';
import '../datasources/enough_mail_smtp_session.dart';
import '../repositories/mail_local_repository.dart';
import '../repositories/mail_remote_repository.dart';

/// Retries only IMAP archival; it can never submit another SMTP message.
class SentCopyService {
  SentCopyService({
    required this.outbox,
    required this.auth,
    required this.local,
    required this.remote,
  });

  final OutboxRepository outbox;
  final AuthRepository auth;
  final MailLocalRepository local;
  final MailRemoteRepository remote;
  final Map<String, Future<void>> _saving = {};

  Future<void> save(String id) {
    final existing = _saving[id];
    if (existing != null) return existing;
    late final Future<void> operation;
    operation = _save(id).whenComplete(() {
      if (identical(_saving[id], operation)) _saving.remove(id);
    });
    _saving[id] = operation;
    return operation;
  }

  Future<void> _save(String id) async {
    final message = await outbox.getById(id);
    if (message == null ||
        message.status != OutboxStatus.sent ||
        message.sentCopySaved) {
      return;
    }
    try {
      final account = await auth.getAccount(message.accountId);
      if (account == null || !account.isEnabled) {
        throw const StorageFailure(userMessage: '发送账户已停用或不存在，本地副本已保留。');
      }
      var folder = await local.getFolderByRole(account.id, FolderRole.sent);
      if (folder == null) {
        await local.upsertMailboxes(
          accountId: account.id,
          mailboxes: await remote.listMailboxes(account),
        );
        folder = await local.getFolderByRole(account.id, FolderRole.sent);
      }
      if (folder == null) {
        throw const StorageFailure(userMessage: '未找到服务器已发送文件夹，本地副本已保留。');
      }
      final messageId = message.outgoingMessageId;
      if (messageId == null || messageId.isEmpty) {
        throw const StorageFailure(
          userMessage: '旧邮件缺少 Message-ID，无法安全核对副本，本地内容已保留。',
        );
      }
      final saved = await remote.saveSentCopy(
        account: account,
        folder: folder,
        messageId: messageId,
        sentAt: message.sentAt,
        buildMimeText: () async => (await buildOutgoingMimeMessage(
          OutgoingMailEnvelope.fromComposeDraft(
            message.toComposeDraft(),
            account,
            messageId: messageId,
          ),
          sentAt: message.sentAt,
        )).renderMessage(),
      );
      if (!saved) {
        throw const StorageFailure(
          userMessage: '尚未找到服务器副本，本地内容已保留。若服务商不自动保存，请在账户管理中开启“保存已发送副本”后补存。',
        );
      }
      await outbox.recordSentCopy(id, saved: true);
      await PollFolderUseCase(localRepository: local, remoteRepository: remote)(
        account: account,
        folder: folder,
      );
    } catch (error) {
      final current = await outbox.getById(id);
      // A refresh failure after confirmed archival must not invalidate it.
      if (current?.sentCopySaved != true) {
        await outbox.recordSentCopy(
          id,
          saved: false,
          error: error is AppFailure
              ? error.userMessage
              : '保存已发送副本失败，本地内容已保留：$error',
        );
      }
      rethrow;
    }
  }
}
