// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math';

import '../logging/sanitized_logger.dart';
import '../../features/auth/domain/entities/mail_account.dart';
import 'account_connection_slot.dart';
import 'imap_session.dart';

class AccountInboxNotification {
  const AccountInboxNotification({
    required this.accountId,
    required this.event,
  });

  final String accountId;
  final ImapInboxEvent event;
}

/// Manages per-account [AccountConnectionSlot] instances across the entire app.
///
/// Guarantees:
/// 1. At most 1 persistent INBOX IDLE connection per account.
/// 2. Serialized transient short connections for non-INBOX folders with instant LOGOUT.
/// 3. Clean bulk LOGOUT release on mobile background > 30s or app termination.
class ConnectionPool {
  ConnectionPool({
    required ImapSessionFactory sessionFactory,
    required CredentialResolver credentialResolver,
    SanitizedLogger? logger,
  })  : _sessionFactory = sessionFactory,
        _credentialResolver = credentialResolver,
        _logger = logger ?? SanitizedLogger.instance;

  final ImapSessionFactory _sessionFactory;
  final CredentialResolver _credentialResolver;
  final SanitizedLogger _logger;

  final Map<String, AccountConnectionSlot> _slots = {};

  final StreamController<AccountInboxNotification> _inboxEventController =
      StreamController<AccountInboxNotification>.broadcast();
  final StreamController<Map<String, ConnectionSlotState>> _statesController =
      StreamController<Map<String, ConnectionSlotState>>.broadcast();
  final StreamController<List<String>> _reconnectedController =
      StreamController<List<String>>.broadcast();

  Stream<AccountInboxNotification> get inboxEvents =>
      _inboxEventController.stream;

  Stream<Map<String, ConnectionSlotState>> get slotStates =>
      _statesController.stream;

  /// Fires with reconnected account IDs when returning from background release.
  Stream<List<String>> get reconnectedAccounts => _reconnectedController.stream;

  bool _isBackgroundReleased = false;
  bool get isBackgroundReleased => _isBackgroundReleased;

  /// Non-null while [releaseAllForBackground] is still closing sockets. A fast
  /// foreground resume must wait for it, otherwise new IDLE sockets could race
  /// with the old LOGOUT teardown.
  Future<void>? _releaseOperation;

  Map<String, ConnectionSlotState> get currentStates => {
        for (final entry in _slots.entries) entry.key: entry.value.state,
      };

  AccountConnectionSlot? slotFor(String accountId) => _slots[accountId];

  /// Registers or updates accounts managed by the pool and initiates INBOX IDLE
  /// for newly added active accounts (unless currently suspended in background).
  Future<void> syncAccounts(List<MailAccount> accounts) async {
    final incomingIds = accounts.map((a) => a.id).toSet();

    // Dispose removed accounts
    final removedIds =
        _slots.keys.where((id) => !incomingIds.contains(id)).toList();
    for (final id in removedIds) {
      final slot = _slots.remove(id);
      await slot?.dispose();
    }

    // Add or update accounts
    for (final account in accounts) {
      final existing = _slots[account.id];
      if (existing != null) {
        existing.updateAccount(account);
        if (!account.isEnabled) {
          await existing.releaseForBackground(markReleased: false);
        } else if (!_isBackgroundReleased &&
            existing.state == ConnectionSlotState.disconnected) {
          unawaited(existing.ensureInboxIdle());
        }
      } else {
        final slot = AccountConnectionSlot(
          account: account,
          sessionFactory: _sessionFactory,
          credentialResolver: _credentialResolver,
          onInboxEvent: (accountId, event) {
            if (!_inboxEventController.isClosed) {
              _inboxEventController.add(
                AccountInboxNotification(accountId: accountId, event: event),
              );
            }
          },
          onStateChanged: (_, _) => _emitStates(),
          logger: _logger,
        );
        _slots[account.id] = slot;
        if (account.isEnabled && !_isBackgroundReleased) {
          unawaited(slot.ensureInboxIdle());
        }
      }
    }
    _emitStates();
  }

