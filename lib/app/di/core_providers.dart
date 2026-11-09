import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/account_connection_slot.dart';
import '../../../core/network/connection_pool.dart';
import '../../../core/network/connectivity_monitor.dart';
import '../../../core/network/imap_session.dart';
import '../../../core/network/lifecycle_manager.dart';
import '../../../core/security/oauth_pkce_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../features/auth/data/account_credential_resolver.dart';
import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/data/imap_connection_tester.dart';
import '../../features/auth/domain/entities/mail_account.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/mail/data/datasources/enough_mail_imap_session.dart';
import '../../features/mail/domain/services/attachment_picker.dart';

part 'core_providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase();
  ref.onDispose(() {
    unawaited(database.close());
  });
  return database;
}

@Riverpod(keepAlive: true)
SecureStorageService secureStorageService(Ref ref) {
  return SecureStorageService();
}

@Riverpod(keepAlive: true)
OAuthPkceService oauthPkceService(Ref ref) {
  return OAuthPkceService();
}

@Riverpod(keepAlive: true)
AccountCredentialResolver accountCredentialResolver(Ref ref) {
  return AccountCredentialResolver(
    secureStorage: ref.watch(secureStorageServiceProvider),
    oauthPkceService: ref.watch(oauthPkceServiceProvider),
  );
}

@Riverpod(keepAlive: true)
ImapSessionFactory imapSessionFactory(Ref ref) {
  return EnoughMailImapSessionFactory();
}

@Riverpod(keepAlive: true)
ConnectionPool connectionPool(Ref ref) {
  final resolver = ref.watch(accountCredentialResolverProvider);
  final pool = ConnectionPool(
    sessionFactory: ref.watch(imapSessionFactoryProvider),
    credentialResolver: resolver.call,
  );
  ref.onDispose(() {
    unawaited(pool.dispose());
  });
  return pool;
}

@Riverpod(keepAlive: true)
ImapConnectionTester imapConnectionTester(Ref ref) {
  return ImapConnectionTester(
    sessionFactory: ref.watch(imapSessionFactoryProvider),
  );
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
    connectionPool: ref.watch(connectionPoolProvider),
    cleanupOutboxAttachments: (paths) {
      return AttachmentStore().cleanupPaths(paths);
    },
  );
}

@Riverpod(keepAlive: true)
AppLifecycleManager appLifecycleManager(Ref ref) {
  return AppLifecycleManager(connectionPool: ref.watch(connectionPoolProvider));
}

@Riverpod(keepAlive: true)
ConnectivityMonitor connectivityMonitor(Ref ref) {
  return ConnectivityMonitor(connectionPool: ref.watch(connectionPoolProvider));
}

@Riverpod(keepAlive: true)
Stream<List<MailAccount>> accounts(Ref ref) {
  return ref.watch(authRepositoryProvider).watchAccounts();
}

@Riverpod(keepAlive: true)
Stream<Map<String, ConnectionSlotState>> accountSlotStates(Ref ref) async* {
  final pool = ref.watch(connectionPoolProvider);
  yield pool.currentStates;
  yield* pool.slotStates;
}
