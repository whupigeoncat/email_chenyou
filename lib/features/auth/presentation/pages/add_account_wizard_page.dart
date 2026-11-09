import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../core/constants/provider_presets.dart';
import '../../domain/entities/mail_account.dart';
import '../providers/account_setup_provider.dart';

/// Guided add-account flow: provider inference, display name/color, password
/// authorization code or OAuth PKCE, advanced ports/TLS, test and save.
class AddAccountWizardPage extends ConsumerStatefulWidget {
  const AddAccountWizardPage({super.key, this.onSaved});

  final ValueChanged<MailAccount>? onSaved;

  @override
  ConsumerState<AddAccountWizardPage> createState() =>
      _AddAccountWizardPageState();
}

class _AddAccountWizardPageState extends ConsumerState<AddAccountWizardPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _imapHostController = TextEditingController();
  final TextEditingController _imapPortController = TextEditingController();
  final TextEditingController _smtpHostController = TextEditingController();
  final TextEditingController _smtpPortController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _imapHostController.dispose();
    _imapPortController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    super.dispose();
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(accountSetupProvider);
    final notifier = ref.read(accountSetupProvider.notifier);

    ref.listen<AccountSetupState>(accountSetupProvider, (previous, next) {
      _syncController(_imapHostController, next.imapHost);
      _syncController(_imapPortController, next.imapPort.toString());
      _syncController(_smtpHostController, next.smtpHost);
      _syncController(_smtpPortController, next.smtpPort.toString());
    });

    return Scaffold(
      appBar: AppBar(title: const Text('添加邮箱账户')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const _WizardIntro(),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '账户信息',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('add-account-email'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: '邮箱地址',
                        hintText: 'name@163.com',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      onChanged: notifier.updateEmail,
                    ),
                    if (setup.email.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Color(setup.preset.defaultColorValue),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mail_outline,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              setup.preset.type == MailProviderType.custom
                                  ? '未识别的服务商，将使用自定义 IMAP / SMTP 配置'
                                  : '已识别服务商：${setup.preset.displayName}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('add-account-display-name'),
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: '显示名称（可选）',
                        hintText: '例如：工作邮箱',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      onChanged: notifier.updateDisplayName,
                    ),
                    const SizedBox(height: 18),
                    Text('账号色标', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (
                          var i = 0;
                          i < ProviderPresets.accountColorPalette.length;
                          i++
                        )
                          _ColorDot(
                            key: Key('account-color-$i'),
                            color: Color(
                              ProviderPresets.accountColorPalette[i],
                            ),
                            selected:
                                setup.colorValue ==
                                ProviderPresets.accountColorPalette[i],
                            onTap: () => notifier.selectColor(
                              ProviderPresets.accountColorPalette[i],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '登录方式',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    if (setup.preset.supportedAuthTypes.length > 1)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final authType
                              in setup.preset.supportedAuthTypes)
                            ChoiceChip(
                              key: Key('auth-type-${authType.storageKey}'),
                              label: Text(authType.displayName),
                              selected: setup.authType == authType,
                              onSelected: (_) =>
                                  notifier.selectAuthType(authType),
                            ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              setup.authType.displayName,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        setup.preset.setupGuideZh,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (setup.authType == MailAuthType.passwordOrAuthCode &&
                        setup.supportsPassword) ...[
                      TextField(
                        key: const Key('add-account-password'),
                        controller: _passwordController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: '授权码 / 密码',
                          hintText:
                              setup.providerType == MailProviderType.qq ||
                                  setup.providerType == MailProviderType.foxmail
                              ? '16 位客户端授权码（不是 QQ 密码）'
                              : '163 / QQ 请填写客户端授权码',
                          prefixIcon: const Icon(Icons.key_outlined),
                        ),
                        onChanged: notifier.updatePasswordOrAuthCode,
                      ),
                      if (setup.providerType == MailProviderType.qq ||
                          setup.providerType == MailProviderType.foxmail)
                        const _TencentAuthCodeGuide(),
                    ] else if (setup.supportsOAuth)
                      _OAuthSection(
                        providerType: setup.providerType,
                        guidance: _oauthGuidance(setup.providerType),
                        isConfigured: ref
                            .watch(oauthPkceServiceProvider)
                            .isConfiguredFor(setup.providerType),
                        unavailableMessage: ref
                            .watch(oauthPkceServiceProvider)
                            .unavailableMessageFor(setup.providerType),
                        isAuthorizing: setup.isOAuthAuthorizing,
                        hasTokens: setup.oauthTokens != null,
                        onAuthorize: notifier.startOAuthAuthorization,
                      )
                    else
                      const Text('当前服务商没有可用的登录方式。'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                key: const Key('add-account-advanced'),
                initiallyExpanded: setup.advancedExpanded,
                onExpansionChanged: (_) => notifier.toggleAdvanced(),
                leading: const Icon(Icons.tune),
                title: const Text('高级设置：IMAP / SMTP 端口与 TLS'),
                subtitle: const Text('通常无需修改，服务商预设已自动填充'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  TextField(
                    key: const Key('add-account-imap-host'),
                    controller: _imapHostController,
                    decoration: const InputDecoration(
                      labelText: 'IMAP 服务器',
                      hintText: 'imap.example.com',
                    ),
                    onChanged: notifier.updateImapHost,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('add-account-imap-port'),
                    controller: _imapPortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'IMAP 端口',
                      hintText: '993',
                    ),
                    onChanged: notifier.updateImapPort,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('IMAP 隐式 TLS（SSL/TLS）'),
                    value: setup.imapImplicitTls,
                    onChanged: notifier.updateImapImplicitTls,
                  ),
                  const Divider(),
                  TextField(
                    key: const Key('add-account-smtp-host'),
                    controller: _smtpHostController,
                    decoration: const InputDecoration(
                      labelText: 'SMTP 服务器',
                      hintText: 'smtp.example.com',
                    ),
                    onChanged: notifier.updateSmtpHost,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('add-account-smtp-port'),
                    controller: _smtpPortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'SMTP 端口',
                      hintText: '465',
                    ),
                    onChanged: notifier.updateSmtpPort,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('SMTP 隐式 TLS（关闭时使用 STARTTLS）'),
                    value: setup.smtpImplicitTls,
                    onChanged: notifier.updateSmtpImplicitTls,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (setup.testStatus == ConnectionTestStatus.testing)
              const _StatusBanner(
                icon: Icons.hourglass_top,
                color: Colors.blue,
                message: '正在连接邮件服务器并验证凭据…',
                showProgress: true,
              ),
            if (setup.testStatus == ConnectionTestStatus.success &&
                setup.testMessage != null)
              _StatusBanner(
                icon: Icons.check_circle_outline,
                color: Colors.green,
                message: setup.testMessage!,
              ),
            if (setup.errorMessage != null)
              _StatusBanner(
                icon: Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                message: setup.errorMessage!,
              ),
            if (setup.saveStatus == AccountSaveStatus.success &&
                setup.saveMessage != null)
              _StatusBanner(
                icon: Icons.verified_outlined,
                color: Colors.green,
                message: setup.saveMessage!,
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('add-account-test'),
                    onPressed: setup.isBusy
                        ? null
                        : () => notifier.runConnectionTest(),
                    icon: setup.testStatus == ConnectionTestStatus.testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check),
                    label: const Text('测试连接'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('add-account-save'),
                    onPressed: setup.isBusy
                        ? null
                        : () => _save(notifier, setup),
                    icon: setup.saveStatus == AccountSaveStatus.saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('保存账户'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(AccountSetup notifier, AccountSetupState setup) async {
    final account = await notifier.saveAccount();
    if (!mounted || account == null) return;
    widget.onSaved?.call(account);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${setup.preset.displayName} 账户已安全保存')),
    );
  }

  String _oauthGuidance(MailProviderType provider) {
    final providerName = provider == MailProviderType.gmail
        ? 'Google'
        : 'Microsoft';
    if (kIsWeb) {
      return '当前 Web 构建不支持系统浏览器 OAuth 回调。';
    }
    if (provider == MailProviderType.gmail &&
        defaultTargetPlatform == TargetPlatform.android) {
      return '点击后将调用设备上的 Google 登录（Google Play 服务），由 $providerName 官方页面处理'
          '验证码与二步验证。应用只申请 Gmail IMAP/SMTP 所需的 mail.google.com 权限，'
          '并通过 Google 官方接口核对登录账号与上方邮箱一致。';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return '桌面端：应用会打开系统浏览器完成 $providerName 官方 PKCE 授权，'
            '并在本机临时回环端口接收回调；全程直连官方端点，不经过第三方中转服务器。';
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return '点击后将打开系统安全浏览器，由 $providerName 官方页面处理验证码与二步验证，'
            '授权完成后返回应用；全程直连官方端点，不经过第三方中转服务器。';
      case TargetPlatform.fuchsia:
        return '请使用系统浏览器完成 $providerName 官方 OAuth 2.0 PKCE 授权，回调仅返回本应用。';
    }
  }
}

class _WizardIntro extends StatelessWidget {
  const _WizardIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '纯本地直连：账户凭据仅保存在系统安全存储（Keychain / Keystore），'
              '不会写入数据库，也不会经过任何自建服务器。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}

class _OAuthSection extends StatelessWidget {
  const _OAuthSection({
    required this.providerType,
    required this.guidance,
    required this.isConfigured,
    required this.unavailableMessage,
    required this.isAuthorizing,
    required this.hasTokens,
    required this.onAuthorize,
  });

  final MailProviderType providerType;
  final String guidance;
  final bool isConfigured;
  final String unavailableMessage;
  final bool isAuthorizing;
  final bool hasTokens;
  final VoidCallback onAuthorize;

  String get _buttonLabel {
    if (isAuthorizing) return '等待官方登录完成…';
    return switch (providerType) {
      MailProviderType.gmail => '使用 Google 登录',
      MailProviderType.outlook => '使用 Microsoft 登录',
      _ => '使用 OAuth 2.0 登录',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(guidance, style: Theme.of(context).textTheme.bodySmall),
        ),
        if (!isConfigured) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              unavailableMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('add-account-oauth'),
            onPressed: isAuthorizing || !isConfigured ? null : onAuthorize,
            icon: isAuthorizing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_browser),
            label: Text(_buttonLabel),
          ),
        ),
        if (hasTokens) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.lock, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '已获取 OAuth 令牌，保存账户时会写入系统安全存储。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// QQ / Foxmail run on Tencent mail servers; this private client uses the
/// official 16-character IMAP/SMTP authorization code, never the QQ web password.
class _TencentAuthCodeGuide extends StatelessWidget {
  const _TencentAuthCodeGuide();

  static final Uri _guideUri = Uri.parse(
    'https://help.mail.qq.com/detail/106/985',
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          '此客户端使用 QQ 官方 16 位 IMAP/SMTP 授权码流程。'
          '请在官方页面开启 POP3/IMAP/SMTP 服务、验证并生成授权码，'
          '然后返回粘贴到上方；不要填写 QQ 登录密码。Foxmail 邮箱同样使用腾讯邮件服务。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          key: const Key('qq-auth-code-guide'),
          onPressed: () =>
              launchUrl(_guideUri, mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.help_outline),
          label: const Text('打开 QQ 邮箱官方授权码指南'),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.message,
    this.showProgress = false,
  });

  final IconData icon;
  final Color color;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: color),
                ),
              ),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(color: color),
          ],
        ],
      ),
    );
  }
}
