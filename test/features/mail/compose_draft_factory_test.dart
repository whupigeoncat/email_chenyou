import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/domain/entities/mail_attachment.dart';
import 'package:local_mail_client/features/mail/domain/entities/mail_folder.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';
import 'package:local_mail_client/features/mail/domain/services/attachment_picker.dart';
import 'package:local_mail_client/features/mail/domain/services/compose_draft_factory.dart';

MailAccount _account() {
  return MailAccount(
    id: 'acc',
    email: 'me@example.com',
    displayName: 'Me',
    providerType: MailProviderType.gmail,
    authType: MailAuthType.passwordOrAuthCode,
    colorValue: 0xFF000001,
    imapHost: 'imap.example.com',
    imapPort: 993,
    imapImplicitTls: true,
    smtpHost: 'smtp.example.com',
    smtpPort: 465,
    smtpImplicitTls: true,
    createdAt: DateTime.utc(2026),
  );
}

UnifiedEmail _original({
  String subject = 'Hello',
  List<MailAttachment> attachments = const [],
}) {
  return UnifiedEmail(
    localId: 1,
    accountId: 'acc',
    accountEmail: 'me@example.com',
    accountDisplayName: 'Me',
    accountColorValue: 1,
    folderId: 'f',
    folderRole: FolderRole.inbox,
    uid: 1,
    messageId: '<original@example.com>',
    subject: subject,
    fromName: 'Alice',
    fromAddress: 'alice@example.com',
    toAddresses: const [
      EmailAddressEntry(email: 'me@example.com', name: 'Me'),
      EmailAddressEntry(email: 'bob@example.com', name: 'Bob'),
    ],
    ccAddresses: const [
      EmailAddressEntry(email: 'carol@example.com', name: 'Carol'),
    ],
    snippet: 'snippet',
    plainBody: 'Original plain body',
    htmlBody:
        '<p>Original</p><script>alert(1)</script><img src="https://tracker.test/p.gif">',
    sentAt: DateTime.utc(2026, 1, 1),
    isRead: true,
    isFlagged: false,
    isAnswered: false,
    hasAttachments: attachments.isNotEmpty,
    bodyDownloaded: true,
    attachments: attachments,
  );
}

void main() {
  final factory = ComposeDraftFactory();

  test('reply fills recipient, subject and sanitized quote', () {
    final draft = factory.reply(account: _account(), original: _original());

    expect(draft.to.single.email, 'alice@example.com');
    expect(draft.subject, 'Re: Hello');
    expect(draft.inReplyTo, '<original@example.com>');
    expect(draft.referencesHeader, '<original@example.com>');
    expect(draft.plainBody, contains('Original plain body'));
    expect(draft.htmlBody, isNot(contains('<script')));
    expect(draft.htmlBody, isNot(contains('tracker.test')));
    expect(draft.mode, ComposeMode.reply);
  });

  test('reply does not duplicate an existing Re prefix', () {
    final draft = factory.reply(
      account: _account(),
      original: _original(subject: 'Re: Hello'),
    );
    expect(draft.subject, 'Re: Hello');
  });

  test('reply all dedupes and excludes the current account', () {
    final draft = factory.reply(
      account: _account(),
      original: _original(),
      replyAll: true,
    );

    expect(draft.to.map((entry) => entry.email), <String>[
      'alice@example.com',
      'bob@example.com',
    ]);
    expect(draft.cc.map((entry) => entry.email), <String>[
      'carol@example.com',
    ]);
    expect(
      draft.to.map((entry) => entry.email),
      isNot(contains('me@example.com')),
    );
    expect(draft.mode, ComposeMode.replyAll);
  });

  test('forward prefixes subject and attaches only existing cached files',
      () async {
    final temp = await Directory.systemTemp.createTemp('compose_forward_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/invoice.pdf');
    await file.writeAsBytes(<int>[1, 2, 3]);
    final cached = MailAttachment(
      id: 'att',
      emailLocalId: 1,
      partId: '2',
      filename: 'invoice.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 3,
      localCachePath: file.path,
    );
    final missing = const MailAttachment(
      id: 'att-2',
      emailLocalId: 1,
      partId: '3',
      filename: 'remote.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 20,
    );

    final outboxRoot = await Directory.systemTemp.createTemp('forward_root_');
    addTearDown(() => outboxRoot.delete(recursive: true));
    final stagingFactory = ComposeDraftFactory(
      attachmentStore: AttachmentStore(
        rootProvider: () async => outboxRoot,
        idGenerator: () => 'forward-copy',
      ),
    );
    final draft = await stagingFactory.forward(
      account: _account(),
      original: _original(attachments: [cached, missing]),
    );

    expect(draft.subject, 'Fwd: Hello');
    expect(draft.attachments.single.fileName, 'invoice.pdf');
    expect(draft.attachments.single.localPath, isNot(file.path));
    expect(
      draft.attachments.single.localPath,
      startsWith(outboxRoot.path),
    );
    expect(File(draft.attachments.single.localPath).existsSync(), isTrue);

    // Clearing the received-mail cache must not affect the staged copy.
    await file.delete();
    expect(File(draft.attachments.single.localPath).existsSync(), isTrue);
    expect(draft.missingAttachmentCount, 1);
    expect(draft.to, isEmpty);
  });

  test('recipient parser validates and dedupes mixed input', () {
    final parsed = factory.parseRecipients(
      'Alice <ALICE@example.com>, not-an-email; bob@example.com',
    );
    expect(parsed.valid.map((entry) => entry.email), <String>[
      'ALICE@example.com',
      'bob@example.com',
    ]);
    expect(parsed.invalid, <String>['not-an-email']);
  });

  test('new mail uses preselected account', () {
    final draft = factory.newMail(account: _account(), subject: 'Hi');
    expect(draft.accountId, 'acc');
    expect(draft.mode, ComposeMode.newMail);
    expect(draft.subject, 'Hi');
  });
}
