import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/unified_email.dart';
import '../providers/unified_inbox_provider.dart';
import '../widgets/account_color_badge.dart';
import 'email_detail_page.dart';

class UnifiedInboxPage extends ConsumerWidget {
  const UnifiedInboxPage({super.key, this.embedded = false, this.onOpenEmail});

  final bool embedded;
  final ValueChanged<UnifiedEmail>? onOpenEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(unifiedInboxViewProvider);
    final emails = ref.watch(inboxEmailsProvider);
    final notifier = ref.read(unifiedInboxViewProvider.notifier);

    final content = Column(
      children: [
        _Header(
          view: view,
          onSync: notifier.syncCurrent,
          onToggleUnread: notifier.toggleUnreadOnly,
        ),
        if (view.errorMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Text(
              view.errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        Expanded(
          child: emails.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('读取邮件失败：$error')),
            data: (items) {
              if (items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: notifier.syncCurrent,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 100),
                      const Icon(Icons.mark_email_read_outlined, size: 48),
                      const SizedBox(height: 12),
                      const Center(child: Text('这里暂时没有邮件')),
                      _HistoryButton(view: view, onLoad: notifier.loadMore),
                    ],
                  ),
                );
              }
              return NotificationListener<ScrollEndNotification>(
                onNotification: (notification) {
                  if (notification.metrics.extentAfter < 300) {
                    unawaited(notifier.loadMore());
                  }
                  return false;
                },
                child: RefreshIndicator(
                  onRefresh: notifier.syncCurrent,
                  child: ListView.separated(
                    key: const Key('inbox-email-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return _HistoryButton(
                          view: view,
                          onLoad: notifier.loadMore,
                        );
                      }
                      final email = items[index];
                      return _EmailTile(
                        key: ValueKey(
                          'email-tile-${email.accountId}-${email.uid}',
                        ),
                        email: email,
                        onTap: () {
                          final callback = onOpenEmail;
                          if (callback != null) {
                            callback(email);
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => _detailRoute(email),
                              ),
                            );
                          }
                        },
                        onToggleStar: () => notifier.toggleStar(email),
                        onToggleRead: () => notifier.toggleRead(email),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );

    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text(view.title)),
      body: content,
    );
  }

  Widget _detailRoute(UnifiedEmail email) {
    // Imported lazily to keep this page independent from the shell.
    return EmailDetailPage(emailLocalId: email.localId);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.view,
    required this.onSync,
    required this.onToggleUnread,
  });

  final UnifiedInboxViewState view;
  final Future<void> Function() onSync;
  final VoidCallback onToggleUnread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              view.title,
              style: Theme.of(context).textTheme.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilterChip(
            key: const Key('toggle-unread-filter'),
            label: const Text('仅未读'),
            selected: view.unreadOnly,
            onSelected: (_) => onToggleUnread(),
          ),
          IconButton(
            key: const Key('sync-inbox'),
            tooltip: '同步',
            onPressed: view.isSyncing ? null : onSync,
            icon: view.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
    );
  }
}

class _EmailTile extends StatelessWidget {
  const _EmailTile({
    super.key,
    required this.email,
    required this.onTap,
    required this.onToggleStar,
    required this.onToggleRead,
  });

  final UnifiedEmail email;
  final VoidCallback onTap;
  final VoidCallback onToggleStar;
  final VoidCallback onToggleRead;

  @override
  Widget build(BuildContext context) {
    final unread = !email.isRead;
    return Dismissible(
      key: ValueKey('dismiss-${email.accountId}-${email.uid}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.secondaryContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.mark_email_read_outlined),
      ),
      confirmDismiss: (_) async {
        onToggleRead();
        // The flag update changes the row in place; do not remove it from the
        // list because the reactive stream still contains the email.
        return false;
      },
      child: ListTile(
        onTap: onTap,
        tileColor: unread
            ? Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: 0.16)
            : null,
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AccountColorBadge(colorValue: email.accountColorValue),
            const SizedBox(height: 4),
            Text(
              _timeLabel(email.sentAt),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        title: Text(
          email.subject.isEmpty ? '(无主题)' : email.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        subtitle: Text(
          '${email.senderDisplay} · ${email.snippet}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: email.isFlagged ? '取消星标' : '添加星标',
          onPressed: onToggleStar,
          icon: Icon(
            email.isFlagged ? Icons.star : Icons.star_border,
            color: email.isFlagged ? Colors.amber : null,
          ),
        ),
      ),
    );
  }

  static String _timeLabel(DateTime date) {
    final now = DateTime.now();
    if (now.difference(date).inDays < 1) {
      return DateFormat('HH:mm').format(date.toLocal());
    }
    return DateFormat('MM/dd').format(date.toLocal());
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.view, required this.onLoad});
  final UnifiedInboxViewState view;
  final Future<void> Function() onLoad;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: TextButton.icon(
      key: const Key('load-older-emails'),
      onPressed: view.isLoadingMore || view.isSyncing ? null : onLoad,
      icon: view.isLoadingMore
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.history),
      label: Text(view.isLoadingMore ? '正在加载历史邮件…' : '加载更早邮件'),
    ),
  );
}
