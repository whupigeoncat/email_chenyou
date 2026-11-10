import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/notifications/data/background_mail_checker.dart';
import 'package:local_mail_client/features/notifications/data/battery_notification_platform.dart';
import 'package:local_mail_client/features/notifications/data/inbox_notification_state_store.dart';
import 'package:local_mail_client/features/notifications/presentation/notification_settings_page.dart';

import '../../core/support/fake_imap_session.dart';

Map<String, dynamic> _settings(int interval) => {
  'intervalMinutes': interval,
  'permissionGranted': true,
  'appNotificationsEnabled': true,
  'channelEnabled': true,
  'canRequestPermission': false,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'off -> on resets watermark, so accumulated mail is not notified',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final store = InboxNotificationStateStore(database: db);
      await db
          .into(db.dbAccounts)
          .insert(
            DbAccountsCompanion.insert(
              id: 'acc-1',
              email: 'alice@example.com',
              displayName: 'Alice',
              providerType: MailProviderType.gmail.storageKey,
              authType: MailAuthType.passwordOrAuthCode.storageKey,
              colorValue: 1,
              imapHost: 'imap.example.com',
              imapPort: 993,
              imapImplicitTls: true,
              smtpHost: 'smtp.example.com',
              smtpPort: 465,
              smtpImplicitTls: true,
              createdAt: 1,
            ),
          );
      await db
          .into(db.dbFolders)
          .insert(
            DbFoldersCompanion.insert(
              id: 'folder-1',
              accountId: 'acc-1',
              remoteName: 'INBOX',
              displayName: 'INBOX',
              role: 'inbox',
              uidValidity: const Value(7),
            ),
          );
      await store.recordSuccess(
        accountId: 'acc-1',
        uidValidity: 7,
        lastNotifiedUid: 5,
      );

      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(BatteryNotificationPlatform.channel, (
            call,
          ) async {
            calls.add(call);
            switch (call.method) {
              case 'getSettings':
                return _settings(0);
              case 'setIntervalMinutes':
                return _settings(30);
              case 'acquireForegroundLease':
                return true;
              case 'releaseForegroundLease':
                return null;
              default:
                return null;
            }
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              BatteryNotificationPlatform.channel,
              null,
            );
      });

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationSettingsPage(resetBaselines: store.resetAll),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('notification-interval-30')));
        await tester.pumpAndSettle();

        expect(
          calls.any((call) => call.method == 'setIntervalMinutes'),
          isTrue,
        );
        expect(
          await store.get('acc-1'),
          isNull,
          reason: 're-enabling must discard the pre-off watermark',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      final factory = FakeImapSessionFactory();
      factory.statuses['INBOX'] = const RemoteMailboxStatus(
        remoteName: 'INBOX',
        uidValidity: 7,
        uidNext: 8,
        messagesExists: 7,
      );
      final notified = <int>[];
      BackgroundMailChecker checker() => BackgroundMailChecker(
        database: db,
        stateStore: store,
        sessionFactory: factory,
        credentialResolver: (_) async => const PasswordCredential('secret'),
        notify: (count) async {
          notified.add(count);
          return true;
        },
        isCancelled: () async => false,
        clock: () => DateTime.utc(2026, 1, 1),
        retryBase: Duration.zero,
      );

      await checker().run();
      expect(
        notified,
        isEmpty,
        reason: 'the first run only rebuilds a baseline',
      );
      expect((await store.get('acc-1'))!.lastNotifiedUid, 7);

      factory.newMailSearchResponse = const RemoteNewMailSearch(
        allUids: [8],
        unseenUids: [8],
      );
      await checker().run();
      expect(notified, [
        1,
      ], reason: 'new mail after the fresh baseline still alerts');
    },
  );
}
