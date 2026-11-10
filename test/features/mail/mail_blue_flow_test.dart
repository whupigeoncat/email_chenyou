import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/app_runtime_providers.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/app/theme/mail_theme.dart';
import 'package:local_mail_client/core/network/account_connection_slot.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/presentation/pages/mail_shell_page.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';
import 'package:local_mail_client/features/notifications/data/battery_notification_platform.dart';

import '../auth/support/fakes.dart';
import 'support/mail_fixture.dart';
import 'support/test_runtime.dart';

Widget _app({
  required Brightness brightness,
  double textScale = 1,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: buildMailTheme(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: child!,
    ),
    home: const MailShellPage(),
  );
}

List<Override> _overrides({
  required TestRuntimeHarness harness,
  required MailFixture fixture,
  required FakeAuthRepository auth,
}) {
  return <Override>[
    appRuntimeProvider.overrideWithValue(harness.runtime),
    outboxCountsProvider.overrideWith(
      (ref) => Stream<OutboxCounts>.value(const OutboxCounts()),
    ),
    accountsProvider.overrideWith((ref) => Stream.value([fixture.account])),
    accountSlotStatesProvider.overrideWith(
      (ref) => Stream<Map<String, ConnectionSlotState>>.value(
        const <String, ConnectionSlotState>{},
      ),
    ),
    authRepositoryProvider.overrideWithValue(auth),
    mailLocalRepositoryProvider.overrideWithValue(fixture.localRepository),
  ];
}

Widget _shell(
  List<Override> overrides, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool disableAnimations = false,
}) {
  return ProviderScope(
    overrides: overrides,
    child: _app(
      brightness: brightness,
      textScale: textScale,
      disableAnimations: disableAnimations,
    ),
  );
}

