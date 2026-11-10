// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:enough_mail/enough_mail.dart' hide MailAccount;
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../../core/constants/provider_presets.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/logging/sanitized_logger.dart';
import '../../../../core/network/imap_session.dart';
import '../../../auth/domain/entities/mail_account.dart';

/// Creates a fresh low-level `enough_mail` client for every socket.
///
/// Tests inject a fake [ImapClient] here; production always uses
/// [SanitizedImapClient] so wire logs cannot leak credentials to stdout.
typedef ImapClientFactory = ImapClient Function();

/// `enough_mail` logs protocol traffic with `print()` by default. This subclass
/// is the only place where raw IMAP wire text is allowed to leave the client,
/// and every line is first passed through [SanitizedLogger.sanitize].
class SanitizedImapClient extends ImapClient {
  SanitizedImapClient({
    required SanitizedLogger logger,
    super.isLogEnabled,
    super.logName,
    super.defaultWriteTimeout,
    super.defaultResponseTimeout,
  }) : _logger = logger;

  final SanitizedLogger _logger;

  @override
  void log(dynamic logObject, {bool isClient = true, String? initial}) {
    if (!isLogEnabled) return;
    final direction = initial ?? (isClient ? 'C' : 'S');
    _logger.debug(
      'ImapWire',
      SanitizedLogger.sanitize('$direction: $logObject'),
    );
  }
}

/// Real IMAP implementation backed by `enough_mail` 3.x.
///
/// Protocol invariants:
/// 1. Authentication happens immediately after the TLS connection is ready.
/// 2. NetEase (163 / 126 / yeah.net) receives RFC 2971 `ID` after auth and
///    **before** any `SELECT`, otherwise it answers `Unsafe Login`.
/// 3. IDLE is entered with `idleStart()` and left with `idleDone()`; no
///    deprecated `closeConnection()` call is used anywhere.
class EnoughMailImapSession implements ImapSession {
  EnoughMailImapSession({
    required ImapClient client,
    SanitizedLogger? logger,
    Duration commandTimeout = const Duration(seconds: 20),
  }) : _client = client,
       _logger = logger ?? SanitizedLogger.instance,
       _commandTimeout = commandTimeout;

  final ImapClient _client;
  final SanitizedLogger _logger;
  final Duration _commandTimeout;

  final StreamController<ImapInboxEvent> _eventsController =
      StreamController<ImapInboxEvent>.broadcast();

  StreamSubscription<ImapEvent>? _clientEventSub;
  bool _isIdle = false;
  bool _eventsClosed = false;
  bool _closed = false;
  String? _selectedFolder;
  RemoteMailboxStatus? _selectedStatus;
  MailAccount? _account;

  static const String _headerFetchDefinition =
      '(UID FLAGS INTERNALDATE RFC822.SIZE ENVELOPE BODYSTRUCTURE)';
  static const String _fullFetchDefinition =
      '(UID FLAGS INTERNALDATE RFC822.SIZE ENVELOPE BODYSTRUCTURE BODY.PEEK[])';

  @override
  bool get isConnected => _client.isConnected;

  @override
  bool get isIdle => _isIdle;

  @override
  bool get supportsIdle => _client.serverInfo.supportsIdle;

  @override
  String? get selectedFolder => _selectedFolder;

  @override
  Stream<ImapInboxEvent> get events => _eventsController.stream;

