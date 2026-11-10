import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/core_providers.dart';
import '../../../auth/domain/entities/mail_account.dart';
import '../../data/datasources/mail_local_datasource.dart';
import '../../data/datasources/mail_remote_datasource.dart';
import '../../data/datasources/outbox_local_datasource.dart';
import '../../data/datasources/smtp_session.dart';
import '../../data/datasources/enough_mail_smtp_session.dart';
import '../../data/repositories/mail_local_repository.dart';
import '../../data/repositories/mail_remote_repository.dart';
import '../../data/repositories/outbox_repository_impl.dart';
import '../../data/repositories/trusted_senders_repository_impl.dart';
import '../../data/services/account_sync_bootstrap.dart';
import '../../data/services/inbox_sync_coordinator.dart';
import '../../data/services/outbox_queue_service.dart';
import '../../data/services/sent_copy_service.dart';
import '../../../notifications/data/foreground_inbox_marker.dart';
import '../../../notifications/data/inbox_notification_state_store.dart';
import '../../../../core/logging/sanitized_logger.dart';
import '../../domain/entities/local_cache_stats.dart';
import '../../domain/entities/mail_folder.dart';
import '../../domain/entities/outbox_message.dart';
import '../../domain/entities/trusted_sender.dart';
import '../../domain/entities/unified_email.dart';
import '../../domain/repositories/outbox_repository.dart';
import '../../domain/repositories/trusted_senders_repository.dart';
import '../../domain/services/attachment_picker.dart';
import '../../domain/services/compose_draft_factory.dart';
import '../../domain/usecases/download_attachment_usecase.dart';
import '../../domain/usecases/fetch_message_body_usecase.dart';
import '../../domain/usecases/poll_folder_usecase.dart';
import '../../domain/usecases/search_emails_usecase.dart';
import '../../domain/usecases/sync_inbox_usecase.dart';
import '../../domain/usecases/outbox_usecases.dart';
import '../../domain/usecases/update_email_flags_usecase.dart';

part 'mail_providers.g.dart';

