import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/repositories/mail_local_repository.dart';
import 'package:local_mail_client/features/mail/data/repositories/trusted_senders_repository_impl.dart';
import 'package:local_mail_client/features/mail/domain/entities/trusted_sender.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';
import 'package:local_mail_client/features/mail/domain/repositories/trusted_senders_repository.dart';
import 'package:local_mail_client/features/mail/domain/usecases/download_attachment_usecase.dart';
import 'package:local_mail_client/features/mail/domain/usecases/fetch_message_body_usecase.dart';
import 'package:local_mail_client/features/mail/presentation/providers/email_detail_provider.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';

import '../auth/support/fakes.dart';
import 'support/mail_fixture.dart';

class _GatedTrustedSendersRepository implements TrustedSendersRepository {
  final Completer<void> gate = Completer<void>();
  final Set<String> trusted = <String>{};

  @override
  Future<void> trustSender(String senderEmail) async {
    await gate.future;
    trusted.add(senderEmail.trim().toLowerCase());
  }

  @override
  Future<bool> isTrusted(String senderEmail) async =>
      trusted.contains(senderEmail.trim().toLowerCase());

  @override
  Future<Set<TrustedSender>> getTrustedSenders() async =>
      const <TrustedSender>{};

  @override
  Stream<Set<TrustedSender>> watchTrustedSenders() =>
      Stream<Set<TrustedSender>>.value(const <TrustedSender>{});

  @override
  Future<void> untrustSender(String senderEmail) async {
    trusted.remove(senderEmail.trim().toLowerCase());
  }
}

class _GatedLocalRepository implements MailLocalRepository {
  _GatedLocalRepository(this.inner);

  final MailLocalRepository inner;
  final Completer<void> missingGate = Completer<void>();

  @override
  Future<UnifiedEmail?> getEmail(int localId) async {
    if (localId == 9999) {
      await missingGate.future;
      return null;
    }
    return inner.getEmail(localId);
  }

  @override
  Stream<UnifiedEmail?> watchEmail(int localId) => inner.watchEmail(localId);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeFetchBodyUseCase implements FetchMessageBodyUseCase {
  _FakeFetchBodyUseCase(this.fixture);

  final MailFixture fixture;
  int calls = 0;

  @override
  Future<UnifiedEmail> call({
    required MailAccount account,
    required int emailLocalId,
  }) async {
    calls++;
    await (fixture.database.update(
      fixture.database.dbEmails,
    )..where((table) => table.localId.equals(emailLocalId))).write(
      DbEmailsCompanion(
        plainBody: Value('Fetched plain body'),
        htmlBody: Value('<p>Fetched HTML</p>'),
        bodyDownloaded: Value(true),
      ),
    );
    return (await fixture.localRepository.getEmail(emailLocalId))!;
  }
}

class _FakeDownloadAttachmentUseCase implements DownloadAttachmentUseCase {
  int calls = 0;