  @override
  Future<void> connectAndAuthenticate({
    required MailAccount account,
    required ResolvedAccountCredential credential,
  }) {
    return _guard(authType: account.authType, () async {
      _closed = false;
      _account = account;
      _logger.info(
        'ImapSession:${account.id}',
        'Connecting to ${account.imapHost}:${account.imapPort} '
            '(implicitTls=${account.imapImplicitTls})',
      );

      await _client
          .connectToServer(
            account.imapHost,
            account.imapPort,
            isSecure: account.imapImplicitTls,
          )
          .timeout(_commandTimeout);
      await _abortIfClosed();

      // Phase 2/3 review follow-up: custom IMAP accounts using port 143 /
      // STARTTLS must refresh capabilities and upgrade the socket BEFORE
      // sending any credential. Fail closed when STARTTLS is unavailable.
      if (!account.imapImplicitTls) {
        await _client.capability().timeout(_commandTimeout);
        await _abortIfClosed();
        if (!_client.serverInfo.supportsStartTls) {
          throw const ImapProtocolFailure(
            reason: ImapFailureReason.protocolError,
            userMessage:
                '服务器未声明 STARTTLS，已阻止在未加密连接上发送邮箱凭据。'
                '请改用隐式 TLS（通常端口 993）或联系邮箱服务商。',
          );
        }
        await _client.startTls().timeout(_commandTimeout);
        await _abortIfClosed();
        _logger.debug(
          'ImapSession:${account.id}',
          'STARTTLS upgrade completed before authentication',
        );
      }

      if (account.authType == MailAuthType.oauth2Pkce) {
        final oauth = credential;
        if (oauth is! OAuthCredential) {
          throw const AuthFailure(
            reason: AuthFailureReason.oauthRequired,
            userMessage: '该账户配置为 OAuth 2.0 登录，但未找到有效的访问令牌。',
          );
        }
        await _client
            .authenticateWithOAuth2(account.email, oauth.accessToken)
            .timeout(_commandTimeout);
      } else {
        final password = credential;
        if (password is! PasswordCredential) {
          throw const AuthFailure(
            reason: AuthFailureReason.authorizationCodeRequired,
            userMessage: '该账户配置为授权码登录，但未找到有效的授权码。',
          );
        }
        await _client
            .login(account.email, password.secret)
            .timeout(_commandTimeout);
      }
      await _abortIfClosed();

      // 163 / 126 / yeah.net protocol red line: RFC 2971 ID must be sent
      // after successful auth and before SELECT / LIST.
      if (account.preset.requiresImapIdCommand) {
        await _client.id(clientId: _buildClientId()).timeout(_commandTimeout);
        await _abortIfClosed();
        _logger.debug(
          'ImapSession:${account.id}',
          'RFC 2971 IMAP ID sent before mailbox selection',
        );
      }

      _logger.info(
        'ImapSession:${account.id}',
        'Authenticated; supportsIdle=${_client.serverInfo.supportsIdle}',
      );
      _attachClientEvents();
    });
  }

  @override
  Future<void> selectFolder(String remoteFolderName) async {
    await selectFolderWithStatus(remoteFolderName);
  }

  @override
  Future<RemoteMailboxStatus> selectFolderWithStatus(String remoteFolderName) {
    return _guard(authType: _account?.authType, () async {
      final Mailbox mailbox;
      if (remoteFolderName.toUpperCase() == 'INBOX') {
        mailbox = await _client.selectInbox().timeout(_commandTimeout);
      } else {
        mailbox = await _client
            .selectMailboxByPath(remoteFolderName)
            .timeout(_commandTimeout);
      }
      _selectedFolder = remoteFolderName;
      final status = RemoteMailboxStatus(
        remoteName: remoteFolderName,
        uidValidity: mailbox.uidValidity,
        uidNext: mailbox.uidNext,
        messagesExists: mailbox.messagesExists,
        messagesUnseen: mailbox.messagesUnseen,
        highestModSeq: mailbox.highestModSequence,
      );
      _selectedStatus = status;
      _logger.debug(
        'ImapSession:${_account?.id ?? "unknown"}',
        'SELECT $remoteFolderName ok (exists=${status.messagesExists}, '
            'unseen=${status.messagesUnseen})',
      );
      return status;
    });
  }

  @override
  Future<List<RemoteMailboxInfo>> listMailboxes() {
    return _guard(authType: _account?.authType, () async {
      final mailboxes = await _client
          .listMailboxes(recursive: true)
          .timeout(_commandTimeout);
      return mailboxes.map(_toRemoteMailbox).toList(growable: false);
    });
  }

