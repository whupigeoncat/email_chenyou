import 'dart:async';
import 'dart:typed_data';

import '../../features/auth/domain/entities/mail_account.dart';

/// Resolved secret credential fetched from `SecureStorageService` just-in-time.
/// Kept ephemeral in memory only during active connection lifecycle.
sealed class ResolvedAccountCredential {
  const ResolvedAccountCredential();
}

final class PasswordCredential extends ResolvedAccountCredential {
  const PasswordCredential(this.secret);
  final String secret;
}

final class OAuthCredential extends ResolvedAccountCredential {
  const OAuthCredential({required this.accessToken, this.expiresAt});

  final String accessToken;
  final DateTime? expiresAt;
}

/// High-level event emitted by an active IMAP IDLE connection on INBOX.
sealed class ImapInboxEvent {
  const ImapInboxEvent();
}

final class ImapMailboxMessagesAdded extends ImapInboxEvent {
  const ImapMailboxMessagesAdded({required this.existsCount});
  final int existsCount;
}

final class ImapMailboxFlagsUpdated extends ImapInboxEvent {
  const ImapMailboxFlagsUpdated();
}

final class ImapMailboxMessagesVanished extends ImapInboxEvent {
  const ImapMailboxMessagesVanished();
}

final class ImapConnectionDropped extends ImapInboxEvent {
  const ImapConnectionDropped([this.reason]);
  final String? reason;
}

/// Lightweight, protocol-only address value used by the mail data layer.
/// Deliberately independent from `enough_mail` so fakes and use cases stay
/// testable without importing a concrete IMAP client.
class RemoteMailAddress {
  const RemoteMailAddress({required this.email, this.name = ''});

  final String name;
  final String email;

  String get displayLabel => name.isNotEmpty ? '$name <$email>' : email;
}

/// Metadata for one MIME attachment part. No bytes are downloaded here.
class RemoteAttachmentMeta {
  const RemoteAttachmentMeta({
    required this.partId,
    required this.filename,
    required this.mimeType,
    this.sizeBytes = 0,
    this.contentId,
    this.isInline = false,
  });

  /// MIME fetch-id such as `2` or `1.2` (BODY.PEEK[partId]).
  final String partId;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final String? contentId;
  final bool isInline;
}

/// A message as returned by a header-only or a full-body UID FETCH.
///
/// Header-only fetches leave [plainBody] / [htmlBody] null and never request
/// `BODY[]`, so the server cannot implicitly set the `\Seen` flag.
class RemoteFetchedMessage {
  const RemoteFetchedMessage({
    required this.uid,
    required this.subject,
    required this.fromAddress,
    required this.sentAt,
    this.fromName = '',
    this.messageId,
    this.toAddresses = const [],
    this.ccAddresses = const [],
    this.flags = const [],
    this.sizeBytes = 0,
    this.snippet = '',
    this.plainBody,
    this.htmlBody,
    this.attachments = const [],
  });

  final int uid;
  final String subject;
  final String fromName;
  final String fromAddress;
  final List<RemoteMailAddress> toAddresses;
  final List<RemoteMailAddress> ccAddresses;
  final String? messageId;
  final DateTime sentAt;
  final List<String> flags;
  final int sizeBytes;
  final String snippet;
  final String? plainBody;
  final String? htmlBody;
  final List<RemoteAttachmentMeta> attachments;

  bool get hasAttachments => attachments.isNotEmpty;

  bool get isSeen => _hasFlag(r'\seen');
  bool get isFlagged => _hasFlag(r'\flagged');
  bool get isAnswered => _hasFlag(r'\answered');

  bool _hasFlag(String name) => flags.any((flag) => flag.toLowerCase() == name);
}

/// Mailbox metadata returned by IMAP `LIST`.
class RemoteMailboxInfo {
  const RemoteMailboxInfo({
    required this.remoteName,
    required this.displayName,
    this.pathSeparator = '/',
    this.attributes = const [],
    this.uidValidity,
    this.uidNext,
    this.messagesExists = 0,
    this.messagesUnseen = 0,
    this.highestModSeq,
    this.isSelectable = true,
  });

  /// Full decoded path accepted by SELECT / `selectMailboxByPath`.
  final String remoteName;

  /// Human-readable leaf name (decoded modified UTF-7).
  final String displayName;
  final String pathSeparator;

  /// Raw special-use attributes such as `sent`, `drafts`, `junk`.
  final List<String> attributes;
  final int? uidValidity;
  final int? uidNext;
  final int messagesExists;
  final int messagesUnseen;
  final int? highestModSeq;
  final bool isSelectable;

