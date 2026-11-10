import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/features/notifications/data/foreground_inbox_marker.dart';
import 'package:local_mail_client/features/notifications/data/inbox_notification_state_store.dart';

void main() {
  late AppDatabase db;
  late InboxNotificationStateStore states;
  late ForegroundInboxMarker marker;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    states = InboxNotificationStateStore(database: db);
    marker = ForegroundInboxMarker(database: db, stateStore: states);
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
    for (final uid in [100, 250]) {
      await db
          .into(db.dbEmails)
          .insert(
            DbEmailsCompanion.insert(
              accountId: 'acc-1',
              folderId: 'folder-1',
              uid: uid,
              subject: 'mail $uid',
              fromName: '',
              fromAddress: 'sender@example.com',
              toRecipientsJson: '[]',
              ccJson: '[]',
              snippet: '',
              sentAt: uid,
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  test('foreground sync advances the same UIDVALIDITY watermark', () async {
    await marker.markSynced('acc-1');

    final state = (await states.get('acc-1'))!;
    expect(state.uidValidity, 7);
    expect(state.lastNotifiedUid, 250);
    expect(state.baselineEstablished, isTrue);
  });

  test(
    'a stale foreground local max never lowers an already notified UID',
    () async {
      await states.recordSuccess(
        accountId: 'acc-1',
        uidValidity: 7,
        lastNotifiedUid: 300,
      );

      await marker.markSynced('acc-1');

      expect((await states.get('acc-1'))!.lastNotifiedUid, 300);
    },
  );
}
