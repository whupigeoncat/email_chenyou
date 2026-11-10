import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/features/notifications/data/inbox_notification_state_store.dart';

Future<void> _account(AppDatabase db, String id) {
  return db
      .into(db.dbAccounts)
      .insert(
        DbAccountsCompanion.insert(
          id: id,
          email: '$id@example.com',
          displayName: id,
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
}

void main() {
  late AppDatabase db;
  late InboxNotificationStateStore store;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = InboxNotificationStateStore(database: db);
    await _account(db, 'acc-1');
  });

  tearDown(() async {
    await db.close();
  });

  test('same UIDVALIDITY never moves the watermark backwards', () async {
    await store.recordSuccess(
      accountId: 'acc-1',
      uidValidity: 7,
      lastNotifiedUid: 300,
    );

    await store.markForegroundSynced(
      accountId: 'acc-1',
      uidValidity: 7,
      lastUid: 250,
    );
    await store.recordSuccess(
      accountId: 'acc-1',
      uidValidity: 7,
      lastNotifiedUid: 200,
    );

    final state = (await store.get('acc-1'))!;
    expect(state.lastNotifiedUid, 300);
    expect(state.uidValidity, 7);
  });

  test('a null UIDVALIDITY never resets a known watermark', () async {
    await store.recordSuccess(
      accountId: 'acc-1',
      uidValidity: 7,
      lastNotifiedUid: 300,
    );

    await store.markForegroundSynced(
      accountId: 'acc-1',
      uidValidity: null,
      lastUid: 250,
    );

    final state = (await store.get('acc-1'))!;
    expect(state.uidValidity, 7);
    expect(state.lastNotifiedUid, 300);
  });

  test('a UIDVALIDITY change may reset the watermark', () async {
    await store.recordSuccess(
      accountId: 'acc-1',
      uidValidity: 7,
      lastNotifiedUid: 300,
    );

    await store.saveBaseline(accountId: 'acc-1', uidValidity: 8, lastUid: 10);

    final state = (await store.get('acc-1'))!;
    expect(state.uidValidity, 8);
    expect(state.lastNotifiedUid, 10);
  });

  test('a successful foreground sync clears failure backoff', () async {
    await store.recordFailure(
      accountId: 'acc-1',
      kind: 'timeout',
      nextRetryAt: DateTime.utc(2026, 1, 1),
      failureCount: 3,
    );
    expect((await store.get('acc-1'))!.failureCount, 3);

    await store.markForegroundSynced(
      accountId: 'acc-1',
      uidValidity: 7,
      lastUid: 42,
    );

    final state = (await store.get('acc-1'))!;
    expect(state.failureCount, 0);
    expect(state.nextRetryAt, isNull);
    expect(state.lastNotifiedUid, 42);
  });

  test('deleting the account cascades the notification state', () async {
    await store.recordSuccess(
      accountId: 'acc-1',
      uidValidity: 7,
      lastNotifiedUid: 42,
    );
    await (db.delete(db.dbAccounts)..where((t) => t.id.equals('acc-1'))).go();

    expect(await store.get('acc-1'), isNull);
  });
}
