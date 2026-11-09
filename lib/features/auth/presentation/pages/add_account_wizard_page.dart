import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _imapHostController = TextEditingController();
  final TextEditingController _imapPortController = TextEditingController();
  final TextEditingController _smtpHostController = TextEditingController();
  final TextEditingController _smtpPortController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _clientIdController.dispose();
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
      _syncController(_clientIdController, next.oauthClientId);
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
                    Text(
                      '账号色标',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0;
                            i < ProviderPresets.accountColorPalette.length;
                            i++)
                          _ColorDot(
                            key: Key('account-color-$i'),
                            color: Color(
                              ProviderPresets.accountColorPalette[i],
                            ),
                            selected: setup.colorValue ==
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
                        setup.supportsPassword)
                      TextField(
                        key: const Key('add-account-password'),
                        controller: _passwordController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: '授权码 / 密码',
                          hintText: '163 / QQ 请填写客户端授权码',
                          prefixIcon: Icon(Icons.key_outlined),
                        ),
                        onChanged: notifier.updatePasswordOrAuthCode,
                      )
                    else if (setup.supportsOAuth)
                      _OAuthSection(
                        clientIdController: _clientIdController,
                        guidance: _oauthGuidance(),
                        isAuthorizing: setup.isOAuthAuthorizing,
                        hasTokens: setup.oauthTokens != null,
                        onClientIdChanged: notifier.updateOAuthClientId,
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
                    onPressed:
                        setup.isBusy ? null : () => _save(notifier, setup),
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

  Future<void> _save(
    AccountSetup notifier,
    AccountSetupState setup,
  ) async {
    final account = await notifier.saveAccount();
    if (!mounted || account == null) return;
    widget.onSaved?.call(account);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${setup.preset.displayName} 账户已安全保存'),
      ),
    );
  }

  String _oauthGuidance() {
    if (kIsWeb) {
      return 'Web 端将打开新标签页完成 OAuth 2.0 PKCE 授权，回调仅返回本应用。';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return '桌面端指引：应用会打开系统浏览器，并在 127.0.0.1 的临时本地回环端口接收授权回调；'
            '全程直连 Google / Microsoft 官方端点，不经过任何第三方中转服务器。'
            '请在 OAuth 应用后台把该回环地址加入允许的重定向 URI。';
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return '移动端指引：应用会打开系统安全浏览器（ASWebAuthenticationSession / Chrome Auth Tab），'
            '授权完成后通过 com.localmail.client://oauth2redirect 返回应用。'
            '全程直连 Google / Microsoft 官方端点，不经过任何第三方中转服务器。';
      case TargetPlatform.fuchsia:
        return '请使用系统浏览器完成 OAuth 2.0 PKCE 授权，回调仅返回本应用。';
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
    required this.clientIdController,
    required this.guidance,
    required this.isAuthorizing,
    required this.hasTokens,
    required this.onClientIdChanged,
    required this.onAuthorize,
  });

  final TextEditingController clientIdController;
  final String guidance;
  final bool isAuthorizing;
  final bool hasTokens;
  final ValueChanged<String> onClientIdChanged;
  final VoidCallback onAuthorize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('add-account-client-id'),
          controller: clientIdController,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'OAuth 客户端 ID（Client ID）',
            hintText: 'Google / Microsoft 应用注册生成的 Client ID',
            prefixIcon: Icon(Icons.app_registration),
          ),
          onChanged: onClientIdChanged,
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            guidance,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('add-account-oauth'),
            onPressed: isAuthorizing ? null : onAuthorize,
            icon: isAuthorizing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_browser),
            label: Text(
              isAuthorizing ? '等待浏览器授权…' : '使用 OAuth 2.0 登录',
            ),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
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
