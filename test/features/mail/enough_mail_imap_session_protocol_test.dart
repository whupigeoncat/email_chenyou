import 'package:enough_mail/enough_mail.dart' hide MailAccount;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/datasources/enough_mail_imap_session.dart';

import '../../core/support/fake_imap_session.dart';
import '../auth/support/fakes.dart';

const String _rawMime =
    'From: Sender <sender@example.com>\r\n'
    'To: Recipient <rcpt@example.com>\r\n'
    'Subject: =?UTF-8?B?5L2g5aW9?=\r\n'
    'Date: Thu, 01 Jan 2026 00:00:00 +0000\r\n'
    'Message-ID: <message-2@example.com>\r\n'
    'MIME-Version: 1.0\r\n'
    'Content-Type: multipart/mixed; boundary="outer"\r\n'
    '\r\n'
    '--outer\r\n'
    'Content-Type: multipart/alternative; boundary="alt"\r\n'
    '\r\n'
    '--alt\r\n'
    'Content-Type: text/plain; charset=utf-8\r\n'
    'Content-Transfer-Encoding: 8bit\r\n'
    '\r\n'
    'Hello body 正文\r\n'
    '--alt\r\n'
    'Content-Type: text/html; charset=utf-8\r\n'
    'Content-Transfer-Encoding: 8bit\r\n'
    '\r\n'
    '<html><body><p>Hello HTML</p><img src="cid:logo@cid"></body></html>\r\n'
    '--alt--\r\n'
    '--outer\r\n'
    'Content-Type: application/pdf; name="invoice.pdf"\r\n'
    'Content-Disposition: attachment; filename="invoice.pdf"\r\n'
    'Content-Transfer-Encoding: base64\r\n'
    '\r\n'
    'AQIDBA==\r\n'
    '--outer\r\n'
    'Content-Type: image/png; name="logo.png"\r\n'
    'Content-Disposition: inline; filename="logo.png"\r\n'
    'Content-ID: <logo@cid>\r\n'
    'Content-Transfer-Encoding: base64\r\n'
    '\r\n'
    'iVBORw0KGgo=\r\n'
    '--outer--\r\n';

MimeMessage _headerMessage() {
  return MimeMessage.fromEnvelope(
    Envelope(
      date: DateTime.utc(2026, 1, 1),
      subject: 'Hello 主题',
      from: <MailAddress>[const MailAddress('Sender', 'sender@example.com')],
      to: <MailAddress>[const MailAddress('Recipient', 'rcpt@example.com')],
      cc: <MailAddress>[const MailAddress('CC', 'cc@example.com')],
      messageId: '<message-1@example.com>',
    ),
    uid: 1,
    sequenceId: 1,
    flags: <String>[r'\Seen', r'\Flagged'],
  )..internalDate = '01-Jan-2026 00:00:00 +0000';
}

MimeMessage _fullMessage() {
  return MimeMessage.parseFromText(_rawMime)
    ..uid = 2
    ..sequenceId = 2
    ..flags = <String>[r'\Answered']
    ..size = 2048
    ..internalDate = '01-Jan-2026 00:00:00 +0000';
}

MimeMessage _attachmentPartMessage() {
  final part = MimePart()
    ..mimeData = TextMimeData('AQIDBA==', containsHeader: false)
    ..addHeader('Content-Transfer-Encoding', 'base64');
  part.parse();
  return MimeMessage()
    ..uid = 2
    ..sequenceId = 2
    ..setPart('2', part);
}

class _ProtocolFakeImapClient extends FakeImapClient {
  String? lastFetchDefinition;
  String? lastUidFetchDefinition;
  MimeMessage? bodyStructureAttachmentMessage;
  StoreAction? lastStoreAction;
  List<String>? lastStoreFlags;

  @override
  Future<Mailbox> selectInbox({
    bool enableCondStore = false,
    QResyncParameters? qresync,
  }) async {
    protocol.add('selectInbox');
    return Mailbox(
      encodedName: 'INBOX',
      encodedPath: 'INBOX',
      flags: <MailboxFlag>[MailboxFlag.inbox],
      pathSeparator: '/',
      uidValidity: 42,
      uidNext: 99,
      messagesExists: 2,
      messagesUnseen: 1,
    );
  }

