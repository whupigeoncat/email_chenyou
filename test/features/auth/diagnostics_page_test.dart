import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/logging/sanitized_logger.dart';
import 'package:local_mail_client/core/network/account_connection_slot.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/auth/presentation/pages/diagnostics_page.dart';
import 'package:local_mail_client/features/mail/domain/entities/local_cache_stats.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';

import '../mail/support/mail_fixture.dart';

void main() {
  testWidgets('diagnostics shows slot states, counts and sanitized logs',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final second = MailAccount(
      id: 'acc-2',
      email: 'second@example.com',
      displayName: 'Second',
      providerType: fixture.account.providerType,
      authType: fixture.account.authType,
      colorValue: 0xFF112233,
      imapHost: 'imap.example.com',
      imapPort: 993,
      imapImplicitTls: true,
      smtpHost: 'smtp.example.com',
      smtpPort: 465,
      smtpImplicitTls: true,
      createdAt: DateTime.utc(2026),
    );
    final logger = SanitizedLogger.instance;
    logger.clear();
    addTearDown(logger.clear);
    logger.debug('DiagnosticsTest', 'access_token=super-secret-token');
    logger.debug(
      'DiagnosticsTest',
      'Authorization: Bearer abc123-secret',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value(
              [fixture.account, second],
            ),
          ),
          accountSlotStatesProvider.overrideWith(
            (ref) => Stream<Map<String, ConnectionSlotState>>.value(
              const {
                'acc-1': ConnectionSlotState.idleInInbox,
                'acc-2': ConnectionSlotState.pollingInInbox,
              },
            ),
          ),
          outboxCountsProvider.overrideWith(
            (ref) => Stream<OutboxCounts>.value(
              const OutboxCounts(
                drafts: 1,
                queued: 2,
                failed: 3,
                uncertain: 4,
                sent: 5,
              ),
            ),
          ),
          localCacheStatsProvider.overrideWith(
            (ref) async => LocalCacheStats(
              folders: 6,
              emails: 10000,
              unread: 42,
              lastSyncedAt: DateTime.utc(2026, 1, 2, 3, 4),
            ),
          ),
        ],
        child: const MaterialApp(home: DiagnosticsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diagnostics-page')), findsOneWidget);
    expect(find.textContaining('idleInInbox'), findsWidgets);
    expect(find.textContaining('pollingInInbox'), findsWidgets);
    expect(find.textContaining('收件箱轮询中'), findsNothing);
    expect(find.text('草稿 1'), findsOneWidget);
    expect(find.text('等待发送 2'), findsOneWidget);
    expect(find.text('失败 3'), findsOneWidget);
    expect(find.text('待确认 4'), findsOneWidget);
    expect(find.text('已发送 5'), findsOneWidget);
    expect(find.text('本地缓存'), findsOneWidget);
    expect(find.text('文件夹 6'), findsOneWidget);
    expect(find.text('邮件 10000'), findsOneWidget);
    expect(find.text('未读 42'), findsOneWidget);
    expect(find.textContaining('最近同步'), findsOneWidget);
    expect(find.textContaining('[REDACTED]'), findsWidgets);
    expect(find.textContaining('super-secret-token'), findsNothing);
    expect(find.textContaining('abc123-secret'), findsNothing);
    expect(find.byKey(const Key('diagnostics-refresh')), findsOneWidget);
    expect(find.byKey(const Key('diagnostics-copy')), findsOneWidget);
  });
}
