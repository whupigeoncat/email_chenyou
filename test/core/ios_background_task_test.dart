import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/network/connection_pool.dart';
import 'package:local_mail_client/core/network/lifecycle_manager.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';

import 'support/fake_imap_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('iOS background task begins, 29s cancel ends, 30s logout ends', () {
    fakeAsync((async) {
      final factory = FakeImapSessionFactory();
      final pool = ConnectionPool(
        sessionFactory: factory,
        credentialResolver: fakeCredentialResolver,
      );
      var beginCount = 0;
      var endCount = 0;
      final manager = AppLifecycleManager(
        connectionPool: pool,
        isMobileOverride: true,
        isIOSOverride: true,
        beginPlatformBackgroundTask: () async => beginCount++,
        endPlatformBackgroundTask: () async => endCount++,
        onPlatformBackgroundExpiring: (_) {},
      );
      manager.start();
      pool.syncAccounts(<MailAccount>[buildTestAccount()]);
      async.flushMicrotasks();

      manager.didChangeAppLifecycleState(AppLifecycleState.inactive);
      manager.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.flushMicrotasks();
      expect(beginCount, 1);
      expect(manager.hasPlatformBackgroundTask, isTrue);
      expect(manager.isGraceTimerActive, isTrue);

      async.elapse(const Duration(seconds: 29));
      manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(endCount, 1);
      expect(manager.hasPlatformBackgroundTask, isFalse);
      expect(factory.totalLogoutCount, 0);

      manager.didChangeAppLifecycleState(AppLifecycleState.inactive);
      manager.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.flushMicrotasks();
      expect(beginCount, 2);
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(factory.totalLogoutCount, 1);
      expect(endCount, 2);
      expect(manager.hasPlatformBackgroundTask, isFalse);

      manager.stop();
      pool.dispose();
      async.flushMicrotasks();
    });
  });

  test('iOS expiration callback releases IMAP immediately and ends task', () {
    fakeAsync((async) {
      final factory = FakeImapSessionFactory();
      final pool = ConnectionPool(
        sessionFactory: factory,
        credentialResolver: fakeCredentialResolver,
      );
      var beginCount = 0;
      var endCount = 0;
      VoidCallback? expiration;
      final manager = AppLifecycleManager(
        connectionPool: pool,
        isMobileOverride: true,
        isIOSOverride: true,
        beginPlatformBackgroundTask: () async => beginCount++,
        endPlatformBackgroundTask: () async => endCount++,
        onPlatformBackgroundExpiring: (handler) => expiration = handler,
      );
      manager.start();
      pool.syncAccounts(<MailAccount>[buildTestAccount()]);
      async.flushMicrotasks();

      manager.didChangeAppLifecycleState(AppLifecycleState.inactive);
      manager.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.flushMicrotasks();
      expect(beginCount, 1);
      expect(expiration, isNotNull);

      expiration!.call();
      async.flushMicrotasks();
      expect(factory.totalLogoutCount, 1);
      expect(manager.isGraceTimerActive, isFalse);
      expect(endCount, 1);
      expect(manager.hasPlatformBackgroundTask, isFalse);

      manager.stop();
      pool.dispose();
      async.flushMicrotasks();
    });
  });

  test('non-iOS mobile background never calls platform task hooks', () {
    fakeAsync((async) {
      final factory = FakeImapSessionFactory();
      final pool = ConnectionPool(
        sessionFactory: factory,
        credentialResolver: fakeCredentialResolver,
      );
      var beginCount = 0;
      var endCount = 0;
      VoidCallback? expiration;
      final manager = AppLifecycleManager(
        connectionPool: pool,
        isMobileOverride: true,
        isIOSOverride: false,
        beginPlatformBackgroundTask: () async => beginCount++,
        endPlatformBackgroundTask: () async => endCount++,
        onPlatformBackgroundExpiring: (handler) => expiration = handler,
      );
      manager.start();
      pool.syncAccounts(<MailAccount>[buildTestAccount()]);
      async.flushMicrotasks();

      manager.didChangeAppLifecycleState(AppLifecycleState.inactive);
      manager.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.flushMicrotasks();
      expect(beginCount, 0);
      expect(expiration, null);
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(factory.totalLogoutCount, 1);
      expect(endCount, 0);

      manager.stop();
      pool.dispose();
      async.flushMicrotasks();
    });
  });
}
