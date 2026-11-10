import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/features/notifications/data/battery_notification_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BatteryNotificationPlatform.channel, null);
  });

  test(
    'native busy/timeout fails closed and does not run credential work',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(BatteryNotificationPlatform.channel, (
            call,
          ) async {
            if (call.method == 'acquireForegroundLease') {
              throw PlatformException(code: 'background_busy');
            }
            return null;
          });
      var ran = false;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await expectLater(
          BatteryNotificationPlatform.instance.withForegroundLease(() async {
            ran = true;
          }),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'background_busy',
            ),
          ),
        );
        expect(ran, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test('missing native plugin keeps non-Android/test harness usable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BatteryNotificationPlatform.channel, (
          call,
        ) async {
          if (call.method == 'acquireForegroundLease') {
            throw MissingPluginException();
          }
          return null;
        });
    var ran = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final value = await BatteryNotificationPlatform.instance
          .withForegroundLease(() async {
            ran = true;
            return 42;
          });
      expect(value, 42);
      expect(ran, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