  @override
  Future<List<RemoteFetchedMessage>> fetchMessageHeaders({int limit = 50}) {
    return _guard(authType: _account?.authType, () async {
      final status = _selectedStatus;
      if (status == null) {
        throw const ImapProtocolFailure(
          reason: ImapFailureReason.protocolError,
          userMessage: '尚未选择邮件文件夹，无法同步邮件头。',
        );
      }
      if (limit <= 0 || status.messagesExists <= 0) {
        return const <RemoteFetchedMessage>[];
      }

      final upper = status.messagesExists;
      final lower = math.max(1, upper - limit + 1);
      final result = await _client
          .fetchMessages(
            MessageSequence.fromRange(lower, upper),
            _headerFetchDefinition,
          )
          .timeout(_commandTimeout);
      return _mapFetchedMessages(result.messages, limit: limit);
    });
  }

  @override
  Future<List<RemoteFetchedMessage>> uidFetchMessageHeaders({
    required int fromUid,
    int? toUid,
    int limit = 0,
  }) {
    return _guard(authType: _account?.authType, () async {
      if (fromUid < 1 || limit < 0) {
        return const <RemoteFetchedMessage>[];
      }
      final sequence = toUid == null
          ? MessageSequence.fromRangeToLast(fromUid, isUidSequence: true)
          : MessageSequence.fromRange(fromUid, toUid, isUidSequence: true);
      final result = await _client
          .uidFetchMessages(sequence, _headerFetchDefinition)
          .timeout(_commandTimeout);
      return _mapFetchedMessages(result.messages, limit: limit);
    });
  }

  @override
  Future<List<RemoteFetchedMessage>> fetchOlderMessageHeaders({
    required int beforeUid,
    int limit = 200,
  }) {
    return _guard(authType: _account?.authType, () async {
      if (beforeUid <= 1 || limit <= 0) return <RemoteFetchedMessage>[];
      final result = await _client
          .uidSearchMessages(searchCriteria: 'UID 1:${beforeUid - 1}')
          .timeout(_commandTimeout);
      final uids =
          (result.matchingSequence?.toList() ?? <int>[])
              .where((uid) => uid > 0 && uid < beforeUid)
              .toList()
            ..sort();
      if (uids.isEmpty) return <RemoteFetchedMessage>[];
      final page = uids.length > limit
          ? uids.sublist(uids.length - limit)
          : uids;
      final fetched = await _client
          .uidFetchMessages(
            MessageSequence.fromIds(page, isUid: true),
            _headerFetchDefinition,
          )
          .timeout(_commandTimeout);
      return _mapFetchedMessages(
        fetched.messages
            .where((message) => page.contains(message.uid))
            .toList(),
        limit: limit,
      );
    });
  }

  @override
  Future<Map<int, List<String>>> uidFetchFlags(List<int> uids) {
    return _guard(authType: _account?.authType, () async {
      if (uids.isEmpty) return <int, List<String>>{};
      final result = await _client
          .uidFetchMessages(
            MessageSequence.fromIds(uids, isUid: true),
            '(UID FLAGS)',
          )
          .timeout(_commandTimeout);
      final requested = uids.toSet();
      return <int, List<String>>{
        for (final message in result.messages)
          if (message.uid != null && requested.contains(message.uid))
            message.uid!: List<String>.of(message.flags ?? const []),
      };
    });
  }

  @override
  Future<RemoteNewMailSearch> searchNewMailUids({required int fromUid}) {
    return _guard(authType: _account?.authType, () async {
      if (fromUid < 1) return const RemoteNewMailSearch.empty();
      final criteria = 'UID $fromUid:*';
      final all = await _client
          .uidSearchMessages(searchCriteria: criteria)
          .timeout(_commandTimeout);
      final unseen = await _client
          .uidSearchMessages(searchCriteria: '$criteria UNSEEN')
          .timeout(_commandTimeout);
      return RemoteNewMailSearch(
        allUids: List<int>.unmodifiable(
          all.matchingSequence?.toList() ?? const <int>[],
        ),
        unseenUids: List<int>.unmodifiable(
          unseen.matchingSequence?.toList() ?? const <int>[],
        ),
      );
    });
  }

