import 'dart:async';

import '../../../../core/logging/sanitized_logger.dart';
import '../../../../core/network/connection_pool.dart';
import '../../../../core/network/imap_session.dart';

/// Coordinates IDLE push events with periodic synchronization.
///
/// - Events are debounced per account so a burst of EXISTS/FETCH responses
///   triggers a single sync.
/// - A second event for the same account never runs concurrently with the
///   first; it is queued and re-debounced after the active run completes.
/// - `ConnectionPool.reconnectedAccounts` (foreground resume) also schedules a
///   sync so messages received while suspended are picked up.
class InboxSyncCoordinator {
  InboxSyncCoordinator({
    required this._connectionPool,
    required this._syncAccount,
    this._debounce = const Duration(milliseconds: 800),
    SanitizedLogger? logger,
  }) : _logger = logger ?? SanitizedLogger.instance;

  final ConnectionPool _connectionPool;
  final Future<void> Function(String accountId) _syncAccount;
  final Duration _debounce;
  final SanitizedLogger _logger;

  StreamSubscription<AccountInboxNotification>? _eventSubscription;
  StreamSubscription<List<String>>? _reconnectedSubscription;

  final Map<String, Timer> _timers = <String, Timer>{};
  final Set<String> _running = <String>{};
  final Set<String> _pending = <String>{};

  bool _disposed = false;

  void start() {
    if (_disposed || _eventSubscription != null) return;
    _eventSubscription = _connectionPool.inboxEvents.listen(
      (notification) {
        if (notification.event is ImapConnectionDropped) return;
        // A sync pass SELECTs INBOX and can itself emit an EXISTS event. While
        // that pass is active the account is in `_running`; ignoring the
        // self-generated event prevents an idleInInbox -> sync -> idle loop.
        if (_running.contains(notification.accountId)) return;
        _schedule(notification.accountId);
      },
      onError: (Object error, StackTrace stack) {
        _logger.warn('InboxSync', 'IDLE event stream error', error);
      },
    );
    _reconnectedSubscription = _connectionPool.reconnectedAccounts.listen((
      accountIds,
    ) {
      for (final accountId in accountIds) {
        if (_running.contains(accountId)) continue;
        _schedule(accountId);
      }
    });
  }

  /// Runs an account sync immediately through the same serialized runner used
  /// by debounced IDLE events. Used by cold-start and new-account bootstrap.
  Future<void> syncNow(String accountId) =>
      _run(accountId, rethrowErrors: true);

  void _schedule(String accountId) {
    if (_disposed) return;
    _timers[accountId]?.cancel();
    _timers[accountId] = Timer(_debounce, () {
      _timers.remove(accountId);
      unawaited(_run(accountId));
    });
  }

  Future<void> _run(String accountId, {bool rethrowErrors = false}) async {
    if (_disposed) return;
    if (_running.contains(accountId)) {
      _pending.add(accountId);
      return;
    }

    _running.add(accountId);
    try {
      await _syncAccount(accountId);
      final shortId = accountId.length > 8
          ? accountId.substring(0, 8)
          : accountId;
      _logger.info('InboxSync', 'account=$shortId sync completed');
    } catch (error, stackTrace) {
      _logger.error(
        'InboxSync',
        'INBOX sync failed for account $accountId',
        error,
        stackTrace,
      );
      if (rethrowErrors) rethrow;
    } finally {
      _running.remove(accountId);
      if (!_disposed && _pending.remove(accountId)) {
        _schedule(accountId);
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _pending.clear();
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _reconnectedSubscription?.cancel();
    _reconnectedSubscription = null;
  }
}
