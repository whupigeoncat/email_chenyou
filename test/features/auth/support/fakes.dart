import 'dart:async';

import 'package:enough_mail/enough_mail.dart' hide MailAccount;
// `ConnectionInfo` is required to override `connectToServer` in the fake and
// is intentionally not part of enough_mail's public barrel export.
import 'package:enough_mail/src/private/util/client_base.dart'
    show ConnectionInfo;
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/network/connection_pool.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/core/security/oauth_pkce_service.dart';
import 'package:local_mail_client/core/security/secure_storage_service.dart';
import 'package:local_mail_client/features/auth/data/imap_connection_tester.dart';
import 'package:local_mail_client/features/auth/domain/entities/account_setup_draft.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/auth/domain/repositories/auth_repository.dart';

import '../../../core/support/fake_imap_session.dart';

class InMemorySecureStorageService extends SecureStorageService {
  final Map<String, String> passwordSecrets = <String, String>{};
  final Map<String, OAuthTokenBundle> oauthBundles =
      <String, OAuthTokenBundle>{};
  int deleteCredentialCalls = 0;

  @override
  Future<void> savePasswordSecret(String accountId, String secret) async {
    passwordSecrets[accountId] = secret;
    oauthBundles.remove(accountId);
  }

  @override
  Future<String?> readPasswordSecret(String accountId) async {
    return passwordSecrets[accountId];
  }

  @override
  Future<void> saveOAuthTokens(
    String accountId,
    OAuthTokenBundle bundle,
  ) async {
    oauthBundles[accountId] = bundle;
    passwordSecrets.remove(accountId);
  }

  @override
  Future<OAuthTokenBundle?> readOAuthTokens(String accountId) async {
    return oauthBundles[accountId];
  }

  @override
  Future<bool> hasAnyCredential(String accountId) async {
    return passwordSecrets.containsKey(accountId) ||
        oauthBundles.containsKey(accountId);
  }

  @override
  Future<void> deleteAccountCredentials(String accountId) async {
    deleteCredentialCalls++;
    passwordSecrets.remove(accountId);
    oauthBundles.remove(accountId);
  }
}

class FakeOAuthPkceService extends OAuthPkceService {
  FakeOAuthPkceService({
    this.refreshDelay = Duration.zero,
    this.configured = true,
  });

  final Duration refreshDelay;
  final bool configured;
  int refreshCount = 0;
  int deviceRefreshCount = 0;
  int authorizeCount = 0;
  Object? authorizeError;
  OAuthTokenBundle? authorizeResult;
  String? lastExpectedEmail;
  final List<String> deviceRefreshEmails = <String>[];

  @override
  bool isConfiguredFor(MailProviderType provider) => configured;

  @override
  String unavailableMessageFor(MailProviderType provider) =>
      provider == MailProviderType.gmail
      ? '此构建未配置 Google 登录。'
      : '此构建未配置 Microsoft 登录。';

  @override
  Future<OAuthTokenBundle> authorize({
    required MailProviderType providerType,
    String? expectedEmail,
    String? loginHintEmail,
  }) async {
    authorizeCount++;
    lastExpectedEmail = expectedEmail ?? loginHintEmail;
    final error = authorizeError;
    if (error != null) throw error;
    return authorizeResult ??
        OAuthTokenBundle(
          accessToken: 'authorized-access-token',
          refreshToken: 'authorized-refresh-token',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          clientId: 'test-client-id',
          tokenEndpoint: 'https://oauth.example.invalid/token',
          scopes: const ['mail'],
          accountEmail: expectedEmail ?? loginHintEmail,
        );
  }

  @override
  Future<OAuthTokenBundle> refreshToken(OAuthTokenBundle current) async {
    refreshCount++;
    if (refreshDelay > Duration.zero) {
      await Future<void>.delayed(refreshDelay);
    }
    return OAuthTokenBundle(
      accessToken: 'refreshed-access-token-$refreshCount',
      refreshToken: current.refreshToken,
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      clientId: current.clientId,
      tokenEndpoint: current.tokenEndpoint,
      scopes: current.scopes,
      accountEmail: current.accountEmail,
    );
  }

  @override
  Future<OAuthTokenBundle> refreshDeviceAuthorization({
    required MailProviderType providerType,
    required OAuthTokenBundle current,
  }) async {
    deviceRefreshCount++;
    deviceRefreshEmails.add(current.accountEmail ?? '');
    if (refreshDelay > Duration.zero) {
      await Future<void>.delayed(refreshDelay);
    }
    return OAuthTokenBundle(
      accessToken: 'device-refreshed-token-$deviceRefreshCount',
      refreshToken: null,
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      clientId: '',
      tokenEndpoint: '',
      scopes: current.scopes,
      accountEmail: current.accountEmail,
      deviceAuthorization: true,
    );
  }
}

