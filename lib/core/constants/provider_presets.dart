/// Built-in direct-connection presets for supported mail providers.
/// Zero middleware: all connections go directly from device to provider servers.
enum MailProviderType {
  gmail('gmail', 'Gmail'),
  outlook('outlook', 'Outlook / Hotmail'),
  netease163('163', '网易 163 邮箱'),
  qq('qq', 'QQ 邮箱'),
  foxmail('foxmail', 'Foxmail 邮箱'),
  custom('custom', '自定义 IMAP / SMTP');

  const MailProviderType(this.storageKey, this.displayName);
  final String storageKey;
  final String displayName;

  static MailProviderType fromStorageKey(String key) {
    return MailProviderType.values.firstWhere(
      (e) => e.storageKey == key,
      orElse: () => MailProviderType.custom,
    );
  }
}

enum MailAuthType {
  passwordOrAuthCode('password', '密码 / 客户端授权码'),
  oauth2Pkce('oauth2', 'OAuth 2.0 (XOAUTH2)');

  const MailAuthType(this.storageKey, this.displayName);
  final String storageKey;
  final String displayName;

  static MailAuthType fromStorageKey(String key) {
    return MailAuthType.values.firstWhere(
      (e) => e.storageKey == key,
      orElse: () => MailAuthType.passwordOrAuthCode,
    );
  }
}

class ProviderPreset {
  const ProviderPreset({
    required this.type,
    required this.displayName,
    required this.domains,
    required this.imapHost,
    required this.imapPort,
    required this.imapImplicitTls,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpImplicitTls,
    required this.supportedAuthTypes,
    required this.defaultAuthType,
    required this.requiresImapIdCommand,
    required this.idleRefreshInterval,
    this.inboxPollInterval = const Duration(seconds: 60),
    required this.defaultColorValue,
    required this.setupGuideZh,
  });

  final MailProviderType type;
  final String displayName;
  final List<String> domains;
  final String imapHost;
  final int imapPort;
  final bool imapImplicitTls;
  final String smtpHost;
  final int smtpPort;
  final bool smtpImplicitTls;
  final List<MailAuthType> supportedAuthTypes;
  final MailAuthType defaultAuthType;

  /// NetEase (163/126/yeah) rejects SELECT unless RFC 2971 IMAP ID is sent.
  final bool requiresImapIdCommand;

  /// Interval to exit IDLE (DONE) and re-enter IDLE before server/NAT drop.
  final Duration idleRefreshInterval;

  /// Single-connection INBOX polling interval used when IDLE is unavailable.
  final Duration inboxPollInterval;

  /// Default ARGB badge color for visual separation in unified inbox.
  final int defaultColorValue;

  final String setupGuideZh;
}

abstract final class ProviderPresets {
  static const List<int> accountColorPalette = [
    0xFFEA4335, // Gmail Red
    0xFF0078D4, // Outlook Blue
    0xFFD93025, // 163 Crimson
    0xFF12B7F5, // QQ Cyan-Blue
    0xFFF59E0B, // Foxmail Amber
    0xFF10B981, // Emerald
    0xFF8B5CF6, // Violet
    0xFFEC4899, // Pink
  ];

  static const ProviderPreset gmail = ProviderPreset(
    type: MailProviderType.gmail,
    displayName: 'Gmail',
    domains: ['gmail.com', 'googlemail.com'],
    imapHost: 'imap.gmail.com',
    imapPort: 993,
    imapImplicitTls: true,
    smtpHost: 'smtp.gmail.com',
    smtpPort: 465,
    smtpImplicitTls: true,
    supportedAuthTypes: [
      MailAuthType.oauth2Pkce,
      MailAuthType.passwordOrAuthCode,
    ],
    defaultAuthType: MailAuthType.oauth2Pkce,
    requiresImapIdCommand: false,
    idleRefreshInterval: Duration(minutes: 20),
    defaultColorValue: 0xFFEA4335,
    setupGuideZh:
        '推荐使用 OAuth 2.0 登录；若使用应用专用密码，请先在 Google 账号开启两步验证并生成 16 位应用专用密码，同时确保 Gmail 网页端已启用 IMAP。',
  );

  static const ProviderPreset outlook = ProviderPreset(
    type: MailProviderType.outlook,
    displayName: 'Outlook / Hotmail',
    domains: ['outlook.com', 'hotmail.com', 'live.com', 'msn.com'],
    imapHost: 'outlook.office365.com',
    imapPort: 993,
    imapImplicitTls: true,
    smtpHost: 'smtp.office365.com',
    smtpPort: 587,
    smtpImplicitTls: false, // STARTTLS on 587
    supportedAuthTypes: [MailAuthType.oauth2Pkce],
    defaultAuthType: MailAuthType.oauth2Pkce,
    requiresImapIdCommand: false,
    idleRefreshInterval: Duration(minutes: 18),
    defaultColorValue: 0xFF0078D4,
    setupGuideZh:
        '微软已停止支持个人版 Outlook 基础密码认证，必须使用 OAuth 2.0 (XOAUTH2) 现代化授权登录。',
  );

