import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/services/inbox_sync_coordinator.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';
import 'package:local_mail_client/features/mail/domain/usecases/update_email_flags_usecase.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';
import 'package:local_mail_client/features/mail/presentation/providers/unified_inbox_provider.dart';

import '../auth/support/fakes.dart';
import 'support/mail_fixture.dart';

class _RecordingCoordinator implements InboxSyncCoordinator {
  int calls = 0;
  final List<String> accountIds = <String>[];

  @override
  Future<void> syncNow(String accountId) async {
    calls++;
    accountIds.add(accountId);
  }

  @override
  void start() {}

  @override
  Future<void> dispose() async {}
}

class _FailingFlagUseCase implements UpdateEmailFlagsUseCase {
  @override
  Future<UnifiedEmail> call({
    required MailAccount account,
    required int emailLocalId,
    bool? isRead,
    bool? isFlagged,
    bool? isAnswered,
  }) async {
    throw const AuthFailure(
      reason: AuthFailureReason.unknown,
      userMessage: '远端标记失败',
    );
  }
}

void main() {
  test('manual refresh uses InboxSyncCoordinator and does not re-enter',
      () async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final coordinator = _RecordingCoordinator();
    final container = ProviderContainer(
      overrides: [
        mailLocalRepositoryProvider.overrideWithValue(fixture.localRepository),
        authRepositoryProvider.overrideWithValue(auth),
        inboxSyncCoordinatorProvider.overrideWithValue(coordinator),
      ],
    );
    addTearDown(container.dispose);
    final keepAlive = container.listen(
      unifiedInboxViewProvider,
      (_, _) {},
    );
    addTearDown(keepAlive.close);

    final notifier = container.read(unifiedInboxViewProvider.notifier);
    final first = notifier.syncCurrent();
    final second = notifier.syncCurrent();
    await Future.wait(<Future<void>>[first, second]);

    expect(coordinator.calls, 1);
    expect(coordinator.accountIds, <String>[fixture.account.id]);
  });

  test('flag failure renders an error state after local optimistic rollback',
      () async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final email = (await fixture.localRepository.getEmail(
      fixture.emailLocalId,
    ))!;
    final container = ProviderContainer(
      overrides: [
        mailLocalRepositoryProvider.overrideWithValue(fixture.localRepository),
        authRepositoryProvider.overrideWithValue(auth),
        updateEmailFlagsUseCaseProvider.overrideWithValue(
          _FailingFlagUseCase(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final keepAlive = container.listen(
      unifiedInboxViewProvider,
      (_, _) {},
    );
    addTearDown(keepAlive.close);

    final notifier = container.read(unifiedInboxViewProvider.notifier);
    await notifier.toggleRead(email);

    final state = container.read(unifiedInboxViewProvider);
    expect(state.errorMessage, '远端标记失败');
  });

  test('pagination starts at 200 and loadMore expands by 200', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final keepAlive = container.listen(
      unifiedInboxViewProvider,
      (_, _) {},
    );
    addTearDown(keepAlive.close);

    expect(container.read(unifiedInboxViewProvider).pageLimit, 200);
    container.read(unifiedInboxViewProvider.notifier).loadMore();
    expect(container.read(unifiedInboxViewProvider).pageLimit, 400);
  });

}
