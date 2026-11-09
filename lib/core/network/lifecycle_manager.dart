// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../logging/sanitized_logger.dart';
import 'connection_pool.dart';

/// Watches [AppLifecycleState] and enforces the mandatory 30-second mobile
/// background LOGOUT rule to protect Gmail / QQ / 163 IMAP connection quotas.
class AppLifecycleManager with WidgetsBindingObserver {
  AppLifecycleManager({
    required ConnectionPool connectionPool,
    Duration backgroundGraceDuration = const Duration(seconds: 30),
    bool? isMobileOverride,
    bool? isIOSOverride,
    Future<void> Function()? beginPlatformBackgroundTask,
    Future<void> Function()? endPlatformBackgroundTask,
    void Function(VoidCallback? handler)? onPlatformBackgroundExpiring,
    SanitizedLogger? logger,
  })  : _connectionPool = connectionPool,
        _backgroundGraceDuration = backgroundGraceDuration,
        _isMobile = isMobileOverride ??
            (!kIsWeb && (Platform.isAndroid || Platform.isIOS)),
        _isIOS = isIOSOverride ?? (!kIsWeb && Platform.isIOS),
        _usesDefaultIosChannel = (isIOSOverride ?? (!kIsWeb && Platform.isIOS)) &&
            beginPlatformBackgroundTask == null &&
            endPlatformBackgroundTask == null &&
            onPlatformBackgroundExpiring == null,
        _logger = logger ?? SanitizedLogger.instance {
    if (_isIOS) {
      _beginPlatformBackgroundTask =
          beginPlatformBackgroundTask ??
              (_usesDefaultIosChannel ? _beginIosBackgroundTask : null);
      _endPlatformBackgroundTask =
          endPlatformBackgroundTask ??
              (_usesDefaultIosChannel ? _endIosBackgroundTask : null);
      _onPlatformBackgroundExpiring = onPlatformBackgroundExpiring;
    } else {
      _beginPlatformBackgroundTask = null;
      _endPlatformBackgroundTask = null;
      _onPlatformBackgroundExpiring = null;
    }
  }

  static const MethodChannel _backgroundChannel =
      MethodChannel('com.localmail.client/background_task');

  final ConnectionPool _connectionPool;
  final Duration _backgroundGraceDuration;
  final bool _isMobile;
  final bool _isIOS;
  final bool _usesDefaultIosChannel;
  final SanitizedLogger _logger;

  late final Future<void> Function()? _beginPlatformBackgroundTask;
  late final Future<void> Function()? _endPlatformBackgroundTask;
  late final void Function(VoidCallback? handler)?
      _onPlatformBackgroundExpiring;

  Timer? _backgroundLogoutTimer;
  Future<void>? _releaseFuture;
  bool _attached = false;
  bool _isInBackground = false;
  bool _platformTaskActive = false;
  bool _expirationHandlerRegistered = false;

  bool get isGraceTimerActive => _backgroundLogoutTimer?.isActive ?? false;
  bool get isInBackground => _isInBackground;
  bool get hasPlatformBackgroundTask => _platformTaskActive;