  @override
  Future<bool> containsMessageId(String messageId) {
    return _guard(authType: _account?.authType, () async {
      if (messageId.isEmpty || messageId.contains(RegExp(r'[\r\n\u0000]'))) {
        throw const StorageFailure(userMessage: '邮件 Message-ID 无效，无法核对已发送副本。');
      }
      final escaped = messageId.replaceAll('\\', r'\\').replaceAll('"', r'\"');
      final result = await _client
          .uidSearchMessages(searchCriteria: 'HEADER Message-ID "$escaped"')
          .timeout(_commandTimeout);
      return result.matchingSequence?.toList().isNotEmpty ?? false;
    });
  }

  @override
  Future<void> appendSentMessage(String mimeText, {DateTime? sentAt}) {
    return _guard(authType: _account?.authType, () async {
      await _client
          .appendMessageText(
            mimeText,
            flags: const [r'\Seen'],
            internalDate: sentAt,
          )
          .timeout(_commandTimeout);
    });
  }

  @override
  Future<RemoteFetchedMessage?> uidFetchFullMessage(int uid) {
    return _guard(authType: _account?.authType, () async {
      final result = await _client
          .uidFetchMessages(
            MessageSequence.fromId(uid, isUid: true),
            _fullFetchDefinition,
          )
          .timeout(_commandTimeout);
      for (final message in result.messages) {
        if (message.uid == uid) {
          return _toRemoteMessage(message, includeBodies: true);
        }
      }
      return null;
    });
  }

  @override
  Future<Uint8List?> uidFetchAttachmentPart({
    required int uid,
    required String partId,
  }) {
    return _guard(authType: _account?.authType, () async {
      // Fetch-ids are dot-separated integers/TEXT tokens. Reject anything
      // that could be injected into the IMAP command line.
      if (!RegExp(r'^[0-9A-Za-z][0-9A-Za-z.]*$').hasMatch(partId)) {
        return null;
      }
      final result = await _client
          .uidFetchMessages(
            MessageSequence.fromId(uid, isUid: true),
            '(BODYSTRUCTURE BODY.PEEK[$partId])',
          )
          .timeout(_commandTimeout);
      MimeMessage? message;
      for (final candidate in result.messages) {
        if (candidate.uid == uid) {
          message = candidate;
          break;
        }
      }
      if (message == null) return null;

      final part = message.getPart(partId);
      if (part == null) return null;

      // BODYSTRUCTURE exposes the transfer encoding. Prefer the loaded part
      // header, then the body-structure child, so Base64/QP parts from Gmail /
      // QQ / 163 are decoded rather than saved as encoded text.
      final bodyPart = message.body?.getChildPart(partId);
      final transferEncoding =
          part.getHeaderValue('content-transfer-encoding') ??
          bodyPart?.encoding;
      final mimeData = part.mimeData;
      if (mimeData != null) {
        return mimeData.decodeBinary(transferEncoding);
      }

      final binary = part.decodeContentBinary();
      if (binary != null) return binary;

      final text = part.decodeContentText();
      return text == null ? null : Uint8List.fromList(utf8.encode(text));
    });
  }

  @override
  Future<void> uidStoreFlags({
    required int uid,
    required List<String> flags,
    required bool add,
  }) {
    return _guard(authType: _account?.authType, () async {
      if (flags.isEmpty) return;
      await _client
          .uidStore(
            MessageSequence.fromId(uid, isUid: true),
            flags,
            action: add ? StoreAction.add : StoreAction.remove,
            silent: true,
          )
          .timeout(_commandTimeout);
    });
  }

