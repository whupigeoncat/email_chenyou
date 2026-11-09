import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/repositories/trusted_senders_repository_impl.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';
import 'package:local_mail_client/features/mail/domain/usecases/download_attachment_usecase.dart';
import 'package:local_mail_client/features/mail/domain/usecases/fetch_message_body_usecase.dart';
import 'package:local_mail_client/features/mail/presentation/providers/email_detail_provider.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';

import '../auth/support/fakes.dart';
import 'support/mail_fixture.dart';

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
    await (fixture.database.update(fixture.database.dbEmails)
          ..where((table) => table.localId.equals(emailLocalId)))
        .write(
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
  test('second detail open restores cached CID only and never downloads again',
      () async {
    final fixture = await MailFixture.create(bodyDownloaded: false);
    addTearDown(fixture.dispose);
    final auth = FakeAuthRepository()..accounts.add(fixture.account);
    addTearDown(auth.dispose);
    final fetch = _FakeFetchBodyUseCase(fixture);
    final download = _FakeDownloadAttachmentUseCase();
    await (fixture.database.update(fixture.database.dbEmails)
          ..where((table) => table.localId.equals(fixture.emailLocalId)))
        .write(
      DbEmailsCompanion(
        bodyDownloaded: Value(false),
        plainBody: Value(null),
        htmlBody: Value(null),
      ),
    );
    await fixture.database.into(fixture.database.dbAttachments).insert(
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
        mailLocalRepositoryProvider.overrideWithValue(fixture.localRepository),
        authRepositoryProvider.overrideWithValue(auth),
        trustedSendersRepositoryProvider.overrideWithValue(
          TrustedSendersRepositoryImpl(database: fixture.database),
        ),
        fetchMessageBodyUseCaseProvider.overrideWithValue(fetch),
        downloadAttachmentUseCaseProvider.overrideWithValue(download),
      ],
    );
    addTearDown(container.dispose);
    final keepAlive = container.listen(
      emailDetailProvider,
      (_, _) {},
    );
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
      reason:
          'second open must not download a missing inline attachment from network',
    );

    final state = container.read(emailDetailProvider);
    expect(state.cidLocalPaths, isEmpty);
    expect(state.isLoadingBody, isFalse);
  });
}
