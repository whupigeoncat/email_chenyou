import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../logging/sanitized_logger.dart';
import 'connection_pool.dart';

/// Watches OS network reachability changes and triggers debounced IDLE recovery.
///
/// Only two transitions are actionable:
/// 1. The device was offline and connectivity came back.
/// 2. The set of online interface types genuinely changed while online.
///
/// The very first event emitted after startup is treated as a baseline, because
/// the connection pool is already opening IDLE sockets at that moment. Acting on
/// it would tear down freshly created sockets for no reason.
class ConnectivityMonitor {
  ConnectivityMonitor({
    required this._connectionPool,
    Connectivity? connectivity,
    Stream<List<ConnectivityResult>>? connectivityStream,
    SanitizedLogger? logger,
  })  : _connectivityStream =
            connectivityStream ?? (connectivity ?? Connectivity()).onConnectivityChanged,
        _logger = logger ?? SanitizedLogger.instance;

  final ConnectionPool _connectionPool;
  final Stream<List<ConnectivityResult>> _connectivityStream;
  final SanitizedLogger _logger;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounce;
  final StreamController<void> _networkRestoredController =
      StreamController<void>.broadcast();

  /// Fires after a genuine offline -> online transition or interface change.
  Stream<void> get networkRestored => _networkRestoredController.stream;

  bool _initialized = false;
  bool _hadConnectivity = true;
  Set<ConnectivityResult>? _onlineTypes;

  void start() {
    if (_sub != null) return;
    _sub = _connectivityStream.listen(
      _handleResults,
      onError: (Object error, StackTrace stack) {
        _logger.warn('Connectivity', 'Connectivity stream error', error);
      },
    );
  }

  void _handleResults(List<ConnectivityResult> results) {
    final onlineTypes = results
        .where((result) => result != ConnectivityResult.none)
        .toSet();
    final hasNetwork = onlineTypes.isNotEmpty;

    // Baseline sample: record the state but never rebuild connections. Startup
    // connection establishment is owned by ConnectionPool.syncAccounts().
    if (!_initialized) {
      _initialized = true;
      _hadConnectivity = hasNetwork;
      _onlineTypes = hasNetwork ? onlineTypes : null;
      _logger.debug(
        'Connectivity',
        'Initial network state: ${hasNetwork ? onlineTypes : "offline"}',
      );
      return;
    }

    if (!hasNetwork) {
      final wasOnline = _hadConnectivity;
      _hadConnectivity = false;
      _onlineTypes = null;
      // A pending "network changed" recovery must not run while offline.
      _debounce?.cancel();
      _debounce = null;
      if (wasOnline) {
        _logger.info('Connectivity', 'Device went offline');
      }
      return;
    }

    final restored = !_hadConnectivity;
    final previousTypes = _onlineTypes;
    final typeChanged =
        previousTypes != null && !_sameTypes(previousTypes, onlineTypes);

    _hadConnectivity = true;
    _onlineTypes = onlineTypes;

    if (!restored && !typeChanged) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), () {
      _debounce = null;
      _logger.info(
        'Connectivity',
        restored
            ? 'Network restored: $onlineTypes'
            : 'Network type changed: $previousTypes -> $onlineTypes',
      );
      if (!_networkRestoredController.isClosed) {
        _networkRestoredController.add(null);
      }
      unawaited(_recoverIdleConnections());
    });
  }

  Future<void> _recoverIdleConnections() async {
    try {
      await _connectionPool.handleNetworkRestored();
    } catch (e) {
      _logger.warn('Connectivity', 'IDLE recovery after network change failed', e);
    }
  }

  static bool _sameTypes(
    Set<ConnectivityResult> a,
    Set<ConnectivityResult> b,
  ) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    _debounce = null;
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
    _hadConnectivity = true;
    _onlineTypes = null;
    if (!_networkRestoredController.isClosed) {
      await _networkRestoredController.close();
    }
  }
}
