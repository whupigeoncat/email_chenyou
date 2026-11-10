import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/battery_notification_settings.dart';

/// Bridge to the Android battery-friendly notification scheduler.
///
/// Every method is a no-op on non-Android platforms so the rest of the app can
/// stay platform-neutral. No native class is touched off Android.
class BatteryNotificationPlatform {
  BatteryNotificationPlatform._();

  static final BatteryNotificationPlatform instance =
      BatteryNotificationPlatform._();

  static const MethodChannel channel = MethodChannel(
    'com.localmail.local_mail_client/battery_notifications',
  );

  final StreamController<void> _openInboxController =
      StreamController<void>.broadcast();
  bool _initialized = false;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Requests emitted when a notification tap should show the inbox.
  Stream<void> get openInboxRequests => _openInboxController.stream;

  /// Must be called once on the UI isolate before the app renders.
  void initialize() {
    if (_initialized || !isSupported) return;
    _initialized = true;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'openInbox') {
        _openInboxController.add(null);
      }
      return null;
    });
  }

  Future<BatteryNotificationSettings> loadSettings() async {
    if (!isSupported) return const BatteryNotificationSettings();
    final map = await channel.invokeMapMethod<String, dynamic>('getSettings');
    return BatteryNotificationSettings.fromMap(map);
  }

  /// Changing the interval is the only operation that may reschedule the job.
  Future<BatteryNotificationSettings> setIntervalMinutes(int minutes) async {
    if (!isSupported) return const BatteryNotificationSettings();
    final map = await channel.invokeMapMethod<String, dynamic>(
      'setIntervalMinutes',
      {'minutes': minutes},
    );
    return BatteryNotificationSettings.fromMap(map);
  }

  /// Android 13+ permission request; must only be called from visible UI.
  Future<BatteryNotificationSettings> requestPermission() async {
    if (!isSupported) return const BatteryNotificationSettings();
    final map = await channel.invokeMapMethod<String, dynamic>(
      'requestNotificationPermission',
    );
    return BatteryNotificationSettings.fromMap(map);
  }

  Future<void> openNotificationSettings() async {
    if (!isSupported) return;
    await channel.invokeMethod<void>('openNotificationSettings');
  }

  /// Lets the scheduler avoid a periodic wake when no account is enabled.
  Future<void> setHasEnabledAccounts(bool value) async {
    if (!isSupported) return;
    await channel.invokeMethod<void>('setHasEnabledAccounts', {'value': value});
  }

  Future<void> cancelNotifications() async {
    if (!isSupported) return;
    await channel.invokeMethod<void>('cancelNotifications');
  }

  /// Returns true when the native notification was actually posted.
  Future<bool> showSummaryNotification(int newMailCount) async {
    if (!isSupported) return false;
    final shown = await channel.invokeMethod<bool>('showSummaryNotification', {
      'count': newMailCount,
    });
    return shown ?? false;
  }

  /// Used by the headless runner between accounts to stop quickly.
  Future<bool> isCancelled() async {
    if (!isSupported) return false;
    final cancelled = await channel.invokeMethod<bool>('isCancelled');
    return cancelled ?? false;
  }

  /// Serializes all foreground credential work against the headless checker.
  ///
  /// The native side requests cancellation and waits for a running job (or
  /// destroys its engine after a short bound), so a token refresh can never
  /// race across two Flutter engines.
  Future<void> waitForBackgroundIdle() async {
    if (!isSupported) return;
    try {
      await channel.invokeMethod<void>('waitForBackgroundIdle');
    } catch (_) {
      // Native side is optional for the rest of the app.
    }
  }

  Future<T> withForegroundLease<T>(Future<T> Function() action) async {
    if (!isSupported) return action();
    var acquired = false;
    try {
      final granted = await channel.invokeMethod<bool>(
        'acquireForegroundLease',
      );
      if (granted != true) {
        throw StateError('Foreground lease was not granted.');
      }
      acquired = true;
    } on MissingPluginException {
      // Native bridge is optional (older build/test harness). Keep the mail
      // flow working, but do not silently ignore a native busy/timeout error.
      return action();
    }
    try {
      return await action();
    } finally {
      if (acquired) {
        try {
          await channel.invokeMethod<void>('releaseForegroundLease');
        } catch (_) {
          // Lease is process-local and is reset on the next activity start.
        }
      }
    }
  }

  /// Returns true once if a notification tap arrived before the UI was ready.
  Future<bool> consumePendingInboxOpen() async {
    if (!isSupported) return false;
    final pending = await channel.invokeMethod<bool>('consumePendingInboxOpen');
    return pending ?? false;
  }
}
