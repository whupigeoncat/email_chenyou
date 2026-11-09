import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/features/mail/data/repositories/trusted_senders_repository_impl.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/presentation/pages/email_detail_page.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';

import '../auth/support/fakes.dart';
import 'support/mail_fixture.dart';

void main() {
  testWidgets('email detail renders HTML and can switch to plain text',
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
          trustedSendersRepositoryProvider.overrideWithValue(
            TrustedSendersRepositoryImpl(database: fixture.database),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EmailDetailPage(
              emailLocalId: fixture.emailLocalId,
              embedded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quarterly report'), findsOneWidget);
    expect(find.byKey(const Key('safe-html-widget')), findsOneWidget);
    expect(find.textContaining('HTML body', findRichText: true), findsOneWidget);

    await tester.tap(find.byKey(const Key('email-view-mode')));
    await tester.pumpAndSettle();
    // Selecting the segment opens a menu whose second item is plain text.
    await tester.tap(find.text('纯文本').last);
    await tester.pumpAndSettle();
    expect(find.text('Plain body text'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('deleted email shows a finite empty state instead of a spinner',
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
          trustedSendersRepositoryProvider.overrideWithValue(
            TrustedSendersRepositoryImpl(database: fixture.database),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: EmailDetailPage(emailLocalId: 999, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('邮件已不存在或已被删除'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('reply button prefills account, recipient and quoted subject',
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
          trustedSendersRepositoryProvider.overrideWithValue(
            TrustedSendersRepositoryImpl(database: fixture.database),
          ),
          outboxCountsProvider.overrideWith(
            (ref) => Stream<OutboxCounts>.value(const OutboxCounts()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EmailDetailPage(
              emailLocalId: fixture.emailLocalId,
              embedded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reply-mail')));
    await tester.pumpAndSettle();

    expect(find.text('回复'), findsOneWidget);
    final subject = tester.widget<TextField>(
      find.byKey(const Key('compose-subject')),
    );
    expect(subject.controller?.text, 'Re: Quarterly report');
    expect(find.textContaining('sender@example.com'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });


  testWidgets('reply all includes sender and other recipients', (tester) async {
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
          trustedSendersRepositoryProvider.overrideWithValue(
            TrustedSendersRepositoryImpl(database: fixture.database),
          ),
          outboxCountsProvider.overrideWith(
            (ref) => Stream<OutboxCounts>.value(const OutboxCounts()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EmailDetailPage(
              emailLocalId: fixture.emailLocalId,
              embedded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reply-all-mail')));
    await tester.pumpAndSettle();

    expect(find.text('全部回复'), findsOneWidget);
    final subject = tester.widget<TextField>(
      find.byKey(const Key('compose-subject')),
    );
    expect(subject.controller?.text, 'Re: Quarterly report');
    expect(find.textContaining('sender@example.com'), findsWidgets);
    expect(find.textContaining('bob@example.com'), findsWidgets);
    expect(find.textContaining('carol@example.com'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('forward carries subject, quote and original context',
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
          trustedSendersRepositoryProvider.overrideWithValue(
            TrustedSendersRepositoryImpl(database: fixture.database),
          ),
          outboxCountsProvider.overrideWith(
            (ref) => Stream<OutboxCounts>.value(const OutboxCounts()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EmailDetailPage(
              emailLocalId: fixture.emailLocalId,
              embedded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forward-mail')));
    await tester.pumpAndSettle();

    expect(find.text('转发'), findsOneWidget);
    final subject = tester.widget<TextField>(
      find.byKey(const Key('compose-subject')),
    );
    expect(subject.controller?.text, 'Fwd: Quarterly report');
    final body = tester.widget<TextField>(
      find.byKey(const Key('compose-body')),
    );
    expect(body.controller?.text, contains('---------- 转发邮件 ----------'));
    expect(body.controller?.text, contains('sender@example.com'));
    expect(body.controller?.text, contains('HTML body'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

}
