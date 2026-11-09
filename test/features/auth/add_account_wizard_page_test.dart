import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/features/auth/domain/entities/account_setup_draft.dart';
import 'package:local_mail_client/features/auth/presentation/pages/add_account_wizard_page.dart';

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
  await tester.enterText(find.byKey(const Key('add-account-email')), email);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    350,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
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
    expect(find.byKey(const Key('add-account-client-id')), findsOneWidget);
    expect(find.textContaining('必须使用 OAuth 2.0'), findsOneWidget);
    expect(find.textContaining('不经过任何第三方中转服务器'), findsOneWidget);
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
}