class RecordingConnectionPool extends ConnectionPool {
  RecordingConnectionPool({ImapSessionFactory? sessionFactory})
    : super(
        sessionFactory: sessionFactory ?? FakeImapSessionFactory(),
        credentialResolver: (_) async =>
            const PasswordCredential('recording-secret'),
      );

  final List<List<String>> syncCalls = <List<String>>[];

  @override
  Future<void> syncAccounts(List<MailAccount> accounts) async {
    syncCalls.add(
      accounts.map((account) => account.id).toList(growable: false),
    );
  }
}

/// Mock wire client used by the session/tester tests. It records every
/// protocol step without opening a socket.
class FakeImapClient extends ImapClient {
  FakeImapClient({
    this.failOnConnect = false,
    this.failOnSelect = false,
    this.loginFailureMessage,
    this.startTlsSupported = false,
    this.supportsIdle = false,
  }) {
    _serverInfo =
        ImapServerInfo(ConnectionInfo('fake.example', 143, isSecure: false))
          ..capabilities = <Capability>[
            if (startTlsSupported)
              const Capability(ImapServerInfo.capabilityStartTls),
            if (supportsIdle) const Capability(ImapServerInfo.capabilityIdle),
          ];
  }

  final bool failOnConnect;
  final bool failOnSelect;
  final String? loginFailureMessage;
  final bool startTlsSupported;
  final bool supportsIdle;

  late final ImapServerInfo _serverInfo;
  final List<String> protocol = <String>[];
  bool _fakeConnected = false;
  Id? lastClientId;

  @override
  ImapServerInfo get serverInfo => _serverInfo;

  @override
  Future<GenericImapResult> startTls() async {
    protocol.add('startTls');
    if (!startTlsSupported) {
      throw ImapException(this, 'STARTTLS is not supported');
    }
    return GenericImapResult();
  }

  @override
  Future<List<Capability>> capability() async {
    protocol.add('capability');
    return serverInfo.capabilities ?? const <Capability>[];
  }

  @override
  bool get isConnected => _fakeConnected;

  @override
  Future<ConnectionInfo> connectToServer(
    String host,
    int port, {
    bool isSecure = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    protocol.add('connect');
    if (failOnConnect) {
      throw ImapException(this, 'connection closed by peer');
    }
    _fakeConnected = true;
    return ConnectionInfo(host, port, isSecure: isSecure);
  }

  @override
  Future<List<Capability>> login(String name, String password) async {
    protocol.add('login');
    final failure = loginFailureMessage;
    if (failure != null) throw ImapException(this, failure);
    isLoggedIn = true;
    return const <Capability>[];
  }

  @override
  Future<List<Capability>> authenticateWithOAuth2(
    String user,
    String accessToken,
  ) async {
    protocol.add('oauth');
    final failure = loginFailureMessage;
    if (failure != null) throw ImapException(this, failure);
    isLoggedIn = true;
    return const <Capability>[];
  }

  @override
  Future<Id?> id({Id? clientId}) async {
    protocol.add('id');
    lastClientId = clientId;
    return null;
  }

  @override
  Future<Mailbox> selectInbox({
    bool enableCondStore = false,
    QResyncParameters? qresync,
  }) async {
    protocol.add('selectInbox');
    if (failOnSelect) {
      throw ImapException(this, 'select failed');
    }
    return Mailbox(
      encodedName: 'INBOX',
      encodedPath: 'INBOX',
      flags: <MailboxFlag>[],
      pathSeparator: '/',
    );
  }

  @override
  Future<Mailbox> selectMailboxByPath(
    String path, {
    bool enableCondStore = false,
    QResyncParameters? qresync,
  }) async {
    protocol.add('select:$path');
    return Mailbox(
      encodedName: path,
      encodedPath: path,
      flags: <MailboxFlag>[],
      pathSeparator: '/',
    );
  }

  @override
  Future<void> idleStart({bool waitForContinuation = false}) async {
    protocol.add('idleStart');
  }

  @override
  Future<dynamic> idleDone() async {
    protocol.add('idleDone');
  }

  @override
  Future<Mailbox?> noop() async {
    protocol.add('noop');
    return null;
  }

  @override
  Future<dynamic> logout() async {
    protocol.add('logout');
    isLoggedIn = false;
  }

  @override
  Future<void> disconnect() async {
    protocol.add('disconnect');
    _fakeConnected = false;
    isLoggedIn = false;
  }
}

class FakeImapConnectionTester extends ImapConnectionTester {
  FakeImapConnectionTester() : super(sessionFactory: FakeImapSessionFactory());

