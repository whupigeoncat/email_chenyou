import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/services/sent_copy_service.dart';
import 'package:local_mail_client/features/mail/domain/entities/mail_folder.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';
import 'package:local_mail_client/features/mail/domain/usecases/poll_folder_usecase.dart';
import 'package:local_mail_client/features/mail/presentation/pages/outbox_queue_page.dart';
import 'package:local_mail_client/features/mail/presentation/pages/unified_inbox_page.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';
import 'package:local_mail_client/features/mail/presentation/providers/unified_inbox_provider.dart';

import '../auth/support/fakes.dart';
import 'support/mail_fixture.dart';

class _Poll implements PollFolderUseCase {
  final pending = Completer<MailFolder>();
  int calls = 0;
  @override
  Future<MailFolder> call({
    required MailAccount account,
    required MailFolder folder,
    bool loadOlder = false,
  }) {
    calls++;
    return pending.future;
  }
}

class _Archive implements SentCopyService {
  final pending = Completer<void>();
  int calls = 0;
  @override
  Future<void> save(String id) {
    calls++;
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 640),
      const Size(800, 600),
      const Size(1280, 800),
    ]) {
      testWidgets(
        'history loading/error and archive retry at $size $brightness',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final fixture = await MailFixture.create();
          addTearDown(fixture.dispose);
          final auth = FakeAuthRepository()..accounts.add(fixture.account);
          addTearDown(auth.dispose);
          final poll = _Poll();
          final email = (await fixture.localRepository.getEmail(
            fixture.emailLocalId,
          ))!;
          addTearDown(() {
            if (!poll.pending.isCompleted) {
              poll.pending.complete(fixture.folder);
            }
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authRepositoryProvider.overrideWithValue(auth),
                mailLocalRepositoryProvider.overrideWithValue(
                  fixture.localRepository,
                ),
                pollFolderUseCaseProvider.overrideWithValue(poll),
                inboxEmailsProvider.overrideWith(
                  (ref) => Stream.value([email]),
                ),
              ],
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: const UnifiedInboxPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('load-older-emails')));
          await tester.pump();
          expect(find.text('正在加载历史邮件…'), findsOneWidget);
          await tester.tap(find.byKey(const Key('load-older-emails')));
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          expect(poll.calls, 1);
          poll.pending.completeError(
            const StorageFailure(userMessage: '历史邮件加载失败，请重试'),
          );
          await tester.pumpAndSettle();
          expect(find.text('历史邮件加载失败，请重试'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();

          final archive = _Archive();
          final row = OutboxMessage(
            id: 'sent-1',
            accountId: fixture.account.id,
            mode: ComposeMode.newMail,
            to: const [EmailAddressEntry(email: 'recipient@example.com')],
            cc: const [],
            bcc: const [],
            subject: '已发送副本',
            plainBody: 'body',
            attachments: const [],
            status: OutboxStatus.sent,
            retryCount: 0,
            retryable: false,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            lastError: '服务器副本尚未保存，本地内容已保留',
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                outboxMessagesProvider.overrideWith(
                  (ref) => Stream.value([row]),
                ),
                sentCopyServiceProvider.overrideWithValue(archive),
              ],
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: const OutboxQueuePage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(row.lastError!), findsOneWidget);
          expect(find.text('立即重试'), findsNothing);
          await tester.tap(find.byKey(const Key('save-sent-copy-sent-1')));
          await tester.pump();
          await tester.tap(find.byKey(const Key('save-sent-copy-sent-1')));
          await tester.pump();
          expect(archive.calls, 1);
          archive.pending.completeError(
            const StorageFailure(userMessage: '补存失败，本地副本仍保留'),
          );
          await tester.pumpAndSettle();
          expect(find.text('补存失败，本地副本仍保留'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
