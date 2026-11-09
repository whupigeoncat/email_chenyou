import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:local_mail_client/core/security/oauth_pkce_service.dart';
import 'package:local_mail_client/core/security/secure_storage_service.dart';
import 'package:local_mail_client/features/auth/data/account_credential_resolver.dart';
import 'package:local_mail_client/features/mail/data/datasources/smtp_session.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/app/di/app_runtime_providers.dart';
import 'package:local_mail_client/core/network/connection_pool.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/core/network/connectivity_monitor.dart';
import 'package:local_mail_client/core/network/lifecycle_manager.dart';
import 'package:local_mail_client/features/mail/data/services/account_sync_bootstrap.dart';
import 'package:local_mail_client/features/mail/data/services/inbox_sync_coordinator.dart';
import 'package:local_mail_client/features/mail/data/services/outbox_queue_service.dart';
import 'package:local_mail_client/features/mail/data/datasources/outbox_local_datasource.dart';
import 'package:local_mail_client/features/mail/data/repositories/outbox_repository_impl.dart';
import 'package:local_mail_client/core/database/app_database.dart';

import '../../../core/support/fake_imap_session.dart';
import '../../auth/support/fakes.dart';

class TestRuntimeHarness {
  TestRuntimeHarness() {
    _auth = FakeAuthRepository();
    _pool = ConnectionPool(
      sessionFactory: FakeImapSessionFactory(),
      credentialResolver: fakeCredentialResolver,
    );
    _coordinator = InboxSyncCoordinator(
      connectionPool: _pool,
      syncAccount: (_) async {},
    );
    final outboxDb = AppDatabase.forTesting(NativeDatabase.memory());
    final outboxRepo = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: outboxDb),
    );
    final outboxQueue = OutboxQueueService(
      repository: outboxRepo,
      sessionFactory: _NoopSmtpSessionFactory(),
      credentialResolver: AccountCredentialResolver(
        secureStorage: SecureStorageService(),
        oauthPkceService: OAuthPkceService(),
      ),
      authRepository: _auth,
    );
    _outboxDb = outboxDb;
    _outboxQueue = outboxQueue;
    runtime = AppRuntime(
      lifecycleManager: AppLifecycleManager(connectionPool: _pool),
      connectivityMonitor: ConnectivityMonitor(
        connectionPool: _pool,
        connectivityStream: Stream<List<ConnectivityResult>>.empty(),
      ),
      inboxSyncCoordinator: _coordinator,
      accountSyncBootstrap: AccountSyncBootstrap(
        authRepository: _auth,
        syncCoordinator: _coordinator,
      ),
      outboxQueue: outboxQueue,
    );
  }

  late final FakeAuthRepository _auth;
  late final ConnectionPool _pool;
  late final InboxSyncCoordinator _coordinator;
  late final AppDatabase _outboxDb;
  late final OutboxQueueService _outboxQueue;
  late final AppRuntime runtime;

  Future<void> dispose() async {
    await _coordinator.dispose();
    await _pool.dispose();
    await _auth.dispose();
    await _outboxQueue.dispose();
    await _outboxDb.close();
  }
}


class _NoopSmtpSessionFactory implements SmtpSessionFactory {
  @override
  SmtpSession createSession() => _NoopSmtpSession();
}

class _NoopSmtpSession implements SmtpSession {
  @override
  bool get isConnected => false;

  @override
  Future<void> connectAndAuthenticate({
    required MailAccount account,
    required ResolvedAccountCredential credential,
  }) async {}

  @override
  Future<void> send(OutgoingMailEnvelope envelope) async {}

  @override
  Future<void> quitAndDisconnect({
    Duration timeout = const Duration(seconds: 5),
  }) async {}

  @override
  Future<void> forceClose() async {}
}
