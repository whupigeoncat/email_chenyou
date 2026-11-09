import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../core/constants/provider_presets.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/logging/sanitized_logger.dart';
import '../../../../core/security/oauth_pkce_service.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/entities/account_setup_draft.dart';
import '../../domain/entities/mail_account.dart';

part 'account_setup_provider.g.dart';

enum ConnectionTestStatus { idle, testing, success, failure }

enum AccountSaveStatus { idle, saving, success, failure }

const Object _unset = Object();

@immutable
class AccountSetupState {
  const AccountSetupState({
    this.email = '',
    this.displayName = '',
    this.providerType = MailProviderType.custom,
    this.authType = MailAuthType.passwordOrAuthCode,
    this.colorValue = 0xFF10B981,
    this.passwordOrAuthCode = '',
    this.oauthTokens,
    this.isOAuthAuthorizing = false,
    this.imapHost = '',
    this.imapPort = 993,
    this.imapImplicitTls = true,
    this.smtpHost = '',
    this.smtpPort = 465,
    this.smtpImplicitTls = true,
    this.advancedExpanded = false,
    this.testStatus = ConnectionTestStatus.idle,
    this.testMessage,
    this.saveStatus = AccountSaveStatus.idle,
    this.saveMessage,
    this.errorMessage,
    this.savedAccount,
  });

  final String email;
  final String displayName;
  final MailProviderType providerType;
  final MailAuthType authType;
  final int colorValue;
  final String passwordOrAuthCode;
  final OAuthTokenBundle? oauthTokens;
  final bool isOAuthAuthorizing;
  final String imapHost;
  final int imapPort;
  final bool imapImplicitTls;
  final String smtpHost;
  final int smtpPort;
  final bool smtpImplicitTls;
  final bool advancedExpanded;
  final ConnectionTestStatus testStatus;
  final String? testMessage;
  final AccountSaveStatus saveStatus;
  final String? saveMessage;
  final String? errorMessage;
  final MailAccount? savedAccount;

  ProviderPreset get preset => ProviderPresets.byType(providerType);

  bool get supportsPassword =>
      preset.supportedAuthTypes.contains(MailAuthType.passwordOrAuthCode);

  bool get supportsOAuth =>
      preset.supportedAuthTypes.contains(MailAuthType.oauth2Pkce);

  bool get isBusy =>
      testStatus == ConnectionTestStatus.testing ||
      saveStatus == AccountSaveStatus.saving ||
      isOAuthAuthorizing;

  bool get hasValidEmail {
    final value = email.trim();
    final at = value.indexOf('@');
    return at > 0 && at < value.length - 1;
  }

  AccountSetupState copyWith({
    String? email,
    String? displayName,
    MailProviderType? providerType,
    MailAuthType? authType,
    int? colorValue,
    String? passwordOrAuthCode,
    Object? oauthTokens = _unset,
    bool? isOAuthAuthorizing,
    String? imapHost,
    int? imapPort,
    bool? imapImplicitTls,
    String? smtpHost,
    int? smtpPort,
    bool? smtpImplicitTls,
    bool? advancedExpanded,
    ConnectionTestStatus? testStatus,
    Object? testMessage = _unset,
    AccountSaveStatus? saveStatus,
    Object? saveMessage = _unset,
    Object? errorMessage = _unset,
    Object? savedAccount = _unset,
  }) {
    return AccountSetupState(
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      providerType: providerType ?? this.providerType,
      authType: authType ?? this.authType,
      colorValue: colorValue ?? this.colorValue,
      passwordOrAuthCode: passwordOrAuthCode ?? this.passwordOrAuthCode,
      oauthTokens: identical(oauthTokens, _unset)
          ? this.oauthTokens
          : oauthTokens as OAuthTokenBundle?,
      isOAuthAuthorizing: isOAuthAuthorizing ?? this.isOAuthAuthorizing,
      imapHost: imapHost ?? this.imapHost,
      imapPort: imapPort ?? this.imapPort,
      imapImplicitTls: imapImplicitTls ?? this.imapImplicitTls,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      smtpImplicitTls: smtpImplicitTls ?? this.smtpImplicitTls,
      advancedExpanded: advancedExpanded ?? this.advancedExpanded,
      testStatus: testStatus ?? this.testStatus,
      testMessage: identical(testMessage, _unset)
          ? this.testMessage
          : testMessage as String?,
      saveStatus: saveStatus ?? this.saveStatus,
      saveMessage: identical(saveMessage, _unset)
          ? this.saveMessage
          : saveMessage as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      savedAccount: identical(savedAccount, _unset)
          ? this.savedAccount
          : savedAccount as MailAccount?,
    );
  }
}

