import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/notifications/background_entrypoint.dart'
    as background_notifications;
import 'features/notifications/data/battery_notification_platform.dart';

/// Native JobService runs this entrypoint in the main library, matching
/// DartExecutor's default library lookup. Keep the forwarding function here.
@pragma('vm:entry-point')
Future<void> backgroundMailMain() =>
    background_notifications.backgroundMailMain();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = BatteryNotificationPlatform.instance;
  notifications.initialize();
  // If a headless check was already running when the user opened the app,
  // wait for its engine to tear down before opening the same database.
  await notifications.waitForBackgroundIdle();
  runApp(const ProviderScope(child: LocalMailApp()));
}
