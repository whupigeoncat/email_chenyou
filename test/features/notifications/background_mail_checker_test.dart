import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/notifications/data/background_mail_checker.dart';
import 'package:local_mail_client/features/notifications/data/inbox_notification_state_store.dart';

import '../../core/support/fake_imap_session.dart';

class _SlowBaselineStore extends InboxNotificationStateStore {
  _SlowBaselineStore({required super.database, required this.delay});

  final Duration delay;

  @override
  Future<void> saveBaseline({
    required String accountId,
    required int? uidValidity,
    required int lastUid,
  }) async {
    await Future<void>.delayed(delay);
    return super.saveBaseline(
      accountId: accountId,
      uidValidity: uidValidity,
      lastUid: lastUid,
    );
  }
}

const _validity = 7;

Future<void> _seedAccount(
  AppDatabase db, {
  String id = 'acc-1',
  String email = 'alice@example.com',
  bool enabled = true,
  String folderId = 'folder-1',
  int? uidValidity = _validity,
}) async {
  await db
      .into(db.dbAccounts)
      .insert(
        DbAccountsCompanion.insert(
          id: id,
          email: email,
          displayName: email,
          providerType: MailProviderType.gmail.storageKey,
          authType: MailAuthType.passwordOrAuthCode.storageKey,
          colorValue: 1,
          imapHost: 'imap.example.com',
          imapPort: 993,
          imapImplicitTls: true,
          smtpHost: 'smtp.example.com',
          smtpPort: 465,
          smtpImplicitTls: true,
          isEnabled: Value(enabled),
          createdAt: id.hashCode,
        ),
      );
  await db
      .into(db.dbFolders)
      .insert(
        DbFoldersCompanion.insert(
          id: folderId,
          accountId: id,
          remoteName: 'INBOX',
          displayName: 'INBOX',
          role: 'inbox',
          uidValidity: Value(uidValidity),
        ),
      );
}

Future<void> _seedLocalEmail(
  AppDatabase db, {
  String accountId = 'acc-1',
  String folderId = 'folder-1',
  required int uid,
}) async {
  await db
      .into(db.dbEmails)
      .insert(
        DbEmailsCompanion.insert(
          accountId: accountId,
          folderId: folderId,
          uid: uid,
          subject: 'local',
          fromName: '',
          fromAddress: 'sender@example.com',
          toRecipientsJson: '[]',
          ccJson: '[]',
          snippet: '',
          sentAt: 1,
        ),
      );
}

RemoteMailboxStatus _status({
  int? uidValidity = _validity,
  int? uidNext,
  int exists = 0,
}) {
  return RemoteMailboxStatus(
    remoteName: 'INBOX',
    uidValidity: uidValidity,
    uidNext: uidNext,
    messagesExists: exists,
  );
}

