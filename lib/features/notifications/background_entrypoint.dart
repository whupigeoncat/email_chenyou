import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/database/app_database.dart';
import '../../core/security/oauth_pkce_service.dart';
import '../../core/security/secure_storage_service.dart';
import '../../core/logging/sanitized_logger.dart';
import '../auth/data/account_credential_resolver.dart';
import '../mail/data/datasources/enough_mail_imap_session.dart';
import 'data/background_mail_checker.dart';
import 'data/battery_notification_platform.dart';
import 'data/inbox_notification_state_store.dart';

/// Headless entrypoint used by [BackgroundMailJobService].
///
/// Keep this dependency graph deliberately small: DB + secure storage + one
/// short-lived IMAP session per account. No AppRuntime, ConnectionPool, IDLE or
/// outbox queue may be imported here.
@pragma('vm:entry-point')
Future<void> backgroundMailMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = BatteryNotificationPlatform.instance;
  platform.initialize();

  AppDatabase? database;
  try {
    final settings = await platform.loadSettings();
    if (!settings.enabled || !settings.notificationsUsable) return;
    database = AppDatabase();
    final credentialResolver = AccountCredentialResolver(
      secureStorage: SecureStorageService(),
      oauthPkceService: OAuthPkceService(),
    );
    final checker = BackgroundMailChecker(
      database: database,
      stateStore: InboxNotificationStateStore(database: database),
      sessionFactory: EnoughMailImapSessionFactory(),
      credentialResolver: credentialResolver.call,
      notify: (count) => platform.showSummaryNotification(count),
      isCancelled: () => platform.isCancelled(),
    );
    final report = await checker.run();
    SanitizedLogger.instance.info(
      'BackgroundMail',
      'check completed: accounts=${report.accountsSeen}, '
          'skipped=${report.accountsSkipped}, notified=${report.notifiedMailCount}, '
          'failures=${report.failures}, cancelled=${report.cancelled}, '
          'deadline=${report.deadlineExceeded}',
    );
  } catch (error) {
    SanitizedLogger.instance.warn(
      'BackgroundMail',
      'background check failed',
      error,
    );
  } finally {
    try {
      await database?.close();
    } catch (_) {
      // Process is about to exit.
    }
    try {
      await BatteryNotificationPlatform.channel.invokeMethod<void>(
        'backgroundFinished',
      );
    } catch (_) {
      // Service may have been destroyed by the system.
    }
  }
}
