import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/network/connection_pool.dart';
import 'package:local_mail_client/core/network/connectivity_monitor.dart';

import 'support/fake_imap_session.dart';

class _RecordingConnectionPool extends ConnectionPool {
  _RecordingConnectionPool()
      : super(
          sessionFactory: FakeImapSessionFactory(),
          credentialResolver: fakeCredentialResolver,
        );

  int restoreCalls = 0;

  @override
  Future<void> handleNetworkRestored() async {
    restoreCalls++;
  }
}

void main() {
  test('first connectivity sample is a baseline; only real changes reconnect',
      () {
    fakeAsync((async) {
      final controller =
          StreamController<List<ConnectivityResult>>.broadcast();
      final pool = _RecordingConnectionPool();
      final monitor = ConnectivityMonitor(
        connectionPool: pool,
        connectivityStream: controller.stream,
      );
      monitor.start();

      controller.add(<ConnectivityResult>[ConnectivityResult.wifi]);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      expect(
        pool.restoreCalls,
        0,
        reason: 'the app-init first frame must not rebuild connections',
      );

      controller.add(<ConnectivityResult>[ConnectivityResult.wifi]);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      expect(pool.restoreCalls, 0, reason: 'same online state is a no-op');

      controller.add(<ConnectivityResult>[ConnectivityResult.none]);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      expect(pool.restoreCalls, 0);

      controller.add(<ConnectivityResult>[ConnectivityResult.wifi]);
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 899));
      expect(pool.restoreCalls, 0, reason: '900ms debounce not elapsed');
      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();
      expect(pool.restoreCalls, 1, reason: 'offline -> online recovery');

      controller.add(<ConnectivityResult>[ConnectivityResult.mobile]);
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 900));
      async.flushMicrotasks();
      expect(pool.restoreCalls, 2, reason: 'genuine interface type switch');

      controller.add(<ConnectivityResult>[ConnectivityResult.mobile]);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      expect(pool.restoreCalls, 2);

      // Going offline must cancel a debounce that is already pending.
      controller.add(<ConnectivityResult>[ConnectivityResult.wifi]);
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 300));
      controller.add(<ConnectivityResult>[ConnectivityResult.none]);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      expect(pool.restoreCalls, 2);

      unawaited(monitor.dispose());
      unawaited(pool.dispose());
      async.flushMicrotasks();
      unawaited(controller.close());
    });
  });
}
