import 'dart:async';

import 'package:flutter/material.dart';

import '../data/battery_notification_platform.dart';
import '../domain/battery_notification_settings.dart';

/// Android-only notification settings. All values live in native
/// SharedPreferences so the headless engine sees the same state.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, this.resetBaselines});

  /// Called under a foreground lease before re-enabling checks. Production
  /// passes the Drift state store so the first background run starts from the
  /// current mailbox instead of notifying mail accumulated while off.
  final Future<void> Function()? resetBaselines;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver {
  final _platform = BatteryNotificationPlatform.instance;

  BatteryNotificationSettings? _settings;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    try {
      final settings = await _platform.loadSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '读取通知设置失败，请重试。');
    }
  }

  Future<void> _changeInterval(BatteryNotificationInterval interval) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final wasOff = _settings?.interval == BatteryNotificationInterval.off;
      if (wasOff && interval != BatteryNotificationInterval.off) {
        final reset = widget.resetBaselines;
        if (reset != null) {
          await BatteryNotificationPlatform.instance.withForegroundLease(reset);
        }
      }
      final settings = await _platform.setIntervalMinutes(interval.minutes);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '保存通知设置失败，请重试。';
      });
    }
  }

  Future<void> _requestPermission() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final settings = await _platform.requestPermission();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '请求通知权限失败，请在系统设置中开启。';
      });
    }
  }

  Future<void> _openSystemSettings() async {
    try {
      await _platform.openNotificationSettings();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '无法打开系统通知设置。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('新邮件通知')),
      body: settings == null
          ? (_error == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            key: const Key('notification-retry-load'),
                            onPressed: _load,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text('省电后台检查', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  settings.enabled
                      ? '系统会在所选间隔附近尝试检查新邮件，具体时间由系统调度，'
                            '可能延迟。不会常驻后台，也不会保持邮件长连接。'
                      : '后台检查已关闭，不会定时检查新邮件，也不会产生通知。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                RadioGroup<BatteryNotificationInterval>(
                  groupValue: settings.interval,
                  onChanged: _busy
                      ? (_) {}
                      : (value) {
                          if (value != null) unawaited(_changeInterval(value));
                        },
                  child: Column(
                    children: [
                      for (final interval in BatteryNotificationInterval.values)
                        RadioListTile<BatteryNotificationInterval>(
                          key: Key('notification-interval-${interval.minutes}'),
                          value: interval,
                          title: Text(interval.label),
                          subtitle: interval == BatteryNotificationInterval.off
                              ? const Text('关闭后台检查，并取消已有通知')
                              : null,
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '仅显示“有新邮件”或数量；通知不会显示验证码、主题、发件人或正文。'
                  '关闭通知后会取消后台任务和已有通知。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (!settings.notificationsUsable)
                  _RecoveryCard(
                    settings: settings,
                    busy: _busy,
                    onRequestPermission: _requestPermission,
                    onOpenSystemSettings: _openSystemSettings,
                  ),
                if (settings.notificationsUsable)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            settings.enabled
                                ? Icons.check_circle_outline
                                : Icons.notifications_off_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              settings.enabled
                                  ? '通知权限已开启。有启用的邮箱时，后台会按系统调度检查新邮件。'
                                  : '通知权限正常，但后台检查已关闭，当前不会提醒新邮件。',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({
    required this.settings,
    required this.busy,
    required this.onRequestPermission,
    required this.onOpenSystemSettings,
  });

  final BatteryNotificationSettings settings;
  final bool busy;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSystemSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final permissionMissing = !settings.permissionGranted;
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              permissionMissing ? '通知权限未开启' : '系统通知已关闭',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              permissionMissing
                  ? '允许通知后才能显示新邮件提醒。后台不会弹登录或授权页面。'
                  : '系统或“新邮件”通知渠道被关闭，请到系统设置重新开启。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (permissionMissing && settings.canRequestPermission)
                  FilledButton(
                    key: const Key('notification-request-permission'),
                    onPressed: busy ? null : onRequestPermission,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('允许通知'),
                  ),
                OutlinedButton(
                  key: const Key('notification-open-system-settings'),
                  onPressed: busy ? null : onOpenSystemSettings,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('系统通知设置'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
