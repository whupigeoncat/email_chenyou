import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/imap_session.dart';
import '../../../core/constants/provider_presets.dart';
import '../../auth/domain/entities/mail_account.dart';
import 'inbox_notification_state_store.dart';

typedef BackgroundNotificationSender = Future<bool> Function(int newMailCount);
typedef BackgroundCancelCheck = Future<bool> Function();

class BackgroundCheckReport {
  const BackgroundCheckReport({
    required this.accountsSeen,
    required this.accountsSkipped,
    required this.notifiedMailCount,
    required this.failures,
    required this.cancelled,
    required this.deadlineExceeded,
  });

  final int accountsSeen;
  final int accountsSkipped;
  final int notifiedMailCount;
  final int failures;
  final bool cancelled;
  final bool deadlineExceeded;
}

class _AccountProbe {
  const _AccountProbe({
    required this.accountId,
    required this.uidValidity,
    required this.observedUid,
    required this.unreadCount,
    required this.baselineRequired,
  });

  final String accountId;
  final int? uidValidity;
  final int observedUid;
  final int unreadCount;
  final bool baselineRequired;
}

class _CheckTimeout implements Exception {
  const _CheckTimeout();
}

class _NotificationFailed implements Exception {
  const _NotificationFailed();
}

/// Headless INBOX check used by the Android JobService.
///
/// It deliberately does not use ConnectionPool, AppRuntime, or
/// AuthRepository.initialize: no IDLE, no full sync, no body/attachment fetch.
class BackgroundMailChecker {
  BackgroundMailChecker({
    required this.database,
    required this.stateStore,
    required this.sessionFactory,
    required this.credentialResolver,
    required this.notify,
    required this.isCancelled,
    DateTime Function()? clock,
    this.perAccountTimeout = const Duration(seconds: 20),
    this.totalTimeout = const Duration(seconds: 55),
    this.retryBase = const Duration(minutes: 15),
    this.retryMax = const Duration(hours: 6),
  }) : clock = clock ?? DateTime.now;

  final AppDatabase database;
  final InboxNotificationStateStore stateStore;
  final ImapSessionFactory sessionFactory;
  final CredentialResolver credentialResolver;
  final BackgroundNotificationSender notify;
  final BackgroundCancelCheck isCancelled;
  final DateTime Function() clock;
  final Duration perAccountTimeout;
  final Duration totalTimeout;
  final Duration retryBase;
  final Duration retryMax;

  Future<BackgroundCheckReport> run() async {
    final started = clock().toUtc();
    final deadline = started.add(totalTimeout);
    final accounts = await _enabledAccounts();
    if (accounts.isEmpty) {
      return const BackgroundCheckReport(
        accountsSeen: 0,
        accountsSkipped: 0,
        notifiedMailCount: 0,
        failures: 0,
        cancelled: false,
        deadlineExceeded: false,
      );
    }

    final pending = <_AccountProbe>[];
    var seen = 0;
    var skipped = 0;
    var failures = 0;
    var cancelled = false;
    var deadlineExceeded = false;

    for (final account in accounts) {
      if (await _cancelled()) {
        cancelled = true;
        break;
      }
      final now = clock().toUtc();
      if (!now.isBefore(deadline)) {
        deadlineExceeded = true;
        break;
      }

      final state = await stateStore.get(account.id);
      final retryAt = state?.nextRetryAt;
      if (retryAt != null && retryAt.isAfter(now)) {
        skipped++;
        continue;
      }

      final remaining = deadline.difference(now);
      final timeout = remaining < perAccountTimeout
          ? remaining
          : perAccountTimeout;
      if (timeout <= Duration.zero) {
        deadlineExceeded = true;
        break;
      }

      try {
        final probe = await _checkAccount(account: account, timeout: timeout);
        // The network operation has no DB writes. Commit or notify only after
        // a fresh cancellation check; a timed-out network future can never
        // reach a SQL write.
        if (await _cancelled()) {
          cancelled = true;
          break;
        }
        seen++;
        if (probe.baselineRequired) {
          await stateStore.saveBaseline(
            accountId: probe.accountId,
            uidValidity: probe.uidValidity,
            lastUid: probe.observedUid,
          );
        } else if (probe.unreadCount > 0) {
          pending.add(probe);
        } else {
          await stateStore.recordSuccess(
            accountId: probe.accountId,
            uidValidity: probe.uidValidity,
            lastNotifiedUid: probe.observedUid,
          );
        }
      } catch (error) {
        failures++;
        // Timeouts and network failures are already bounded per account; the
        // next periodic run respects this exponential backoff.
        final count = (state?.failureCount ?? 0) + 1;
        final delay = _backoff(count);
        await stateStore.recordFailure(
          accountId: account.id,
          kind: _failureKind(error),
          nextRetryAt: clock().toUtc().add(delay),
          failureCount: count,
        );
      }
    }

    var notified = 0;
    if (pending.isNotEmpty && !cancelled && !await _cancelled()) {
      final unread = pending.fold<int>(
        0,
        (sum, item) => sum + item.unreadCount,
      );
      try {
        final shown = await notify(unread);
        if (!shown) throw const _NotificationFailed();
        notified = unread;
        for (final item in pending) {
          await stateStore.recordSuccess(
            accountId: item.accountId,
            uidValidity: item.uidValidity,
            lastNotifiedUid: item.observedUid,
          );
        }
      } catch (error) {
        failures += pending.length;
        for (final item in pending) {
          final previous = await stateStore.get(item.accountId);
          final count = (previous?.failureCount ?? 0) + 1;
          await stateStore.recordFailure(
            accountId: item.accountId,
            kind: _failureKind(error),
            nextRetryAt: clock().toUtc().add(_backoff(count)),
            failureCount: count,
          );
        }
      }
    }

    return BackgroundCheckReport(
      accountsSeen: seen,
      accountsSkipped: skipped,
      notifiedMailCount: notified,
      failures: failures,
      cancelled: cancelled,
      deadlineExceeded: deadlineExceeded,
    );
  }