@riverpod
class AccountSetup extends _$AccountSetup {
  /// Incremented whenever the account identity/auth mode changes or a new
  /// authorization starts. A late result from an older request must never be
  /// written into the newer form state.
  int _oauthRequestVersion = 0;

  @override
  AccountSetupState build() => const AccountSetupState();

  void updateEmail(String value) {
    _oauthRequestVersion++;
    final preset = ProviderPresets.inferFromEmail(value);
    final providerChanged = preset.type != state.providerType;
    var authType = state.authType;
    if (providerChanged || !preset.supportedAuthTypes.contains(authType)) {
      authType = preset.defaultAuthType;
    }

    // Keep manual custom-host edits intact until a known provider is detected.
    final applyPresetHosts =
        preset.type != MailProviderType.custom || providerChanged;
    state = state.copyWith(
      email: value,
      providerType: preset.type,
      authType: authType,
      colorValue: providerChanged ? preset.defaultColorValue : state.colorValue,
      imapHost: applyPresetHosts
          ? ProviderPresets.resolveImapHostForEmail(preset.type, value)
          : state.imapHost,
      imapPort: applyPresetHosts ? preset.imapPort : state.imapPort,
      imapImplicitTls: applyPresetHosts
          ? preset.imapImplicitTls
          : state.imapImplicitTls,
      smtpHost: applyPresetHosts
          ? ProviderPresets.resolveSmtpHostForEmail(preset.type, value)
          : state.smtpHost,
      smtpPort: applyPresetHosts ? preset.smtpPort : state.smtpPort,
      smtpImplicitTls: applyPresetHosts
          ? preset.smtpImplicitTls
          : state.smtpImplicitTls,
      oauthTokens: null,
      isOAuthAuthorizing: false,
      testStatus: ConnectionTestStatus.idle,
      testMessage: null,
      saveStatus: AccountSaveStatus.idle,
      saveMessage: null,
      errorMessage: null,
      savedAccount: null,
    );
  }

  void updateDisplayName(String value) {
    state = state.copyWith(displayName: value, errorMessage: null);
  }

  void selectColor(int colorValue) {
    state = state.copyWith(colorValue: colorValue);
  }

  void selectAuthType(MailAuthType authType) {
    if (!state.preset.supportedAuthTypes.contains(authType)) return;
    _oauthRequestVersion++;
    state = state.copyWith(
      authType: authType,
      isOAuthAuthorizing: false,
      testStatus: ConnectionTestStatus.idle,
      testMessage: null,
      errorMessage: null,
      saveStatus: AccountSaveStatus.idle,
      saveMessage: null,
    );
  }

  void updatePasswordOrAuthCode(String value) {
    state = state.copyWith(
      passwordOrAuthCode: value,
      testStatus: ConnectionTestStatus.idle,
      testMessage: null,
      errorMessage: null,
      saveStatus: AccountSaveStatus.idle,
      saveMessage: null,
    );
  }

  void toggleAdvanced() {
    state = state.copyWith(advancedExpanded: !state.advancedExpanded);
  }

  void updateImapHost(String value) {
    state = state.copyWith(imapHost: value);
  }

  void updateImapPort(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    state = state.copyWith(imapPort: parsed);
  }

  void updateImapImplicitTls(bool value) {
    state = state.copyWith(imapImplicitTls: value);
  }

  void updateSmtpHost(String value) {
    state = state.copyWith(smtpHost: value);
  }