  @override
  Future<String> call({
    required MailAccount account,
    required int emailLocalId,
    required String partId,
  }) async {
    calls++;
    return '/tmp/inline-logo.png';
  }
}

void main() {
  test(
    'second detail open restores cached CID only and never downloads again',
    () async {
      final fixture = await MailFixture.create(bodyDownloaded: false);
      addTearDown(fixture.dispose);
      final auth = FakeAuthRepository()..accounts.add(fixture.account);
      addTearDown(auth.dispose);
      final fetch = _FakeFetchBodyUseCase(fixture);
      final download = _FakeDownloadAttachmentUseCase();
      await (fixture.database.update(
        fixture.database.dbEmails,
      )..where((table) => table.localId.equals(fixture.emailLocalId))).write(
        DbEmailsCompanion(
          bodyDownloaded: Value(false),
          plainBody: Value(null),
          htmlBody: Value(null),
        ),
      );
      await fixture.database
          .into(fixture.database.dbAttachments)
          .insert(
            DbAttachmentsCompanion.insert(
              id: 'inline-1',
              emailLocalId: fixture.emailLocalId,
              partId: '2',
              filename: 'logo.png',
              mimeType: 'image/png',
              sizeBytes: 4,
              contentId: const Value('logo@cid'),
              isInline: const Value(true),
            ),
          );

      final container = ProviderContainer(
        overrides: [
          mailLocalRepositoryProvider.overrideWithValue(
            fixture.localRepository,
          ),
          authRepositoryProvider.overrideWithValue(auth),
          trustedSendersRepositoryProvider.overrideWithValue(
            TrustedSendersRepositoryImpl(database: fixture.database),
          ),
          fetchMessageBodyUseCaseProvider.overrideWithValue(fetch),
          downloadAttachmentUseCaseProvider.overrideWithValue(download),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(emailDetailProvider, (_, _) {});
      addTearDown(keepAlive.close);

      final notifier = container.read(emailDetailProvider.notifier);
      notifier.open(fixture.emailLocalId);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fetch.calls, 1);
      expect(download.calls, 1);

      notifier.open(fixture.emailLocalId);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fetch.calls, 1, reason: 'body is cached after first fetch');
      expect(
        download.calls,
        1,
        reason: 'second open must not download a missing inline attachment from network',
      );

      final state = container.read(emailDetailProvider);
      expect(state.cidLocalPaths, isEmpty);
      expect(state.isLoadingBody, isFalse);
    },
  );

  test(
    'trust write for message A does not grant permission to message B',
    () async {
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

      final trusted = _GatedTrustedSendersRepository();
      addTearDown(() {
        if (!trusted.gate.isCompleted) trusted.gate.complete();
      });
      final container = ProviderContainer(
        overrides: [
          mailLocalRepositoryProvider.overrideWithValue(
            fixture.localRepository,
          ),
          authRepositoryProvider.overrideWithValue(auth),
          trustedSendersRepositoryProvider.overrideWithValue(trusted),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(emailDetailProvider, (_, _) {});
      addTearDown(keepAlive.close);

      final notifier = container.read(emailDetailProvider.notifier);
      notifier.open(fixture.emailLocalId);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(container.read(emailDetailProvider).trustedSender, isFalse);

      final pending = notifier.trustSender('sender@example.com');
      notifier.open(secondId);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(container.read(emailDetailProvider).emailLocalId, secondId);
      expect(container.read(emailDetailProvider).trustedSender, isFalse);

      trusted.gate.complete();
      await pending;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(emailDetailProvider);
      expect(state.emailLocalId, secondId);
      expect(
        state.trustedSender,
        isFalse,
        reason: 'A trust completion must not authorize the newly opened B',
      );
      expect(state.allowRemoteImages, isFalse);
      expect(state.errorMessage, isNull);
    },
  );

  test(
    'late missing-body result cannot overwrite the newly opened message',
    () async {
      final fixture = await MailFixture.create();
      addTearDown(fixture.dispose);
      final auth = FakeAuthRepository()..accounts.add(fixture.account);
      addTearDown(auth.dispose);
      final gated = _GatedLocalRepository(fixture.localRepository);
      addTearDown(() {
        if (!gated.missingGate.isCompleted) gated.missingGate.complete();
      });
      final container = ProviderContainer(
        overrides: [
          mailLocalRepositoryProvider.overrideWithValue(gated),
          authRepositoryProvider.overrideWithValue(auth),
          trustedSendersRepositoryProvider.overrideWithValue(
            TrustedSendersRepositoryImpl(database: fixture.database),
          ),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(emailDetailProvider, (_, _) {});
      addTearDown(keepAlive.close);

      final notifier = container.read(emailDetailProvider.notifier);
      notifier.open(9999);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      notifier.open(fixture.emailLocalId);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        container.read(emailDetailProvider).errorMessage,
        isNull,
        reason: 'the valid message must not be replaced by a slow missing one',
      );

      gated.missingGate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(emailDetailProvider);
      expect(state.emailLocalId, fixture.emailLocalId);
      expect(state.errorMessage, isNull);
      expect(state.isLoadingBody, isFalse);
    },
  );
}
