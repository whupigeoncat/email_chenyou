import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_runtime_providers.dart';
import '../../../../app/di/core_providers.dart';
import '../../../../core/network/account_connection_slot.dart';
import '../../../auth/domain/entities/mail_account.dart';
import '../../../auth/presentation/pages/account_manage_page.dart';
import '../../../auth/presentation/pages/add_account_wizard_page.dart';
import '../../domain/entities/mail_folder.dart';
import '../../domain/entities/outbox_message.dart';
import '../providers/mail_providers.dart';
import '../providers/unified_inbox_provider.dart';
import '../widgets/account_color_badge.dart';
import 'compose_email_page.dart';
import 'email_detail_page.dart';
import 'outbox_queue_page.dart';
import 'search_emails_page.dart';
import 'unified_inbox_page.dart';

/// Root mail shell: three panes on desktop, drawer + list + pushed detail on
/// mobile. Connection status shown here comes from the Phase 1 pool slots.
class MailShellPage extends ConsumerStatefulWidget {
  const MailShellPage({super.key});

  @override
  ConsumerState<MailShellPage> createState() => _MailShellPageState();
}

class _MailShellPageState extends ConsumerState<MailShellPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int? _selectedEmailLocalId;

  @override
  Widget build(BuildContext context) {
    ref.watch(appRuntimeProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final slotsAsync = ref.watch(accountSlotStatesProvider);
    final view = ref.watch(unifiedInboxViewProvider);
    final accounts = accountsAsync.value ?? const <MailAccount>[];
    final slots = slotsAsync.value ?? const <String, ConnectionSlotState>{};

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 960;
        if (!desktop) {
          return _buildMobile(
            context,
            accounts,
            slots,
            view,
            accountsAsync,
          );
        }
        return Scaffold(
          appBar: _buildAppBar(context),
          body: Row(
            children: [
              SizedBox(
                width: 280,
                child: _buildSidebar(
                  context,
                  accounts,
                  slots,
                  view,
                  accountsAsync.error,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 5,
                child: accounts.isEmpty
                    ? _EmptyAccountCard(onAdd: () => _openAddAccount(context))
                    : UnifiedInboxPage(
                        embedded: true,
                        onOpenEmail: (email) {
                          setState(() =>
                              _selectedEmailLocalId = email.localId);
                        },
                      ),
              ),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 440,
                child: _selectedEmailLocalId == null
                    ? const EmailDetailPage(emailLocalId: null, embedded: true)
                    : EmailDetailPage(
                        emailLocalId: _selectedEmailLocalId,
                        embedded: true,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('本地邮箱'),
      actions: [
        IconButton(
          key: const Key('open-search'),
          tooltip: '搜索',
          onPressed: () => _openSearch(context),
          icon: const Icon(Icons.search),
        ),
        IconButton(
          key: const Key('open-account-manage'),
          tooltip: '账户管理',
          onPressed: () => _openAccountManage(context),
          icon: const Icon(Icons.manage_accounts_outlined),
        ),
        IconButton(
          key: const Key('compose-mail'),
          tooltip: '撰写邮件',
          onPressed: () => _openCompose(context),
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    );
  }

  Widget _buildMobile(
    BuildContext context,
    List<MailAccount> accounts,
    Map<String, ConnectionSlotState> slots,
    UnifiedInboxViewState view,
    AsyncValue<List<MailAccount>> accountsAsync,
  ) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('open-mail-drawer'),
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(view.title),
        actions: [
          IconButton(
            key: const Key('open-search'),
            onPressed: () => _openSearch(context),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            key: const Key('compose-mail'),
            onPressed: () => _openCompose(context),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: _buildSidebar(
            context,
            accounts,
            slots,
            view,
            accountsAsync.error,
            onFolderSelected: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: accounts.isEmpty
          ? _EmptyAccountCard(onAdd: () => _openAddAccount(context))
          : UnifiedInboxPage(
              embedded: true,
              onOpenEmail: (email) {
                final localId = email.localId;
                if (localId == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EmailDetailPage(emailLocalId: localId),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    List<MailAccount> accounts,
    Map<String, ConnectionSlotState> slots,
    UnifiedInboxViewState view,
    Object? accountsError, {
    VoidCallback? onFolderSelected,
  }) {
    final viewNotifier = ref.read(unifiedInboxViewProvider.notifier);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        key: const Key('mail-sidebar'),
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '邮箱',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('sidebar-add-account'),
                  tooltip: '添加邮箱',
                  onPressed: () => _openAddAccount(context),
                  icon: const Icon(Icons.add, size: 20),
                ),
              ],
            ),
          ),
          ListTile(
            key: const Key('unified-inbox-target'),
            selected: view.isUnified && view.accountId == null,
            leading: const Icon(Icons.all_inbox_outlined),
            title: const Text('聚合收件箱'),
            onTap: () {
              setState(() => _selectedEmailLocalId = null);
              viewNotifier.selectAccount(null);
              unawaited(viewNotifier.openFolder(null));
              onFolderSelected?.call();
            },
          ),
          if (accountsError != null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('账户加载失败'),
            ),
          for (final account in accounts) ...[
            const Divider(height: 16),
            ListTile(
              selected: view.accountId == account.id,
              onTap: () {
                setState(() => _selectedEmailLocalId = null);
                viewNotifier.selectAccount(account.id);
                unawaited(viewNotifier.openFolder(null));
                onFolderSelected?.call();
              },
              leading: AccountColorBadge(
                colorValue: account.colorValue,
                size: 12,
              ),
              title: Text(
                account.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Row(
                children: [
                  Icon(
                    _slotIcon(slots[account.id]),
                    size: 12,
                    color: _slotColor(slots[account.id]),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _slotLabel(slots[account.id]),
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            _FolderList(
              accountId: account.id,
              onSelected: (folder) {
                setState(() => _selectedEmailLocalId = null);
                viewNotifier.selectAccount(account.id);
                unawaited(viewNotifier.openFolder(folder));
                onFolderSelected?.call();
              },
            ),
          ],
          const Divider(),
          ListTile(
            key: const Key('sidebar-outbox'),
            leading: const Icon(Icons.outbox_outlined),
            title: const Text('草稿与发件箱'),
            trailing: _OutboxBadge(counts: ref.watch(outboxCountsProvider).value),
            onTap: () => _openOutbox(context),
          ),
          ListTile(
            key: const Key('sidebar-account-manage'),
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('账户管理'),
            onTap: () => _openAccountManage(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddAccount(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const AddAccountWizardPage(),
      ),
    );
  }

  Future<void> _openAccountManage(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AccountManagePage()),
    );
  }

  Future<void> _openOutbox(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const OutboxQueuePage()),
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const SearchEmailsPage()),
    );
  }

  Future<void> _openCompose(BuildContext context) async {
    final accounts = ref.read(accountsProvider).value ?? const <MailAccount>[];
    final account = accounts.isEmpty ? null : accounts.first;
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加并启用一个邮箱账户')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ComposeEmailPage(account: account),
      ),
    );
  }

  static IconData _slotIcon(ConnectionSlotState? state) {
    return switch (state) {
      ConnectionSlotState.idleInInbox => Icons.cloud_done_outlined,
      ConnectionSlotState.pollingInInbox => Icons.sync_alt,
      ConnectionSlotState.busyInInbox => Icons.sync,
      ConnectionSlotState.connecting => Icons.cloud_sync_outlined,
      ConnectionSlotState.backoffWaiting => Icons.cloud_off_outlined,
      ConnectionSlotState.loggingOut => Icons.logout,
      ConnectionSlotState.backgroundReleased => Icons.pause_circle_outline,
      ConnectionSlotState.disconnected => Icons.cloud_off_outlined,
      null => Icons.cloud_queue,
    };
  }

  static Color _slotColor(ConnectionSlotState? state) {
    return switch (state) {
      ConnectionSlotState.idleInInbox => Colors.green,
      ConnectionSlotState.pollingInInbox => Colors.teal,
      ConnectionSlotState.busyInInbox => Colors.blue,
      ConnectionSlotState.connecting => Colors.orange,
      ConnectionSlotState.backoffWaiting => Colors.orange,
      _ => Colors.grey,
    };
  }

  static String _slotLabel(ConnectionSlotState? state) {
    return switch (state) {
      ConnectionSlotState.idleInInbox => '收件箱 IDLE 监听中',
      ConnectionSlotState.pollingInInbox => '收件箱轮询中',
      ConnectionSlotState.busyInInbox => '处理中',
      ConnectionSlotState.connecting => '连接中',
      ConnectionSlotState.backoffWaiting => '等待重连',
      ConnectionSlotState.loggingOut => '断开中',
      ConnectionSlotState.backgroundReleased => '后台释放',
      ConnectionSlotState.disconnected => '未连接',
      null => '未连接',
    };
  }
}

class _OutboxBadge extends StatelessWidget {
  const _OutboxBadge({required this.counts});

  final OutboxCounts? counts;

  @override
  Widget build(BuildContext context) {
    final count = counts == null ? 0 : counts!.drafts + counts!.pending;
    if (count <= 0) return const SizedBox.shrink();
    return Badge(
      label: Text('$count'),
      child: const Icon(Icons.outbox_outlined),
    );
  }
}

class _FolderList extends ConsumerWidget {
  const _FolderList({required this.accountId, required this.onSelected});

  final String accountId;
  final ValueChanged<MailFolder> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(accountFoldersProvider(accountId));
    return folders.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        final sorted = [...items]
          ..sort((a, b) {
            if (a.role == FolderRole.inbox) return -1;
            if (b.role == FolderRole.inbox) return 1;
            return a.displayName.compareTo(b.displayName);
          });
        return Column(
          children: [
            for (final folder in sorted)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 44, right: 12),
                leading: Icon(
                  _folderIcon(folder.role),
                  size: 18,
                ),
                title: Text(
                  folder.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onSelected(folder),
              ),
          ],
        );
      },
    );
  }

  static IconData _folderIcon(FolderRole role) {
    return switch (role) {
      FolderRole.inbox => Icons.inbox_outlined,
      FolderRole.sent => Icons.send_outlined,
      FolderRole.drafts => Icons.edit_note_outlined,
      FolderRole.trash => Icons.delete_outline,
      FolderRole.junk => Icons.report_gmailerrorred_outlined,
      FolderRole.archive => Icons.archive_outlined,
      FolderRole.custom => Icons.folder_outlined,
    };
  }
}

class _EmptyAccountCard extends StatelessWidget {
  const _EmptyAccountCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 56),
              const SizedBox(height: 12),
              Text(
                '还没有绑定邮箱账户',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '添加 Gmail、Outlook、163、QQ、Foxmail 或自定义 IMAP 邮箱，'
                '开始纯本地直连阅读。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('empty-add-account'),
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('添加邮箱账户'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
