import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/network/account_connection_slot.dart';
import 'package:local_mail_client/core/network/connection_pool.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/core/network/lifecycle_manager.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';

import 'support/fake_imap_session.dart';

AccountConnectionSlot _newSlot(
  FakeImapSessionFactory factory, {
  Duration? inboxPollIntervalOverride,
  void Function(String accountId, ImapInboxEvent event)? onInboxEvent,
}) {
  return AccountConnectionSlot(
    account: buildTestAccount(),
    sessionFactory: factory,
    credentialResolver: fakeCredentialResolver,
    onInboxEvent: onInboxEvent ?? (_, _) {},
    inboxPollIntervalOverride: inboxPollIntervalOverride,
  );
}

void main() {
  group('persistent INBOX connection', () {
    test('concurrent ensureInboxIdle/runOnInbox opens and reuses one socket',
        () async {
      final factory = FakeImapSessionFactory(
        connectDelay: const Duration(milliseconds: 15),
      );
      final slot = _newSlot(factory);

      final ensures = <Future<void>>[
        slot.ensureInboxIdle(),
        slot.ensureInboxIdle(),
        slot.ensureInboxIdle(),
      ];
      final firstCommand = slot.runOnInbox<String>((session) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return session.selectedFolder ?? '';
      });
      final secondCommand = slot.runOnInbox<String>(
        (session) async => session.selectedFolder ?? '',
      );

      await Future.wait(ensures);
      expect(await firstCommand, 'INBOX');
      expect(await secondCommand, 'INBOX');

      expect(factory.createdCount, 1);
      expect(slot.persistentConnectCount, 1);
      expect(slot.activePersistentCount, 1);
      expect(slot.state, ConnectionSlotState.idleInInbox);
      expect(factory.sessions.single.connectCount, 1);
      expect(factory.sessions.single.isIdle, isTrue);

      await slot.dispose();
      expect(factory.activeCount, 0);
      expect(slot.activePersistentCount, 0);
    });

    test('command-driven INBOX sessions attach the unified stream error handler',
        () async {
      final factory = FakeImapSessionFactory();
      final slot = _newSlot(factory);

      await slot.runOnInbox<String>(
        (session) async => session.selectedFolder ?? '',
      );
      expect(slot.state, ConnectionSlotState.idleInInbox);

      // This path is established by _establishInboxForCommand(), not by
      // ensureInboxIdle(); both must listen for stream errors.
      factory.sessions.single.emitError(StateError('socket reset'));
      await Future<void>.delayed(Duration.zero);

      expect(slot.state, ConnectionSlotState.backoffWaiting);
      await slot.dispose();
    });
  });

  group('transient non-INBOX folders', () {
    test('serializes tasks and completes only after LOGOUT', () async {
      final factory = FakeImapSessionFactory(
        logoutDelay: const Duration(milliseconds: 5),
      );
      final slot = _newSlot(factory);

      var activeActions = 0;
      var maxActiveActions = 0;
      final disconnectedAtCompletion = <bool>[];

      Future<String> startTask(int index) {
        return slot.runTransientFolderTask<String>(
          folderPath: 'Sent',
          action: (session) async {
            activeActions++;
            if (activeActions > maxActiveActions) {
              maxActiveActions = activeActions;
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
            activeActions--;
            return 'result-$index';
          },
        );
      }

      final tasks = <Future<String>>[startTask(0), startTask(1), startTask(2)];
      for (final task in tasks) {
        unawaited(
          task.then((_) {
            // If completion happened before LOGOUT this would be 1.
            disconnectedAtCompletion.add(factory.activeCount == 0);
          }),
        );
      }

      expect(
        await Future.wait(tasks),
        <String>['result-0', 'result-1', 'result-2'],
      );
      await Future<void>.delayed(Duration.zero);

      expect(maxActiveActions, 1, reason: 'transient actions must not overlap');
      expect(disconnectedAtCompletion, <bool>[true, true, true]);
      expect(factory.createdCount, 3);
      expect(factory.totalLogoutCount, 3);
      expect(factory.activeCount, 0);
      expect(slot.activeTransientCount, 0);
      expect(slot.logoutSentCount, 3);

      for (final session in factory.sessions) {
        expect(session.logoutCount, 1);
        expect(session.isConnected, isFalse);
        expect(session.isIdle, isFalse);
      }

      final log = factory.protocolLog;
      expect(log.indexOf('logout:1') < log.indexOf('connect:2'), isTrue);
      expect(log.indexOf('logout:2') < log.indexOf('connect:3'), isTrue);

      await slot.dispose();
    });

    test('action errors surface only after LOGOUT', () async {
      final factory = FakeImapSessionFactory(
        logoutDelay: const Duration(milliseconds: 5),
      );
      final slot = _newSlot(factory);

      final future = slot.runTransientFolderTask<void>(
        folderPath: 'Archive',
        action: (session) async => throw StateError('fetch failed'),
      );

      await expectLater(future, throwsA(isA<StateError>()));
      expect(factory.sessions.single.logoutCount, 1);
      expect(factory.sessions.single.isConnected, isFalse);
      expect(slot.activeTransientCount, 0);

      await slot.dispose();
    });

    test('background release rejects new INBOX and transient work', () async {
      final factory = FakeImapSessionFactory(
        logoutDelay: const Duration(milliseconds: 5),
      );
      final slot = _newSlot(factory);

      await slot.ensureInboxIdle();
      expect(factory.createdCount, 1);

      await slot.releaseForBackground();
      expect(slot.isBackgroundReleased, isTrue);
      expect(factory.activeCount, 0);
      expect(slot.activePersistentCount, 0);

      await expectLater(
        slot.runTransientFolderTask<String>(
          folderPath: 'Archive',
          action: (session) async => 'should-not-run',
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        slot.runOnInbox<String>((session) async => 'should-not-run'),
        throwsA(isA<StateError>()),
      );

      expect(factory.createdCount, 1, reason: 'no socket may be revived');
      expect(slot.activeTransientCount, 0);

      await slot.dispose();
    });

    test('a task queued behind an active transient does not reconnect after release',
        () async {
      final factory = FakeImapSessionFactory(
        logoutDelay: const Duration(milliseconds: 5),
      );
      final slot = _newSlot(factory);

      final started = Completer<void>();
      final gate = Completer<void>();

      final first = slot.runTransientFolderTask<String>(
        folderPath: 'Sent',
        action: (session) async {
          started.complete();
          await gate.future;
          return 'first';
        },
      );
      await started.future;
      expect(factory.createdCount, 1);
      expect(factory.activeCount, 1);

      // This task is queued while the first one is still in flight.
      final second = slot.runTransientFolderTask<String>(
        folderPath: 'Drafts',
        action: (session) async => 'second',
      );

      await slot.releaseForBackground();
      expect(factory.activeCount, 0);

      gate.complete();
      expect(await first, 'first');
      await expectLater(second, throwsA(isA<StateError>()));
      expect(factory.createdCount, 1);
      expect(slot.activeTransientCount, 0);

      await slot.dispose();
    });
  });

  group('INBOX polling fallback', () {
    test('non-IDLE server enters polling and reuses one persistent socket', () {
      fakeAsync((async) {
        final factory = FakeImapSessionFactory(supportsIdle: false);
        final slot = _newSlot(factory);

        unawaited(slot.ensureInboxIdle());
        async.flushMicrotasks();

        expect(slot.state, ConnectionSlotState.pollingInInbox);
        expect(factory.sessions.single.startIdleCount, 0);
        expect(slot.persistentConnectCount, 1);
        expect(slot.activePersistentCount, 1);
        final initialSelects = factory.selectStatusCalls;
        expect(initialSelects, greaterThanOrEqualTo(1));

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
        expect(factory.selectStatusCalls, greaterThanOrEqualTo(2));
        expect(factory.maxConcurrentActiveCount, 1);

        unawaited(slot.dispose());
        async.flushMicrotasks();
      });
    });

    test('poll detects new messages and emits a single added event', () {
      fakeAsync((async) {
        final factory = FakeImapSessionFactory(supportsIdle: false);
        factory.statuses['INBOX'] = const RemoteMailboxStatus(
          remoteName: 'INBOX',
          uidValidity: 1,
          messagesExists: 3,
          messagesUnseen: 1,
        );
        final events = <ImapInboxEvent>[];
        final slot = _newSlot(
          factory,
          onInboxEvent: (_, event) => events.add(event),
        );

        unawaited(slot.ensureInboxIdle());
        async.flushMicrotasks();
        events.clear();

        factory.statuses['INBOX'] = const RemoteMailboxStatus(
          remoteName: 'INBOX',
          uidValidity: 1,
          messagesExists: 4,
          messagesUnseen: 1,
        );
        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();

        final added = events.whereType<ImapMailboxMessagesAdded>().toList();
        expect(added, hasLength(1));
        expect(added.single.existsCount, 4);
        expect(events.whereType<ImapMailboxFlagsUpdated>(), isEmpty);

        unawaited(slot.dispose());
        async.flushMicrotasks();
      });
    });

    test('poll detects flag changes and emits one flags-updated event', () {
      fakeAsync((async) {
        final factory = FakeImapSessionFactory(supportsIdle: false);
        factory.statuses['INBOX'] = const RemoteMailboxStatus(
          remoteName: 'INBOX',
          uidValidity: 1,
          messagesExists: 3,
          messagesUnseen: 3,
        );
        final events = <ImapInboxEvent>[];
        final slot = _newSlot(
          factory,
          onInboxEvent: (_, event) => events.add(event),
        );

        unawaited(slot.ensureInboxIdle());
        async.flushMicrotasks();
        events.clear();

        factory.statuses['INBOX'] = const RemoteMailboxStatus(
          remoteName: 'INBOX',
          uidValidity: 1,
          messagesExists: 3,
          messagesUnseen: 1,
        );
        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();

        final flags = events.whereType<ImapMailboxFlagsUpdated>().toList();
        expect(flags, hasLength(1));
        expect(events.whereType<ImapMailboxMessagesAdded>(), isEmpty);

        unawaited(slot.dispose());
        async.flushMicrotasks();
      });
    });

    test('IDLE start failure falls back to polling and never retries IDLE', () {
      fakeAsync((async) {
        final factory = FakeImapSessionFactory(
          supportsIdle: true,
          failStartIdle: true,
        );
        final slot = _newSlot(factory);

        unawaited(slot.ensureInboxIdle());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(slot.state, ConnectionSlotState.pollingInInbox);
        expect(
          factory.sessions.fold<int>(
            0,
            (sum, session) => sum + session.startIdleCount,
          ),
          1,
        );
        expect(slot.persistentConnectCount, 2);
        expect(slot.activePersistentCount, 1);

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
        expect(
          factory.sessions.fold<int>(
            0,
            (sum, session) => sum + session.startIdleCount,
          ),
          1,
        );

        unawaited(slot.dispose());
        async.flushMicrotasks();
      });
    });

    test('transient folder task restores polling INBOX connection', () async {
      final factory = FakeImapSessionFactory(supportsIdle: false);
      final slot = _newSlot(factory);

      await slot.ensureInboxIdle();
      expect(slot.state, ConnectionSlotState.pollingInInbox);

      await slot.runTransientFolderTask<void>(
        folderPath: 'Sent',
        action: (session) async {
          expect(factory.activeCount, 1);
          expect(slot.activePersistentCount, 0);
          expect(slot.activeTransientCount, 1);
        },
      );

      expect(slot.state, ConnectionSlotState.pollingInInbox);
      expect(slot.activeTransientCount, 0);
      expect(slot.activePersistentCount, 1);
      expect(factory.maxConcurrentActiveCount, 1);

      await slot.dispose();
    });

    test('background release cancels polling and foreground resumes it',
        () async {
      fakeAsync((async) {
        final factory = FakeImapSessionFactory(supportsIdle: false);
        final slot = _newSlot(factory);

        unawaited(slot.ensureInboxIdle());
        async.flushMicrotasks();
        expect(slot.state, ConnectionSlotState.pollingInInbox);
        final beforeRelease = factory.selectStatusCalls;

        unawaited(slot.releaseForBackground());
        async.flushMicrotasks();
        expect(slot.state, ConnectionSlotState.backgroundReleased);
        expect(slot.activePersistentCount, 0);

        async.elapse(const Duration(minutes: 2));
        async.flushMicrotasks();
        expect(factory.selectStatusCalls, beforeRelease);

        unawaited(slot.reconnectFromForeground());
        async.flushMicrotasks();
        expect(slot.state, ConnectionSlotState.pollingInInbox);
        expect(slot.activePersistentCount, 1);

        unawaited(slot.dispose());
        async.flushMicrotasks();
      });
    });
  });

  group('Transient folder connection serialization & LOGOUT', () {
    test(
        'tears down INBOX IDLE before transient folder task and restores '
        'INBOX IDLE afterward with max 1 active socket', () async {
      final factory = FakeImapSessionFactory();
      final slot = _newSlot(factory);

      await slot.ensureInboxIdle();
      // AFTER_IDLE
      expect(factory.activeCount, 1);
      expect(slot.activePersistentCount, 1);
      expect(slot.activeTransientCount, 0);

      await slot.runTransientFolderTask<void>(
        folderPath: 'Sent',
        action: (session) async {
          // DURING_TRANSIENT
          expect(factory.activeCount, 1);
          expect(slot.activePersistentCount, 0);
          expect(slot.activeTransientCount, 1);
          expect(slot.state, ConnectionSlotState.busyInInbox);
          expect(session.selectedFolder, 'Sent');
        },
      );

      // AFTER_TRANSIENT
      expect(factory.activeCount, 1);
      expect(slot.activePersistentCount, 1);
      expect(slot.activeTransientCount, 0);
      expect(slot.state, ConnectionSlotState.idleInInbox);
      expect(factory.maxConcurrentActiveCount, 1);

      final log = factory.protocolLog;
      expect(log.indexOf('logout:1') < log.indexOf('connect:2'), isTrue);
      expect(log.indexOf('logout:2') < log.indexOf('connect:3'), isTrue);

      await slot.dispose();
    });

    test(
        'coalesces INBOX IDLE teardown and restore across back-to-back '
        'concurrent transient tasks', () async {
      final factory = FakeImapSessionFactory();
      final slot = _newSlot(factory);

      await slot.ensureInboxIdle();
      expect(factory.createdCount, 1);

      Future<String> task(String folder) {
        return slot.runTransientFolderTask<String>(
          folderPath: folder,
          action: (session) async {
            expect(factory.activeCount, 1);
            expect(slot.activePersistentCount, 0);
            expect(slot.activeTransientCount, 1);
            expect(session.selectedFolder, folder);
            return folder;
          },
        );
      }

      final results = await Future.wait(<Future<String>>[
        task('Sent'),
        task('Trash'),
      ]);

      expect(results, <String>['Sent', 'Trash']);
      expect(slot.state, ConnectionSlotState.idleInInbox);
      expect(slot.activePersistentCount, 1);
      expect(slot.activeTransientCount, 0);
      expect(factory.maxConcurrentActiveCount, 1);
      expect(factory.createdCount, 4);

      await slot.dispose();
    });

    test('restores INBOX IDLE even when transient folder task throws',
        () async {
      final factory = FakeImapSessionFactory();
      final slot = _newSlot(factory);

      await slot.ensureInboxIdle();
      await expectLater(
        slot.runTransientFolderTask<void>(
          folderPath: 'Archive',
          action: (session) async => throw StateError('fetch failed'),
        ),
        throwsA(isA<StateError>()),
      );

      expect(slot.state, ConnectionSlotState.idleInInbox);
      expect(slot.activePersistentCount, 1);
      expect(slot.activeTransientCount, 0);
      expect(factory.maxConcurrentActiveCount, 1);
      expect(factory.sessions[1].logoutCount, 1);
      expect(factory.sessions[1].isConnected, isFalse);

      await slot.dispose();
    });
  });

  group('mobile 30s background release', () {
    test('inactive -> paused keeps one timer; 29s resume cancels, 30s releases all',
        () {
      fakeAsync((async) {
        final factory = FakeImapSessionFactory();
        final pool = ConnectionPool(
          sessionFactory: factory,
          credentialResolver: fakeCredentialResolver,
        );
        final manager = AppLifecycleManager(
          connectionPool: pool,
          isMobileOverride: true,
        );
        final accounts = <MailAccount>[
          buildTestAccount(id: 'acc-1'),
          buildTestAccount(id: 'acc-2', email: 'bob@outlook.com'),
        ];

        pool.syncAccounts(accounts);
        async.flushMicrotasks();
        expect(factory.createdCount, 2);
        expect(factory.activeCount, 2);

        manager.didChangeAppLifecycleState(AppLifecycleState.inactive);
        async.elapse(const Duration(seconds: 20));
        manager.didChangeAppLifecycleState(AppLifecycleState.paused);
        async.elapse(const Duration(seconds: 9));

        expect(manager.isGraceTimerActive, isTrue);
        expect(factory.totalLogoutCount, 0);

        manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
        async.flushMicrotasks();
        expect(manager.isGraceTimerActive, isFalse);
        expect(factory.totalLogoutCount, 0);
        expect(factory.activeCount, 2);

        // Second cycle crosses the hard 30-second boundary.
        manager.didChangeAppLifecycleState(AppLifecycleState.inactive);
        manager.didChangeAppLifecycleState(AppLifecycleState.paused);
        async.elapse(const Duration(seconds: 29));
        expect(factory.totalLogoutCount, 0);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(factory.totalLogoutCount, 2);
        expect(factory.activeCount, 0);
        expect(pool.isBackgroundReleased, isTrue);

        // Foreground resume rebuilds exactly one IDLE socket per account.
        manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(factory.createdCount, 4);
        expect(factory.activeCount, 2);
        expect(pool.isBackgroundReleased, isFalse);
        for (final session in factory.sessions.where((s) => s.isConnected)) {
          expect(session.isIdle, isTrue);
        }

        pool.dispose();
        async.flushMicrotasks();
      });
    });

    test('resume during an in-flight release waits for LOGOUT before reconnecting',
        () {
      fakeAsync((async) {
        final factory = FakeImapSessionFactory(
          logoutDelay: const Duration(milliseconds: 50),
        );
        final pool = ConnectionPool(
          sessionFactory: factory,
          credentialResolver: fakeCredentialResolver,
        );
        final manager = AppLifecycleManager(
          connectionPool: pool,
          isMobileOverride: true,
        );

        pool.syncAccounts(<MailAccount>[buildTestAccount()]);
        async.flushMicrotasks();
        expect(factory.createdCount, 1);

        manager.didChangeAppLifecycleState(AppLifecycleState.inactive);
        manager.didChangeAppLifecycleState(AppLifecycleState.paused);
        async.elapse(const Duration(seconds: 30));

        // The grace timer fired and the LOGOUT is still in flight.
        expect(pool.isBackgroundReleased, isTrue);
        expect(factory.totalLogoutCount, 0);

        manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
        async.flushMicrotasks();
        expect(
          factory.createdCount,
          1,
          reason: 'reconnect must wait for the pending release to complete',
        );

        async.elapse(const Duration(milliseconds: 50));
        async.flushMicrotasks();
        expect(factory.totalLogoutCount, 1);
        expect(pool.isBackgroundReleased, isFalse);
        expect(factory.createdCount, 1);

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(factory.createdCount, 2);
        expect(factory.activeCount, 1);
        expect(
          factory.protocolLog.indexOf('logout:1') <
              factory.protocolLog.indexOf('connect:2'),
          isTrue,
          reason: 'old LOGOUT must precede the reconnected socket',
        );

        pool.dispose();
        async.flushMicrotasks();
      });
    });

    test('desktop background never triggers the mobile 30s logout', () {
      fakeAsync((async) {
        final factory = FakeImapSessionFactory();
        final pool = ConnectionPool(
          sessionFactory: factory,
          credentialResolver: fakeCredentialResolver,
        );
        final manager = AppLifecycleManager(
          connectionPool: pool,
          isMobileOverride: false,
        );

        pool.syncAccounts(<MailAccount>[buildTestAccount()]);
        async.flushMicrotasks();
        expect(factory.createdCount, 1);
        expect(factory.activeCount, 1);

        manager.didChangeAppLifecycleState(AppLifecycleState.inactive);
        manager.didChangeAppLifecycleState(AppLifecycleState.paused);
        manager.didChangeAppLifecycleState(AppLifecycleState.hidden);
        async.elapse(const Duration(minutes: 2));
        async.flushMicrotasks();

        expect(manager.isGraceTimerActive, isFalse);
        expect(factory.totalLogoutCount, 0);
        expect(factory.activeCount, 1);

        manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
        async.flushMicrotasks();
        expect(factory.createdCount, 1);
        expect(factory.activeCount, 1);

        pool.dispose();
        async.flushMicrotasks();
      });
    });
  });
}