  @override
  Future<List<Mailbox>> listMailboxes({
    String path = '""',
    bool recursive = false,
    List<String>? mailboxPatterns,
    List<String>? selectionOptions,
    List<ReturnOption>? returnOptions,
  }) async {
    protocol.add('listMailboxes');
    return <Mailbox>[
      Mailbox(
        encodedName: 'INBOX',
        encodedPath: 'INBOX',
        flags: <MailboxFlag>[MailboxFlag.inbox],
        pathSeparator: '/',
      ),
      Mailbox(
        encodedName: 'Sent',
        encodedPath: 'Sent',
        flags: <MailboxFlag>[MailboxFlag.sent],
        pathSeparator: '/',
      ),
      Mailbox(
        encodedName: 'NoSelect',
        encodedPath: 'NoSelect',
        flags: <MailboxFlag>[MailboxFlag.noSelect],
        pathSeparator: '/',
      ),
    ];
  }

  @override
  Future<FetchImapResult> fetchMessages(
    MessageSequence sequence,
    String? fetchContentDefinition, {
    int? changedSinceModSequence,
    Duration? responseTimeout,
  }) async {
    lastFetchDefinition = fetchContentDefinition;
    return FetchImapResult(<MimeMessage>[_headerMessage()], null);
  }

  @override
  Future<FetchImapResult> uidFetchMessages(
    MessageSequence sequence,
    String? fetchContentDefinition, {
    int? changedSinceModSequence,
    Duration? responseTimeout,
  }) async {
    lastUidFetchDefinition = fetchContentDefinition;
    if (fetchContentDefinition == '(BODYSTRUCTURE BODY.PEEK[2])') {
      return FetchImapResult(
        <MimeMessage>[
          bodyStructureAttachmentMessage ?? _attachmentPartMessage(),
        ],
        null,
      );
    }
    return FetchImapResult(<MimeMessage>[_fullMessage()], null);
  }

  @override
  Future<StoreImapResult> uidStore(
    MessageSequence sequence,
    List<String> flags, {
    StoreAction? action,
    bool? silent,
    int? unchangedSinceModSequence,
  }) async {
    lastStoreAction = action;
    lastStoreFlags = flags;
    return StoreImapResult();
  }
}


MimeMessage _bodyStructureOnlyEncodingMessage() {
  final part = MimePart()
    ..mimeData = TextMimeData('AQIDBA==', containsHeader: false);
  part.parse();
  final message = MimeMessage()
    ..uid = 2
    ..sequenceId = 2
    ..setPart('2', part);
  // The part intentionally has no Content-Transfer-Encoding header. Only the
  // BODYSTRUCTURE child knows that the payload is Base64.
  message.body = BodyPart();
  message.body!.addPart(BodyPart());
  message.body!.addPart(BodyPart()..encoding = 'base64');
  return message;
}