@Riverpod(keepAlive: true)
MailLocalDataSource mailLocalDataSource(Ref ref) {
  return MailLocalDataSource(database: ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
MailLocalRepository mailLocalRepository(Ref ref) {
  return MailLocalRepository(
    dataSource: ref.watch(mailLocalDataSourceProvider),
  );
}

@Riverpod(keepAlive: true)
MailRemoteDataSource mailRemoteDataSource(Ref ref) {
  return MailRemoteDataSource(
    connectionPool: ref.watch(connectionPoolProvider),
  );
}

@Riverpod(keepAlive: true)
MailRemoteRepository mailRemoteRepository(Ref ref) {
  return MailRemoteRepository(
    dataSource: ref.watch(mailRemoteDataSourceProvider),
  );
}

@Riverpod(keepAlive: true)
SyncInboxUseCase syncInboxUseCase(Ref ref) {
  return SyncInboxUseCase(
    localRepository: ref.watch(mailLocalRepositoryProvider),
    remoteRepository: ref.watch(mailRemoteRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
PollFolderUseCase pollFolderUseCase(Ref ref) {
  return PollFolderUseCase(
    localRepository: ref.watch(mailLocalRepositoryProvider),
    remoteRepository: ref.watch(mailRemoteRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
FetchMessageBodyUseCase fetchMessageBodyUseCase(Ref ref) {
  return FetchMessageBodyUseCase(
    localRepository: ref.watch(mailLocalRepositoryProvider),
    remoteRepository: ref.watch(mailRemoteRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
DownloadAttachmentUseCase downloadAttachmentUseCase(Ref ref) {
  return DownloadAttachmentUseCase(
    localRepository: ref.watch(mailLocalRepositoryProvider),
    remoteRepository: ref.watch(mailRemoteRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
UpdateEmailFlagsUseCase updateEmailFlagsUseCase(Ref ref) {
  return UpdateEmailFlagsUseCase(
    localRepository: ref.watch(mailLocalRepositoryProvider),
    remoteRepository: ref.watch(mailRemoteRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
SearchEmailsUseCase searchEmailsUseCase(Ref ref) {
  return SearchEmailsUseCase(
    localRepository: ref.watch(mailLocalRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
Stream<List<UnifiedEmail>> unifiedInbox(Ref ref) {
  return ref.watch(mailLocalRepositoryProvider).watchUnifiedInbox();
}

@Riverpod(keepAlive: true)
Stream<List<MailFolder>> accountFolders(Ref ref, String accountId) {
  return ref.watch(mailLocalRepositoryProvider).watchFolders(accountId);
}

@Riverpod(keepAlive: true)
TrustedSendersRepository trustedSendersRepository(Ref ref) {
  return TrustedSendersRepositoryImpl(database: ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
Stream<Set<TrustedSender>> trustedSenders(Ref ref) {
  return ref.watch(trustedSendersRepositoryProvider).watchTrustedSenders();
}

@Riverpod(keepAlive: true)
AttachmentPicker attachmentPicker(Ref ref) =>
    const FilePickerAttachmentPicker();

@Riverpod(keepAlive: true)
AttachmentStore attachmentStore(Ref ref) => AttachmentStore();

@Riverpod(keepAlive: true)
ComposeDraftFactory composeDraftFactory(Ref ref) {
  return ComposeDraftFactory(
    attachmentStore: ref.watch(attachmentStoreProvider),
  );
}

@Riverpod(keepAlive: true)
OutboxLocalDataSource outboxLocalDataSource(Ref ref) {
  return OutboxLocalDataSource(database: ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
OutboxRepository outboxRepository(Ref ref) {
  return OutboxRepositoryImpl(
    dataSource: ref.watch(outboxLocalDataSourceProvider),
    attachmentStore: ref.watch(attachmentStoreProvider),
  );
}

@Riverpod(keepAlive: true)
Future<LocalCacheStats> localCacheStats(Ref ref) {
  return ref.watch(mailLocalRepositoryProvider).readLocalCacheStats();
}

@Riverpod(keepAlive: true)
Stream<List<OutboxMessage>> outboxMessages(Ref ref) {
  return ref.watch(outboxRepositoryProvider).watchMessages();
}

@Riverpod(keepAlive: true)
Stream<List<OutboxMessage>> outboxDrafts(Ref ref) {
  return ref.watch(outboxRepositoryProvider).watchDrafts();
}

@Riverpod(keepAlive: true)
Stream<OutboxCounts> outboxCounts(Ref ref) {
  return ref.watch(outboxRepositoryProvider).watchCounts();
}

@Riverpod(keepAlive: true)
SmtpSessionFactory smtpSessionFactory(Ref ref) {
  return EnoughMailSmtpSessionFactory();
}

@Riverpod(keepAlive: true)
OutboxQueueService outboxQueue(Ref ref) {
  final queue = OutboxQueueService(
    repository: ref.watch(outboxRepositoryProvider),
    sessionFactory: ref.watch(smtpSessionFactoryProvider),
    credentialResolver: ref.watch(accountCredentialResolverProvider),
    authRepository: ref.watch(authRepositoryProvider),
    postSendHook: (message, account) async {
      if (message.mode.isReply && message.originEmailLocalId != null) {
        try {
          final original = await ref
              .read(mailLocalRepositoryProvider)
              .getEmail(message.originEmailLocalId!);
          final owner = original == null
              ? null
              : await ref
                    .read(authRepositoryProvider)
                    .getAccount(original.accountId);
          if (owner != null && owner.isEnabled) {
            await ref.read(updateEmailFlagsUseCaseProvider)(
              account: owner,
              emailLocalId: message.originEmailLocalId!,
              isAnswered: true,
            );
          }
        } catch (error) {
          SanitizedLogger.instance.warn(
            'OutboxQueue',
            'Failed to mark original as answered',
            error,
          );
        }
      }
      await ref.read(sentCopyServiceProvider).save(message.id);
    },
  );
  ref.onDispose(() {
    unawaited(queue.dispose());
  });
  return queue;
}

@Riverpod(keepAlive: true)
SaveDraftUseCase saveDraftUseCase(Ref ref) {
  return SaveDraftUseCase(
    repository: ref.watch(outboxRepositoryProvider),
    queue: ref.watch(outboxQueueProvider),
  );
}

@Riverpod(keepAlive: true)
QueueAndSendEmailUseCase queueAndSendEmailUseCase(Ref ref) {
  return QueueAndSendEmailUseCase(
    repository: ref.watch(outboxRepositoryProvider),
    queue: ref.watch(outboxQueueProvider),
  );
}

@Riverpod(keepAlive: true)
RetryOutboxMessageUseCase retryOutboxMessageUseCase(Ref ref) {
  return RetryOutboxMessageUseCase(queue: ref.watch(outboxQueueProvider));
}

@Riverpod(keepAlive: true)
MarkOutboxMessageSentUseCase markOutboxMessageSentUseCase(Ref ref) {
  return MarkOutboxMessageSentUseCase(
    repository: ref.watch(outboxRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
DeleteOutboxMessageUseCase deleteOutboxMessageUseCase(Ref ref) {
  return DeleteOutboxMessageUseCase(
    repository: ref.watch(outboxRepositoryProvider),
    queue: ref.watch(outboxQueueProvider),
  );
}

@Riverpod(keepAlive: true)
InboxNotificationStateStore inboxNotificationStateStore(Ref ref) {
  return InboxNotificationStateStore(database: ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
ForegroundInboxMarker foregroundInboxMarker(Ref ref) {
  return ForegroundInboxMarker(
    database: ref.watch(appDatabaseProvider),
    stateStore: ref.watch(inboxNotificationStateStoreProvider),
  );
}

@Riverpod(keepAlive: true)
InboxSyncCoordinator inboxSyncCoordinator(Ref ref) {
  final coordinator = InboxSyncCoordinator(
    connectionPool: ref.watch(connectionPoolProvider),
    syncAccount: (String accountId) async {
      final MailAccount? account = await ref
          .read(authRepositoryProvider)
          .getAccount(accountId);
      if (account == null || !account.isEnabled) return;
      await ref.read(syncInboxUseCaseProvider).call(account);
    },
    notifySynced: (accountId) {
      return ref.read(foregroundInboxMarkerProvider).markSynced(accountId);
    },
  );
  ref.onDispose(() {
    unawaited(coordinator.dispose());
  });
  return coordinator;
}

@Riverpod(keepAlive: true)
AccountSyncBootstrap accountSyncBootstrap(Ref ref) {
  final bootstrap = AccountSyncBootstrap(
    authRepository: ref.watch(authRepositoryProvider),
    syncCoordinator: ref.watch(inboxSyncCoordinatorProvider),
  );
  ref.onDispose(() {
    unawaited(bootstrap.dispose());
  });
  return bootstrap;
}

@Riverpod(keepAlive: true)
SentCopyService sentCopyService(Ref ref) => SentCopyService(
  outbox: ref.watch(outboxRepositoryProvider),
  auth: ref.watch(authRepositoryProvider),
  local: ref.watch(mailLocalRepositoryProvider),
  remote: ref.watch(mailRemoteRepositoryProvider),
);
