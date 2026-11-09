import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/domain/entities/mail_attachment.dart';
import 'package:local_mail_client/features/mail/domain/usecases/download_attachment_usecase.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';
import 'package:local_mail_client/features/mail/presentation/widgets/attachment_preview_sheet.dart';

import '../../core/support/fake_imap_session.dart';

class _FakeDownloadAttachmentUseCase implements DownloadAttachmentUseCase {
  int calls = 0;

  @override
  Future<String> call({
    required MailAccount account,
    required int emailLocalId,
    required String partId,
  }) async {
    calls++;
    return '/tmp/attachment-preview.txt';
  }
}

void main() {
  testWidgets('attachment sheet downloads on demand and opens through system',
      (tester) async {
    final download = _FakeDownloadAttachmentUseCase();
    String? opened;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadAttachmentUseCaseProvider.overrideWithValue(download),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AttachmentPreviewSheet(
              account: buildTestAccount(),
              emailLocalId: 1,
              attachment: const MailAttachment(
                id: 'a',
                emailLocalId: 1,
                partId: '2',
                filename: 'notes.txt',
                mimeType: 'text/plain',
                sizeBytes: 4,
              ),
              openFile: (path) async => opened = path,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(download.calls, 1);
    expect(find.text('notes.txt'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-attachment-external')));
    await tester.pumpAndSettle();
    expect(opened, '/tmp/attachment-preview.txt');
  });
}
