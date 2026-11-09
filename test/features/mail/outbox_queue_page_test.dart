import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/auth/data/account_credential_resolver.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/datasources/outbox_local_datasource.dart';
import 'package:local_mail_client/features/mail/data/datasources/smtp_session.dart';
import 'package:local_mail_client/features/mail/data/repositories/outbox_repository_impl.dart';
import 'package:local_mail_client/features/mail/data/services/outbox_queue_service.dart';
import 'package:local_mail_client/features/mail/domain/usecases/outbox_usecases.dart';
import 'package:local_mail_client/features/mail/presentation/pages/outbox_queue_page.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';

import '../auth/support/fakes.dart';
import 'support/mail_fixture.dart';

class _FakeRetry implements RetryOutboxMessageUseCase {
  final List<String> ids = <String>[];

  @override
  Future<void> call(String id) async {
    ids.add(id);
  }
}

class _FakeMarkSent implements MarkOutboxMessageSentUseCase {
  final List<String> ids = <String>[];

  @override
  Future<void> call(String id) async {
    ids.add(id);
  }
}

class _FakeDelete implements DeleteOutboxMessageUseCase {
  final List<String> ids = <String>[];

  @override
  Future<void> call(String id) async {
    ids.add(id);
  }
}

class _PageSmtpSession implements SmtpSession {
  Object? sendError;
  int sendCount = 0;

  @override
  bool get isConnected => false;

  @override
  Future<void> connectAndAuthenticate({
    required MailAccount account,
    required ResolvedAccountCredential credential,
  }) async {}

  @override
  Future<void> send(OutgoingMailEnvelope envelope) async {
    sendCount++;
    final error = sendError;
    if (error != null) throw error;
  }

  @override
  Future<void> quitAndDisconnect({
    Duration timeout = const Duration(seconds: 5),
  }) async {}

  @override
  Future<void> forceClose() async {}
}

class _PageSmtpFactory implements SmtpSessionFactory {
  _PageSmtpFactory(this.session);
  final _PageSmtpSession session;

  @override
  SmtpSession createSession() => session;
}

class _PageCredentialResolver implements AccountCredentialResolver {
  @override
  Future<ResolvedAccountCredential> call(MailAccount account) async =>
      const PasswordCredential('code');
}