  bool _hasAttribute(String name) =>
      attributes.any((attribute) => attribute.toLowerCase() == name);

  bool get isInbox =>
      remoteName.toUpperCase() == 'INBOX' || _hasAttribute('inbox');
  bool get isSent => _hasAttribute('sent');
  bool get isDrafts => _hasAttribute('drafts');
  bool get isTrash => _hasAttribute('trash');
  bool get isJunk => _hasAttribute('junk');
  bool get isArchive => _hasAttribute('archive');
}

/// Status returned by a successful `SELECT` (RFC 3501 mailbox status).
class RemoteMailboxStatus {
  const RemoteMailboxStatus({
    required this.remoteName,
    this.uidValidity,
    this.uidNext,
    this.messagesExists = 0,
    this.messagesUnseen = 0,
    this.highestModSeq,
  });

  final String remoteName;
  final int? uidValidity;
  final int? uidNext;
  final int messagesExists;
  final int messagesUnseen;
  final int? highestModSeq;
}

/// Abstract IMAP session interface decoupling `ConnectionPool` from `enough_mail`
/// so lifecycle invariants can be thoroughly unit-tested without live sockets.
abstract interface class ImapSession {
  bool get isConnected;
  bool get isIdle;

  /// True only when the server advertised RFC 2177 IDLE after authentication.
  /// Callers MUST fall back to single-connection polling when false.
  bool get supportsIdle;
  String? get selectedFolder;

  Stream<ImapInboxEvent> get events;

  Future<void> connectAndAuthenticate({
    required MailAccount account,
    required ResolvedAccountCredential credential,
  });

  Future<void> selectFolder(String remoteFolderName);

  /// Selects [remoteFolderName] and returns UIDVALIDITY / UIDNEXT / counts.
  Future<RemoteMailboxStatus> selectFolderWithStatus(String remoteFolderName);

  /// Lists all mailboxes without changing the currently selected folder.
  Future<List<RemoteMailboxInfo>> listMailboxes();

  /// Fetches headers for the most recent [limit] messages in the selected
  /// folder. Implementations MUST use ENVELOPE/BODYSTRUCTURE/BODY.PEEK and
  /// never fetch `BODY[]` here.
  Future<List<RemoteFetchedMessage>> fetchMessageHeaders({int limit = 50});

  /// Fetches headers for UIDs >= [fromUid] (inclusive), up to [toUid].
  /// `toUid == null` renders the RFC 3501 `fromUid:*` range.
  /// `limit == 0` means unlimited; incremental sync must never drop UIDs.
  Future<List<RemoteFetchedMessage>> uidFetchMessageHeaders({
    required int fromUid,
    int? toUid,
    int limit = 0,
  });

  /// Bounded history page, strictly before [beforeUid].
  Future<List<RemoteFetchedMessage>> fetchOlderMessageHeaders({
    required int beforeUid,
    int limit = 200,
  });

  /// Returns flags for existing requested UIDs; missing UIDs have vanished.
  Future<Map<int, List<String>>> uidFetchFlags(List<int> uids);

  Future<bool> containsMessageId(String messageId);

  Future<void> appendSentMessage(String mimeText, {DateTime? sentAt});

  /// Fetches the full message using `BODY.PEEK[]` (never sets `\Seen`).
  Future<RemoteFetchedMessage?> uidFetchFullMessage(int uid);

  /// Fetches one MIME part with `BODY.PEEK[partId]`, returning decoded bytes.
  Future<Uint8List?> uidFetchAttachmentPart({
    required int uid,
    required String partId,
  });

  /// Adds or removes flags for [uid] on the currently selected folder.
  Future<void> uidStoreFlags({
    required int uid,
    required List<String> flags,
    required bool add,
  });

  Future<void> startIdle();

  Future<void> stopIdle();

  Future<void> noop();

  /// Must send IMAP DONE (if IDLE) + LOGOUT within [timeout] and always close
  /// the underlying TCP socket in `finally`.
  Future<void> logoutAndDisconnect({
    Duration timeout = const Duration(seconds: 3),
  });

  /// Immediate socket tear-down without waiting for server ACK.
  Future<void> forceClose();
}

/// Factory creating fresh [ImapSession] instances and resolving credentials.
abstract interface class ImapSessionFactory {
  ImapSession createSession();
}

typedef CredentialResolver = Future<ResolvedAccountCredential> Function(
  MailAccount account,
);
