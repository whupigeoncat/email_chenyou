import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/app_runtime_providers.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/core/network/account_connection_slot.dart';
import 'package:local_mail_client/features/mail/data/repositories/mail_local_repository.dart';
import 'package:local_mail_client/features/mail/data/repositories/trusted_senders_repository_impl.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/domain/entities/mail_folder.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/domain/usecases/poll_folder_usecase.dart';
import 'package:local_mail_client/features/mail/presentation/pages/mail_shell_page.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';

import '../auth/support/fakes.dart';
import 'support/mail_fixture.dart';
import 'support/test_runtime.dart';

class RecordingPollFolderUseCase implements PollFolderUseCase {
  int calls = 0;
  MailFolder? lastFolder;

  @override
  Future<MailFolder> call({
    required MailAccount account,
    required MailFolder folder,
    bool loadOlder = false,
  }) async {
    calls++;
    lastFolder = folder;
    return folder;
  }
}

const List<String> _folderNames = <String>[
  '收件箱',
  '已发送',
  '草稿箱',
  '已删除',
  '垃圾邮件',
  '归档',
  '自定义文件夹',
];

MailAccount _makeAccount(int index, {bool isEnabled = true}) {
  return MailAccount(
    id: 'ui-$index',
    email: 'account${index + 1}@example.com',
    displayName: '邮箱 ${index + 1}',
    providerType: MailProviderType.gmail,
    authType: MailAuthType.passwordOrAuthCode,
    colorValue: 0xFF0F766E,
    imapHost: 'imap.example.com',
    imapPort: 993,
    imapImplicitTls: true,
    smtpHost: 'smtp.example.com',
    smtpPort: 465,
    smtpImplicitTls: true,
    isEnabled: isEnabled,
    createdAt: DateTime.utc(2026),
  );
}

List<MailFolder> _makeFolders(MailAccount account, {int count = 7}) {
  return List<MailFolder>.generate(count, (index) {
    return MailFolder(
      id: '${account.id}-folder-$index',
      accountId: account.id,
      remoteName: 'Folder$index',
      displayName: _folderNames[index % _folderNames.length],
      role: FolderRole.values[index % FolderRole.values.length],
    );
  });
}

List<Override> _shellOverrides({
  required TestRuntimeHarness harness,
  required List<MailAccount> accounts,
  required FakeAuthRepository auth,
  required MailLocalRepository localRepository,
  Stream<List<MailAccount>>? accountsStream,
  Map<String, List<MailFolder>>? foldersByAccount,
  PollFolderUseCase? pollFolder,
}) {
  return <Override>[
    appRuntimeProvider.overrideWithValue(harness.runtime),
    outboxCountsProvider.overrideWith(
      (ref) => Stream<OutboxCounts>.value(const OutboxCounts()),
    ),
    accountsProvider.overrideWith(
      (ref) => accountsStream ?? Stream<List<MailAccount>>.value(accounts),
    ),
    accountSlotStatesProvider.overrideWith(
      (ref) => Stream<Map<String, ConnectionSlotState>>.value(
        const <String, ConnectionSlotState>{},
      ),
    ),
    authRepositoryProvider.overrideWithValue(auth),
    mailLocalRepositoryProvider.overrideWithValue(localRepository),
    if (pollFolder != null)
      pollFolderUseCaseProvider.overrideWithValue(pollFolder),
    if (foldersByAccount != null)
      for (final entry in foldersByAccount.entries)
        accountFoldersProvider(entry.key)
            .overrideWith((ref) => Stream<List<MailFolder>>.value(entry.value)),
  ];
}

MaterialApp _shellApp({double textScale = 1}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const MailShellPage(),
  );
}

Widget _shell(List<Override> overrides, {double textScale = 1}) {
  return ProviderScope(
    overrides: overrides,
    child: _shellApp(textScale: textScale),
  );
}

Finder _sidebarScrollable() {
  return find
      .descendant(
        of: find.byKey(const Key('mail-sidebar')),
        matching: find.byType(Scrollable),
      )
      .first;
}