  /// Ensures INBOX IDLE for a specific account (e.g., right after onboarding).
  Future<void> connectAccount(String accountId) async {
    final slot = _slots[accountId];
    if (slot == null) return;
    await slot.ensureInboxIdle(forceFromBackground: !_isBackgroundReleased);
  }

  /// Runs an IMAP action on INBOX by pausing & reusing the single IDLE socket.
  Future<T> runOnInbox<T>(
    String accountId,
    Future<T> Function(ImapSession session) action,
  ) {
    final slot = _slots[accountId];
    if (slot == null) {
      return Future.error(StateError('Unknown account $accountId'));
    }
    return slot.runOnInbox(action);
  }

  /// Runs an on-demand action on a non-INBOX folder and immediately LOGOUTs.
  Future<T> runTransientFolderTask<T>({
    required String accountId,
    required String remoteFolderName,
    required Future<T> Function(ImapSession session) action,
  }) {
    final slot = _slots[accountId];
    if (slot == null) {
      return Future.error(StateError('Unknown account $accountId'));
    }
    return slot.runTransientFolderTask(
      folderPath: remoteFolderName,
      action: action,
    );
  }

  /// Actively sends LOGOUT across ALL accounts when mobile stays in background
  /// past 30 seconds or when app terminates.
  Future<void> releaseAllForBackground() {
    _isBackgroundReleased = true;
    final inFlight = _releaseOperation;
    if (inFlight != null) return inFlight;

    final operation = _performReleaseAll();
    _releaseOperation = operation;
    return operation;
  }

  Future<void> _performReleaseAll() async {
    _logger.info(
      'ConnectionPool',
      'Releasing all ${_slots.length} account connections via LOGOUT',
    );
    try {
      await Future.wait(
        _slots.values.map((s) => s.releaseForBackground(markReleased: true)),
      );
      _emitStates();
    } catch (e, st) {
      _logger.error(
        'ConnectionPool',
        'Failed to release all account connections',
        e,
        st,
      );
    } finally {
      _releaseOperation = null;
    }
  }

  /// Re-establishes single INBOX IDLE connections with slight per-account
  /// stagger upon returning to foreground. If a background release is still
  /// running, wait for LOGOUT to finish first.
  Future<void> reconnectAfterForeground() async {
    final pendingRelease = _releaseOperation;
    if (pendingRelease != null) {
      await pendingRelease;
    }

    final wasReleased = _isBackgroundReleased;
    _isBackgroundReleased = false;
    if (!wasReleased) return;

    final enabledSlots = _slots.values.where((s) => s.account.isEnabled).toList();
    if (enabledSlots.isEmpty) return;

    _logger.info(
      'ConnectionPool',
      'Reconnecting ${enabledSlots.length} accounts on foreground resume',
    );

    final rng = Random();
    await Future.wait([
      for (var i = 0; i < enabledSlots.length; i++)
        Future<void>.delayed(
          Duration(milliseconds: i * 120 + rng.nextInt(150)),
          () => enabledSlots[i].reconnectFromForeground(),
        ),
    ]);

    if (!_reconnectedController.isClosed) {
      _reconnectedController.add(
        enabledSlots.map((s) => s.account.id).toList(growable: false),
      );
    }
    _emitStates();
  }

  Future<void> handleNetworkRestored() async {
    if (_isBackgroundReleased) return;
    _logger.info('ConnectionPool', 'Network restored, refreshing IDLE slots');
    await Future.wait(
      _slots.values.map((s) => s.handleNetworkRestored()),
    );
  }

  Future<void> dispose() async {
    for (final slot in _slots.values) {
      await slot.dispose();
    }
    _slots.clear();
    await _inboxEventController.close();
    await _statesController.close();
    await _reconnectedController.close();
  }

  void _emitStates() {
    if (!_statesController.isClosed) {
      _statesController.add(currentStates);
    }
  }
}
