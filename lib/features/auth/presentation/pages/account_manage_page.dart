import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_runtime_providers.dart';
import '../../../../app/di/core_providers.dart';
import '../../../../core/constants/provider_presets.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/account_connection_slot.dart';
import '../../domain/entities/account_setup_draft.dart';
import '../../domain/entities/mail_account.dart';
import 'add_account_wizard_page.dart';
import 'diagnostics_page.dart';

class AccountManagePage extends ConsumerWidget {
  const AccountManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Starts the lifecycle/connectivity watchers and seeds the pool once.
    ref.watch(appRuntimeProvider);

    final accounts = ref.watch(accountsProvider);
    final slotStates = ref.watch(accountSlotStatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('邮箱账户'),
        actions: [
          IconButton(
            key: const Key('open-diagnostics'),
            tooltip: '连接与诊断',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const DiagnosticsPage()),
            ),
            icon: const Icon(Icons.monitor_heart_outlined),
          ),
          IconButton(
            key: const Key('manage-add-account'),
            tooltip: '添加邮箱账户',
            onPressed: () => _openWizard(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorState(
          message: error is AppFailure ? error.userMessage : '读取账户列表失败',
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyState(onAdd: () => _openWizard(context));
          }
          final states = slotStates.when(
            data: (value) => value,
            loading: () => const <String, ConnectionSlotState>{},
            error: (_, _) => const <String, ConnectionSlotState>{},
          );
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final account = items[index];
              return _AccountCard(
                account: account,
                slotState: states[account.id],
                onToggleEnabled: (enabled) =>
                    _setEnabled(context, ref, account, enabled),
                onResetCredential: () =>
                    _resetCredential(context, ref, account),
                onDelete: () => _deleteAccount(context, ref, account),
                onToggleSentCopy: (enabled) async {
                  try {
                    await ref
                        .read(authRepositoryProvider)
                        .updateAccount(account.copyWith(saveSentCopy: enabled));
                  } catch (error) {
                    if (context.mounted) _showError(context, error, '保存副本设置失败');
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openWizard(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => const AddAccountWizardPage()),
    );
  }

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    MailAccount account,
    bool enabled,
  ) async {
    try {
      await ref
          .read(authRepositoryProvider)
          .setAccountEnabled(account.id, enabled);
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, error, '更新账户启用状态失败');
    }
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    MailAccount account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除邮箱账户'),
        content: Text(
          '将删除 ${account.email} 的本地账户信息与系统安全存储中的凭据，'
          '并立即释放该账户的连接池槽位。此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-delete-account'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(authRepositoryProvider).deleteAccount(account.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已删除 ${account.email}')));
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, error, '删除账户失败');
    }
  }

  Future<void> _resetCredential(
    BuildContext context,
    WidgetRef ref,
    MailAccount account,
  ) async {
    if (account.authType == MailAuthType.passwordOrAuthCode) {
      final secret = await _promptPassword(context, account);
      if (secret == null || !context.mounted) return;
      try {
        await ref
            .read(authRepositoryProvider)
            .replaceCredential(account.id, PasswordAccountCredential(secret));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('授权码已更新并写入系统安全存储')));
      } catch (error) {
        if (!context.mounted) return;
        _showError(context, error, '重设凭据失败');
      }
      return;
    }

    final oauthService = ref.read(oauthPkceServiceProvider);
    if (!oauthService.isConfiguredFor(account.providerType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            oauthService.unavailableMessageFor(account.providerType),
          ),
        ),
      );
      return;
    }
    try {
      final tokens = await oauthService.authorize(
        providerType: account.providerType,
        expectedEmail: account.email,
        loginHintEmail: account.email,
      );
      await ref
          .read(authRepositoryProvider)
          .replaceCredential(account.id, OAuthAccountCredential(tokens));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('OAuth 授权已刷新并写入系统安全存储')));
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, error, 'OAuth 重新授权失败');
    }
  }

  Future<String?> _promptPassword(
    BuildContext context,
    MailAccount account,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('重设 ${account.email} 的授权码'),
        content: TextField(
          key: const Key('reset-password-field'),
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '新的授权码 / 密码',
            helperText: '请填写客户端授权码，不是网页登录密码',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  void _showError(BuildContext context, Object error, String fallback) {
    final message = error is AppFailure ? error.userMessage : fallback;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.slotState,
    required this.onToggleEnabled,
    required this.onResetCredential,
    required this.onDelete,
    required this.onToggleSentCopy,
  });

  final MailAccount account;
  final ConnectionSlotState? slotState;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onResetCredential;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleSentCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Color(account.colorValue),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    account.shortLabel.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.email,
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${account.displayName.isEmpty ? '未命名' : account.displayName} · '
                        '${account.preset.displayName} · ${account.authType.displayName}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(value: account.isEnabled, onChanged: onToggleEnabled),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'reset') onResetCredential();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'reset',
                      child: Text(
                        account.authType == MailAuthType.oauth2Pkce
                            ? '重新授权 OAuth'
                            : '重设授权码',
                      ),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('删除账户')),
                  ],
                ),
              ],
            ),
            SwitchListTile.adaptive(
              key: Key('save-sent-copy-${account.id}'),
              contentPadding: EdgeInsets.zero,
              title: const Text('保存已发送副本'),
              subtitle: const Text('服务商不自动保存时开启；保存前会先核对是否已有副本。'),
              value: account.saveSentCopy,
              onChanged: onToggleSentCopy,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _SlotBadge(state: slotState),
                const Spacer(),
                Flexible(
                  child: Text(
                    '${account.imapHost}:${account.imapPort}',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotBadge extends StatelessWidget {
  const _SlotBadge({required this.state});

  final ConnectionSlotState? state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      ConnectionSlotState.idleInInbox => ('收件箱 IDLE 监听中', Colors.green),
      ConnectionSlotState.pollingInInbox => ('收件箱轮询中', Colors.teal),
      ConnectionSlotState.busyInInbox => ('正在处理收件箱', Colors.blue),
      ConnectionSlotState.connecting => ('正在连接', Colors.orange),
      ConnectionSlotState.backoffWaiting => ('等待重连', Colors.orange),
      ConnectionSlotState.loggingOut => ('正在断开', Colors.grey),
      ConnectionSlotState.backgroundReleased => ('后台已释放连接', Colors.grey),
      ConnectionSlotState.disconnected => ('未连接', Colors.grey),
      null => ('未连接', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 56),
            const SizedBox(height: 12),
            Text('还没有绑定邮箱账户', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '添加 Gmail、Outlook、163、QQ、Foxmail 或任意自定义 IMAP 邮箱。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('empty-add-account'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('添加邮箱账户'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
