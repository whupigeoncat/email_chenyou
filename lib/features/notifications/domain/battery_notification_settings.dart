import 'package:flutter/foundation.dart';

/// User-selectable background check cadence.
///
/// The OS may delay any of these; the UI must never promise an exact time.
enum BatteryNotificationInterval {
  off(0, '关闭'),
  fifteen(15, '每 15 分钟'),
  thirty(30, '每 30 分钟'),
  sixty(60, '每 60 分钟');

  const BatteryNotificationInterval(this.minutes, this.label);

  final int minutes;
  final String label;

  static BatteryNotificationInterval fromMinutes(int? value) {
    return BatteryNotificationInterval.values.firstWhere(
      (interval) => interval.minutes == value,
      orElse: () => BatteryNotificationInterval.thirty,
    );
  }
}

@immutable
class BatteryNotificationSettings {
  const BatteryNotificationSettings({
    this.interval = BatteryNotificationInterval.thirty,
    this.permissionGranted = true,
    this.appNotificationsEnabled = true,
    this.channelEnabled = true,
    this.canRequestPermission = false,
  });

  final BatteryNotificationInterval interval;

  /// Android 13+ runtime permission. True on older Android versions.
  final bool permissionGranted;

  /// System-level app notification switch.
  final bool appNotificationsEnabled;

  /// The `new_mail` channel has not been blocked by the system.
  final bool channelEnabled;

  /// Whether the UI may show the runtime permission request button.
  final bool canRequestPermission;

  bool get enabled => interval != BatteryNotificationInterval.off;

  bool get notificationsUsable =>
      permissionGranted && appNotificationsEnabled && channelEnabled;

  /// True when the user must visit Android settings to recover notifications.
  bool get needsSystemSettings => !appNotificationsEnabled || !channelEnabled;

  BatteryNotificationSettings copyWith({
    BatteryNotificationInterval? interval,
    bool? permissionGranted,
    bool? appNotificationsEnabled,
    bool? channelEnabled,
    bool? canRequestPermission,
  }) {
    return BatteryNotificationSettings(
      interval: interval ?? this.interval,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      appNotificationsEnabled:
          appNotificationsEnabled ?? this.appNotificationsEnabled,
      channelEnabled: channelEnabled ?? this.channelEnabled,
      canRequestPermission: canRequestPermission ?? this.canRequestPermission,
    );
  }

  factory BatteryNotificationSettings.fromMap(Map<String, dynamic>? map) {
    return BatteryNotificationSettings(
      interval: BatteryNotificationInterval.fromMinutes(
        (map?['intervalMinutes'] as num?)?.toInt(),
      ),
      permissionGranted: (map?['permissionGranted'] as bool?) ?? true,
      appNotificationsEnabled:
          (map?['appNotificationsEnabled'] as bool?) ?? true,
      channelEnabled: (map?['channelEnabled'] as bool?) ?? true,
      canRequestPermission: (map?['canRequestPermission'] as bool?) ?? false,
    );
  }
}