  void start() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
    if (_isIOS && !_expirationHandlerRegistered) {
      final injected = _onPlatformBackgroundExpiring;
      if (injected != null) {
        injected(_handlePlatformExpiration);
      } else if (_usesDefaultIosChannel) {
        _backgroundChannel.setMethodCallHandler(_handlePlatformCall);
      }
      _expirationHandlerRegistered = true;
    }
  }

  void stop() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
    _backgroundLogoutTimer?.cancel();
    _backgroundLogoutTimer = null;
    if (_usesDefaultIosChannel) {
      _backgroundChannel.setMethodCallHandler(null);
    }
    _expirationHandlerRegistered = false;
    unawaited(_endPlatformTask());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (_isMobile) {
          _onMobileEnteredBackground(state);
        }
      case AppLifecycleState.resumed:
        _onReturnedToForeground();
      case AppLifecycleState.detached:
        _onAppDetached();
    }
  }

  void _onMobileEnteredBackground(AppLifecycleState state) {
    _isInBackground = true;
    // Do NOT reset the timer when transitioning inactive -> paused.
    if (_backgroundLogoutTimer?.isActive ?? false) return;
    if (_connectionPool.isBackgroundReleased) return;

    _logger.info(
      'LifecycleManager',
      'Mobile entered ${state.name}; scheduling IMAP LOGOUT in '
          '${_backgroundGraceDuration.inSeconds}s',
    );
    unawaited(_beginPlatformTask());
    _backgroundLogoutTimer = Timer(_backgroundGraceDuration, () {
      _backgroundLogoutTimer = null;
      if (_isInBackground) {
        _logger.info(
          'LifecycleManager',
          'Background grace elapsed; sending LOGOUT on all IMAP slots',
        );
        unawaited(_releaseForBackground());
      }
    });
  }

  void _onReturnedToForeground() {
    _isInBackground = false;
    if (_backgroundLogoutTimer?.isActive ?? false) {
      _logger.info(
        'LifecycleManager',
        'Returned to foreground within ${_backgroundGraceDuration.inSeconds}s; '
            'cancelled scheduled LOGOUT',
      );
    }
    _backgroundLogoutTimer?.cancel();
    _backgroundLogoutTimer = null;

    // Releasing the iOS task is idempotent and must happen even when the
    // pipeline was already released by the 30s deadline.
    unawaited(_endPlatformTask());

    if (_connectionPool.isBackgroundReleased) {
      unawaited(_connectionPool.reconnectAfterForeground());
    }
  }

  void _onAppDetached() {
    _backgroundLogoutTimer?.cancel();
    _backgroundLogoutTimer = null;
    unawaited(_releaseForBackground());
  }

  Future<void> _releaseForBackground() {
    final existing = _releaseFuture;
    if (existing != null) return existing;
    final future = () async {
      try {
        await _connectionPool.releaseAllForBackground();
      } catch (error, stackTrace) {
        _logger.error(
          'LifecycleManager',
          'releaseAllForBackground failed',
          error,
          stackTrace,
        );
      } finally {
        await _endPlatformTask();
      }
    }();
    _releaseFuture = future;
    return future.whenComplete(() {
      if (identical(_releaseFuture, future)) _releaseFuture = null;
    });
  }

  void _handlePlatformExpiration() {
    if (!_isInBackground) {
      unawaited(_endPlatformTask());
      return;
    }
    _backgroundLogoutTimer?.cancel();
    _backgroundLogoutTimer = null;
    _logger.warn(
      'LifecycleManager',
      'iOS background task expiring early; releasing all IMAP sockets now',
    );
    unawaited(_releaseForBackground());
  }

  Future<void> _handlePlatformCall(MethodCall call) async {
    if (call.method == 'onBackgroundTaskExpiring') {
      _handlePlatformExpiration();
    }
  }

  Future<void> _beginPlatformTask() async {
    if (_beginPlatformBackgroundTask == null &&
        _endPlatformBackgroundTask == null) {
      return;
    }
    if (_platformTaskActive) return;
    _platformTaskActive = true;
    try {
      await _beginPlatformBackgroundTask?.call();
    } catch (error) {
      _platformTaskActive = false;
      _logger.warn(
        'LifecycleManager',
        'Failed to begin iOS background task',
        error,
      );
    }
  }

  Future<void> _endPlatformTask() async {
    if (!_platformTaskActive) return;
    _platformTaskActive = false;
    try {
      await _endPlatformBackgroundTask?.call();
    } catch (error) {
      _logger.warn(
        'LifecycleManager',
        'Failed to end iOS background task',
        error,
      );
    }
  }

  static Future<void> _beginIosBackgroundTask() async {
    await _backgroundChannel.invokeMethod<void>('beginBackgroundTask');
  }

  static Future<void> _endIosBackgroundTask() async {
    await _backgroundChannel.invokeMethod<void>('endBackgroundTask');
  }
}