  Future<_AccountProbe> _checkAccount({
    required MailAccount account,
    required Duration timeout,
  }) async {
    final session = sessionFactory.createSession();
    final run = _AccountRun();
    final operation = () async {
      final credential = await credentialResolver(account);
      if (run.cancelled) throw const _CheckTimeout();
      // A timed-out credential lookup must never leak into a new socket.
      await session.connectAndAuthenticate(
        account: account,
        credential: credential,
      );
      if (run.cancelled) throw const _CheckTimeout();

      final status = await session.selectFolderWithStatus('INBOX');
      if (run.cancelled) throw const _CheckTimeout();
      final uidValidity = status.uidValidity;
      final local = await _localInbox(account.id);
      if (run.cancelled) throw const _CheckTimeout();
      final state = await stateStore.get(account.id);
      if (run.cancelled) throw const _CheckTimeout();
      final hasBaseline = state?.baselineEstablished ?? false;
      // A null UIDVALIDITY cannot prove that UIDs were not reused. Stay
      // conservative (re-baseline, no notice) instead of treating "unknown" as
      // a valid identity. Servers that omit UIDVALIDITY still get a baseline,
      // but background notices wait until the server provides one.
      final validityUnknown =
          hasBaseline && (state!.uidValidity == null || uidValidity == null);
      final validityChanged =
          hasBaseline &&
          state!.uidValidity != null &&
          uidValidity != null &&
          state.uidValidity != uidValidity;

      if (!hasBaseline || validityChanged || validityUnknown) {
        final remoteMax = await _remoteMaxUid(session, status);
        if (run.cancelled) throw const _CheckTimeout();
        // Local UIDs are only comparable when the local folder was cached
        // under the same UIDVALIDITY. After a reset, old local high UIDs would
        // otherwise push the baseline too far and hide genuinely new mail.
        final localComparable =
            uidValidity != null && local.uidValidity == uidValidity;
        final baseline = validityChanged || !localComparable
            ? remoteMax
            : math.max(local.maxUid, remoteMax);
        if (run.cancelled) throw const _CheckTimeout();
        return _AccountProbe(
          accountId: account.id,
          uidValidity: uidValidity,
          observedUid: baseline,
          unreadCount: 0,
          baselineRequired: true,
        );
      }

      // A foreground sync may have shown mail before this check. Never notify
      // anything already present in the local cache, even if the watermark
      // write from the foreground was lost.
      final localComparable =
          uidValidity != null && local.uidValidity == uidValidity;
      final watermark = math.max(
        state!.lastNotifiedUid,
        localComparable ? local.maxUid : 0,
      );
      final search = await session.searchNewMailUids(fromUid: watermark + 1);
      if (run.cancelled) throw const _CheckTimeout();
      var observed = watermark;
      for (final uid in search.allUids) {
        // `fromUid:*` can echo the last existing UID when nothing newer
        // exists. Only UIDs strictly above the watermark are new.
        if (uid <= watermark || uid <= 0) continue;
        if (uid > observed) observed = uid;
      }
      var unread = 0;
      for (final uid in search.unseenUids) {
        if (uid <= watermark || uid <= 0) continue;
        unread++;
        // The unseen query runs after the all-UID query. A message can arrive
        // between them, so include both maxima in the observed watermark.
        if (uid > observed) observed = uid;
      }
      return _AccountProbe(
        accountId: account.id,
        uidValidity: uidValidity,
        observedUid: observed,
        unreadCount: unread,
        baselineRequired: false,
      );
    }();

    // Mark errors as observed so a late failure after timeout cannot become an
    // unhandled zone error.
    operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});

    try {
      return await operation.timeout(
        timeout,
        onTimeout: () async {
          // Future.timeout does not cancel sockets. Mark the run cancelled and
          // close it before reporting. The late operation checks this flag
          // after every await, so it cannot save a baseline afterwards.
          run.cancelled = true;
          await _forceClose(session);
          throw const _CheckTimeout();
        },
      );
    } finally {
      await _close(session);
    }
  }

  Future<int> _remoteMaxUid(
    ImapSession session,
    RemoteMailboxStatus status,
  ) async {
    final uidNext = status.uidNext;
    if (uidNext != null) return math.max(0, uidNext - 1);
    final recent = await session.fetchMessageHeaders(limit: 1);
    if (recent.isEmpty) return 0;
    return recent.last.uid;
  }

  Future<_LocalInbox> _localInbox(String accountId) async {
    final folder =
        await (database.select(database.dbFolders)
              ..where(
                (table) =>
                    table.accountId.equals(accountId) &
                    table.role.equals('inbox'),
              )
              ..limit(1))
            .getSingleOrNull();
    if (folder == null) return const _LocalInbox(maxUid: 0, uidValidity: null);
    final row = await database
        .customSelect(
          'SELECT MAX(uid) AS max_uid FROM db_emails WHERE folder_id = ?',
          variables: [Variable.withString(folder.id)],
        )
        .getSingle();
    return _LocalInbox(
      maxUid: (row.data['max_uid'] as int?) ?? 0,
      uidValidity: folder.uidValidity,
    );
  }

  Future<List<MailAccount>> _enabledAccounts() async {
    final rows = await (database.select(
      database.dbAccounts,
    )..where((table) => table.isEnabled.equals(true))).get();
    rows.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return rows.map(_accountFromRow).toList(growable: false);
  }

  MailAccount _accountFromRow(DbAccount row) {
    return MailAccount(
      id: row.id,
      email: row.email,
      displayName: row.displayName,
      providerType: MailProviderType.fromStorageKey(row.providerType),
      authType: MailAuthType.fromStorageKey(row.authType),
      colorValue: row.colorValue,
      imapHost: row.imapHost,
      imapPort: row.imapPort,
      imapImplicitTls: row.imapImplicitTls,
      smtpHost: row.smtpHost,
      smtpPort: row.smtpPort,
      smtpImplicitTls: row.smtpImplicitTls,
      isEnabled: row.isEnabled,
      saveSentCopy: row.saveSentCopy,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
    );
  }

  Future<bool> _cancelled() async {
    try {
      return await isCancelled();
    } catch (_) {
      return false;
    }
  }

  Future<void> _close(ImapSession session) async {
    try {
      if (session.isConnected) {
        await session.logoutAndDisconnect(timeout: const Duration(seconds: 2));
      }
    } catch (_) {
      await _forceClose(session);
    }
  }

  Future<void> _forceClose(ImapSession session) async {
    try {
      await session.forceClose();
    } catch (_) {
      // Socket is already gone.
    }
  }

  Duration _backoff(int failureCount) {
    final exponent = math.min(math.max(failureCount - 1, 0), 8);
    final millis = retryBase.inMilliseconds * (1 << exponent);
    return Duration(milliseconds: math.min(millis, retryMax.inMilliseconds));
  }

  String _failureKind(Object error) {
    if (error is _CheckTimeout || error is TimeoutException) return 'timeout';
    if (error is _NotificationFailed) return 'notification';
    if (error is AuthFailure) return 'auth';
    if (error is ImapProtocolFailure) {
      return error.reason.name;
    }
    return 'unknown';
  }
}

class _LocalInbox {
  const _LocalInbox({required this.maxUid, required this.uidValidity});
  final int maxUid;
  final int? uidValidity;
}

class _AccountRun {
  bool cancelled = false;
}
