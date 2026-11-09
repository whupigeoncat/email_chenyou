import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/app.dart';
import 'package:local_mail_client/app/di/app_runtime_providers.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/network/account_connection_slot.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';
import 'features/mail/support/test_runtime.dart';


void main() {
  testWidgets('LocalMailApp mounts the mail shell and empty-account guide',
      (WidgetTester tester) async {
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimeProvider.overrideWithValue(harness.runtime),
          outboxCountsProvider.overrideWith(
            (ref) => Stream<OutboxCounts>.value(const OutboxCounts()),
          ),
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value(const <MailAccount>[]),
          ),
          accountSlotStatesProvider.overrideWith(
            (ref) => Stream<Map<String, ConnectionSlotState>>.value(
              const <String, ConnectionSlotState>{},
            ),
          ),
        ],
        child: const LocalMailApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本地邮箱'), findsOneWidget);
    expect(find.text('还没有绑定邮箱账户'), findsOneWidget);
    expect(find.byKey(const Key('empty-add-account')), findsOneWidget);
  });
}
