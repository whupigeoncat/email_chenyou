import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/app.dart';
import 'package:local_mail_client/app/motion/mail_motion.dart';
import 'package:local_mail_client/app/di/app_runtime_providers.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/network/account_connection_slot.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';

import 'features/mail/support/test_runtime.dart';

Widget _app(TestRuntimeHarness harness) => ProviderScope(
  overrides: [
    appRuntimeProvider.overrideWithValue(harness.runtime),
    outboxCountsProvider.overrideWith(
      (ref) => Stream.value(const OutboxCounts()),
    ),
    accountsProvider.overrideWith((ref) => Stream.value(const <MailAccount>[])),
    accountSlotStatesProvider.overrideWith(
      (ref) => Stream.value(const <String, ConnectionSlotState>{}),
    ),
  ],
  child: const LocalMailApp(),
);

void main() {
  testWidgets('LocalMailApp mounts the mail shell and empty-account guide', (
    WidgetTester tester,
  ) async {
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

  for (final keyboard in [false, true]) {
    testWidgets('app navigation origin respects keyboard=$keyboard', (
      tester,
    ) async {
      final harness = TestRuntimeHarness();
      addTearDown(harness.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(harness));
      await tester.pumpAndSettle();
      const point = Offset(100, 300);
      await tester.tapAt(point);
      if (keyboard) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      }
      Navigator.of(tester.element(find.byKey(const Key('open-search')))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('navigation probe')),
        ),
      );
      await tester.pump();
      await tester.pump();
      final reveal = tester.widget<ClipPath>(
        find.byKey(const ValueKey('mail-liquid-reveal')).last,
      );
      final origin = (reveal.clipper! as MailLiquidClipper).origin;
      if (keyboard) {
        expect(origin, Alignment.center);
      } else {
        expect(origin.x, closeTo(point.dx / 390 * 2 - 1, .01));
        expect(origin.y, closeTo(point.dy / 844 * 2 - 1, .01));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });
  }
}
