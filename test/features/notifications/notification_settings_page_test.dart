import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/features/notifications/data/battery_notification_platform.dart';
import 'package:local_mail_client/features/notifications/domain/battery_notification_settings.dart';
import 'package:local_mail_client/features/notifications/presentation/notification_settings_page.dart';

Map<String, dynamic> _settings({
  int interval = 30,
  bool permission = true,
  bool appEnabled = true,
  bool channel = true,
  bool canRequest = false,
}) {
  return {
    'intervalMinutes': interval,
    'permissionGranted': permission,
    'appNotificationsEnabled': appEnabled,
    'channelEnabled': channel,
    'canRequestPermission': canRequest,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BatteryNotificationSettings parsing', () {
    test('defaults to 30 minutes for missing or corrupt values', () {
      expect(
        BatteryNotificationSettings.fromMap(null).interval,
        BatteryNotificationInterval.thirty,
      );
      expect(
        BatteryNotificationSettings.fromMap({'intervalMinutes': 17}).interval,
        BatteryNotificationInterval.thirty,
      );
    });

    test('accepts off/15/30/60 and reports recovery state', () {
      expect(
        BatteryNotificationSettings.fromMap({'intervalMinutes': 0}).interval,
        BatteryNotificationInterval.off,
      );
      expect(
        BatteryNotificationSettings.fromMap({'intervalMinutes': 60}).interval,
        BatteryNotificationInterval.sixty,
      );
      final broken = BatteryNotificationSettings.fromMap(
        _settings(permission: false, channel: false),
      );
      expect(broken.notificationsUsable, isFalse);
      expect(broken.needsSystemSettings, isTrue);
    });
  });

  group('NotificationSettingsPage', () {
    late List<MethodCall> calls;
    late Map<String, dynamic> current;
    var failLoads = 0;

    setUp(() {
      calls = <MethodCall>[];
      current = _settings();
      failLoads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(BatteryNotificationPlatform.channel, (
            call,
          ) async {
            calls.add(call);
            switch (call.method) {
              case 'getSettings':
                if (failLoads > 0) {
                  failLoads--;
                  throw PlatformException(code: 'load_failed');
                }
                return current;
              case 'setIntervalMinutes':
                final minutes = (call.arguments as Map)['minutes'] as int;
                current = _settings(interval: minutes);
                return current;
              case 'requestNotificationPermission':
                current = _settings(permission: true);
                return current;
              case 'openNotificationSettings':
                return null;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(BatteryNotificationPlatform.channel, null);
    });

    Future<void> asAndroid(Future<void> Function() body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const NotificationSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('off/15/30/60 options persist and explain OS delay', (
      tester,
    ) async {
      await asAndroid(() async {
        await pumpPage(tester);

        expect(find.text('每 15 分钟'), findsOneWidget);
        expect(find.text('每 30 分钟'), findsOneWidget);
        expect(find.text('每 60 分钟'), findsOneWidget);
        expect(find.textContaining('可能延迟'), findsOneWidget);

        await tester.tap(find.byKey(const Key('notification-interval-0')));
        await tester.pumpAndSettle();

        final saved = calls.where(
          (call) => call.method == 'setIntervalMinutes',
        );
        expect(saved, isNotEmpty);
        expect((saved.last.arguments as Map)['minutes'], 0);
      });
    });

    testWidgets('permission denied shows request and system recovery entry', (
      tester,
    ) async {
      await asAndroid(() async {
        current = _settings(permission: false, canRequest: true);
        await pumpPage(tester);

        final request = find.byKey(
          const Key('notification-request-permission'),
        );
        await tester.scrollUntilVisible(
          request,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('通知权限未开启'), findsOneWidget);
        expect(request, findsOneWidget);
        expect(
          find.byKey(const Key('notification-open-system-settings')),
          findsOneWidget,
        );

        await tester.ensureVisible(request);
        await tester.pumpAndSettle();
        await tester.tap(request);
        await tester.pumpAndSettle();
        expect(
          calls.any((call) => call.method == 'requestNotificationPermission'),
          isTrue,
        );
      });
    });

    testWidgets('system channel off shows recovery without permission button', (
      tester,
    ) async {
      await asAndroid(() async {
        current = _settings(channel: false);
        await pumpPage(tester);

        final openSettings = find.byKey(
          const Key('notification-open-system-settings'),
        );
        await tester.scrollUntilVisible(
          openSettings,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('系统通知已关闭'), findsOneWidget);
        expect(
          find.byKey(const Key('notification-request-permission')),
          findsNothing,
        );

        await tester.ensureVisible(openSettings);
        await tester.pumpAndSettle();
        await tester.tap(openSettings);
        await tester.pumpAndSettle();
        expect(
          calls.any((call) => call.method == 'openNotificationSettings'),
          isTrue,
        );
      });
    });

    testWidgets('initial load failure shows a visible retry action', (
      tester,
    ) async {
      await asAndroid(() async {
        failLoads = 1;
        await pumpPage(tester);

        expect(find.text('读取通知设置失败，请重试。'), findsOneWidget);
        final retry = find.byKey(const Key('notification-retry-load'));
        expect(retry, findsOneWidget);

        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(find.text('每 30 分钟'), findsOneWidget);
        expect(find.byKey(const Key('notification-retry-load')), findsNothing);
      });
    });

    testWidgets('off selection does not claim background checks still run', (
      tester,
    ) async {
      await asAndroid(() async {
        current = _settings(interval: 0);
        await pumpPage(tester);
        expect(find.textContaining('后台检查已关闭'), findsWidgets);
        expect(find.textContaining('后台检查会按系统调度运行'), findsNothing);
      });
    });
  });
}
