import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/security/secure_storage_service.dart';
import 'package:local_mail_client/features/auth/domain/entities/account_setup_draft.dart';
import 'package:local_mail_client/features/auth/presentation/pages/add_account_wizard_page.dart';
import 'package:local_mail_client/features/auth/presentation/providers/account_setup_provider.dart';

import 'support/fakes.dart';

Widget _wizardApp({
  required FakeAuthRepository repository,
  required FakeImapConnectionTester tester,
  FakeOAuthPkceService? oauth,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      imapConnectionTesterProvider.overrideWithValue(tester),
      oauthPkceServiceProvider.overrideWithValue(
        oauth ?? FakeOAuthPkceService(),
      ),
    ],
    child: const MaterialApp(home: AddAccountWizardPage()),
  );
}

Future<void> _enterEmail(WidgetTester tester, String email) async {
  final finder = find.byKey(const Key('add-account-email'));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      -350,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.enterText(finder, email);
  await tester.pumpAndSettle();
}

Future<void> _scrollToWhileBusy(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    350,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    350,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

OAuthTokenBundle _oauthBundle(String email) {
  return OAuthTokenBundle(
    accessToken: 'access-$email',
    refreshToken: 'refresh-$email',
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    clientId: 'client-id',
    tokenEndpoint: 'https://oauth.example.invalid/token',
    scopes: const ['https://mail.google.com/'],
    accountEmail: email,
  );
}

class _ControllableOAuthPkceService extends FakeOAuthPkceService {
  final Map<String, Completer<OAuthTokenBundle>> pending =
      <String, Completer<OAuthTokenBundle>>{};

  @override
  Future<OAuthTokenBundle> authorize({
    required MailProviderType providerType,
    String? expectedEmail,
    String? loginHintEmail,
  }) {
    authorizeCount++;
    final email = (expectedEmail ?? loginHintEmail ?? '').trim();
    lastExpectedEmail = email;
    final completer = Completer<OAuthTokenBundle>();
    pending[email] = completer;
    return completer.future;
  }
}

void main() {
  testWidgets('infers 163, Foxmail and Outlook presets from the domain', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final testerService = FakeImapConnectionTester();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      _wizardApp(repository: repository, tester: testerService),
    );

    await _enterEmail(tester, 'carol@163.com');
    expect(find.textContaining('已识别服务商：网易 163 邮箱'), findsOneWidget);
    expect(find.byKey(const Key('add-account-password')), findsOneWidget);
    expect(find.byKey(const Key('add-account-client-id')), findsNothing);

    await _enterEmail(tester, 'erin@foxmail.com');
    expect(find.textContaining('已识别服务商：Foxmail 邮箱'), findsOneWidget);

    await _enterEmail(tester, 'bob@outlook.com');
    expect(find.textContaining('已识别服务商：Outlook / Hotmail'), findsOneWidget);
  });

  testWidgets('Outlook forces OAuth and hides the password field', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      _wizardApp(repository: repository, tester: FakeImapConnectionTester()),
    );

    await _enterEmail(tester, 'bob@outlook.com');

    expect(find.byKey(const Key('add-account-password')), findsNothing);
    expect(find.byKey(const Key('add-account-client-id')), findsNothing);
    expect(find.text('使用 Microsoft 登录'), findsOneWidget);
    expect(find.textContaining('微软已停止支持个人版 Outlook'), findsOneWidget);
    expect(find.textContaining('不经过第三方中转服务器'), findsOneWidget);
  });

  testWidgets('shows a clear message when this build has no Microsoft config', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      _wizardApp(
        repository: repository,
        tester: FakeImapConnectionTester(),
        oauth: FakeOAuthPkceService(configured: false),
      ),
    );

    await _enterEmail(tester, 'bob@outlook.com');

    expect(find.textContaining('此构建未配置 Microsoft 登录'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('add-account-oauth')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Google login button binds the typed email and shows success', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final oauth = FakeOAuthPkceService();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      _wizardApp(
        repository: repository,
        tester: FakeImapConnectionTester(),
        oauth: oauth,
      ),
    );

    await _enterEmail(tester, 'alice@gmail.com');
    await _scrollTo(tester, const Key('add-account-oauth'));
    expect(find.text('使用 Google 登录'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-account-oauth')));
    await tester.pumpAndSettle();

    expect(oauth.lastExpectedEmail, 'alice@gmail.com');
    expect(find.textContaining('已获取 OAuth 令牌'), findsOneWidget);
  });

  testWidgets('cancelled Google login surfaces the cancellation message', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final oauth = FakeOAuthPkceService()
      ..authorizeError = const AuthFailure(
        reason: AuthFailureReason.oauthCancelled,
        userMessage: 'Google 登录已取消。',
      );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      _wizardApp(
        repository: repository,
        tester: FakeImapConnectionTester(),
        oauth: oauth,
      ),
    );

    await _enterEmail(tester, 'alice@gmail.com');
    await _scrollTo(tester, const Key('add-account-oauth'));
    await tester.tap(find.byKey(const Key('add-account-oauth')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Google 登录已取消'), findsOneWidget);
  });

  testWidgets('QQ guide is shown and short codes are rejected before connect', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final testerService = FakeImapConnectionTester();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      _wizardApp(repository: repository, tester: testerService),
    );

    await _enterEmail(tester, 'dave@qq.com');
    expect(find.byKey(const Key('qq-auth-code-guide')), findsOneWidget);
    expect(find.textContaining('此客户端使用 QQ 官方 16 位'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('add-account-password')),
      'qq-password',
    );
    await _scrollTo(tester, const Key('add-account-test'));
    await tester.tap(find.byKey(const Key('add-account-test')));
    await tester.pumpAndSettle();

    expect(find.textContaining('16 位客户端授权码'), findsWidgets);
    expect(testerService.testedAccounts, isEmpty);
  });

  testWidgets('renders the Chinese failure returned by the connection test', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final testerService = FakeImapConnectionTester()
      ..error = const AuthFailure(
        reason: AuthFailureReason.invalidCredentials,
        userMessage: '认证失败：请使用客户端授权码（不是登录密码）。',
      );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      _wizardApp(repository: repository, tester: testerService),
    );

    await _enterEmail(tester, 'carol@163.com');
    await tester.enterText(
      find.byKey(const Key('add-account-password')),
      'wrong-code',
    );
    await _scrollTo(tester, const Key('add-account-test'));
    await tester.tap(find.byKey(const Key('add-account-test')));
    await tester.pumpAndSettle();

    expect(find.textContaining('认证失败：请使用客户端授权码'), findsOneWidget);
    expect(testerService.testedAccounts.single.email, 'carol@163.com');
  });

  testWidgets('save passes metadata and credential as separate objects', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      _wizardApp(repository: repository, tester: FakeImapConnectionTester()),
    );

    await _enterEmail(tester, 'carol@163.com');
    await tester.enterText(
      find.byKey(const Key('add-account-password')),
      '163-auth-code',
    );
    await _scrollTo(tester, const Key('add-account-save'));
    await tester.tap(find.byKey(const Key('add-account-save')));
    await tester.pumpAndSettle();

    expect(repository.addedDrafts, hasLength(1));
    expect(repository.addedDrafts.single.email, 'carol@163.com');
    expect(
      repository.addedCredentials.single,
      isA<PasswordAccountCredential>(),
    );
    expect(
      (repository.addedCredentials.single as PasswordAccountCredential).secret,
      '163-auth-code',
    );
    expect(find.textContaining('账户已保存'), findsOneWidget);
  });

  testWidgets(
    'googlemail alias authorization can test and save through the wizard',
    (tester) async {
      final repository = FakeAuthRepository();
      final oauth = FakeOAuthPkceService()
        ..authorizeResult = _oauthBundle('alice@gmail.com');
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        _wizardApp(
          repository: repository,
          tester: FakeImapConnectionTester(),
          oauth: oauth,
        ),
      );

      await _enterEmail(tester, 'alice@googlemail.com');
      await _scrollTo(tester, const Key('add-account-oauth'));
      await tester.tap(find.byKey(const Key('add-account-oauth')));
      await tester.pumpAndSettle();
      expect(find.textContaining('已获取 OAuth 令牌'), findsOneWidget);

      await _scrollTo(tester, const Key('add-account-test'));
      await tester.tap(find.byKey(const Key('add-account-test')));
      await tester.pumpAndSettle();
      expect(find.textContaining('连接成功'), findsOneWidget);

      await _scrollTo(tester, const Key('add-account-save'));
      await tester.tap(find.byKey(const Key('add-account-save')));
      await tester.pumpAndSettle();

      expect(repository.addedDrafts.single.email, 'alice@googlemail.com');
      final credential =
          repository.addedCredentials.single as OAuthAccountCredential;
      expect(credential.tokens.accountEmail, 'alice@gmail.com');
    },
  );

  testWidgets(
    'a stale authorization result cannot overwrite a newer email request',
    (tester) async {
      final repository = FakeAuthRepository();
      final oauth = _ControllableOAuthPkceService();
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        _wizardApp(
          repository: repository,
          tester: FakeImapConnectionTester(),
          oauth: oauth,
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AddAccountWizardPage)),
      );

      await _enterEmail(tester, 'alice@gmail.com');
      await _scrollTo(tester, const Key('add-account-oauth'));
      await tester.tap(find.byKey(const Key('add-account-oauth')));
      await tester.pump();
      expect(oauth.pending.keys, contains('alice@gmail.com'));

      await _enterEmail(tester, 'bob@gmail.com');
      expect(container.read(accountSetupProvider).isOAuthAuthorizing, isFalse);

      await _scrollTo(tester, const Key('add-account-oauth'));
      await tester.tap(find.byKey(const Key('add-account-oauth')));
      await tester.pump();
      expect(oauth.pending.keys, contains('bob@gmail.com'));

      oauth.pending['alice@gmail.com']!.complete(
        _oauthBundle('alice@gmail.com'),
      );
      await tester.pump();
      await tester.pump();
      var state = container.read(accountSetupProvider);
      expect(state.oauthTokens, isNull);
      expect(
        state.isOAuthAuthorizing,
        isTrue,
        reason: 'newer request still runs',
      );

      oauth.pending['bob@gmail.com']!.complete(_oauthBundle('bob@gmail.com'));
      await tester.pumpAndSettle();
      state = container.read(accountSetupProvider);
      expect(state.oauthTokens?.accountEmail, 'bob@gmail.com');
      expect(state.isOAuthAuthorizing, isFalse);

      await _scrollTo(tester, const Key('add-account-save'));
      await tester.tap(find.byKey(const Key('add-account-save')));
      await tester.pumpAndSettle();

      expect(repository.addedDrafts.single.email, 'bob@gmail.com');
      final credential =
          repository.addedCredentials.single as OAuthAccountCredential;
      expect(credential.tokens.accountEmail, 'bob@gmail.com');
    },
  );

  testWidgets('switching auth type invalidates a pending OAuth result', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final oauth = _ControllableOAuthPkceService();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      _wizardApp(
        repository: repository,
        tester: FakeImapConnectionTester(),
        oauth: oauth,
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AddAccountWizardPage)),
    );

    await _enterEmail(tester, 'alice@gmail.com');
    await _scrollTo(tester, const Key('add-account-oauth'));
    await tester.tap(find.byKey(const Key('add-account-oauth')));
    await tester.pump();

    await _scrollToWhileBusy(tester, const Key('auth-type-password'));
    await tester.tap(find.byKey(const Key('auth-type-password')));
    await tester.pumpAndSettle();

    oauth.pending['alice@gmail.com']!.complete(_oauthBundle('alice@gmail.com'));
    await tester.pump();
    await tester.pump();

    final state = container.read(accountSetupProvider);
    expect(state.authType, MailAuthType.passwordOrAuthCode);
    expect(state.oauthTokens, isNull);
    expect(state.isOAuthAuthorizing, isFalse);
    expect(state.errorMessage, isNull);
    expect(find.byKey(const Key('add-account-password')), findsOneWidget);
  });
}