  final List<MailAccount> testedAccounts = <MailAccount>[];
  final List<ResolvedAccountCredential> testedCredentials =
      <ResolvedAccountCredential>[];
  AppFailure? error;
  Duration elapsed = const Duration(milliseconds: 12);

  @override
  Future<ImapConnectionTestResult> testConnection({
    required MailAccount account,
    required ResolvedAccountCredential credential,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    testedAccounts.add(account);
    testedCredentials.add(credential);
    final failure = error;
    if (failure != null) throw failure;
    return ImapConnectionTestResult(
      imapHost: account.imapHost,
      selectedFolder: 'INBOX',
      elapsed: elapsed,
    );
  }
}

class FakeAuthRepository implements AuthRepository {
  final List<MailAccount> accounts = <MailAccount>[];
  final List<MailAccountDraft> addedDrafts = <MailAccountDraft>[];
  final List<PendingAccountCredential> addedCredentials =
      <PendingAccountCredential>[];
  final List<String> deletedIds = <String>[];
  final List<(String, bool)> enabledChanges = <(String, bool)>[];
  final List<(String, PendingAccountCredential)> replacedCredentials =
      <(String, PendingAccountCredential)>[];

  final StreamController<List<MailAccount>> _controller =
      StreamController<List<MailAccount>>.broadcast();

  @override
  Stream<List<MailAccount>> watchAccounts() async* {
    yield List<MailAccount>.unmodifiable(accounts);
    yield* _controller.stream;
  }

  @override
  Future<List<MailAccount>> getAccounts() async =>
      List<MailAccount>.unmodifiable(accounts);

  @override
  Future<MailAccount?> getAccount(String accountId) async {
    for (final account in accounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  @override
  Future<MailAccount> addAccount({
    required MailAccountDraft draft,
    required PendingAccountCredential credential,
  }) async {
    addedDrafts.add(draft);
    addedCredentials.add(credential);
    final account = draft.toAccount(
      id: 'acc-${accounts.length + 1}',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    accounts.add(account);
    _controller.add(List<MailAccount>.unmodifiable(accounts));
    return account;
  }

  @override
  Future<MailAccount> updateAccount(MailAccount account) async {
    final index = accounts.indexWhere((item) => item.id == account.id);
    if (index >= 0) accounts[index] = account;
    _controller.add(List<MailAccount>.unmodifiable(accounts));
    return account;
  }

  @override
  Future<void> setAccountEnabled(String accountId, bool isEnabled) async {
    enabledChanges.add((accountId, isEnabled));
    final index = accounts.indexWhere((item) => item.id == accountId);
    if (index >= 0) {
      accounts[index] = accounts[index].copyWith(isEnabled: isEnabled);
      _controller.add(List<MailAccount>.unmodifiable(accounts));
    }
  }

  @override
  Future<void> replaceCredential(
    String accountId,
    PendingAccountCredential credential,
  ) async {
    replacedCredentials.add((accountId, credential));
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    deletedIds.add(accountId);
    accounts.removeWhere((item) => item.id == accountId);
    _controller.add(List<MailAccount>.unmodifiable(accounts));
  }

  @override
  Future<void> initialize() async {}

  Future<void> dispose() => _controller.close();
}

MailAccountDraft buildDraft({
  String email = 'carol@163.com',
  MailProviderType? providerType,
  MailAuthType authType = MailAuthType.passwordOrAuthCode,
  String displayName = 'Carol',
  int colorValue = 0xFFD93025,
}) {
  final preset = ProviderPresets.inferFromEmail(email);
  final type = providerType ?? preset.type;
  return MailAccountDraft(
    email: email,
    displayName: displayName,
    providerType: type,
    authType: authType,
    colorValue: colorValue,
    imapHost: ProviderPresets.resolveImapHostForEmail(type, email),
    imapPort: preset.imapPort,
    imapImplicitTls: preset.imapImplicitTls,
    smtpHost: ProviderPresets.resolveSmtpHostForEmail(type, email),
    smtpPort: preset.smtpPort,
    smtpImplicitTls: preset.smtpImplicitTls,
  );
}
