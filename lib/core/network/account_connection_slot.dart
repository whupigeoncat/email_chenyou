// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math';

import '../logging/sanitized_logger.dart';
import '../../features/auth/domain/entities/mail_account.dart';
import 'imap_session.dart';

enum ConnectionSlotState {
  disconnected,
  connecting,
  idleInInbox,
  pollingInInbox,
  busyInInbox,
  backoffWaiting,
  loggingOut,
  backgroundReleased,
}

/// Enforces the strict per-account connection invariant:
/// - At most ONE persistent connection permanently assigned to INBOX + IDLE.
/// - INBOX commands pause IDLE and reuse that single socket.
/// - Non-INBOX folder polling uses a serialized transient session that
///   MUST immediately send LOGOUT and close upon completion.
class AccountConnectionSlot {
  AccountConnectionSlot({
    required this.account,
    required ImapSessionFactory sessionFactory,
    required CredentialResolver credentialResolver,
    required this.onInboxEvent,
    this.onStateChanged,
    SanitizedLogger? logger,
    Duration? inboxPollIntervalOverride,
  })  : _sessionFactory = sessionFactory,
        _credentialResolver = credentialResolver,
        _logger = logger ?? SanitizedLogger.instance,
        _inboxPollIntervalOverride = inboxPollIntervalOverride;

  MailAccount account;
  final ImapSessionFactory _sessionFactory;
  final CredentialResolver _credentialResolver;
  final void Function(String accountId, ImapInboxEvent event) onInboxEvent;
  final void Function(String accountId, ConnectionSlotState state)? onStateChanged;
  final SanitizedLogger _logger;
  final Duration? _inboxPollIntervalOverride;

  ConnectionSlotState _state = ConnectionSlotState.disconnected;
  ConnectionSlotState get state => _state;

  ImapSession? _persistentInboxSession;
  StreamSubscription<ImapInboxEvent>? _inboxEventSub;
  Timer? _idleRefreshTimer;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  bool _isPollingMode = false;
  bool _forcePolling = false;
  int _lastInboxExists = 0;
  int _lastInboxUnseen = 0;
  DateTime? _lastFlagsReconcileAt;
  int _reconnectAttempt = 0;

  static const Duration _flagsReconcileInterval = Duration(minutes: 5);

  Duration get _inboxPollInterval =>
      _inboxPollIntervalOverride ?? account.preset.inboxPollInterval;

  /// Guards concurrent `ensureInboxIdle` / INBOX command serialization so two
  /// persistent sockets can NEVER be opened for the same account.
  Future<void>? _inboxOpChain;

  /// Transient work shares the same serial queue as persistent INBOX work.
  int _pendingTransientCount = 0;
  bool _restoreInboxAfterTransient = false;
  bool _busyStateFromTransient = false;
  ImapSession? _activeTransientSession;

  bool _releasedForBackground = false;
  bool _disposed = false;

  // Diagnostic counters (useful in tests & connection auditing)
  int persistentConnectCount = 0;
  int transientConnectCount = 0;
  int logoutSentCount = 0;

  int get activePersistentCount =>
      (_persistentInboxSession?.isConnected ?? false) ? 1 : 0;

  int get activeTransientCount =>
      (_activeTransientSession?.isConnected ?? false) ? 1 : 0;

  bool get isBackgroundReleased => _releasedForBackground;

  void updateAccount(MailAccount updated) {
    if (updated.providerType != account.providerType) {
      _forcePolling = false;
    }
    account = updated;
  }

  void _setState(ConnectionSlotState next) {
    if (_state == next) return;
    _state = next;
    onStateChanged?.call(account.id, next);
  }

  /// Ensures the single persistent INBOX IDLE connection is established.
  /// Serialized to prevent duplicate concurrent connection attempts.
  Future<void> ensureInboxIdle({bool forceFromBackground = false}) {
    if (_disposed || !account.isEnabled) return Future<void>.value();
    if (_releasedForBackground && !forceFromBackground) {
      return Future<void>.value();
    }
    return _enqueueInboxOp(
      () => _establishInboxIdleInline(forceFromBackground: forceFromBackground),
    );
  }