  void updateSmtpPort(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    state = state.copyWith(smtpPort: parsed);
  }

  void updateSmtpImplicitTls(bool value) {
    state = state.copyWith(smtpImplicitTls: value);
  }

  Future<void> startOAuthAuthorization() async {
    if (state.isOAuthAuthorizing) return;
    if (!state.supportsOAuth) {
      state = state.copyWith(
        errorMessage: '${state.preset.displayName} 不支持 OAuth 2.0 登录。',
      );
      return;
    }
    if (!state.hasValidEmail) {
      state = state.copyWith(errorMessage: '请先填写有效的邮箱地址。');
      return;
    }
    final requestEmail = state.email.trim();
    final requestProvider = state.providerType;
    final oauthService = ref.read(oauthPkceServiceProvider);
    if (!oauthService.isConfiguredFor(requestProvider)) {
      state = state.copyWith(
        errorMessage: oauthService.unavailableMessageFor(requestProvider),
      );
      return;
    }

    final requestVersion = ++_oauthRequestVersion;
    state = state.copyWith(
      isOAuthAuthorizing: true,
      errorMessage: null,
      saveStatus: AccountSaveStatus.idle,
      saveMessage: null,
    );

    try {
      final tokens = await oauthService.authorize(
        providerType: requestProvider,
        expectedEmail: requestEmail,
        loginHintEmail: requestEmail,
      );
      if (!ref.mounted || requestVersion != _oauthRequestVersion) return;
      state = state.copyWith(
        oauthTokens: tokens,
        isOAuthAuthorizing: false,
        testStatus: ConnectionTestStatus.idle,
        testMessage: null,
        saveStatus: AccountSaveStatus.idle,
        saveMessage: null,
        errorMessage: null,
      );
    } on AppFailure catch (failure) {
      if (!ref.mounted || requestVersion != _oauthRequestVersion) return;
      state = state.copyWith(
        isOAuthAuthorizing: false,
        errorMessage: failure.userMessage,
      );
    } catch (error) {
      if (!ref.mounted || requestVersion != _oauthRequestVersion) return;
      state = state.copyWith(
        isOAuthAuthorizing: false,
        errorMessage:
            'OAuth 授权失败：${SanitizedLogger.sanitize(error.toString())}',
      );
    }
  }

