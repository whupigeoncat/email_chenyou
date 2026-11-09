// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../../../../core/logging/sanitized_logger.dart';
import '../../../auth/domain/entities/mail_account.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import 'inbox_sync_coordinator.dart';

/// Seeds the local cache for already-enabled accounts at cold start and syncs
/// newly added/enabled accounts once.
///
/// Syncing is delegated to [InboxSyncCoordinator.syncNow] so a bootstrap pass
/// shares the same per-account running guard as IDLE-triggered synchronization.
/// This prevents the `idleInInbox -> SELECT -> EXISTS -> sync` self-trigger loop.
class AccountSyncBootstrap {
  AccountSyncBootstrap({
    required AuthRepository authRepository,
    required InboxSyncCoordinator syncCoordinator,
    SanitizedLogger? logger,
  })  : _authRepository = authRepository,
        _syncCoordinator = syncCoordinator,
        _logger = logger ?? SanitizedLogger.instance;

  final AuthRepository _authRepository;
  final InboxSyncCoordinator _syncCoordinator;
  final SanitizedLogger _logger;

  final Set<String> _syncedAccountIds = <String>{};
  final Set<String> _inFlight = <String>{};
  StreamSubscription<List<MailAccount>>? _accountSubscription;
  bool _started = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    final accounts = await _authRepository.getAccounts();
    for (final account in accounts) {
      await _syncIfNeeded(account);
    }

    _accountSubscription = _authRepository.watchAccounts().listen(
      (accounts) {
        if (_disposed) return;
        final ids = accounts.map((account) => account.id).toSet();
        final enabledIds = accounts
            .where((account) => account.isEnabled)
            .map((account) => account.id)
            .toSet();
        _syncedAccountIds.removeWhere(
          (id) => !ids.contains(id) || !enabledIds.contains(id),
        );
        for (final account in accounts) {
          unawaited(_syncIfNeeded(account));
        }
      },
      onError: (Object error, StackTrace stack) {
        _logger.warn(
          'AccountSyncBootstrap',
          'Account stream failed; initial sync will not be retried',
          error,
        );
      },
    );
  }

  Future<void> _syncIfNeeded(MailAccount account) async {
    if (_disposed || !account.isEnabled) return;
    if (_syncedAccountIds.contains(account.id) ||
        _inFlight.contains(account.id)) {
      return;
    }

    _inFlight.add(account.id);
    try {
      // A newly inserted account can be observed by the Drift watch stream
      // before AuthRepository has finished seeding the pool slot. Retry a
      // couple of times with a short delay instead of silently losing the
      // first sync.
      for (var attempt = 0; attempt < 3; attempt++) {
        if (_disposed || !account.isEnabled) return;
        try {
          await _syncCoordinator.syncNow(account.id);
          _syncedAccountIds.add(account.id);
          final shortId = account.id.length > 8
              ? account.id.substring(0, 8)
              : account.id;
          _logger.info(
            'AccountSyncBootstrap',
            'Initial sync completed for account $shortId',
          );
          return;
        } catch (error, stackTrace) {
          if (attempt == 2) {
            _logger.warn(
              'AccountSyncBootstrap',
              'Initial sync failed for account ${account.id}',
              error,
            );
            if (stackTrace.toString().isNotEmpty) {
              _logger.debug(
                'AccountSyncBootstrap',
                SanitizedLogger.sanitize(stackTrace.toString()),
              );
            }
            return;
          }
          await Future<void>.delayed(
            Duration(milliseconds: 250 * (attempt + 1)),
          );
        }
      }
    } finally {
      _inFlight.remove(account.id);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _accountSubscription?.cancel();
    _accountSubscription = null;
  }
}