  /// Must run inside `_enqueueInboxOp`.
  Future<void> _establishInboxIdleInline({
    bool forceFromBackground = false,
  }) async {
    if (_disposed || !account.isEnabled) return;
    if (_releasedForBackground && !forceFromBackground) return;
    _releasedForBackground = false;

    final existing = _persistentInboxSession;
    if (existing != null && existing.isConnected) {
      if (existing.isIdle) {
        _setState(ConnectionSlotState.idleInInbox);
        return;
      }
      if (_isPollingMode && (!existing.supportsIdle || _forcePolling)) {
        _setState(ConnectionSlotState.pollingInInbox);
        _scheduleInboxPolling();
        return;
      }
    }

    _reconnectTimer?.cancel();
    _setState(ConnectionSlotState.connecting);

    ImapSession? pending;
    try {
      await _teardownPersistentSession(sendLogout: false);

      final credential = await _credentialResolver(account);
      if (_disposed || _releasedForBackground) return;

      pending = _sessionFactory.createSession();
      persistentConnectCount++;

      await pending.connectAndAuthenticate(
        account: account,
        credential: credential,
      );
      if (_disposed || _releasedForBackground) {
        await _discardSession(pending);
        return;
      }

      // SELECT INBOX must happen before attaching the event stream; otherwise
      // the SELECT EXISTS response would be fed back into InboxSyncCoordinator.
      final status = await pending.selectFolderWithStatus('INBOX');
      _lastInboxExists = status.messagesExists;
      _lastInboxUnseen = status.messagesUnseen;
      if (_disposed || _releasedForBackground) {
        await _discardSession(pending);
        return;
      }

      _persistentInboxSession = pending;
      _attachInboxEventStream(pending);
      if (_disposed || _releasedForBackground) {
        await _teardownPersistentSession(sendLogout: false);
        return;
      }

      final canIdle = pending.supportsIdle && !_forcePolling;
      if (canIdle) {
        try {
          await pending.startIdle();
          if (_disposed || _releasedForBackground) {
            await _teardownPersistentSession(sendLogout: false);
            return;
          }
          _isPollingMode = false;
          _reconnectAttempt = 0;
          _scheduleIdleHeartbeat();
          _setState(ConnectionSlotState.idleInInbox);
          _logger.info('ConnSlot:${account.id}', 'INBOX IDLE active');
          _emitInboxReady();
          return;
        } catch (e) {
          _logger.warn(
            'ConnSlot:${account.id}',
            'IDLE start failed; falling back to polling',
            e,
          );
          _forcePolling = true;
          // Never reuse a socket that may still be inside IDLE.
          await _teardownPersistentSession(sendLogout: false);
          await Future<void>.delayed(const Duration(seconds: 2));
          if (!_disposed && !_releasedForBackground) {
            await _establishInboxIdleInline();
          }
          return;
        }
      }

      _isPollingMode = true;
      _reconnectAttempt = 0;
      _lastFlagsReconcileAt = DateTime.now();
      _setState(ConnectionSlotState.pollingInInbox);
      _scheduleInboxPolling();
      _logger.info(
        'ConnSlot:${account.id}',
        'INBOX polling active every ${_inboxPollInterval.inSeconds}s '
        '(IDLE unsupported)',
      );
      _emitInboxReady();
    } catch (e, st) {
      _logger.error(
        'ConnSlot:${account.id}',
        'Failed to establish INBOX IDLE',
        e,
        st,
      );
      await _teardownPersistentSession(sendLogout: false);
      if (pending != null && pending.isConnected) {
        await _discardSession(pending);
      }
      _scheduleReconnect();
    }
  }

  void _emitInboxReady() {
    onInboxEvent(
      account.id,
      ImapMailboxMessagesAdded(existsCount: _lastInboxExists),
    );
  }

