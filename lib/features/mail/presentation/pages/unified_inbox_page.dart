import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/mail_theme.dart';
import '../../../../app/widgets/mail_filter_switch.dart';
import '../../domain/entities/unified_email.dart';
import '../providers/unified_inbox_provider.dart';
import 'email_detail_page.dart';

class UnifiedInboxPage extends ConsumerWidget {
  const UnifiedInboxPage({
    super.key,
    this.embedded = false,
    this.onOpenEmail,
    this.showTitle = true,
    this.scopeLabel,
  });

  final bool embedded;
  final ValueChanged<UnifiedEmail>? onOpenEmail;

  /// The phone shell already owns the blue title header, so it hides this one.
  final bool showTitle;

  /// Human-readable account scope supplied by the shell.
  final String? scopeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(unifiedInboxViewProvider);
    final emails = ref.watch(inboxEmailsProvider);
    final notifier = ref.read(unifiedInboxViewProvider.notifier);
    final bottomInset = MediaQuery.paddingOf(context).bottom + 8;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) _InboxHeading(view: view, scopeLabel: scopeLabel),
        _FilterBar(
          view: view,
          onSync: notifier.syncCurrent,
          onToggleUnread: notifier.toggleUnreadOnly,
        ),
        if (view.errorMessage != null)
          _ErrorBanner(message: view.errorMessage!),
        Expanded(
          child: emails.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('读取邮件失败：$error', textAlign: TextAlign.center),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: notifier.syncCurrent,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(24, 72, 24, bottomInset),
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        size: 44,
                        color: MailColors.muted(context),
                      ),
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
                    padding: EdgeInsets.only(bottom: bottomInset),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 72,
                      endIndent: 20,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
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
      appBar: AppBar(title: const Text('本地邮箱')),
      body: content,
    );
  }

  Widget _detailRoute(UnifiedEmail email) {
    // Imported lazily to keep this page independent from the shell.
    return EmailDetailPage(emailLocalId: email.localId);
  }
}

class _InboxHeading extends StatelessWidget {
  const _InboxHeading({required this.view, required this.scopeLabel});

  final UnifiedInboxViewState view;
  final String? scopeLabel;

  @override
  Widget build(BuildContext context) {
    final title = view.folder?.displayName ?? '收件箱';
    final scope = scopeLabel ?? (view.accountId == null ? '所有邮箱' : '当前邮箱');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 3),
          Text(
            scope,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: MailColors.muted(context)),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
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
      padding: const EdgeInsets.fromLTRB(20, 6, 10, 8),
      child: Row(
        children: [
          MailFilterSwitch(
            labels: const ['全部', '未读'],
            selectedIndex: view.unreadOnly ? 1 : 0,
            onSelected: (index) {
              final targetUnread = index == 1;
              if (targetUnread != view.unreadOnly) onToggleUnread();
            },
            segmentKeys: const [
              Key('inbox-filter-all'),
              Key('toggle-unread-filter'),
            ],
          ),
          const Spacer(),
          IconButton(
            key: const Key('sync-inbox'),
            tooltip: '同步',
            color: MailColors.muted(context),
            onPressed: view.isSyncing ? null : onSync,
            icon: view.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: scheme.onErrorContainer),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = !email.isRead;
    final sender = email.senderDisplay.trim().isEmpty
        ? email.fromAddress
        : email.senderDisplay;
    final subject = email.subject.isEmpty ? '(无主题)' : email.subject;
    final snippet = email.snippet.trim();
    final timeLabel = _timeLabel(email.sentAt);
    final timeStyle = (theme.textTheme.labelSmall ?? const TextStyle())
        .copyWith(
          color: MailColors.muted(context),
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final timePainter = TextPainter(
      text: TextSpan(text: timeLabel, style: timeStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final timeWidth = timePainter.width;
    timePainter.dispose();
    // Keep the 48dp star target, but let the scaled timestamp widen its own
    // column instead of clipping the last digit at large system font sizes.
    final trailingWidth = math.max(48.0, timeWidth + 6);

    return Dismissible(
      key: ValueKey('dismiss-${email.accountId}-${email.uid}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.primaryContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(
          Icons.mark_email_read_outlined,
          color: scheme.onPrimaryContainer,
        ),
      ),
      confirmDismiss: (_) async {
        onToggleRead();
        // The flag update changes the row in place; do not remove it from the
        // list because the reactive stream still contains the email.
        return false;
      },
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 110),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SenderAvatar(sender: sender),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (unread) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: MailColors.brandBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              sender,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: unread
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (snippet.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          snippet,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: MailColors.muted(context),
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Color(email.accountColorValue),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              email.accountEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: MailColors.muted(context),
                              ),
                            ),
                          ),
                          if (email.hasAttachments) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.attach_file,
                              size: 13,
                              color: MailColors.muted(context),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: trailingWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 4),
                        child: Text(
                          timeLabel,
                          key: ValueKey(
                            'email-time-${email.accountId}-${email.uid}',
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: timeStyle,
                        ),
                      ),
                      IconButton(
                        tooltip: email.isFlagged ? '取消星标' : '添加星标',
                        onPressed: onToggleStar,
                        color: email.isFlagged
                            ? MailColors.warning(context)
                            : MailColors.muted(context),
                        icon: Icon(
                          email.isFlagged ? Icons.star : Icons.star_border,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _timeLabel(DateTime date) {
    final now = DateTime.now();
    final local = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final difference = today.difference(day).inDays;
    if (difference <= 0) return DateFormat('HH:mm').format(local);
    if (difference == 1) return '昨天';
    if (local.year == now.year) return DateFormat('MM/dd').format(local);
    return DateFormat('yyyy/MM/dd').format(local);
  }
}

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.sender});

  final String sender;

  @override
  Widget build(BuildContext context) {
    final trimmed = sender.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MailColors.avatarTint(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        initial,
        maxLines: 1,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: MailColors.avatarInk(context),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
