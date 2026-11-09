import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';
import 'package:local_mail_client/features/mail/presentation/pages/unified_inbox_page.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/domain/usecases/update_email_flags_usecase.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';

import '../auth/support/fakes.dart';
import 'support/mail_fixture.dart';


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
      userMessage: '星标更新失败',
    );
  }
}

void main() {
  testWidgets('unified inbox renders cached mail and opens a selection',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    UnifiedEmail? opened;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mailLocalRepositoryProvider.overrideWithValue(
            fixture.localRepository,
          ),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          home: UnifiedInboxPage(
            onOpenEmail: (email) => opened = email,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quarterly report'), findsOneWidget);
    expect(find.textContaining('Sender'), findsOneWidget);
    expect(find.byKey(const Key('inbox-email-list')), findsOneWidget);

    await tester.tap(find.text('Quarterly report'));
    await tester.pump();
    expect(opened?.subject, 'Quarterly report');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('unread filter hides read messages', (tester) async {
    final fixture = await MailFixture.create(flagsBitmask: 1);
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mailLocalRepositoryProvider.overrideWithValue(
            fixture.localRepository,
          ),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(home: UnifiedInboxPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quarterly report'), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle-unread-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Quarterly report'), findsNothing);
    expect(find.text('这里暂时没有邮件'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('failed star update renders the Chinese error banner',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mailLocalRepositoryProvider.overrideWithValue(
            fixture.localRepository,
          ),
          authRepositoryProvider.overrideWithValue(auth),
          updateEmailFlagsUseCaseProvider.overrideWithValue(
            _FailingFlagUseCase(),
          ),
        ],
        child: const MaterialApp(home: UnifiedInboxPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pumpAndSettle();

    expect(find.text('星标更新失败'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

}
