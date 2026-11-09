import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/outbox_message.dart';
import '../providers/mail_providers.dart';
import 'compose_email_page.dart';

class OutboxQueuePage extends ConsumerStatefulWidget {
  const OutboxQueuePage({super.key});

  @override
  ConsumerState<OutboxQueuePage> createState() => _OutboxQueuePageState();
}

class _OutboxQueuePageState extends ConsumerState<OutboxQueuePage> {
  final Set<String> _busy = <String>{};

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(outboxMessagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('草稿与发件箱')),
      body: messagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('读取发件箱失败：$error')),
        data: (messages) {
          if (messages.isEmpty) {
            return const Center(child: Text('草稿与发件箱为空'));
          }
          return ListView.separated(
            key: const Key('outbox-message-list'),
            padding: const EdgeInsets.all(12),
            itemCount: messages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _buildMessageTile(context, messages[index]),
          );
        },
      ),
    );
  }

  Widget _buildMessageTile(BuildContext context, OutboxMessage message) {
    final statusColor = switch (message.status) {
      OutboxStatus.draft => Colors.blueGrey,
      OutboxStatus.queued => Colors.orange,
      OutboxStatus.sending => Colors.blue,
      OutboxStatus.failed => Colors.red,
      OutboxStatus.uncertain => Colors.deepOrange,
      OutboxStatus.sent => Colors.green,
    };
    final recipients = message.to.map((entry) => entry.displayLabel).join(', ');
    final isSending = message.status == OutboxStatus.sending;
    return Card(
      key: ValueKey('outbox-message-${message.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    message.subject.isEmpty ? '(无主题)' : message.subject,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    message.status.labelZh,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              recipients.isEmpty ? '未填写收件人' : recipients,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              '${message.mode.labelZh} · ${DateFormat('MM-dd HH:mm').format(message.updatedAt.toLocal())}'
              '${message.retryCount > 0 ? ' · 已重试 ${message.retryCount} 次' : ''}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (message.status == OutboxStatus.uncertain) ...[
              const SizedBox(height: 6),
              Text(
                '投递状态不确定：服务器可能已接收该邮件。已暂停自动重试，'
                '请核对后选择“确认重发”或“标记为已发送”。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            if (message.lastError != null &&
                (message.status != OutboxStatus.sent ||
                    !message.sentCopySaved)) ...[
              const SizedBox(height: 6),
              Text(
                message.lastError!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            if (message.status == OutboxStatus.sent)
              Text(message.sentCopySaved ? '服务器副本已保存' : '已发送，本地副本保留，服务器副本待核对'),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (message.status == OutboxStatus.sent &&
                    !message.sentCopySaved)
                  TextButton(
                    key: Key('save-sent-copy-${message.id}'),
                    onPressed: _busy.contains(message.id)
                        ? null
                        : () => _saveSentCopy(message),
                    child: const Text('补存已发送副本'),
                  ),
                if (message.status == OutboxStatus.uncertain) ...[
                  TextButton(
                    key: Key('mark-sent-${message.id}'),
                    onPressed: _busy.contains(message.id)
                        ? null
                        : () => _markSent(message),
                    child: const Text('标记为已发送'),
                  ),
                  TextButton(
                    key: Key('confirm-resend-${message.id}'),
                    onPressed: _busy.contains(message.id)
                        ? null
                        : () => _confirmUncertainResend(message),
                    child: const Text('确认重发'),
                  ),
                ] else if (message.retryable &&
                    (message.status == OutboxStatus.failed ||
                        message.status == OutboxStatus.queued))
                  TextButton(
                    key: Key('retry-outbox-${message.id}'),
                    onPressed: _busy.contains(message.id)
                        ? null
                        : () => _retry(message),
                    child: const Text('立即重试'),
                  ),
                IconButton(
                  key: Key('delete-outbox-${message.id}'),
                  tooltip: isSending ? '发送中暂不可删除' : '删除',
                  onPressed: (_busy.contains(message.id) || isSending)
                      ? null
                      : () => _delete(message),
                  icon: const Icon(Icons.delete_outline),
                ),
                if (message.status == OutboxStatus.draft ||
                    message.status == OutboxStatus.failed)
                  TextButton(
                    key: Key('edit-outbox-${message.id}'),
                    onPressed: _busy.contains(message.id)
                        ? null
                        : () => _edit(context, message),
                    child: const Text('编辑'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSentCopy(OutboxMessage message) async {
    setState(() => _busy.add(message.id));
    try {
      await ref.read(sentCopyServiceProvider).save(message.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('服务器副本已保存')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AppFailure ? error.userMessage : '补存失败，本地副本已保留',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(message.id));
    }
  }

  Future<void> _retry(OutboxMessage message) async {
    setState(() => _busy.add(message.id));
    try {
      await ref.read(retryOutboxMessageUseCaseProvider).call(message.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已重新加入发送队列')));
    } catch (error) {
      if (!mounted) return;
      final text = error is AppFailure ? error.userMessage : '重试失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy.remove(message.id));
    }
  }

  Future<void> _confirmUncertainResend(OutboxMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重发？'),
        content: const Text(
          '服务器可能已经接收这封邮件，重发可能产生重复邮件。'
          '请先确认收件人没有收到后再继续。',
        ),
        actions: [
          TextButton(
            key: const Key('cancel-uncertain-resend'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-uncertain-resend'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认重发'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _retry(message);
  }

  Future<void> _markSent(OutboxMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('标记为已发送？'),
        content: const Text('该操作不会再次发送邮件，仅结束本地待确认状态。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-mark-sent'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('标记为已发送'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(message.id));
    try {
      await ref.read(markOutboxMessageSentUseCaseProvider).call(message.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已标记为已发送')));
    } catch (error) {
      if (!mounted) return;
      final text = error is AppFailure ? error.userMessage : '操作失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy.remove(message.id));
    }
  }

  Future<void> _delete(OutboxMessage message) async {
    if (message.status == OutboxStatus.sending) return;
    setState(() => _busy.add(message.id));
    try {
      await ref.read(deleteOutboxMessageUseCaseProvider).call(message.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已删除')));
    } catch (error) {
      if (!mounted) return;
      final text = error is AppFailure ? error.userMessage : '删除失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy.remove(message.id));
    }
  }

  Future<void> _edit(BuildContext context, OutboxMessage message) async {
    ref.read(outboxQueueProvider).cancelRetry(message.id);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ComposeEmailPage(
          draft: message.toComposeDraft(),
          draftId: message.id,
        ),
      ),
    );
  }
}