void _expectInsideSidebarViewport(WidgetTester tester, Finder target) {
  expect(
    target.hitTestable(),
    findsOneWidget,
    reason: 'target must be tappable inside the sidebar viewport',
  );
  final viewport = tester.getRect(find.byKey(const Key('mail-sidebar')));
  final targetRect = tester.getRect(target);
  expect(
    viewport.contains(targetRect.center),
    isTrue,
    reason: '$targetRect is outside sidebar viewport $viewport',
  );
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('desktop shell uses three panes and empty-account guidance', (
    tester,
  ) async {
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimeProvider.overrideWithValue(harness.runtime),
          outboxCountsProvider.overrideWith(
            (ref) => Stream<OutboxCounts>.value(const OutboxCounts()),
          ),
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value(const <MailAccount>[]),
          ),
          accountSlotStatesProvider.overrideWith(
            (ref) => Stream<Map<String, ConnectionSlotState>>.value(
              const <String, ConnectionSlotState>{},
            ),
          ),
        ],
        child: const MaterialApp(home: MailShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mail-sidebar')), findsOneWidget);
    expect(find.text('聚合收件箱'), findsOneWidget);
    expect(find.byKey(const Key('empty-add-account')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('mobile shell uses a drawer and hides the desktop sidebar', (
    tester,
  ) async {
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimeProvider.overrideWithValue(harness.runtime),
          outboxCountsProvider.overrideWith(
            (ref) => Stream<OutboxCounts>.value(const OutboxCounts()),
          ),
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value(const <MailAccount>[]),
          ),
          accountSlotStatesProvider.overrideWith(
            (ref) => Stream<Map<String, ConnectionSlotState>>.value(
              const <String, ConnectionSlotState>{},
            ),
          ),
        ],
        child: const MaterialApp(home: MailShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open-mail-drawer')), findsOneWidget);
    expect(find.byKey(const Key('mail-sidebar')), findsNothing);
    await tester.tap(find.byKey(const Key('open-mail-drawer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mail-sidebar')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('selecting a non-INBOX folder invokes PollFolderUseCase', (
    tester,
  ) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    await fixture.database
        .into(fixture.database.dbFolders)
        .insert(
          DbFoldersCompanion.insert(
            id: 'sent-folder',
            accountId: fixture.account.id,
            remoteName: 'Sent',
            displayName: 'Sent',
            role: FolderRole.sent.storageKey,
          ),
        );
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final poll = RecordingPollFolderUseCase();
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimeProvider.overrideWithValue(harness.runtime),
          outboxCountsProvider.overrideWith(
            (ref) => Stream<OutboxCounts>.value(const OutboxCounts()),
          ),
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          accountSlotStatesProvider.overrideWith(
            (ref) => Stream<Map<String, ConnectionSlotState>>.value(
              const <String, ConnectionSlotState>{
                'acc-1': ConnectionSlotState.pollingInInbox,
              },
            ),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          mailLocalRepositoryProvider.overrideWithValue(
            fixture.localRepository,
          ),
          pollFolderUseCaseProvider.overrideWithValue(poll),
          trustedSendersRepositoryProvider.overrideWithValue(
            TrustedSendersRepositoryImpl(database: fixture.database),
          ),
        ],
        child: const MaterialApp(home: MailShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('收件箱轮询中'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);
    await tester.tap(find.text('Sent'));
    await tester.pumpAndSettle();

    expect(poll.calls, 1);
    expect(poll.lastFolder?.remoteName, 'Sent');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('selected reading pane resets when folder changes', (
    tester,
  ) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    await fixture.database
        .into(fixture.database.dbFolders)
        .insert(
          DbFoldersCompanion.insert(
            id: 'sent-folder',
            accountId: fixture.account.id,
            remoteName: 'Sent',
            displayName: 'Sent',
            role: FolderRole.sent.storageKey,
          ),
        );
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final poll = RecordingPollFolderUseCase();
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimeProvider.overrideWithValue(harness.runtime),
          outboxCountsProvider.overrideWith(
            (ref) => Stream<OutboxCounts>.value(const OutboxCounts()),
          ),
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          accountSlotStatesProvider.overrideWith(
            (ref) => Stream<Map<String, ConnectionSlotState>>.value(
              const <String, ConnectionSlotState>{},
            ),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          mailLocalRepositoryProvider.overrideWithValue(
            fixture.localRepository,
          ),
          pollFolderUseCaseProvider.overrideWithValue(poll),
          trustedSendersRepositoryProvider.overrideWithValue(
            TrustedSendersRepositoryImpl(database: fixture.database),
          ),
        ],
        child: const MaterialApp(home: MailShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('email-tile-${fixture.account.id}-1')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safe-html-widget')), findsOneWidget);

    await tester.tap(find.text('Sent'));
    await tester.pumpAndSettle();
    expect(find.text('选择一封邮件开始阅读'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('responsive boundaries render without overflow', (tester) async {
    for (final width in <double>[960, 959, 500, 360, 320]) {
      final harness = TestRuntimeHarness();
      addTearDown(harness.dispose);
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appRuntimeProvider.overrideWithValue(harness.runtime),
            outboxCountsProvider.overrideWith(
              (ref) => Stream<OutboxCounts>.value(const OutboxCounts()),
            ),
            accountsProvider.overrideWith(
              (ref) => Stream<List<MailAccount>>.value(const <MailAccount>[]),
            ),
            accountSlotStatesProvider.overrideWith(
              (ref) => Stream<Map<String, ConnectionSlotState>>.value(
                const <String, ConnectionSlotState>{},
              ),
            ),
          ],
          child: const MaterialApp(home: MailShellPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width overflow');
      if (width >= 960) {
        expect(find.byKey(const Key('mail-sidebar')), findsOneWidget);
      } else {
        expect(find.byKey(const Key('open-mail-drawer')), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('compose button opens the real compose page', (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimeProvider.overrideWithValue(harness.runtime),
          outboxCountsProvider.overrideWith(
            (ref) => Stream<OutboxCounts>.value(const OutboxCounts()),
          ),
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          accountSlotStatesProvider.overrideWith(
            (ref) => Stream<Map<String, ConnectionSlotState>>.value(
              const <String, ConnectionSlotState>{},
            ),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          mailLocalRepositoryProvider.overrideWithValue(
            fixture.localRepository,
          ),
        ],
        child: const MaterialApp(home: MailShellPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose-mail')));
    await tester.pumpAndSettle();

    expect(find.text('写邮件'), findsOneWidget);
    expect(find.byKey(const Key('compose-send')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('sidebar shows outbox badge and opens the outbox page', (
    tester,
  ) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimeProvider.overrideWithValue(harness.runtime),
          outboxCountsProvider.overrideWith(
            (ref) => Stream<OutboxCounts>.value(
              const OutboxCounts(drafts: 1, queued: 2),
            ),
          ),
          outboxMessagesProvider.overrideWith(
            (ref) => Stream<List<OutboxMessage>>.value(const []),
          ),
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          accountSlotStatesProvider.overrideWith(
            (ref) => Stream<Map<String, ConnectionSlotState>>.value(
              const <String, ConnectionSlotState>{},
            ),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          mailLocalRepositoryProvider.overrideWithValue(
            fixture.localRepository,
          ),
          trustedSendersRepositoryProvider.overrideWithValue(
            TrustedSendersRepositoryImpl(database: fixture.database),
          ),
        ],
        child: const MaterialApp(home: MailShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sidebar-outbox')));
    await tester.pumpAndSettle();
    expect(find.text('草稿与发件箱'), findsOneWidget);
    expect(find.text('草稿与发件箱为空'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('mobile drawer opens outbox at narrow width', (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimeProvider.overrideWithValue(harness.runtime),
          outboxCountsProvider.overrideWith(
            (ref) => Stream<OutboxCounts>.value(const OutboxCounts(failed: 1)),
          ),
          outboxMessagesProvider.overrideWith(
            (ref) => Stream<List<OutboxMessage>>.value(const []),
          ),
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value([fixture.account]),
          ),
          accountSlotStatesProvider.overrideWith(
            (ref) => Stream<Map<String, ConnectionSlotState>>.value(
              const <String, ConnectionSlotState>{},
            ),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          mailLocalRepositoryProvider.overrideWithValue(
            fixture.localRepository,
          ),
          trustedSendersRepositoryProvider.overrideWithValue(
            TrustedSendersRepositoryImpl(database: fixture.database),
          ),
        ],
        child: const MaterialApp(home: MailShellPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-mail-drawer')));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsWidgets);
    await tester.tap(find.byKey(const Key('sidebar-outbox')));
    await tester.pumpAndSettle();
    expect(find.text('草稿与发件箱为空'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'twelve-account drawer scrolls to the last account and folder and collapses',
    (tester) async {
      final fixture = await MailFixture.create();
      addTearDown(fixture.dispose);
      final harness = TestRuntimeHarness();
      addTearDown(harness.dispose);
      final accounts = List<MailAccount>.generate(
        12,
        (index) => _makeAccount(index),
      );
      final auth = FakeAuthRepository()..accounts.addAll(accounts);
      addTearDown(auth.dispose);
      final poll = RecordingPollFolderUseCase();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _shell(
          _shellOverrides(
            harness: harness,
            accounts: accounts,
            auth: auth,
            localRepository: fixture.localRepository,
            pollFolder: poll,
            foldersByAccount: {
              for (final account in accounts) account.id: _makeFolders(account),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-mail-drawer')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mail-sidebar')), findsOneWidget);
      // Multi-account default: folders stay collapsed, footer stays reachable.
      expect(
        find.byKey(const ValueKey('folder-tile-ui-0-folder-0')),
        findsNothing,
      );
      expect(find.byKey(const Key('sidebar-outbox')), findsOneWidget);

      final toggle = find.byKey(const ValueKey('account-toggle-ui-11'));
      await tester.scrollUntilVisible(
        toggle,
        200,
        scrollable: _sidebarScrollable(),
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      _expectInsideSidebarViewport(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byTooltip('收起 account12@example.com 的文件夹'), findsOneWidget);

      final lastFolder = find.byKey(
        const ValueKey('folder-tile-ui-11-folder-6'),
      );
      await tester.scrollUntilVisible(
        lastFolder,
        200,
        scrollable: _sidebarScrollable(),
      );
      await tester.ensureVisible(lastFolder);
      await tester.pumpAndSettle();
      _expectInsideSidebarViewport(tester, lastFolder);
      await tester.tap(lastFolder);
      await tester.pumpAndSettle();

      expect(poll.calls, 1);
      expect(poll.lastFolder?.remoteName, 'Folder6');
      expect(poll.lastFolder?.accountId, 'ui-11');
      expect(find.byKey(const Key('mail-sidebar')), findsNothing);

      // Expansion selection survives closing and reopening the drawer.
      await tester.tap(find.byKey(const Key('open-mail-drawer')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('folder-tile-ui-11-folder-6')),
        300,
        scrollable: _sidebarScrollable(),
      );
      final selectedFolder = tester.widget<ListTile>(
        find.byKey(const ValueKey('folder-tile-ui-11-folder-6')),
      );
      expect(selectedFolder.selected, isTrue);

      // Collapsing is also retained when the drawer is closed and reopened.
      final reopenedToggle = find.byKey(const ValueKey('account-toggle-ui-11'));
      await tester.ensureVisible(reopenedToggle);
      await tester.pumpAndSettle();
      _expectInsideSidebarViewport(tester, reopenedToggle);
      await tester.tap(reopenedToggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('folder-tile-ui-11-folder-6')),
        findsNothing,
      );

      await tester.tapAt(const Offset(380, 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mail-sidebar')), findsNothing);

      await tester.tap(find.byKey(const Key('open-mail-drawer')));
      await tester.pumpAndSettle();
      final collapsedToggle = find.byKey(
        const ValueKey('account-toggle-ui-11'),
      );
      await tester.scrollUntilVisible(
        collapsedToggle,
        200,
        scrollable: _sidebarScrollable(),
      );
      await tester.ensureVisible(collapsedToggle);
      await tester.pumpAndSettle();
      _expectInsideSidebarViewport(tester, collapsedToggle);
      expect(find.byTooltip('展开 account12@example.com 的文件夹'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('folder-tile-ui-11-folder-6')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'folder selection highlights and toggling does not switch account',
    (tester) async {
      final fixture = await MailFixture.create();
      addTearDown(fixture.dispose);
      final harness = TestRuntimeHarness();
      addTearDown(harness.dispose);
      final first = _makeAccount(0);
      final second = _makeAccount(1);
      final accounts = <MailAccount>[first, second];
      final auth = FakeAuthRepository()..accounts.addAll(accounts);
      addTearDown(auth.dispose);
      final poll = RecordingPollFolderUseCase();
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _shell(
          _shellOverrides(
            harness: harness,
            accounts: accounts,
            auth: auth,
            localRepository: fixture.localRepository,
            pollFolder: poll,
            foldersByAccount: {
              for (final account in accounts) account.id: _makeFolders(account),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('account-tile-ui-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('folder-tile-ui-0-folder-1')));
      await tester.pumpAndSettle();

      expect(poll.lastFolder?.accountId, 'ui-0');
      expect(poll.lastFolder?.remoteName, 'Folder1');
      expect(
        tester
            .widget<ListTile>(
              find.byKey(const ValueKey('folder-tile-ui-0-folder-1')),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ListTile>(
              find.byKey(const ValueKey('folder-tile-ui-0-folder-0')),
            )
            .selected,
        isFalse,
      );

      // Return account one to its inbox selection, then use account two's
      // chevron without selecting account two.
      await tester.tap(find.byKey(const ValueKey('account-tile-ui-0')));
      await tester.pumpAndSettle();
      final secondToggle = find.byKey(const ValueKey('account-toggle-ui-1'));
      await tester.ensureVisible(secondToggle);
      await tester.pumpAndSettle();
      await tester.tap(secondToggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('folder-tile-ui-1-folder-0')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('account-tile-ui-0')))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('account-tile-ui-1')))
            .selected,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('folder-tile-ui-0-folder-1')),
        findsOneWidget,
      );

      await tester.tap(secondToggle);
      await tester.pumpAndSettle();
      // Collapsing account two must not change the selected account.
      expect(
        find.byKey(const ValueKey('folder-tile-ui-1-folder-0')),
        findsNothing,
      );
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('account-tile-ui-0')))
            .selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('folder-tile-ui-0-folder-1')),
        findsOneWidget,
      );
      expect(find.byTooltip('展开 account2@example.com 的文件夹'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sidebar-collapse-all')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('展开 account1@example.com 的文件夹'), findsOneWidget);
      expect(find.byTooltip('展开 account2@example.com 的文件夹'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('compact heights and large text keep the sidebar scrollable', (
    tester,
  ) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    final accounts = List<MailAccount>.generate(
      12,
      (index) => _makeAccount(index),
    );
    final auth = FakeAuthRepository()..accounts.addAll(accounts);
    addTearDown(auth.dispose);
    final overrides = _shellOverrides(
      harness: harness,
      accounts: accounts,
      auth: auth,
      localRepository: fixture.localRepository,
      foldersByAccount: {
        for (final account in accounts) account.id: _makeFolders(account),
      },
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cases = <(Size, double)>[
      (const Size(320, 640), 1),
      (const Size(390, 844), 2),
      (const Size(640, 320), 1),
    ];
    for (final (size, textScale) in cases) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_shell(overrides, textScale: textScale));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-mail-drawer')));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'drawer overflow at $size textScale $textScale',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('sidebar-outbox')),
        300,
        scrollable: _sidebarScrollable(),
      );
      expect(find.byKey(const Key('sidebar-outbox')), findsOneWidget);
      expect(find.byKey(const Key('sidebar-account-manage')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('desktop widths keep usable sidebar and list panes', (
    tester,
  ) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    final accounts = List<MailAccount>.generate(
      12,
      (index) => _makeAccount(index),
    );
    final auth = FakeAuthRepository()..accounts.addAll(accounts);
    addTearDown(auth.dispose);
    final overrides = _shellOverrides(
      harness: harness,
      accounts: accounts,
      auth: auth,
      localRepository: fixture.localRepository,
      foldersByAccount: {
        for (final account in accounts) account.id: _makeFolders(account),
      },
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in <double>[960, 1024, 1200, 1440]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_shell(overrides));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'overflow at $width');
      expect(find.byKey(const Key('mail-sidebar')), findsOneWidget);
      final sidebarWidth = tester
          .getSize(find.byKey(const Key('mail-sidebar')))
          .width;
      expect(sidebarWidth, greaterThanOrEqualTo(249));
      expect(sidebarWidth, lessThanOrEqualTo(301));
      expect(
        tester.getSize(find.byKey(const Key('inbox-email-list'))).width,
        greaterThan(400),
        reason: 'list pane too narrow at $width',
      );
      expect(
        find.text('选择一封邮件开始阅读'),
        width >= 1200 ? findsOneWidget : findsNothing,
        reason: 'three-pane breakpoint at $width',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('removed accounts do not leave stale expansion state', (
    tester,
  ) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    final first = _makeAccount(0);
    final second = _makeAccount(1);
    final auth = FakeAuthRepository()..accounts.addAll([first, second]);
    addTearDown(auth.dispose);
    final accountsController = StreamController<List<MailAccount>>.broadcast();
    addTearDown(accountsController.close);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _shell(
        _shellOverrides(
          harness: harness,
          accounts: const <MailAccount>[],
          accountsStream: accountsController.stream,
          auth: auth,
          localRepository: fixture.localRepository,
          foldersByAccount: {
            first.id: _makeFolders(first),
            second.id: _makeFolders(second),
          },
        ),
      ),
    );
    accountsController.add([first, second]);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('account-toggle-ui-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('folder-tile-ui-1-folder-1')),
      findsOneWidget,
    );

    accountsController.add([first]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-tile-ui-1')), findsNothing);

    accountsController.add([first, second]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-tile-ui-1')), findsOneWidget);
    // Re-added account starts collapsed instead of restoring a stale override.
    expect(
      find.byKey(const ValueKey('folder-tile-ui-1-folder-1')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('compose uses the account selected in the sidebar', (
    tester,
  ) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final harness = TestRuntimeHarness();
    addTearDown(harness.dispose);
    final first = _makeAccount(0);
    final second = _makeAccount(1);
    final auth = FakeAuthRepository()..accounts.addAll([first, second]);
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _shell(
        _shellOverrides(
          harness: harness,
          accounts: [first, second],
          auth: auth,
          localRepository: fixture.localRepository,
          foldersByAccount: {
            first.id: _makeFolders(first),
            second.id: _makeFolders(second),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-tile-ui-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose-mail')));
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('compose-account')),
    );
    expect(dropdown.initialValue, 'ui-1');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'compose refuses a disabled selected account without falling back',
    (tester) async {
      final fixture = await MailFixture.create();
      addTearDown(fixture.dispose);
      final harness = TestRuntimeHarness();
      addTearDown(harness.dispose);
      final first = _makeAccount(0);
      final disabled = _makeAccount(1, isEnabled: false);
      final auth = FakeAuthRepository()..accounts.addAll([first, disabled]);
      addTearDown(auth.dispose);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _shell(
          _shellOverrides(
            harness: harness,
            accounts: [first, disabled],
            auth: auth,
            localRepository: fixture.localRepository,
            foldersByAccount: {
              first.id: _makeFolders(first),
              disabled.id: _makeFolders(disabled),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-tile-ui-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('compose-mail')));
      await tester.pumpAndSettle();

      expect(find.text('当前选中的邮箱账户不可用，请先在侧栏选择一个已启用的账户'), findsOneWidget);
      expect(find.text('写邮件'), findsNothing);
      expect(find.byKey(const Key('compose-account')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