  Future<void> runConnectionTest() async {
    final validationError = _validate(requireTestableCredential: true);
    if (validationError != null) {
      state = state.copyWith(
        testStatus: ConnectionTestStatus.failure,
        testMessage: validationError,
        errorMessage: validationError,
      );
      return;
    }

    state = state.copyWith(
      testStatus: ConnectionTestStatus.testing,
      testMessage: null,
      errorMessage: null,
      saveStatus: AccountSaveStatus.idle,
      saveMessage: null,
    );

    try {
      final result = await ref
          .read(imapConnectionTesterProvider)
          .testConnection(
            account: _buildDraftAccount(),
            credential: _buildCredential().toResolvedCredential(),
          );
      if (!ref.mounted) return;
      state = state.copyWith(
        testStatus: ConnectionTestStatus.success,
        testMessage:
            '连接成功：已通过 ${result.imapHost} 完成认证并打开 INBOX '
            '（${result.elapsed.inMilliseconds} ms）。',
        errorMessage: null,
      );
    } on AppFailure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(
        testStatus: ConnectionTestStatus.failure,
        testMessage: failure.userMessage,
        errorMessage: failure.userMessage,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        testStatus: ConnectionTestStatus.failure,
        testMessage: '连接测试失败：${SanitizedLogger.sanitize(error.toString())}',
        errorMessage: '连接测试失败：${SanitizedLogger.sanitize(error.toString())}',
      );
    }
  }

  Future<MailAccount?> saveAccount() async {
    final validationError = _validate(requireTestableCredential: true);
    if (validationError != null) {
      state = state.copyWith(
        saveStatus: AccountSaveStatus.failure,
        saveMessage: validationError,
        errorMessage: validationError,
      );
      return null;
    }

    state = state.copyWith(
      saveStatus: AccountSaveStatus.saving,
      saveMessage: null,
      errorMessage: null,
    );

    try {
      final account = await ref
          .read(authRepositoryProvider)
          .addAccount(draft: _buildDraft(), credential: _buildCredential());
      if (!ref.mounted) return account;
      state = state.copyWith(
        saveStatus: AccountSaveStatus.success,
        saveMessage: '账户已保存，凭据已写入系统安全存储。',
        errorMessage: null,
        savedAccount: account,
      );
      return account;
    } on AppFailure catch (failure) {
      if (!ref.mounted) return null;
      state = state.copyWith(
        saveStatus: AccountSaveStatus.failure,
        saveMessage: failure.userMessage,
        errorMessage: failure.userMessage,
      );
      return null;
    } catch (error) {
      if (!ref.mounted) return null;
      state = state.copyWith(
        saveStatus: AccountSaveStatus.failure,
        saveMessage: '保存账户失败：${SanitizedLogger.sanitize(error.toString())}',
        errorMessage: '保存账户失败：${SanitizedLogger.sanitize(error.toString())}',
      );
      return null;
    }
  }

  String? _validate({required bool requireTestableCredential}) {
    if (!state.hasValidEmail) return '请输入有效的邮箱地址。';
    if (state.imapHost.trim().isEmpty) return 'IMAP 服务器地址不能为空。';
    if (state.imapPort < 1 || state.imapPort > 65535) {
      return 'IMAP 端口必须在 1 到 65535 之间。';
    }
    if (state.smtpHost.trim().isEmpty) return 'SMTP 服务器地址不能为空。';
    if (state.smtpPort < 1 || state.smtpPort > 65535) {
      return 'SMTP 端口必须在 1 到 65535 之间。';
    }
    if (!state.preset.supportedAuthTypes.contains(state.authType)) {
      return '${state.preset.displayName} 不支持当前认证方式。';
    }
    if (!requireTestableCredential) return null;

    if (state.authType == MailAuthType.passwordOrAuthCode) {
      final secretError = ProviderPresets.validateAuthorizationSecret(
        state.providerType,
        state.passwordOrAuthCode,
      );
      if (secretError != null) return secretError;
    } else {
      final tokens = state.oauthTokens;
      if (tokens == null) return '请先完成 OAuth 2.0 授权登录。';
      final boundEmail = tokens.accountEmail;
      if (boundEmail != null &&
          !OAuthPkceService.emailsMatchForProvider(
            state.providerType,
            state.email,
            boundEmail,
          )) {
        return 'OAuth 授权账号与填写的邮箱不一致，请重新登录正确的账户。';
      }
    }
    return null;
  }

  MailAccountDraft _buildDraft() {
    return MailAccountDraft(
      email: state.email.trim(),
      displayName: state.displayName.trim(),
      providerType: state.providerType,
      authType: state.authType,
      colorValue: state.colorValue,
      imapHost: state.imapHost.trim(),
      imapPort: state.imapPort,
      imapImplicitTls: state.imapImplicitTls,
      smtpHost: state.smtpHost.trim(),
      smtpPort: state.smtpPort,
      smtpImplicitTls: state.smtpImplicitTls,
    );
  }

  MailAccount _buildDraftAccount() {
    return _buildDraft().toAccount(
      id: 'draft-preview',
      createdAt: DateTime.now().toUtc(),
    );
  }

  PendingAccountCredential _buildCredential() {
    if (state.authType == MailAuthType.oauth2Pkce) {
      final tokens = state.oauthTokens;
      if (tokens == null) {
        throw const AuthFailure(
          reason: AuthFailureReason.oauthRequired,
          userMessage: '请先完成 OAuth 2.0 授权登录。',
        );
      }
      return OAuthAccountCredential(tokens);
    }
    return PasswordAccountCredential(
      ProviderPresets.normalizeAuthorizationSecret(
        state.providerType,
        state.passwordOrAuthCode,
      ),
    );
  }
}