  @override
  Future<void> startIdle() {
    return _guard(authType: _account?.authType, () async {
      if (!_client.serverInfo.supportsIdle) {
        throw const ImapProtocolFailure(
          reason: ImapFailureReason.protocolError,
          userMessage: '服务器未声明 IMAP IDLE 能力，已切换为轮询模式。',
        );
      }
      await _client
          .idleStart(waitForContinuation: true)
          .timeout(_commandTimeout);
      _isIdle = true;
      _logger.debug('ImapSession:${_account?.id ?? "unknown"}', 'IDLE started');
    });
  }

  @override
  Future<void> stopIdle() async {
    if (!_isIdle) return;
    try {
      await _client.idleDone().timeout(_commandTimeout);
    } finally {
      _isIdle = false;
    }
  }

  @override
  Future<void> noop() {
    return _guard(
      authType: _account?.authType,
      () => _client.noop().timeout(_commandTimeout),
    );
  }

  @override
  Future<void> logoutAndDisconnect({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    _closed = true;
    try {
      if (_isIdle) {
        try {
          await _client.idleDone().timeout(timeout);
        } catch (_) {
          // DONE may fail if the server already dropped the socket; the
          // mandatory disconnect below still runs.
        } finally {
          _isIdle = false;
        }
      }

      if (_client.isConnected && _client.isLoggedIn) {
        try {
          await _client.logout().timeout(timeout);
          _logger.debug(
            'ImapSession:${_account?.id ?? "unknown"}',
            'LOGOUT completed',
          );
        } catch (e) {
          _logger.warn(
            'ImapSession:${_account?.id ?? "unknown"}',
            'LOGOUT failed; forcing socket close',
            e,
          );
        }
      }
    } finally {
      try {
        await _client.disconnect().timeout(timeout);
      } catch (e) {
        _logger.warn(
          'ImapSession:${_account?.id ?? "unknown"}',
          'disconnect() failed; socket is already gone',
          e,
        );
      }
      _selectedFolder = null;
      _selectedStatus = null;
      await _closeEvents();
    }
  }

  @override
  Future<void> forceClose() async {
    _closed = true;
    _isIdle = false;
    try {
      await _client.disconnect();
    } catch (_) {
      // Socket is already gone.
    } finally {
      _selectedFolder = null;
      _selectedStatus = null;
      await _closeEvents();
    }
  }

  RemoteMailboxInfo _toRemoteMailbox(Mailbox mailbox) {
    return RemoteMailboxInfo(
      remoteName: mailbox.path,
      displayName: mailbox.name,
      pathSeparator: mailbox.pathSeparator,
      attributes: mailbox.flags
          .map((flag) => flag.name)
          .toList(growable: false),
      uidValidity: mailbox.uidValidity,
      uidNext: mailbox.uidNext,
      messagesExists: mailbox.messagesExists,
      messagesUnseen: mailbox.messagesUnseen,
      highestModSeq: mailbox.highestModSequence,
      isSelectable: !mailbox.isNotSelectable && !mailbox.isVirtual,
    );
  }

  List<RemoteFetchedMessage> _mapFetchedMessages(
    List<MimeMessage> messages, {
    required int limit,
  }) {
    final mapped = <RemoteFetchedMessage>[];
    for (final message in messages) {
      if (message.uid == null) continue;
      mapped.add(_toRemoteMessage(message));
    }
    mapped.sort((a, b) => a.uid.compareTo(b.uid));
    if (limit > 0 && mapped.length > limit) {
      return mapped.sublist(mapped.length - limit);
    }
    return mapped;
  }

  RemoteFetchedMessage _toRemoteMessage(
    MimeMessage message, {
    bool includeBodies = false,
  }) {
    final envelope = message.envelope;
    final from = envelope?.from ?? message.from;
    final to = envelope?.to ?? message.to;
    final cc = envelope?.cc ?? message.cc;
    final fromEntry = (from != null && from.isNotEmpty) ? from.first : null;
    final sentAt =
        envelope?.date ??
        message.decodeDate() ??
        _decodeInternalDate(message.internalDate) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final plainBody = includeBodies ? message.decodeTextPlainPart() : null;
    final htmlBody = includeBodies ? message.decodeTextHtmlPart() : null;

    return RemoteFetchedMessage(
      uid: message.uid!,
      subject: message.decodeSubject() ?? envelope?.subject ?? '',
      fromName: fromEntry?.personalName ?? '',
      fromAddress: fromEntry?.email ?? '',
      toAddresses: _mapAddresses(to),
      ccAddresses: _mapAddresses(cc),
      messageId: envelope?.messageId ?? message.decodeHeaderValue('message-id'),
      sentAt: sentAt.toUtc(),
      flags: List<String>.unmodifiable(message.flags ?? const <String>[]),
      sizeBytes: message.size ?? 0,
      snippet: includeBodies ? _buildSnippet(plainBody, htmlBody) : '',
      plainBody: plainBody,
      htmlBody: htmlBody,
      attachments: List<RemoteAttachmentMeta>.unmodifiable(
        _extractAttachments(message),
      ),
    );
  }

  static List<RemoteMailAddress> _mapAddresses(List<MailAddress>? addresses) {
    if (addresses == null) return const [];
    final result = <RemoteMailAddress>[];
    for (final address in addresses) {
      final email = address.email.trim();
      if (email.isEmpty) continue;
      result.add(
        RemoteMailAddress(
          email: email,
          name: (address.personalName ?? '').trim(),
        ),
      );
    }
    return List<RemoteMailAddress>.unmodifiable(result);
  }

  List<RemoteAttachmentMeta> _extractAttachments(MimeMessage message) {
    final byPartId = <String, RemoteAttachmentMeta>{};

    void add(ContentInfo info, {required bool isInline}) {
      final partId = info.fetchId;
      if (partId.isEmpty ||
          partId.toUpperCase() == 'TEXT' ||
          byPartId.containsKey(partId)) {
        return;
      }

      final mimeType = info.mediaType?.text ?? 'application/octet-stream';
      if (isInline && (mimeType == 'text/plain' || mimeType == 'text/html')) {
        return;
      }

      final rawName = info.fileName?.trim();
      final bodyPart = message.body?.getChildPart(partId);
      byPartId[partId] = RemoteAttachmentMeta(
        partId: partId,
        filename: rawName == null || rawName.isEmpty
            ? 'attachment-$partId'
            : rawName,
        mimeType: mimeType,
        sizeBytes: info.size ?? bodyPart?.size ?? 0,
        contentId: _normalizeContentId(info.cid),
        isInline: isInline,
      );
    }

    for (final info in message.findContentInfo()) {
      add(info, isInline: false);
    }
    for (final info in message.findContentInfo(
      disposition: ContentDisposition.inline,
    )) {
      add(info, isInline: true);
    }

    return byPartId.values.toList(growable: false);
  }

  static String? _normalizeContentId(String? contentId) {
    if (contentId == null) return null;
    var value = contentId.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('<')) value = value.substring(1);
    if (value.endsWith('>')) value = value.substring(0, value.length - 1);
    value = value.trim();
    return value.isEmpty ? null : value;
  }