void main() {
  late _ProtocolFakeImapClient client;
  late EnoughMailImapSession session;
  late MailAccount account;

  setUp(() async {
    client = _ProtocolFakeImapClient();
    session = EnoughMailImapSession(client: client);
    account = buildTestAccount(id: 'protocol', email: 'alice@gmail.com');
    await session.connectAndAuthenticate(
      account: account,
      credential: const PasswordCredential('auth-code'),
    );
  });

  tearDown(() async {
    await session.logoutAndDisconnect();
  });

  test('LIST maps special-use flags and selectable state', () async {
    final mailboxes = await session.listMailboxes();

    expect(mailboxes, hasLength(3));
    expect(mailboxes[0].isInbox, isTrue);
    expect(mailboxes[1].isSent, isTrue);
    expect(mailboxes[2].isSelectable, isFalse);
    expect(mailboxes[1].remoteName, 'Sent');
  });

  test('selectFolderWithStatus exposes UIDVALIDITY and counts', () async {
    final status = await session.selectFolderWithStatus('INBOX');

    expect(status.uidValidity, 42);
    expect(status.uidNext, 99);
    expect(status.messagesExists, 2);
    expect(status.messagesUnseen, 1);
    expect(session.selectedFolder, 'INBOX');
  });

  test('header fetch requests ENVELOPE/BODYSTRUCTURE but no BODY[]', () async {
    await session.selectFolder('INBOX');
    final messages = await session.fetchMessageHeaders(limit: 50);

    expect(client.lastFetchDefinition, contains('ENVELOPE'));
    expect(client.lastFetchDefinition, contains('BODYSTRUCTURE'));
    expect(client.lastFetchDefinition, isNot(contains('BODY[]')));
    expect(client.lastFetchDefinition, isNot(contains('BODY.PEEK[]')));

    expect(messages, hasLength(1));
    expect(messages.single.uid, 1);
    expect(messages.single.subject, 'Hello 主题');
    expect(messages.single.fromAddress, 'sender@example.com');
    expect(messages.single.isSeen, isTrue);
    expect(messages.single.isFlagged, isTrue);
    expect(messages.single.sentAt, DateTime.utc(2026, 1, 1));
  });

  test(
    'full UID fetch uses BODY.PEEK[], decodes bodies and cid attachments',
    () async {
      final message = await session.uidFetchFullMessage(2);

      expect(client.lastUidFetchDefinition, contains('BODY.PEEK[]'));
      expect(message, isNotNull);
      expect(message!.plainBody, contains('Hello body'));
      expect(message.plainBody, contains('正文'));
      expect(message.htmlBody, contains('<p>Hello HTML</p>'));
      expect(message.attachments, hasLength(2));

      final pdf = message.attachments.firstWhere(
        (attachment) => attachment.mimeType == 'application/pdf',
      );
      expect(pdf.partId, '2');
      expect(pdf.filename, 'invoice.pdf');
      expect(pdf.isInline, isFalse);

      final logo = message.attachments.firstWhere(
        (attachment) => attachment.mimeType == 'image/png',
      );
      expect(logo.isInline, isTrue);
      expect(logo.contentId, 'logo@cid');
    },
  );


  test('attachment decoding falls back to BODYSTRUCTURE child encoding',
      () async {
    client.bodyStructureAttachmentMessage =
        _bodyStructureOnlyEncodingMessage();
    final bytes = await session.uidFetchAttachmentPart(uid: 2, partId: '2');

    expect(client.lastUidFetchDefinition, '(BODYSTRUCTURE BODY.PEEK[2])');
    expect(bytes, <int>[1, 2, 3, 4]);
  });

  test(
    'attachment part fetch uses BODYSTRUCTURE/BODY.PEEK, decodes Base64 and rejects injection',
    () async {
      final bytes = await session.uidFetchAttachmentPart(uid: 2, partId: '2');
      expect(client.lastUidFetchDefinition, '(BODYSTRUCTURE BODY.PEEK[2])');
      // AQIDBA== is Base64 for [1, 2, 3, 4]. The fake part stores the encoded
      // text, so this assertion fails if transfer-encoding is not applied.
      expect(bytes, <int>[1, 2, 3, 4]);

      final before = client.lastUidFetchDefinition;
      final rejected = await session.uidFetchAttachmentPart(
        uid: 2,
        partId: '2\r\nLOGOUT',
      );
      expect(rejected, isNull);
      expect(client.lastUidFetchDefinition, before);
    },
  );

  test('UID STORE maps add/remove actions', () async {
    await session.uidStoreFlags(
      uid: 2,
      flags: const <String>[r'\Seen'],
      add: true,
    );
    expect(client.lastStoreAction, StoreAction.add);
    expect(client.lastStoreFlags, <String>[r'\Seen']);

    await session.uidStoreFlags(
      uid: 2,
      flags: const <String>[r'\Flagged'],
      add: false,
    );
    expect(client.lastStoreAction, StoreAction.remove);
    expect(client.lastStoreFlags, <String>[r'\Flagged']);
  });
}