void main() {
  late AppDatabase db;
  late InboxNotificationStateStore states;
  late FakeImapSessionFactory factory;
  late List<int> notified;
  late bool failNotification;
  late int credentialCalls;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    states = InboxNotificationStateStore(database: db);
    factory = FakeImapSessionFactory();
    notified = <int>[];
    failNotification = false;
    credentialCalls = 0;
    await _seedAccount(db);
  });

  tearDown(() async {
    await db.close();
  });

  BackgroundMailChecker checker({
    Duration perAccountTimeout = const Duration(seconds: 2),
    Duration retryBase = Duration.zero,
    bool cancelled = false,
  }) {
    return BackgroundMailChecker(
      database: db,
      stateStore: states,
      sessionFactory: factory,
      credentialResolver: (account) async {
        credentialCalls++;
        return const PasswordCredential('secret');
      },
      notify: (count) async {
        if (failNotification) throw StateError('notify failed');
        notified.add(count);
        return true;
      },
      isCancelled: () async => cancelled,
      clock: () => DateTime.utc(2026, 1, 1),
      perAccountTimeout: perAccountTimeout,
      retryBase: retryBase,
      totalTimeout: const Duration(seconds: 10),
    );
  }

  test('first run establishes baseline without notifying history and authenticates before SELECT', () async {
    factory.statuses['INBOX'] = _status(uidNext: 5001, exists: 5000);

    final report = await checker().run();

    expect(notified, isEmpty);
    expect(report.notifiedMailCount, 0);
    expect(credentialCalls, 1);
    expect(factory.selectStatusCalls, 1);
    expect(factory.newMailSearchCalls, 0);
    expect(
      factory.protocolLog.indexOf('connect:1'),
      lessThan(factory.protocolLog.indexOf('select:1:INBOX')),
    );
    final state = await states.get('acc-1');
    expect(state!.baselineEstablished, isTrue);
    expect(state.uidValidity, _validity);
    expect(state.lastNotifiedUid, 5000);
    expect(factory.totalLogoutCount + factory.totalForceCloseCount, 1);
    expect(factory.activeCount, 0);
  });

  test(
    'new unread UIDs are counted once and echoed old UID is ignored',
    () async {
      factory.statuses['INBOX'] = _status(uidNext: 6, exists: 5);
      await checker().run();
      notified.clear();

      factory.newMailSearchResponse = const RemoteNewMailSearch(
        allUids: [5, 6, 7, 8],
        unseenUids: [5, 6, 7, 8],
      );
      final first = await checker().run();
      expect(notified, [3]);
      expect(first.notifiedMailCount, 3);
      expect((await states.get('acc-1'))!.lastNotifiedUid, 8);

      final second = await checker().run();
      expect(notified, [3], reason: 'the same UIDs must not notify twice');
      expect(second.notifiedMailCount, 0);
    },
  );

  test('read-but-new mail advances the watermark without notifying', () async {
    factory.statuses['INBOX'] = _status(uidNext: 6, exists: 5);
    await checker().run();

    factory.newMailSearchResponse = const RemoteNewMailSearch(
      allUids: [6],
      unseenUids: [],
    );
    final report = await checker().run();

    expect(notified, isEmpty);
    expect(report.notifiedMailCount, 0);
    expect((await states.get('acc-1'))!.lastNotifiedUid, 6);
  });

  test('UIDVALIDITY change re-baselines and ignores stale local high UIDs', () async {
    await states.saveBaseline(
      accountId: 'acc-1',
      uidValidity: _validity,
      lastUid: 5000,
    );
    await _seedLocalEmail(db, uid: 5000);
    factory.statuses['INBOX'] = _status(uidValidity: 8, uidNext: 10, exists: 9);

    final report = await checker().run();

    expect(notified, isEmpty);
    expect(report.notifiedMailCount, 0);
    final state = (await states.get('acc-1'))!;
    expect(state.uidValidity, 8);
    expect(
      state.lastNotifiedUid,
      9,
      reason:
          'the new mailbox identity starts at UIDNEXT-1, not old local maxUid',
    );
  });

  test(
    'local max UID only suppresses when folder UIDVALIDITY matches',
    () async {
      await states.saveBaseline(
        accountId: 'acc-1',
        uidValidity: _validity,
        lastUid: 100,
      );
      await _seedLocalEmail(db, uid: 250);
      factory.statuses['INBOX'] = _status(uidNext: 300, exists: 299);
      factory.newMailSearchResponse = const RemoteNewMailSearch.empty();

      await checker().run();

      expect(notified, isEmpty);
      expect(
        factory.protocolLog,
        contains('searchNewMail:1:251'),
        reason:
            'local UID 250 is visible in the app and must move the watermark',
      );
    },
  );

  test('late unseen UID after the all-UID search is included in observed watermark', () async {
    await states.saveBaseline(
      accountId: 'acc-1',
      uidValidity: _validity,
      lastUid: 5,
    );
    factory.statuses['INBOX'] = _status(uidNext: 8, exists: 7);
    factory.newMailSearchResponse = const RemoteNewMailSearch(
      allUids: [6],
      unseenUids: [6, 7],
    );

    final first = await checker().run();
    expect(first.notifiedMailCount, 2);
    expect(notified, [2]);
    expect((await states.get('acc-1'))!.lastNotifiedUid, 7);

    final second = await checker().run();
    expect(second.notifiedMailCount, 0);
    expect(notified, [2]);
  });

  test(
    'UIDVALIDITY null is treated conservatively and never notifies',
    () async {
      factory.statuses['INBOX'] = _status(
        uidValidity: null,
        uidNext: 6,
        exists: 5,
      );
      await checker().run();
      expect(notified, isEmpty);

      factory.newMailSearchResponse = const RemoteNewMailSearch(
        allUids: [6],
        unseenUids: [6],
      );
      factory.statuses['INBOX'] = _status(
        uidValidity: null,
        uidNext: 7,
        exists: 6,
      );
      await checker().run();
      expect(notified, isEmpty);
    },
  );

  test(
    'missing UIDNEXT with an empty mailbox establishes a zero baseline safely',
    () async {
      factory.statuses['INBOX'] = _status(uidValidity: null, uidNext: null);
      factory.headers['INBOX'] = [];

      await checker().run();

      expect(notified, isEmpty);
      expect((await states.get('acc-1'))!.lastNotifiedUid, 0);
    },
  );

  test('per-account failure sets exponential backoff and does not block another account', () async {
    await _seedAccount(
      db,
      id: 'acc-2',
      email: 'bob@example.com',
      folderId: 'folder-2',
    );
    factory.statuses['INBOX'] = _status(uidNext: 6, exists: 5);
    final failing = BackgroundMailChecker(
      database: db,
      stateStore: states,
      sessionFactory: factory,
      credentialResolver: (account) async {
        if (account.id == 'acc-1') throw StateError('gmail unreachable');
        return const PasswordCredential('secret');
      },
      notify: (count) async {
        notified.add(count);
        return true;
      },
      isCancelled: () async => false,
      clock: () => DateTime.utc(2026, 1, 1),
      perAccountTimeout: const Duration(seconds: 2),
      retryBase: const Duration(minutes: 15),
      totalTimeout: const Duration(seconds: 10),
    );

    final first = await failing.run();
    expect(first.failures, 1);
    expect(first.accountsSeen, 1);
    final failed = (await states.get('acc-1'))!;
    expect(failed.failureCount, 1);
    expect(
      failed.nextRetryAt,
      DateTime.utc(2026, 1, 1).add(const Duration(minutes: 15)),
    );
    expect((await states.get('acc-2'))!.baselineEstablished, isTrue);

    final second = await failing.run();
    expect(second.accountsSkipped, 1);
  });

  test(
    'notification failure keeps the cursor and retries on the next run',
    () async {
      factory.statuses['INBOX'] = _status(uidNext: 6, exists: 5);
      await checker().run();
      factory.newMailSearchResponse = const RemoteNewMailSearch(
        allUids: [6],
        unseenUids: [6],
      );

      failNotification = true;
      final failed = await checker().run();
      expect(failed.failures, 1);
      expect((await states.get('acc-1'))!.lastNotifiedUid, 5);

      failNotification = false;
      final retried = await checker(retryBase: Duration.zero).run();
      expect(notified, [1]);
      expect(retried.notifiedMailCount, 1);
      expect((await states.get('acc-1'))!.lastNotifiedUid, 6);
    },
  );

  test('timeout force-closes the session and late operation cannot save a baseline', () async {
    factory.statuses['INBOX'] = _status(uidNext: 5001, exists: 5000);
    factory.selectDelay = const Duration(milliseconds: 250);

    final report = await checker(
      perAccountTimeout: const Duration(milliseconds: 30),
    ).run();

    expect(report.failures, 1);
    expect(factory.totalForceCloseCount, 1);
    expect(factory.activeCount, 0);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final late = await states.get('acc-1');
    expect(
      late?.baselineEstablished ?? false,
      isFalse,
      reason: 'a timed-out operation must not write the first baseline',
    );
    expect(late?.lastNotifiedUid ?? 0, 0);
  });

  test(
    'baseline SQL commit is outside network timeout and is awaited',
    () async {
      factory.statuses['INBOX'] = _status(uidNext: 5001, exists: 5000);
      final slow = _SlowBaselineStore(
        database: db,
        delay: const Duration(milliseconds: 120),
      );
      final slowChecker = BackgroundMailChecker(
        database: db,
        stateStore: slow,
        sessionFactory: factory,
        credentialResolver: (_) async => const PasswordCredential('secret'),
        notify: (count) async {
          notified.add(count);
          return true;
        },
        isCancelled: () async => false,
        clock: () => DateTime.utc(2026, 1, 1),
        perAccountTimeout: const Duration(milliseconds: 20),
        totalTimeout: const Duration(seconds: 10),
      );

      final report = await slowChecker.run();

      expect(report.failures, 0);
      final state = (await states.get('acc-1'))!;
      expect(state.baselineEstablished, isTrue);
      expect(state.lastNotifiedUid, 5000);
      expect(notified, isEmpty);
    },
  );

  test(
    'cancellation after network but before commit writes no baseline',
    () async {
      factory.statuses['INBOX'] = _status(uidNext: 5001, exists: 5000);
      var cancelChecks = 0;
      final cancelChecker = BackgroundMailChecker(
        database: db,
        stateStore: states,
        sessionFactory: factory,
        credentialResolver: (_) async => const PasswordCredential('secret'),
        notify: (count) async {
          notified.add(count);
          return true;
        },
        isCancelled: () async {
          cancelChecks++;
          return cancelChecks >= 2;
        },
        clock: () => DateTime.utc(2026, 1, 1),
        perAccountTimeout: const Duration(seconds: 2),
        totalTimeout: const Duration(seconds: 10),
      );

      final report = await cancelChecker.run();

      expect(report.cancelled, isTrue);
      expect(await states.get('acc-1'), isNull);
      expect(notified, isEmpty);
      expect(factory.createdCount, 1);
    },
  );

  test('cancellation before the first account opens no socket', () async {
    factory.statuses['INBOX'] = _status(uidNext: 6, exists: 5);

    final report = await checker(cancelled: true).run();

    expect(report.cancelled, isTrue);
    expect(factory.createdCount, 0);
    expect(notified, isEmpty);
  });

  test('no enabled accounts opens no socket and notifies nothing', () async {
    await (db.update(db.dbAccounts)..where((t) => t.id.equals('acc-1'))).write(
      const DbAccountsCompanion(isEnabled: Value(false)),
    );
    factory.statuses['INBOX'] = _status(uidNext: 6, exists: 5);

    final report = await checker().run();

    expect(report.accountsSeen, 0);
    expect(factory.createdCount, 0);
    expect(notified, isEmpty);
  });
}