  static String _buildSnippet(String? plainBody, String? htmlBody) {
    var text = plainBody?.trim() ?? '';
    if (text.isEmpty && htmlBody != null && htmlBody.trim().isNotEmpty) {
      try {
        final document = html_parser.parse(htmlBody);
        text = document.body?.text ?? document.documentElement?.text ?? '';
      } catch (_) {
        text = htmlBody.replaceAll(RegExp('<[^>]+>'), ' ');
      }
    }
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > 180) {
      return '${text.substring(0, 180)}…';
    }
    return text;
  }

  static DateTime? _decodeInternalDate(String? text) {
    if (text == null || text.isEmpty) return null;
    return DateCodec.decodeDate(text) ?? DateTime.tryParse(text);
  }

  Future<void> _abortIfClosed() async {
    if (!_closed) return;
    try {
      await _client.disconnect();
    } catch (_) {
      // Socket is already gone.
    }
    throw const ImapProtocolFailure(
      reason: ImapFailureReason.connectionClosed,
      userMessage: '连接测试已超时或被取消，邮件连接已强制释放。',
    );
  }

  Id _buildClientId() {
    return Id(
      name: 'LocalMailClient',
      version: '1.0.0',
      vendor: 'LocalMailClient',
      os: kIsWeb ? 'web' : defaultTargetPlatform.name,
      supportUrl: 'local-only',
    );
  }

  void _attachClientEvents() {
    if (_clientEventSub != null) return;
    _clientEventSub = _client.eventStream.listen(
      (event) {
        if (_eventsClosed) return;
        switch (event) {
          case ImapMessagesExistEvent():
            _eventsController.add(
              ImapMailboxMessagesAdded(existsCount: event.newMessagesExists),
            );
          case ImapFetchEvent():
            _eventsController.add(const ImapMailboxFlagsUpdated());
          case ImapExpungeEvent():
          case ImapVanishedEvent():
            _eventsController.add(const ImapMailboxMessagesVanished());
          case ImapConnectionLostEvent():
            _isIdle = false;
            _eventsController.add(
              const ImapConnectionDropped('IMAP connection lost'),
            );
          default:
            break;
        }
      },
      onError: (Object error, StackTrace stack) {
        _isIdle = false;
        if (!_eventsClosed) {
          _eventsController.add(
            ImapConnectionDropped(SanitizedLogger.sanitize(error.toString())),
          );
        }
        _logger.warn(
          'ImapSession:${_account?.id ?? "unknown"}',
          'IMAP event stream error',
          error,
        );
      },
      onDone: () {
        _isIdle = false;
        if (!_eventsClosed) {
          _eventsController.add(const ImapConnectionDropped());
        }
      },
    );
  }

  Future<void> _closeEvents() async {
    if (_eventsClosed) return;
    _eventsClosed = true;
    final sub = _clientEventSub;
    _clientEventSub = null;
    if (sub != null) {
      try {
        await sub.cancel();
      } catch (_) {
        // Client already closed.
      }
    }
    try {
      await _eventsController.close();
    } catch (_) {
      // Already closed.
    }
  }

  Future<T> _guard<T>(
    Future<T> Function() action, {
    MailAuthType? authType,
  }) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } catch (e, st) {
      throw mapImapExceptionToFailure(e, stackTrace: st, authType: authType);
    }
  }
}

