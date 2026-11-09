import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/app_runtime_providers.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/core/network/account_connection_slot.dart';
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
  }) async {
    calls++;
    lastFolder = folder;
    return folder;
  }
}

void main() {
  testWidgets('desktop shell uses three panes and empty-account guidance',
      (tester) async {
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

  testWidgets('mobile shell uses a drawer and hides the desktop sidebar',
      (tester) async {
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

  testWidgets('selecting a non-INBOX folder invokes PollFolderUseCase',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    await fixture.database.into(fixture.database.dbFolders).insert(
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
  testWidgets('selected reading pane resets when folder changes',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    await fixture.database.into(fixture.database.dbFolders).insert(
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
      find.byKey(
        ValueKey('email-tile-${fixture.account.id}-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safe-html-widget')), findsOneWidget);

    await tester.tap(find.text('Sent'));
    await tester.pumpAndSettle();
    expect(find.text('选择一封邮件开始阅读'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('responsive boundaries render without overflow',
      (tester) async {
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


  testWidgets('sidebar shows outbox badge and opens the outbox page',
      (tester) async {
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
            (ref) => Stream<OutboxCounts>.value(
              const OutboxCounts(failed: 1),
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
    await tester.tap(find.byKey(const Key('open-mail-drawer')));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsWidgets);
    await tester.tap(find.byKey(const Key('sidebar-outbox')));
    await tester.pumpAndSettle();
    expect(find.text('草稿与发件箱为空'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

}