OutboxMessage _message({
  OutboxStatus status = OutboxStatus.failed,
  String? error,
  String id = 'outbox-1',
}) {
  return OutboxMessage(
    id: id,
    accountId: 'account-1',
    mode: ComposeMode.newMail,
    to: const [EmailAddressEntry(email: 'bob@example.com', name: 'Bob')],
    cc: const [],
    bcc: const [],
    subject: 'Queue subject',
    plainBody: 'body',
    attachments: const [],
    status: status,
    retryCount: 1,
    retryable: status != OutboxStatus.sent,
    lastError: error,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  testWidgets('shows failed error and supports retry/delete transitions',
      (tester) async {
    final controller = StreamController<List<OutboxMessage>>.broadcast();
    addTearDown(controller.close);
    final retry = _FakeRetry();
    final delete = _FakeDelete();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outboxMessagesProvider.overrideWith((ref) => controller.stream),
          retryOutboxMessageUseCaseProvider.overrideWithValue(retry),
          deleteOutboxMessageUseCaseProvider.overrideWithValue(delete),
        ],
        child: const MaterialApp(home: OutboxQueuePage()),
      ),
    );
    controller.add([_message(error: 'SMTP 认证失败')]);
    await tester.pumpAndSettle();

    expect(find.text('Queue subject'), findsOneWidget);
    expect(find.text('发送失败'), findsOneWidget);
    expect(find.text('SMTP 认证失败'), findsOneWidget);
    expect(find.textContaining('已重试 1 次'), findsOneWidget);

    await tester.tap(find.byKey(const Key('retry-outbox-outbox-1')));
    await tester.pumpAndSettle();
    expect(retry.ids, <String>['outbox-1']);

    controller.add([_message(status: OutboxStatus.sent)]);
    await tester.pumpAndSettle();
    expect(find.text('已发送'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-outbox-outbox-1')));
    await tester.pumpAndSettle();
    expect(delete.ids, <String>['outbox-1']);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outboxMessagesProvider.overrideWith(
            (ref) => Stream<List<OutboxMessage>>.value(const []),
          ),
        ],
        child: const MaterialApp(home: OutboxQueuePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('草稿与发件箱为空'), findsOneWidget);
  });

  testWidgets('shows a draft and edit opens ComposeEmailPage', (tester) async {
    final message = _message(status: OutboxStatus.draft)
        .copyWith(subject: 'Editable draft', status: OutboxStatus.draft);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outboxMessagesProvider.overrideWith(
            (ref) => Stream<List<OutboxMessage>>.value([message]),
          ),
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value(const []),
          ),
        ],
        child: const MaterialApp(home: OutboxQueuePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Editable draft'), findsOneWidget);
    expect(find.text('草稿'), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-outbox-outbox-1')));
    await tester.pumpAndSettle();
    expect(find.text('写邮件'), findsOneWidget);
    final subject = tester.widget<TextField>(
      find.byKey(const Key('compose-subject')),
    );
    expect(subject.controller?.text, 'Editable draft');
  });

  testWidgets('uncertain row requires confirmation before resend/mark sent',
      (tester) async {
    final retry = _FakeRetry();
    final markSent = _FakeMarkSent();
    final uncertain = _message(status: OutboxStatus.uncertain);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outboxMessagesProvider.overrideWith(
            (ref) => Stream<List<OutboxMessage>>.value([uncertain]),
          ),
          retryOutboxMessageUseCaseProvider.overrideWithValue(retry),
          markOutboxMessageSentUseCaseProvider.overrideWithValue(markSent),
        ],
        child: const MaterialApp(home: OutboxQueuePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('待确认'), findsOneWidget);
    expect(find.textContaining('投递状态不确定'), findsOneWidget);
    expect(find.byKey(const Key('retry-outbox-outbox-1')), findsNothing);

    await tester.tap(find.byKey(const Key('confirm-resend-outbox-1')));
    await tester.pumpAndSettle();
    expect(find.text('确认重发？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-uncertain-resend')));
    await tester.pumpAndSettle();
    expect(retry.ids, <String>['outbox-1']);

    await tester.tap(find.byKey(const Key('mark-sent-outbox-1')));
    await tester.pumpAndSettle();
    expect(find.text('标记为已发送？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-mark-sent')));
    await tester.pumpAndSettle();
    expect(markSent.ids, <String>['outbox-1']);
  });


  testWidgets('sending row disables delete and never calls delete use case',
      (tester) async {
    final delete = _FakeDelete();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outboxMessagesProvider.overrideWith(
            (ref) => Stream<List<OutboxMessage>>.value(
              [_message(status: OutboxStatus.sending)],
            ),
          ),
          deleteOutboxMessageUseCaseProvider.overrideWithValue(delete),
        ],
        child: const MaterialApp(home: OutboxQueuePage()),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<IconButton>(
      find.byKey(const Key('delete-outbox-outbox-1')),
    );
    expect(button.onPressed, isNull);
    expect(button.tooltip, '发送中暂不可删除');
    await tester.tap(find.byKey(const Key('delete-outbox-outbox-1')));
    await tester.pump();
    expect(delete.ids, isEmpty);
  });

  testWidgets('edit cancels an active retry timer before opening compose',
      (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);
    final repo = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: fixture.database),
    );
    final saved = await repo.saveDraft(
      draft: ComposeDraft(
        accountId: fixture.account.id,
        mode: ComposeMode.newMail,
        to: const [EmailAddressEntry(email: 'bob@example.com')],
        cc: const [],
        bcc: const [],
        subject: 'Retry cancel',
        plainBody: 'body',
      ),
    );
    await repo.enqueue(saved.id);
    final smtp = _PageSmtpSession()
      ..sendError = const SmtpFailure(
        reason: SmtpFailureReason.protocolError,
        retryable: true,
        userMessage: 'temporary',
      );
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final queue = OutboxQueueService(
      repository: repo,
      sessionFactory: _PageSmtpFactory(smtp),
      credentialResolver: _PageCredentialResolver(),
      authRepository: auth,
      retryDelays: const [Duration(minutes: 1)],
    );
    addTearDown(queue.dispose);
    await queue.scheduleNow(saved.id);
    final failed = (await repo.getById(saved.id))!;
    expect(failed.status, OutboxStatus.failed);
    expect(smtp.sendCount, 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outboxMessagesProvider.overrideWith(
            (ref) => Stream<List<OutboxMessage>>.value([failed]),
          ),
          outboxQueueProvider.overrideWithValue(queue),
          accountsProvider.overrideWith(
            (ref) => Stream<List<MailAccount>>.value(const []),
          ),
        ],
        child: const MaterialApp(home: OutboxQueuePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('edit-outbox-${failed.id}')));
    await tester.pumpAndSettle();
    expect(find.text('写邮件'), findsOneWidget);

    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(smtp.sendCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('all statuses render without overflow at 960/500/360/320',
      (tester) async {
    final messages = [
      _message(id: 'draft', status: OutboxStatus.draft),
      _message(id: 'sending', status: OutboxStatus.sending),
      _message(id: 'failed', status: OutboxStatus.failed),
      _message(id: 'uncertain', status: OutboxStatus.uncertain),
      _message(id: 'sent', status: OutboxStatus.sent),
    ];
    for (final width in <double>[960, 500, 360, 320]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            outboxMessagesProvider.overrideWith(
              (ref) => Stream<List<OutboxMessage>>.value(messages),
            ),
          ],
          child: const MaterialApp(home: OutboxQueuePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

}