/// Factory used by `ConnectionPool` and `ImapConnectionTester`.
class EnoughMailImapSessionFactory implements ImapSessionFactory {
  EnoughMailImapSessionFactory({
    ImapClientFactory? clientFactory,
    SanitizedLogger? logger,
    Duration commandTimeout = const Duration(seconds: 20),
  }) : _logger = logger ?? SanitizedLogger.instance,
       _commandTimeout = commandTimeout,
       _clientFactory =
           clientFactory ??
           (() =>
               SanitizedImapClient(logger: logger ?? SanitizedLogger.instance));

  final ImapClientFactory _clientFactory;
  final SanitizedLogger _logger;
  final Duration _commandTimeout;

  @override
  ImapSession createSession() {
    return EnoughMailImapSession(
      client: _clientFactory(),
      logger: _logger,
      commandTimeout: _commandTimeout,
    );
  }
}

/// Translates `enough_mail` protocol errors into stable Chinese [AppFailure]s.
///
/// Matching is intentionally text-based because providers return non-standard
/// response codes; the original error is retained only as sanitized technical
/// detail and never contains credentials/tokens.
AppFailure mapImapExceptionToFailure(
  Object error, {
  StackTrace? stackTrace,
  MailAuthType? authType,
}) {
  final timeout = error is TimeoutException;
  final rawText = error is ImapException
      ? '${error.message ?? ''} ${error.details ?? ''}'
      : error.toString();
  final detail = SanitizedLogger.sanitize(rawText.trim());
  // Classify on the raw server text: sanitization deliberately removes the
  // very words ("LOGIN failed", "invalid credentials") needed for mapping.
  final text = rawText.toLowerCase();

  if (timeout || text.contains('timeout') || text.contains('timed out')) {
    return ImapProtocolFailure(
      reason: ImapFailureReason.timeout,
      userMessage: '连接邮件服务器超时，请检查网络、服务器地址、端口与加密方式。',
      technicalDetail: detail,
      cause: error,
    );
  }

  if (text.contains('unsafe login') || text.contains('unsafe_login')) {
    return ImapProtocolFailure(
      reason: ImapFailureReason.unsafeLoginMissingId,
      userMessage:
          '网易邮箱返回 Unsafe Login：服务端要求认证后立即发送 RFC 2971 IMAP ID。'
          '请确认已使用 163/126/yeah.net 预设并重试。',
      technicalDetail: detail,
      cause: error,
    );
  }

  if (text.contains('too many connections') ||
      text.contains('too many simultaneous') ||
      text.contains('maximum number of connections') ||
      text.contains('connection limit') ||
      text.contains('too many login') ||
      text.contains('concurrent')) {
    return ImapProtocolFailure(
      reason: ImapFailureReason.tooManyConnections,
      userMessage:
          '邮箱服务商限制了同时连接数（163 / QQ 等通常最多 5 个）。'
          '请先在其它邮件客户端中退出该邮箱，稍后再试。',
      technicalDetail: detail,
      cause: error,
    );
  }

  final imapDisabled =
      text.contains('imap') &&
      (text.contains('disabled') ||
          text.contains('not enabled') ||
          text.contains('not open') ||
          text.contains('enable imap') ||
          text.contains('not activated') ||
          text.contains('未开启'));
  if (imapDisabled) {
    return AuthFailure(
      reason: AuthFailureReason.imapDisabled,
      userMessage: '该邮箱尚未开启 IMAP 服务。请登录网页版邮箱设置，开启 IMAP/SMTP 后重试。',
      technicalDetail: detail,
      cause: error,
    );
  }

  final oauthRejected =
      authType == MailAuthType.oauth2Pkce ||
      text.contains('xoauth2') ||
      text.contains('oauth') ||
      text.contains('bearer');
  final authFailed =
      text.contains('authenticationfailed') ||
      text.contains('authentication failed') ||
      text.contains('authenticate failed') ||
      text.contains('login failed') ||
      text.contains('invalid credentials') ||
      text.contains('invalid username or password') ||
      text.contains('authorization failed') ||
      text.contains('auth failed');
  if (authFailed) {
    if (oauthRejected) {
      return AuthFailure(
        reason: AuthFailureReason.oauthTokenExpired,
        userMessage: 'OAuth 授权已被服务端拒绝或已过期，请重新授权该邮箱账户。',
        technicalDetail: detail,
        cause: error,
      );
    }
    return AuthFailure(
      reason: AuthFailureReason.invalidCredentials,
      userMessage:
          '认证失败：请确认邮箱地址正确，并使用客户端授权码（不是网页登录密码）；'
          '同时确认邮箱已开启 IMAP 服务。',
      technicalDetail: detail,
      cause: error,
    );
  }

  if (text.contains('connection closed') ||
      text.contains('connection lost') ||
      text.contains('connection reset') ||
      text.contains('broken pipe') ||
      text.contains('not connected') ||
      text.contains('socket')) {
    return ImapProtocolFailure(
      reason: ImapFailureReason.connectionClosed,
      userMessage: '与邮件服务器的连接已断开，请检查网络后重试。',
      technicalDetail: detail,
      cause: error,
    );
  }

  return ImapProtocolFailure(
    reason: ImapFailureReason.protocolError,
    userMessage: 'IMAP 协议交互失败，请检查服务器地址、端口与 SSL/TLS 配置。',
    technicalDetail: detail,
    cause: error,
  );
}
