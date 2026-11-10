import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/notifications/data/notification_scheduling_bootstrap.dart';

import '../../core/support/fake_imap_session.dart';

MailAccount _account({required bool enabled}) {
  return buildTestAccount().copyWith(isEnabled: enabled);
}

void main() {
  test('throwing notification setup never escapes startup', () async {
    final bootstrap = NotificationSchedulingBootstrap(
      getAccounts: () async => throw StateError('platform channel missing'),
      watchAccounts: () => const Stream<List<MailAccount>>.empty(),
      setHasEnabledAccounts: (_) async {},
      cancelNotifications: () async {},
    );

    await expectLater(bootstrap.start(), completes);
  });

  test('account stream updates scheduling and absorbs cancel errors', () async {
    final controller = StreamController<List<MailAccount>>();
    addTearDown(controller.close);
    final enabledValues = <bool>[];
    var cancelCalls = 0;
    final bootstrap = NotificationSchedulingBootstrap(
      getAccounts: () async => [_account(enabled: true)],
      watchAccounts: () => controller.stream,
      setHasEnabledAccounts: (value) async {
        enabledValues.add(value);
        if (!value) throw StateError('native unavailable');
      },
      cancelNotifications: () async {
        cancelCalls++;
        throw StateError('native unavailable');
      },
    );
    await bootstrap.start();
    expect(enabledValues, [true]);

    controller.add([_account(enabled: false)]);
    await Future<void>.delayed(Duration.zero);

    expect(enabledValues, [true, false]);
    expect(cancelCalls, 1);
    await bootstrap.dispose();
  });
}