  void _scheduleInboxPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_disposed || _releasedForBackground || !account.isEnabled) return;
    _pollTimer = Timer(_inboxPollInterval, () {
      unawaited(_runInboxPoll());
    });
  }

  Future<void> _runInboxPoll() async {
    if (_disposed || _releasedForBackground) return;
    await _enqueueInboxOp(() async {
      if (_disposed || _releasedForBackground) return;
      if (_state != ConnectionSlotState.pollingInInbox) return;

      final session = _persistentInboxSession;
      if (session == null || !session.isConnected) {
        _scheduleReconnect();
        return;
      }

      try {
        final status = await session.selectFolderWithStatus('INBOX');
        final grew = status.messagesExists > _lastInboxExists;
        final flagsChanged = status.messagesUnseen != _lastInboxUnseen;
        _lastInboxExists = status.messagesExists;
        _lastInboxUnseen = status.messagesUnseen;
        final now = DateTime.now();

        if (grew) {
          _lastFlagsReconcileAt = now;
          onInboxEvent(
            account.id,
            ImapMailboxMessagesAdded(existsCount: status.messagesExists),
          );
        } else if (flagsChanged) {
          _lastFlagsReconcileAt = now;
          onInboxEvent(account.id, const ImapMailboxFlagsUpdated());
        } else if (_lastFlagsReconcileAt == null ||
            now.difference(_lastFlagsReconcileAt!) >=
                _flagsReconcileInterval) {
          // 163 can report UNSEEN=0 even after the user reads mail. Periodically
          // ask the coordinator to reconcile recent-window flags on this same
          // persistent session.
          _lastFlagsReconcileAt = now;
          onInboxEvent(account.id, const ImapMailboxFlagsUpdated());
        }
        _scheduleInboxPolling();
      } catch (e) {
        _logger.warn('ConnSlot:${account.id}', 'INBOX poll failed', e);
        await _teardownPersistentSession(sendLogout: false);
        _scheduleReconnect();
      }
    });
  }

  /// Executes an operation on INBOX using the SAME single persistent connection
  /// (pauses IDLE -> runs task -> resumes IDLE). Zero extra sockets opened.
  Future<T> runOnInbox<T>(Future<T> Function(ImapSession session) action) {
    final completer = Completer<T>();
    _enqueueInboxOp(() async {
      if (_disposed) {
        completer.completeError(StateError('Connection slot disposed'));
        return;
      }
      if (_releasedForBackground) {
        completer.completeError(
          StateError('Connection slot released for background'),
        );
        return;
      }

      try {
        if (_persistentInboxSession == null ||
            !_persistentInboxSession!.isConnected) {
          await _establishInboxForCommand();
        }
        if (_disposed || _releasedForBackground) {
          completer.completeError(
            StateError(
              _disposed
                  ? 'Connection slot disposed'
                  : 'Connection slot released for background',
            ),
          );
          return;
        }

        final session = _persistentInboxSession!;
        _pollTimer?.cancel();
        _pollTimer = null;
        _setState(ConnectionSlotState.busyInInbox);
        _idleRefreshTimer?.cancel();
        _idleRefreshTimer = null;

        if (session.isIdle) {
          await session.stopIdle();
        }
        if (session.selectedFolder?.toUpperCase() != 'INBOX') {
          await session.selectFolder('INBOX');
        }

        final result = await action(session);

        if (!_releasedForBackground && !_disposed && session.isConnected) {
          if (_isPollingMode || !session.supportsIdle || _forcePolling) {
            _isPollingMode = true;
            _scheduleInboxPolling();
            _setState(ConnectionSlotState.pollingInInbox);
          } else {
            await session.startIdle();
            _scheduleIdleHeartbeat();
            _setState(ConnectionSlotState.idleInInbox);
          }
        } else if (!_releasedForBackground && !_disposed) {
          await _teardownPersistentSession(sendLogout: false);
          _scheduleReconnect();
        }
        completer.complete(result);
      } catch (e, st) {
        _logger.error('ConnSlot:${account.id}', 'INBOX command error', e, st);
        await _teardownPersistentSession(sendLogout: false);
        if (!_releasedForBackground && !_disposed) {
          _scheduleReconnect();
        }
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Polls or operates on a non-INBOX folder using the same serial queue as
  /// INBOX work. The persistent INBOX IDLE socket is fully LOGOUTed first, at
  /// most one transient socket exists during [action], and INBOX IDLE is
  /// restored before this future completes.
  Future<T> runTransientFolderTask<T>({
    required String folderPath,
    required Future<T> Function(ImapSession session) action,
  }) {
    if (_disposed) {
      return Future<T>.error(StateError('Connection slot disposed'));
    }
    if (_releasedForBackground) {
      return Future<T>.error(
        StateError('Connection slot released for background'),
      );
    }
    if (folderPath.trim().toUpperCase() == 'INBOX') {
      return Future<T>.error(
        StateError('Use runOnInbox for the INBOX folder'),
      );
    }

    final completer = Completer<T>();
    _pendingTransientCount++;
    _enqueueInboxOp(() async {
      if (_disposed || _releasedForBackground) {
        _pendingTransientCount--;
        if (_pendingTransientCount == 0) {
          _restoreInboxAfterTransient = false;
        }
        completer.completeError(
          StateError(
            'Cannot run transient folder task while released or disposed',
          ),
        );
        return;
      }

      final hadPersistentInbox =
          (_persistentInboxSession != null &&
              _persistentInboxSession!.isConnected) ||
          _state == ConnectionSlotState.idleInInbox ||
          _state == ConnectionSlotState.pollingInInbox ||
          (_state == ConnectionSlotState.busyInInbox &&
              !_busyStateFromTransient);
      if (hadPersistentInbox) {
        _restoreInboxAfterTransient = true;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        await _teardownPersistentSession(sendLogout: true);
      }
      _busyStateFromTransient = true;
      _setState(ConnectionSlotState.busyInInbox);

      ImapSession? transient;
      Object? failure;
      StackTrace? failureStack;
      late T result;
      var producedResult = false;

      try {
        transient = _sessionFactory.createSession();
        _activeTransientSession = transient;
        transientConnectCount++;

        final credential = await _credentialResolver(account);
        if (_disposed || _releasedForBackground) {
          throw StateError(
            _disposed
                ? 'Connection slot disposed'
                : 'Connection slot released for background',
          );
        }

        await transient.connectAndAuthenticate(
          account: account,
          credential: credential,
        );
        if (_disposed || _releasedForBackground) {
          throw StateError(
            _disposed
                ? 'Connection slot disposed'
                : 'Connection slot released for background',
          );
        }

        await transient.selectFolder(folderPath);
        if (_disposed || _releasedForBackground) {
          throw StateError(
            _disposed
                ? 'Connection slot disposed'
                : 'Connection slot released for background',
          );
        }

        result = await action(transient);
        producedResult = true;
      } catch (e, st) {
        failure = e;
        failureStack = st;
      } finally {
        final active = transient;
        if (active != null) {
          try {
            if (active.isConnected) {
              await active.logoutAndDisconnect();
              logoutSentCount++;
            }
          } catch (e) {
            _logger.warn(
              'ConnSlot:${account.id}',
              'Transient LOGOUT cleanup warning',
              e,
            );
            try {
              await active.forceClose();
            } catch (_) {
              // Socket is already gone.
            }
          } finally {
            if (identical(_activeTransientSession, active)) {
              _activeTransientSession = null;
            }
          }
        }

        _pendingTransientCount--;
        if (_pendingTransientCount == 0 && _restoreInboxAfterTransient) {
          _restoreInboxAfterTransient = false;
          _busyStateFromTransient = false;
          if (!_disposed && !_releasedForBackground && account.isEnabled) {
            await _establishInboxIdleInline();
          }
        } else if (_pendingTransientCount == 0 &&
            !_restoreInboxAfterTransient &&
            !_disposed &&
            !_releasedForBackground) {
          if (_persistentInboxSession == null ||
              !_persistentInboxSession!.isConnected) {
            _busyStateFromTransient = false;
            _setState(ConnectionSlotState.disconnected);
          }
        }
      }

      if (failure != null) {
        completer.completeError(failure, failureStack);
      } else if (producedResult) {
        completer.complete(result);
      } else {
        completer.completeError(
          StateError('Transient folder task produced no result'),
        );
      }
    });
    return completer.future;
  }

  /// Actively sends LOGOUT on all open sockets for this account (used when
  /// mobile enters background > 30s or app exits).
  ///
  /// Intentionally NOT queued behind `_inboxOpChain`: the 30-second rule is a
  /// hard deadline, so a hung INBOX command must not delay socket teardown.
  /// In-flight operations detect `_releasedForBackground` after each await and
  /// will not install/revive a socket once this flag is set.
  Future<void> releaseForBackground({bool markReleased = true}) async {
    if (markReleased) {
      _releasedForBackground = true;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _idleRefreshTimer?.cancel();
    _idleRefreshTimer = null;
    _restoreInboxAfterTransient = false;
    _busyStateFromTransient = false;
    _isPollingMode = false;

    _setState(ConnectionSlotState.loggingOut);
    await _teardownPersistentSession(sendLogout: true);
    await _releaseActiveTransientSession();

    _setState(
      markReleased
          ? ConnectionSlotState.backgroundReleased
          : ConnectionSlotState.disconnected,
    );
    _logger.info(
      'ConnSlot:${account.id}',
      'Connections released via LOGOUT (background=$markReleased)',
    );
  }

  Future<void> reconnectFromForeground() async {
    _releasedForBackground = false;
    await ensureInboxIdle(forceFromBackground: true);
  }

  Future<void> handleNetworkRestored() async {
    if (_disposed || _releasedForBackground || !account.isEnabled) return;
    _reconnectAttempt = 0;
    await _enqueueInboxOp(() async {
      if (_disposed || _releasedForBackground) return;
      await _teardownPersistentSession(sendLogout: false);
    });
    await ensureInboxIdle();
  }

  Future<void> dispose() async {
    _disposed = true;
    await releaseForBackground(markReleased: false);
  }

  Future<void> _establishInboxForCommand() async {
    await _teardownPersistentSession(sendLogout: false);

    final credential = await _credentialResolver(account);
    if (_disposed || _releasedForBackground) {
      throw StateError(
        _disposed
            ? 'Connection slot disposed'
            : 'Connection slot released for background',
      );
    }

    final session = _sessionFactory.createSession();
    persistentConnectCount++;
    try {
      await session.connectAndAuthenticate(
        account: account,
        credential: credential,
      );
      if (_disposed || _releasedForBackground) {
        throw StateError(
          _disposed
              ? 'Connection slot disposed'
              : 'Connection slot released for background',
        );
      }

      await session.selectFolder('INBOX');
      if (_disposed || _releasedForBackground) {
        throw StateError(
          _disposed
              ? 'Connection slot disposed'
              : 'Connection slot released for background',
        );
      }
    } catch (_) {
      await _discardSession(session);
      rethrow;
    }

    _persistentInboxSession = session;
    _attachInboxEventStream(session);
  }

  /// Single source of truth for INBOX event-stream error handling. Both the
  /// IDLE bootstrap path and the command-driven bootstrap path use this.
  void _attachInboxEventStream(ImapSession session) {
    unawaited(_inboxEventSub?.cancel());
    _inboxEventSub = session.events.listen(
      (event) {
        if (event is ImapConnectionDropped) {
          _logger.warn(
            'ConnSlot:${account.id}',
            'INBOX IDLE dropped: ${event.reason ?? "unknown"}',
          );
          _scheduleReconnect();
        } else if (_isPollingMode && event is! ImapConnectionDropped) {
          // Polling decides real growth from SELECT status; suppress raw events
          // that would otherwise trigger duplicate syncs every cycle.
          return;
        }
        onInboxEvent(account.id, event);
      },
      onError: (Object error, StackTrace stack) {
        _logger.warn('ConnSlot:${account.id}', 'INBOX stream error', error);
        _scheduleReconnect();
      },
      onDone: () {
        if (_disposed || _releasedForBackground) return;
        if (!identical(_persistentInboxSession, session)) return;
        _logger.warn('ConnSlot:${account.id}', 'INBOX event stream closed');
        _scheduleReconnect();
      },
    );
  }

  Future<void> _teardownPersistentSession({required bool sendLogout}) async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _idleRefreshTimer?.cancel();
    _idleRefreshTimer = null;

    // Do NOT await subscription cancellation here: on some platforms the
    // cancellation future is completed outside the current microtask turn and
    // would needlessly delay the mandatory LOGOUT/force-close below. The
    // listener guards on `_persistentInboxSession` so late events are ignored.
    final subscription = _inboxEventSub;
    _inboxEventSub = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    final session = _persistentInboxSession;
    _persistentInboxSession = null;
    if (session == null) return;

    if (sendLogout && session.isConnected) {
      try {
        await session.logoutAndDisconnect();
        logoutSentCount++;
      } catch (_) {
        await session.forceClose();
      }
    } else {
      await session.forceClose();
    }
  }

  Future<void> _releaseActiveTransientSession() async {
    final transient = _activeTransientSession;
    if (transient == null) return;
    if (!transient.isConnected) {
      if (identical(_activeTransientSession, transient)) {
        _activeTransientSession = null;
      }
      return;
    }

    try {
      await transient.logoutAndDisconnect();
      logoutSentCount++;
    } catch (_) {
      try {
        await transient.forceClose();
      } catch (_) {
        // Socket is already gone.
      }
    } finally {
      if (identical(_activeTransientSession, transient)) {
        _activeTransientSession = null;
      }
    }
  }

  /// Closes a socket that never became the installed persistent session.
  Future<void> _discardSession(ImapSession session) async {
    if (!session.isConnected) return;
    try {
      await session.logoutAndDisconnect();
      logoutSentCount++;
    } catch (_) {
      try {
        await session.forceClose();
      } catch (_) {
        // Socket is already gone.
      }
    }
  }

  void _scheduleIdleHeartbeat() {
    _idleRefreshTimer?.cancel();
    final interval = account.preset.idleRefreshInterval;
    _idleRefreshTimer = Timer(interval, () {
      if (_disposed || _releasedForBackground) return;
      _enqueueInboxOp(() async {
        if (_disposed || _releasedForBackground) return;
        final session = _persistentInboxSession;
        if (session == null || !session.isConnected) return;
        try {
          if (session.isIdle) {
            await session.stopIdle();
          }
          await session.noop();
          if (_disposed || _releasedForBackground || !session.isConnected) {
            return;
          }
          await session.startIdle();
          _scheduleIdleHeartbeat();
        } catch (e) {
          _logger.warn('ConnSlot:${account.id}', 'IDLE heartbeat failed', e);
          await _teardownPersistentSession(sendLogout: false);
          _scheduleReconnect();
        }
      });
    });
  }

  void _scheduleReconnect() {
    if (_disposed || _releasedForBackground || !account.isEnabled) return;
    if (_reconnectTimer?.isActive ?? false) return;

    _setState(ConnectionSlotState.backoffWaiting);
    final exp = min(6, _reconnectAttempt);
    final baseSec = pow(2, exp).toInt(); // 1, 2, 4, 8, 16, 32, 64s
    final jitterMs = Random().nextInt(600);
    _reconnectAttempt++;

    _reconnectTimer = Timer(
      Duration(seconds: baseSec, milliseconds: jitterMs),
      () {
        if (!_disposed && !_releasedForBackground) {
          unawaited(ensureInboxIdle());
        }
      },
    );
  }

  Future<void> _enqueueInboxOp(Future<void> Function() task) {
    final prev = _inboxOpChain ?? Future<void>.value();
    final next = prev.catchError((_) {}).then((_) => task());
    _inboxOpChain = next;
    return next;
  }
}
