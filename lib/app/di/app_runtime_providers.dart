import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/logging/sanitized_logger.dart';
import '../../core/network/connectivity_monitor.dart';
import '../../core/network/lifecycle_manager.dart';
import '../../features/mail/data/services/account_sync_bootstrap.dart';
import '../../features/mail/data/services/inbox_sync_coordinator.dart';
import '../../features/mail/data/services/outbox_queue_service.dart';
import '../../features/mail/presentation/providers/mail_providers.dart';
import 'core_providers.dart';

part 'app_runtime_providers.g.dart';

@immutable
class AppRuntime {
  const AppRuntime({
    required this.lifecycleManager,
    required this.connectivityMonitor,
    required this.inboxSyncCoordinator,
    required this.accountSyncBootstrap,
    required this.outboxQueue,
  });

  final AppLifecycleManager lifecycleManager;
  final ConnectivityMonitor connectivityMonitor;
  final InboxSyncCoordinator inboxSyncCoordinator;
  final AccountSyncBootstrap accountSyncBootstrap;
  final OutboxQueueService outboxQueue;
}

/// Starts lifecycle/network observers, seeds connection-pool slots, runs the
/// first sync for enabled accounts, and mounts the IDLE coordinator exactly
/// once per app process.
@Riverpod(keepAlive: true)
AppRuntime appRuntime(Ref ref) {
  final lifecycle = ref.watch(appLifecycleManagerProvider);
  final connectivity = ref.watch(connectivityMonitorProvider);
  final repository = ref.watch(authRepositoryProvider);
  final syncCoordinator = ref.watch(inboxSyncCoordinatorProvider);
  final bootstrap = ref.watch(accountSyncBootstrapProvider);
  final outboxQueue = ref.watch(outboxQueueProvider);

  lifecycle.start();
  connectivity.start();
  syncCoordinator.start();
  unawaited(() async {
    try {
      await repository.initialize();
      await bootstrap.start();
      await outboxQueue.start(
        networkRestored: connectivity.networkRestored,
      );
    } catch (error, stackTrace) {
      SanitizedLogger.instance.error(
        'AppRuntime',
        'Failed to initialize accounts, connection pool or first sync',
        error,
        stackTrace,
      );
    }
  }());

  ref.onDispose(() {
    lifecycle.stop();
    unawaited(connectivity.dispose());
    unawaited(syncCoordinator.dispose());
    unawaited(bootstrap.dispose());
    unawaited(outboxQueue.dispose());
  });

  return AppRuntime(
    lifecycleManager: lifecycle,
    connectivityMonitor: connectivity,
    inboxSyncCoordinator: syncCoordinator,
    accountSyncBootstrap: bootstrap,
    outboxQueue: outboxQueue,
  );
}
