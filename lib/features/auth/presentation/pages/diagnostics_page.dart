import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../core/logging/sanitized_logger.dart';
import '../../../../core/network/account_connection_slot.dart';
import '../../domain/entities/mail_account.dart';
import '../../../mail/domain/entities/outbox_message.dart';
import '../../../mail/presentation/providers/mail_providers.dart';

/// Read-only connection diagnostics. Never reads secure storage and never
/// exposes a switch that could enable plaintext protocol logging.
class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends ConsumerState<DiagnosticsPage> {
  int _refreshTick = 0;

  @override
  Widget build(BuildContext context) {
    _refreshTick; // rebuilds the log snapshot on refresh
    final accounts = ref.watch(accountsProvider).value ?? const <MailAccount>[];
    final slots = ref.watch(accountSlotStatesProvider).value ??
        const <String, ConnectionSlotState>{};
    final counts = ref.watch(outboxCountsProvider).value ?? const OutboxCounts();
    final cache = ref.watch(localCacheStatsProvider);
    final logs = SanitizedLogger.instance.recentEntries
        .map(SanitizedLogger.sanitize)
        .toList(growable: false)
        .reversed
        .toList(growable: false);

    return Scaffold(
      key: const Key('diagnostics-page'),
      appBar: AppBar(
        title: const Text('连接与诊断'),
        actions: [
          IconButton(
            key: const Key('diagnostics-refresh'),
            tooltip: '刷新',
            onPressed: () {
              ref.invalidate(localCacheStatsProvider);
              setState(() => _refreshTick++);
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            key: const Key('diagnostics-copy'),
            tooltip: '复制脱敏日志',
            onPressed: logs.isEmpty
                ? null
                : () async {
                    final safe = logs
                        .map(SanitizedLogger.sanitize)
                        .join('\n');
                    await Clipboard.setData(ClipboardData(text: safe));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制脱敏日志')),
                    );
                  },
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('连接槽位', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (accounts.isEmpty)
            const Text('暂无账户')
          else
            for (final account in accounts)
              Card(
                key: ValueKey('diagnostics-slot-${account.id}'),
                child: ListTile(
                  dense: true,
                  title: Text(account.email),
                  subtitle: Text(
                    slots[account.id]?.name ?? 'disconnected',
                  ),
                  trailing: Text(
                    slots[account.id]?.name ?? 'disconnected',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
          const SizedBox(height: 16),
          Text('发件箱统计', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('草稿 ${counts.drafts}')),
              Chip(label: Text('等待发送 ${counts.queued}')),
              Chip(label: Text('发送中 ${counts.sending}')),
              Chip(label: Text('失败 ${counts.failed}')),
              Chip(label: Text('待确认 ${counts.uncertain}')),
              Chip(label: Text('已发送 ${counts.sent}')),
            ],
          ),
          const SizedBox(height: 16),
          Text('本地缓存', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          cache.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => Text('读取缓存统计失败：$error'),
            data: (stats) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('文件夹 ${stats.folders}')),
                Chip(label: Text('邮件 ${stats.emails}')),
                Chip(label: Text('未读 ${stats.unread}')),
                Chip(
                  label: Text(
                    '最近同步 ${stats.lastSyncedAt == null ? "无" : DateFormat("MM-dd HH:mm").format(stats.lastSyncedAt!.toLocal())}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('脱敏诊断日志', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (logs.isEmpty)
            const Text('暂无日志')
          else
            for (final line in logs)
              SelectableText(
                line,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
        ],
      ),
    );
  }
}