void main() {
  testWidgets('phone first viewport keeps one title and real controls', (
    tester,
  ) async {
    final fixture = await MailFixture.create(flagsBitmask: 1);
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _shell(
        _overrides(harness: harness, fixture: fixture, auth: auth),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open-mail-drawer')), findsOneWidget);
    expect(find.byKey(const Key('open-search')), findsOneWidget);
    expect(find.byKey(const Key('inbox-scope')), findsOneWidget);
    expect(find.byKey(const Key('compose-mail')), findsOneWidget);
    expect(find.byKey(const Key('sync-inbox')), findsOneWidget);
    expect(find.byKey(const Key('inbox-email-list')), findsOneWidget);
    expect(find.byKey(const Key('toggle-unread-filter')), findsOneWidget);

    // The brand, the inbox title and the scope each appear once.
    expect(find.text('本地邮箱'), findsOneWidget);
    expect(find.text('收件箱'), findsOneWidget);
    expect(find.text('所有邮箱'), findsOneWidget);
    expect(find.text('聚合收件箱'), findsNothing);

    expect(
      tester.getSize(find.byKey(const Key('inbox-scope'))).height,
      greaterThanOrEqualTo(48),
      reason: 'scope switcher must remain a 48dp touch target',
    );
    expect(
      tester.getSize(find.byKey(const Key('compose-mail'))).height,
      greaterThanOrEqualTo(48),
    );
    final chrome = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byKey(const Key('mobile-system-ui')),
    );
    expect(chrome.value.statusBarIconBrightness, Brightness.light);
    expect(chrome.value.statusBarBrightness, Brightness.dark);
    expect(
      chrome.value.systemNavigationBarIconBrightness,
      Brightness.dark,
      reason: 'light reading surface uses dark navigation icons',
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('all/unread filter is real and reversible', (tester) async {
    final fixture = await MailFixture.create(flagsBitmask: 1);
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _shell(_overrides(harness: harness, fixture: fixture, auth: auth)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quarterly report'), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle-unread-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Quarterly report'), findsNothing);
    expect(find.text('这里暂时没有邮件'), findsOneWidget);

    await tester.tap(find.byKey(const Key('inbox-filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('Quarterly report'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('large text keeps the whole timestamp and toolbar glyphs', (
    tester,
  ) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _shell(
        _overrides(harness: harness, fixture: fixture, auth: auth),
        textScale: 2,
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();

    final timestamp = find.byKey(
      ValueKey('email-time-${fixture.account.id}-1'),
    );
    expect(timestamp, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(timestamp);
    expect(paragraph.text.toPlainText(), isNotEmpty);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(
      paragraph.size.width + 0.5,
      greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity)),
      reason: 'scaled timestamp must have room for its final digit',
    );

    for (final key in <Key>[
      const Key('open-mail-drawer'),
      const Key('open-search'),
      if (BatteryNotificationPlatform.instance.isSupported)
        const Key('open-notification-settings'),
    ]) {
      final target = find.byKey(key);
      expect(target.hitTestable(), findsOneWidget, reason: '$key missing');
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'compact landscape header leaves a usable list and Back closes drawer',
    (tester) async {
      final fixture = await MailFixture.create();
      addTearDown(fixture.dispose);
      final auth = FakeAuthRepository()..accounts.add(fixture.account);
      addTearDown(auth.dispose);
      final harness = TestRuntimeHarness();
      addTearDown(harness.dispose);
      tester.view.physicalSize = const Size(867, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _shell(
          _overrides(harness: harness, fixture: fixture, auth: auth),
          brightness: Brightness.dark,
          textScale: 2,
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('本地邮箱'), findsNothing);
      expect(find.byKey(const Key('mobile-inbox-title')), findsOneWidget);
      expect(find.byKey(const Key('inbox-scope')), findsNothing);
      expect(find.byKey(const Key('inbox-email-list')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('inbox-email-list'))).height,
        greaterThanOrEqualTo(180),
        reason: 'compact header must leave useful message viewport',
      );

      final menu = find.byKey(const Key('open-mail-drawer'));
      final search = find.byKey(const Key('open-search'));
      expect(menu.hitTestable(), findsOneWidget);
      expect(search.hitTestable(), findsOneWidget);
      expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(search).height, greaterThanOrEqualTo(48));

      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mail-sidebar')), findsOneWidget);
      // Scope remains reachable through the drawer in compact height.
      expect(find.byKey(const Key('unified-inbox-target')), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.byKey(const Key('mail-sidebar')), findsNothing);
      expect(find.byType(MailShellPage), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('wide layout keeps all panes and desktop compose action', (
    tester,
  ) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _shell(_overrides(harness: harness, fixture: fixture, auth: auth)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mail-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('inbox-email-list')), findsOneWidget);
    expect(find.text('选择一封邮件开始阅读'), findsOneWidget);
    expect(find.text('收件箱'), findsOneWidget);
    expect(find.byKey(const Key('compose-mail')), findsOneWidget);
    final headingLeft = tester.getTopLeft(find.text('收件箱')).dx;
    final listLeft = tester
        .getTopLeft(find.byKey(const Key('inbox-email-list')))
        .dx;
    expect(
      headingLeft,
      closeTo(listLeft + 20, 1),
      reason: 'inbox heading must align with the list left inset',
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('phone dark and large text render without overflow', (
    tester,
  ) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cases = <(Size, Brightness, double)>[
      (const Size(390, 844), Brightness.dark, 1),
      (const Size(320, 640), Brightness.light, 2),
      (const Size(390, 844), Brightness.dark, 2),
    ];
    for (final (size, brightness, textScale) in cases) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _shell(
          _overrides(harness: harness, fixture: fixture, auth: auth),
          brightness: brightness,
          textScale: textScale,
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: '$size dark=$brightness textScale=$textScale',
      );
      expect(find.byKey(const Key('inbox-scope')), findsOneWidget);
      expect(find.byKey(const Key('toggle-unread-filter')), findsOneWidget);
      expect(find.byKey(const Key('compose-mail')), findsOneWidget);
      final chrome = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byKey(const Key('mobile-system-ui')),
      );
      expect(chrome.value.statusBarIconBrightness, Brightness.light);
      expect(
        chrome.value.systemNavigationBarIconBrightness,
        brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
