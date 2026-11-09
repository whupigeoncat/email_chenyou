import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/network/connection_pool.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/datasources/mail_remote_datasource.dart';
import 'package:local_mail_client/features/mail/data/datasources/outbox_local_datasource.dart';
import 'package:local_mail_client/features/mail/data/repositories/mail_remote_repository.dart';
import 'package:local_mail_client/features/mail/data/repositories/outbox_repository_impl.dart';
import 'package:local_mail_client/features/mail/data/services/sent_copy_service.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';
import 'package:local_mail_client/features/mail/domain/services/attachment_picker.dart';
import 'package:local_mail_client/features/mail/domain/usecases/update_email_flags_usecase.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';

import '../../core/support/fake_imap_session.dart';
import '../auth/support/fakes.dart';
import 'support/mail_fixture.dart';

class _RecordingFlags implements UpdateEmailFlagsUseCase {
  _RecordingFlags(this.email);
  final UnifiedEmail email;
  MailAccount? owner;
  @override
  Future<UnifiedEmail> call({
    required MailAccount account,
    required int emailLocalId,
    bool? isRead,
    bool? isFlagged,
    bool? isAnswered,
  }) async {
    owner = account;
    return email;
  }
}

void main() {
  late MailFixture fixture;
  late FakeAuthRepository auth;
  late FakeImapSessionFactory factory;
  late ConnectionPool pool;
  late MailRemoteRepository remote;
  late OutboxRepositoryImpl outbox;
  late SentCopyService service;
  late Directory temp;
  late OutgoingAttachment attachment;

  setUp(() async {
    fixture = await MailFixture.create();
    auth = FakeAuthRepository()
      ..accounts.add(fixture.account.copyWith(saveSentCopy: true));
    factory = FakeImapSessionFactory(
      mailboxes: const [
        RemoteMailboxInfo(
          remoteName: 'Sent',
          displayName: 'Sent',
          attributes: ['sent'],
        ),
      ],
    );
    pool = ConnectionPool(
      sessionFactory: factory,
      credentialResolver: fakeCredentialResolver,
    );
    await pool.syncAccounts(auth.accounts);
    await pool.connectAccount(fixture.account.id);
    remote = MailRemoteRepository(
      dataSource: MailRemoteDataSource(connectionPool: pool),
    );
    temp = Directory.systemTemp.createTempSync('sent_copy_test_');
    final source = File('${temp.path}/source.txt')
      ..writeAsStringSync('Keep this attachment');
    final store = AttachmentStore(rootProvider: () async => temp);
    attachment = await store.stage(
      PickedAttachment(
        path: source.path,
        fileName: 'source.txt',
        sizeBytes: source.lengthSync(),
        mimeType: 'text/plain',
      ),
    );
    outbox = OutboxRepositoryImpl(
      dataSource: OutboxLocalDataSource(database: fixture.database),
      attachmentStore: store,
    );
    service = SentCopyService(
      outbox: outbox,
      auth: auth,
      local: fixture.localRepository,
      remote: remote,
    );
  });
  tearDown(() async {
    await pool.dispose();
    await auth.dispose();
    await fixture.dispose();
    temp.deleteSync(recursive: true);
  });
  Future<OutboxMessage> sent({ComposeMode mode = ComposeMode.newMail}) async {
    final row = await outbox.saveDraft(
      draft: ComposeDraft(
        accountId: fixture.account.id,
        mode: mode,
        originEmailLocalId: fixture.emailLocalId,
        to: const [EmailAddressEntry(email: 'recipient@example.com')],
        cc: const [],
        bcc: const [EmailAddressEntry(email: 'private@example.com')],
        subject: 'Test sent copy',
        plainBody: 'Saved body',
        attachments: [attachment],
      ),
    );
    await outbox.markSent(row.id);
    return (await outbox.getById(row.id))!;
  }

  test(
    'SMTP acceptance retains attachments until IMAP confirms archival',
    () async {
      final row = await sent();
      expect(File(attachment.localPath).existsSync(), isTrue);
      expect(row.sentCopySaved, isFalse);
      await service.save(row.id);
      expect(factory.totalAppends, 1);
      expect(factory.lastAppendedMime, contains(row.outgoingMessageId));
      expect(factory.lastAppendedMime, contains('Saved body'));
      expect(factory.lastAppendedMime, contains('source.txt'));
      expect(factory.lastAppendedMime, isNot(contains('private@example.com')));
      expect((await outbox.getById(row.id))!.sentCopySaved, isTrue);
      expect(File(attachment.localPath).existsSync(), isFalse);
      await service.save(row.id);
      expect(factory.totalAppends, 1);
      expect((await outbox.getById(row.id))!.status, OutboxStatus.sent);
    },
  );

  test(
    'server auto-saved copy is verified without a duplicate APPEND',
    () async {
      final row = await sent();
      factory.messageIdsByFolder['Sent'] = {row.outgoingMessageId!};
      await service.save(row.id);
      expect(factory.totalAppends, 0);
      expect((await outbox.getById(row.id))!.sentCopySaved, isTrue);
    },
  );

  test('append failure preserves sent status and local files for retry after restart', () async {
    final row = await sent();
    factory.failAppend = true;
    await expectLater(service.save(row.id), throwsA(isA<StateError>()));
    final failed = (await outbox.getById(row.id))!;
    expect(failed.status, OutboxStatus.sent);
    expect(failed.sentCopySaved, isFalse);
    expect(failed.lastError, isNotNull);
    expect(File(attachment.localPath).existsSync(), isTrue);
    factory.failAppend = false;
    final restarted = SentCopyService(
      outbox: outbox,
      auth: auth,
      local: fixture.localRepository,
      remote: remote,
    );
    await restarted.save(row.id);
    expect(factory.totalAppends, 1);
    expect((await outbox.getById(row.id))!.sentCopySaved, isTrue);
    expect(await outbox.getRetryable(), isEmpty);
  });

  test(
    'lost APPEND acknowledgement is recovered by Message-ID lookup',
    () async {
      final row = await sent();
      factory.failAfterAppend = true;
      await expectLater(service.save(row.id), throwsA(isA<StateError>()));
      expect(factory.totalAppends, 1);
      expect(File(attachment.localPath).existsSync(), isTrue);
      factory.failAfterAppend = false;
      await service.save(row.id);
      expect(factory.totalAppends, 1);
      expect((await outbox.getById(row.id))!.sentCopySaved, isTrue);
    },
  );

  test(
    'automatic-save policy waits for server and retains local content',
    () async {
      auth.accounts[0] = fixture.account.copyWith(saveSentCopy: false);
      final row = await sent();
      await expectLater(service.save(row.id), throwsA(isA<StorageFailure>()));
      expect(factory.totalAppends, 0);
      expect(File(attachment.localPath).existsSync(), isTrue);
      factory.messageIdsByFolder['Sent'] = {row.outgoingMessageId!};
      await service.save(row.id);
      expect((await outbox.getById(row.id))!.sentCopySaved, isTrue);
    },
  );

  test('concurrent archive requests produce one APPEND', () async {
    final row = await sent();
    await Future.wait([service.save(row.id), service.save(row.id)]);
    expect(factory.totalAppends, 1);
  });

  test(
    'production post-send hook uses original owner after changing sender',
    () async {
      final row = await sent(mode: ComposeMode.reply);
      final sender = buildTestAccount(id: 'other', email: 'other@gmail.com');
      auth.accounts.add(sender);
      final flags = _RecordingFlags(
        (await fixture.localRepository.getEmail(fixture.emailLocalId))!,
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          connectionPoolProvider.overrideWithValue(pool),
          mailLocalRepositoryProvider.overrideWithValue(
            fixture.localRepository,
          ),
          mailRemoteRepositoryProvider.overrideWithValue(remote),
          outboxRepositoryProvider.overrideWithValue(outbox),
          sentCopyServiceProvider.overrideWithValue(service),
          updateEmailFlagsUseCaseProvider.overrideWithValue(flags),
        ],
      );
      addTearDown(container.dispose);
      final queue = container.read(outboxQueueProvider);
      await queue.postSendHook!(row.copyWith(accountId: sender.id), sender);
      expect(flags.owner!.id, fixture.account.id);
    },
  );
}
