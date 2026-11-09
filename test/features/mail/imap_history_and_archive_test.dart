import 'package:enough_mail/enough_mail.dart' hide MailAccount;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/features/mail/data/datasources/enough_mail_imap_session.dart';

import '../auth/support/fakes.dart';

class _Client extends FakeImapClient {
  String? criteria;
  List<int> searchIds = [];
  List<int>? requested;
  String? definition;
  String? mime;
  List<String>? appendedFlags;
  DateTime? appendedDate;
  @override
  Future<SearchImapResult> uidSearchMessages({
    String searchCriteria = 'UNSEEN',
    List<ReturnOption>? returnOptions,
    Duration? responseTimeout,
  }) async {
    criteria = searchCriteria;
    return SearchImapResult()
      ..matchingSequence = MessageSequence.fromIds(searchIds, isUid: true);
  }

  @override
  Future<FetchImapResult> uidFetchMessages(
    MessageSequence sequence,
    String? fetchContentDefinition, {
    int? changedSinceModSequence,
    Duration? responseTimeout,
  }) async {
    requested = sequence.toList();
    definition = fetchContentDefinition;
    return FetchImapResult([
      for (final uid in [...requested!, 999999])
        MimeMessage()
          ..uid = uid
          ..flags = [r'\Seen'],
    ], MessageSequence.fromIds(requested!, isUid: true));
  }

  @override
  Future<GenericImapResult> appendMessageText(
    String messageText, {
    List<String>? flags,
    Mailbox? targetMailbox,
    String? targetMailboxPath,
    DateTime? internalDate,
    Duration? responseTimeout,
  }) async {
    mime = messageText;
    appendedFlags = flags;
    appendedDate = internalDate;
    return GenericImapResult();
  }
}

void main() {
  test(
    'history uses bounded UID page with sparse IDs and header-only fetch',
    () async {
      final client = _Client()..searchIds = [1, 10, 1000, 2999, 3000];
      final session = EnoughMailImapSession(client: client);
      final page = await session.fetchOlderMessageHeaders(
        beforeUid: 3000,
        limit: 2,
      );
      expect(client.criteria, 'UID 1:2999');
      expect(client.requested, [1000, 2999]);
      expect(page.map((message) => message.uid), [1000, 2999]);
      expect(client.definition, isNot(contains('BODY.PEEK[]')));
      client.criteria = null;
      expect(await session.fetchOlderMessageHeaders(beforeUid: 1), isEmpty);
      expect(client.criteria, isNull);
    },
  );
  test(
    'flag reconciliation fetches only UID FLAGS and filters unsolicited UIDs',
    () async {
      final client = _Client();
      final session = EnoughMailImapSession(client: client);
      final flags = await session.uidFetchFlags([3, 7]);
      expect(client.definition, '(UID FLAGS)');
      expect(flags, {
        3: [r'\Seen'],
        7: [r'\Seen'],
      });
    },
  );
  test(
    'archive lookup escapes IMAP quotes and rejects command injection',
    () async {
      final client = _Client()..searchIds = [99];
      final session = EnoughMailImapSession(client: client);
      expect(await session.containsMessageId('<test@example.com>'), isTrue);
      expect(client.criteria, 'HEADER Message-ID "<test@example.com>"');
      await session.containsMessageId('quote"slash\\');
      expect(client.criteria, r'HEADER Message-ID "quote\"slash\\"');
      await expectLater(
        session.containsMessageId('bad\r\nUID STORE 1'),
        throwsA(isA<StorageFailure>()),
      );
    },
  );
  test('archive APPEND sets Seen and original sent time', () async {
    final client = _Client();
    final session = EnoughMailImapSession(client: client);
    final time = DateTime.utc(2026, 1, 1);
    await session.appendSentMessage(
      'Message-ID: <id@example.com>\r\n\r\nBody',
      sentAt: time,
    );
    expect(client.mime, contains('Body'));
    expect(client.appendedFlags, [r'\Seen']);
    expect(client.appendedDate, time);
  });
}