  static const ProviderPreset netease163 = ProviderPreset(
    type: MailProviderType.netease163,
    displayName: '网易 163 邮箱',
    domains: ['163.com', '126.com', 'yeah.net'],
    imapHost: 'imap.163.com',
    imapPort: 993,
    imapImplicitTls: true,
    smtpHost: 'smtp.163.com',
    smtpPort: 465,
    smtpImplicitTls: true,
    supportedAuthTypes: [MailAuthType.passwordOrAuthCode],
    defaultAuthType: MailAuthType.passwordOrAuthCode,
    requiresImapIdCommand: true,
    idleRefreshInterval: Duration(minutes: 14),
    inboxPollInterval: Duration(seconds: 60),
    defaultColorValue: 0xFFD93025,
    setupGuideZh:
        '请登录网页版 163 邮箱 -> 设置 -> POP3/SMTP/IMAP，开启 IMAP/SMTP 服务并新增客户端授权码（请填写授权码而非登录密码）。客户端将自动发送 RFC 2971 IMAP ID 报文。',
  );

  static const ProviderPreset qq = ProviderPreset(
    type: MailProviderType.qq,
    displayName: 'QQ 邮箱',
    domains: ['qq.com', 'vip.qq.com'],
    imapHost: 'imap.qq.com',
    imapPort: 993,
    imapImplicitTls: true,
    smtpHost: 'smtp.qq.com',
    smtpPort: 465,
    smtpImplicitTls: true,
    supportedAuthTypes: [MailAuthType.passwordOrAuthCode],
    defaultAuthType: MailAuthType.passwordOrAuthCode,
    requiresImapIdCommand: false,
    idleRefreshInterval: Duration(minutes: 14),
    defaultColorValue: 0xFF12B7F5,
    setupGuideZh:
        '请登录网页版 QQ 邮箱 -> 设置 -> 账号 -> POP3/IMAP/SMTP/Exchange/CardDAV/CalDAV 服务，开启 IMAP/SMTP 并生成 16 位授权码。QQ 邮箱严格限制并发连接数。',
  );

  static const ProviderPreset foxmail = ProviderPreset(
    type: MailProviderType.foxmail,
    displayName: 'Foxmail 邮箱',
    domains: ['foxmail.com'],
    imapHost: 'imap.qq.com',
    imapPort: 993,
    imapImplicitTls: true,
    smtpHost: 'smtp.qq.com',
    smtpPort: 465,
    smtpImplicitTls: true,
    supportedAuthTypes: [MailAuthType.passwordOrAuthCode],
    defaultAuthType: MailAuthType.passwordOrAuthCode,
    requiresImapIdCommand: false,
    idleRefreshInterval: Duration(minutes: 14),
    defaultColorValue: 0xFFF59E0B,
    setupGuideZh:
        'Foxmail 邮箱使用腾讯邮件服务器（imap.qq.com / smtp.qq.com）。请使用对应的 QQ/Foxmail 网页端生成的 IMAP/SMTP 授权码登录。',
  );

  static const ProviderPreset custom = ProviderPreset(
    type: MailProviderType.custom,
    displayName: '自定义 IMAP / SMTP',
    domains: [],
    imapHost: '',
    imapPort: 993,
    imapImplicitTls: true,
    smtpHost: '',
    smtpPort: 465,
    smtpImplicitTls: true,
    supportedAuthTypes: [
      MailAuthType.passwordOrAuthCode,
      MailAuthType.oauth2Pkce,
    ],
    defaultAuthType: MailAuthType.passwordOrAuthCode,
    requiresImapIdCommand: false,
    idleRefreshInterval: Duration(minutes: 15),
    defaultColorValue: 0xFF10B981,
    setupGuideZh: '请填写邮件服务商提供的 IMAP 与 SMTP 主机、端口及 SSL/TLS 加密方式。',
  );

  static const List<ProviderPreset> all = [
    gmail,
    outlook,
    netease163,
    qq,
    foxmail,
    custom,
  ];

  static ProviderPreset byType(MailProviderType type) {
    return all.firstWhere((p) => p.type == type, orElse: () => custom);
  }

  /// Infers preset from an email address domain (e.g., alice@foxmail.com -> foxmail).
  static ProviderPreset inferFromEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex < 0 || atIndex == email.length - 1) return custom;
    final domain = email.substring(atIndex + 1).trim().toLowerCase();
    for (final preset in all) {
      if (preset.domains.contains(domain)) {
        return preset;
      }
    }
    return custom;
  }

  /// Resolves domain-specific NetEase IMAP host if user enters @126.com or @yeah.net.
  static String resolveImapHostForEmail(MailProviderType type, String email) {
    if (type == MailProviderType.netease163) {
      final lower = email.toLowerCase();
      if (lower.endsWith('@126.com')) return 'imap.126.com';
      if (lower.endsWith('@yeah.net')) return 'imap.yeah.net';
    }
    return byType(type).imapHost;
  }

  static String resolveSmtpHostForEmail(MailProviderType type, String email) {
    if (type == MailProviderType.netease163) {
      final lower = email.toLowerCase();
      if (lower.endsWith('@126.com')) return 'smtp.126.com';
      if (lower.endsWith('@yeah.net')) return 'smtp.yeah.net';
    }
    return byType(type).smtpHost;
  }
}
