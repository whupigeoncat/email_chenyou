import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/database/app_database.dart'
    show DbEmailsCompanion;
import 'package:local_mail_client/features/mail/data/repositories/trusted_senders_repository_impl.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/presentation/pages/email_detail_page.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';

import '../auth/support/fakes.dart';
import 'support/mail_fixture.dart';

void main() {
  testWidgets('email detail renders HTML and can switch to plain text', (
    tester,
  ) async {
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
    expect(
      find.textContaining('HTML body', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('email-view-mode')));
    await tester.pumpAndSettle();
    // Selecting the segment opens a menu whose second item is plain text.
    await tester.tap(find.text('纯文本').last);
    await tester.pumpAndSettle();
    expect(find.text('Plain body text'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('deleted email shows a finite empty state instead of a spinner', (
    tester,
  ) async {
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

  testWidgets('reply button prefills account, recipient and quoted subject', (
    tester,
  ) async {
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

  testWidgets('forward carries subject, quote and original context', (
    tester,
  ) async {
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

  testWidgets('switching messages resets expanded header and scroll offset', (
    tester,
  ) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final secondId = await fixture.database
        .into(fixture.database.dbEmails)
        .insert(
          DbEmailsCompanion.insert(
            accountId: fixture.account.id,
            folderId: fixture.folder.id,
            uid: 2,
            subject: 'Second message',
            fromName: 'Other',
            fromAddress: 'other@example.com',
            toRecipientsJson: '[]',
            ccJson: '[]',
            snippet: 'second',
            sentAt: DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
            plainBody: const Value('Second plain body'),
            htmlBody: const Value('<p>Second HTML body</p>'),
            bodyDownloaded: const Value(true),
          ),
        );
    // Make the first message tall enough to scroll.
    await (fixture.database.update(
      fixture.database.dbEmails,
    )..where((table) => table.localId.equals(fixture.emailLocalId))).write(
      DbEmailsCompanion(
        htmlBody: Value(
          List.generate(
            30,
            (i) => '<p>Long paragraph $i for scrolling</p>',
          ).join(),
        ),
      ),
    );

    tester.view.physicalSize = const Size(320, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var currentId = fixture.emailLocalId;
    late StateSetter setHost;
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
            body: StatefulBuilder(
              builder: (context, setState) {
                setHost = setState;
                return EmailDetailPage(emailLocalId: currentId, embedded: true);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quarterly report'));
    await tester.pumpAndSettle();
    expect(find.textContaining('收件人：'), findsOneWidget);

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    scrollView.controller!.jumpTo(120);
    await tester.pump();
    expect(scrollView.controller!.offset, greaterThan(0));

    setHost(() => currentId = secondId);
    await tester.pumpAndSettle();

    expect(find.text('Second message'), findsOneWidget);
    expect(find.textContaining('收件人：'), findsNothing);
    expect(scrollView.controller!.offset, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('narrow width with 2x text keeps the reader usable', (
    tester,
  ) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    await (fixture.database.update(
      fixture.database.dbEmails,
    )..where((table) => table.localId.equals(fixture.emailLocalId))).write(
      DbEmailsCompanion(
        htmlBody: Value(
          '<body style="background:#ffffff;color:#202020">'
          '<img src="https://tracker.example/pixel.png">'
          '<div style="width:680px"><table width="900"><tr>'
          '<th>项目</th><th>说明</th></tr><tr><td>本地邮箱</td>'
          '<td>很长的说明文本 SuperCalifragilisticExpialidocious</td>'
          '</tr></table></div>'
          '<p>https://example.com/a/very/long/unbroken/link/with/many/'
          'segments/that/needs/wrapping</p></body>',
        ),
      ),
    );

    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('email-view-mode')), findsOneWidget);
    expect(find.byKey(const Key('remote-content-banner')), findsOneWidget);
    expect(find.byKey(const Key('safe-html-canvas')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
