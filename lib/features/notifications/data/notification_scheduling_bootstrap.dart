import 'dart:async';

import '../../../core/logging/sanitized_logger.dart';
import '../../auth/domain/entities/mail_account.dart';

/// Keeps native notification scheduling in sync with enabled accounts.
///
/// Every platform call is optional: a failing notification channel must never
/// abort repository initialization, the initial sync, or the outbox queue.
class NotificationSchedulingBootstrap {
  NotificationSchedulingBootstrap({
    required this.getAccounts,
    required this.watchAccounts,
    required this.setHasEnabledAccounts,
    required this.cancelNotifications,
    SanitizedLogger? logger,
  }) : _logger = logger ?? SanitizedLogger.instance;

  final Future<List<MailAccount>> Function() getAccounts;
  final Stream<List<MailAccount>> Function() watchAccounts;
  final Future<void> Function(bool value) setHasEnabledAccounts;
  final Future<void> Function() cancelNotifications;
  final SanitizedLogger _logger;

  StreamSubscription<List<MailAccount>>? _subscription;

  Future<void> start() async {
    try {
      final accounts = await getAccounts();
      await setHasEnabledAccounts(accounts.any((account) => account.isEnabled));
      _subscription = watchAccounts().listen(
        (accounts) => unawaited(_update(accounts)),
        onError: (Object error, StackTrace stack) {
          _logger.warn(
            'NotificationScheduling',
            'Account stream failed',
            error,
          );
        },
      );
    } catch (error) {
      _logger.warn(
        'NotificationScheduling',
        'Initial scheduling failed; mail flow continues',
        error,
      );
    }
  }

  Future<void> _update(List<MailAccount> accounts) async {
    try {
      await setHasEnabledAccounts(accounts.any((account) => account.isEnabled));
    } catch (error) {
      _logger.warn(
        'NotificationScheduling',
        'Scheduling update failed; mail flow continues',
        error,
      );
    }
    try {
      await cancelNotifications();
    } catch (error) {
      _logger.warn(
        'NotificationScheduling',
        'Notification cancel failed; mail flow continues',
        error,
      );
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
