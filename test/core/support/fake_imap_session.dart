import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';

/// In-memory [ImapSessionFactory] used by connection/lifecycle tests.
/// No sockets, no network, no real credentials.
class FakeImapSessionFactory implements ImapSessionFactory {
  FakeImapSessionFactory({
    this.connectDelay = Duration.zero,
    this.logoutDelay = Duration.zero,
    this.selectDelay = Duration.zero,
    List<RemoteMailboxInfo>? mailboxes,
    Map<String, RemoteMailboxStatus>? statuses,
    Map<String, List<RemoteFetchedMessage>>? headers,
    Map<int, RemoteFetchedMessage>? fullMessages,
    Map<String, Uint8List>? attachmentParts,
    this.failFlagStore = false,
    this.supportsIdle = true,
    this.failStartIdle = false,
    this.onConnected,
  }) : mailboxes = mailboxes ?? <RemoteMailboxInfo>[],
       statuses = statuses ?? <String, RemoteMailboxStatus>{},
       headers = headers ?? <String, List<RemoteFetchedMessage>>{},
       fullMessages = fullMessages ?? <int, RemoteFetchedMessage>{},
       attachmentParts = attachmentParts ?? <String, Uint8List>{};

  final Duration connectDelay;
  final Duration logoutDelay;
  Duration selectDelay;

  final List<FakeImapSession> sessions = <FakeImapSession>[];
  final List<String> protocolLog = <String>[];

  /// Controllable mailbox/header data shared by all sessions of this factory.
  List<RemoteMailboxInfo> mailboxes;
  Map<String, RemoteMailboxStatus> statuses;
  Map<String, List<RemoteFetchedMessage>> headers;
  Map<int, RemoteFetchedMessage> fullMessages;
  Map<String, Uint8List> attachmentParts;

  /// When set, `uidFetchMessageHeaders` returns exactly this list to emulate
  /// the RFC 3501 `fromUid:*` "last message echo" quirk.
  List<RemoteFetchedMessage>? uidFetchResponse;

  /// Overrides the UID-only background search when a test needs the `n:*`
  /// echo or a non-message count.
  RemoteNewMailSearch? newMailSearchResponse;

  Map<int, List<String>>? flagFetchResponse;
  final List<int> flagFetchBatchSizes = [];
  final Map<String, Set<String>> messageIdsByFolder = {};
  bool failAppend = false;
  bool failAfterAppend = false;
  int totalAppends = 0;
  String? lastAppendedMime;
  bool failFlagStore;
  final bool supportsIdle;
  final bool failStartIdle;
  final VoidCallback? onConnected;
  int _maxConcurrentActiveCount = 0;

  int listMailboxesCalls = 0;
  int fetchHeaderCalls = 0;
  int uidFetchHeaderCalls = 0;
  int newMailSearchCalls = 0;
  int uidFetchFullCalls = 0;
  int attachmentFetchCalls = 0;
  int flagStoreCalls = 0;
  int selectStatusCalls = 0;
  final List<(int uid, List<String> flags, bool add)> flagStores =
      <(int, List<String>, bool)>[];

  int get createdCount => sessions.length;
  int get activeCount =>
      sessions.where((session) => session.isConnected).length;
  int get maxConcurrentActiveCount => _maxConcurrentActiveCount;

  void recordActiveSnapshot() {
    final active = activeCount;
    if (active > _maxConcurrentActiveCount) {
      _maxConcurrentActiveCount = active;
    }
  }

  int get totalLogoutCount =>
      sessions.fold(0, (sum, session) => sum + session.logoutCount);
  int get totalForceCloseCount =>
      sessions.fold(0, (sum, session) => sum + session.forceCloseCount);

  @override
  ImapSession createSession() {
    final session = FakeImapSession._(
      this,
      sessions.length + 1,
      onConnected: onConnected,
    );
    sessions.add(session);
    protocolLog.add('create:${session.index}');
    return session;
  }
}

class FakeImapSession implements ImapSession {
  FakeImapSession._(this._factory, this.index, {this._onConnected});

  final FakeImapSessionFactory _factory;
  final int index;
  final VoidCallback? _onConnected;
  final StreamController<ImapInboxEvent> _events =
      StreamController<ImapInboxEvent>.broadcast();

  bool _connected = false;
  bool _idle = false;
  String? _selectedFolder;

  int connectCount = 0;
  int logoutCount = 0;
  int forceCloseCount = 0;
  int startIdleCount = 0;
  int stopIdleCount = 0;
  final List<String> selectedFolders = <String>[];

  @override
  bool get isConnected => _connected;

  @override
  bool get isIdle => _idle;

  @override
  bool get supportsIdle => _factory.supportsIdle;

  @override
  String? get selectedFolder => _selectedFolder;

  @override
  Stream<ImapInboxEvent> get events => _events.stream;

  void emit(ImapInboxEvent event) => _events.add(event);

  void emitError(Object error, [StackTrace? stackTrace]) =>
      _events.addError(error, stackTrace);

  @override
  Future<void> connectAndAuthenticate({
    required MailAccount account,
    required ResolvedAccountCredential credential,
  }) async {
    connectCount++;
    _factory.protocolLog.add('connect:$index');
    if (_factory.connectDelay > Duration.zero) {
      await Future<void>.delayed(_factory.connectDelay);
    }
    _connected = true;
    _factory.recordActiveSnapshot();
    _onConnected?.call();
  }

  @override
  Future<void> selectFolder(String remoteFolderName) async {
    await selectFolderWithStatus(remoteFolderName);
  }

  @override
  Future<RemoteMailboxStatus> selectFolderWithStatus(
    String remoteFolderName,
  ) async {
    selectedFolders.add(remoteFolderName);
    _selectedFolder = remoteFolderName;
    _factory.selectStatusCalls++;
    _factory.protocolLog.add('select:$index:$remoteFolderName');
    if (_factory.selectDelay > Duration.zero) {
      await Future<void>.delayed(_factory.selectDelay);
    }
    final status =
        _factory.statuses[remoteFolderName] ??
        RemoteMailboxStatus(
          remoteName: remoteFolderName,
          uidValidity: 1,
          uidNext: 1,
          messagesExists: _factory.headers[remoteFolderName]?.length ?? 0,
        );
    return status;
  }

  @override
  Future<List<RemoteMailboxInfo>> listMailboxes() async {
    _factory.listMailboxesCalls++;
    _factory.protocolLog.add('listMailboxes:$index');
    return List<RemoteMailboxInfo>.of(_factory.mailboxes);
  }

  @override
  Future<List<RemoteFetchedMessage>> fetchMessageHeaders({
    int limit = 50,
  }) async {
    _factory.fetchHeaderCalls++;
    final folder = _selectedFolder ?? 'INBOX';
    final messages = List<RemoteFetchedMessage>.of(
      _factory.headers[folder] ?? const <RemoteFetchedMessage>[],
    )..sort((a, b) => a.uid.compareTo(b.uid));
    if (messages.length <= limit) return messages;
    return messages.sublist(messages.length - limit);
  }

  @override
  Future<List<RemoteFetchedMessage>> uidFetchMessageHeaders({
    required int fromUid,
    int? toUid,
    int limit = 0,
  }) async {
    _factory.uidFetchHeaderCalls++;
    final override = _factory.uidFetchResponse;
    if (override != null) {
      return List<RemoteFetchedMessage>.of(override);
    }
    final folder = _selectedFolder ?? 'INBOX';
    final messages =
        (_factory.headers[folder] ?? const <RemoteFetchedMessage>[]).where((
          message,
        ) {
          if (message.uid < fromUid) return false;
          if (toUid != null && message.uid > toUid) return false;
          return true;
        }).toList()..sort((a, b) => a.uid.compareTo(b.uid));
    if (limit <= 0 || messages.length <= limit) return messages;
    return messages.sublist(messages.length - limit);
  }

  int appendCount = 0;
  Set<String> get sentMessageIds => _factory.messageIdsByFolder.putIfAbsent(
    _selectedFolder ?? 'INBOX',
    () => {},
  );
  String? appendedMime;

  @override
  Future<List<RemoteFetchedMessage>> fetchOlderMessageHeaders({
    required int beforeUid,
    int limit = 200,
  }) async {
    final messages =
        (_factory.headers[_selectedFolder ?? 'INBOX'] ??
                <RemoteFetchedMessage>[])
            .where((message) => message.uid < beforeUid)
            .toList()
          ..sort((a, b) => a.uid.compareTo(b.uid));
    return messages.length > limit
        ? messages.sublist(messages.length - limit)
        : messages;
  }

  @override
  Future<RemoteNewMailSearch> searchNewMailUids({required int fromUid}) async {
    _factory.newMailSearchCalls++;
    _factory.protocolLog.add('searchNewMail:$index:$fromUid');
    final override = _factory.newMailSearchResponse;
    if (override != null) return override;
    final folder = _selectedFolder ?? 'INBOX';
    final messages = _factory.headers[folder] ?? const <RemoteFetchedMessage>[];
    final all = <int>[
      for (final message in messages)
        if (message.uid >= fromUid) message.uid,
    ]..sort();
    final unseen = <int>[
      for (final message in messages)
        if (message.uid >= fromUid && !message.isSeen) message.uid,
    ]..sort();
    return RemoteNewMailSearch(
      allUids: List<int>.unmodifiable(all),
      unseenUids: List<int>.unmodifiable(unseen),
    );
  }

  @override
  Future<Map<int, List<String>>> uidFetchFlags(List<int> uids) async {
    _factory.flagFetchBatchSizes.add(uids.length);
    if (_factory.flagFetchResponse != null) {
      return {
        for (final uid in uids)
          if (_factory.flagFetchResponse!.containsKey(uid))
            uid: _factory.flagFetchResponse![uid]!,
      };
    }
    return {
      for (final message
          in _factory.headers[_selectedFolder ?? 'INBOX'] ??
              <RemoteFetchedMessage>[])
        if (uids.contains(message.uid)) message.uid: message.flags,
    };
  }

  @override
  Future<bool> containsMessageId(String messageId) async =>
      sentMessageIds.contains(messageId);

  @override
  Future<void> appendSentMessage(String mimeText, {DateTime? sentAt}) async {
    if (_factory.failAppend) throw StateError('simulated append failure');
    appendCount++;
    _factory.totalAppends++;
    appendedMime = mimeText;
    _factory.lastAppendedMime = mimeText;
    final id = RegExp(
      r'^Message-ID:\s*(.+)$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(mimeText)?.group(1)?.trim();
    if (id != null) sentMessageIds.add(id);
    if (_factory.failAfterAppend) {
      throw StateError('simulated lost APPEND acknowledgement');
    }
  }

  @override
  Future<RemoteFetchedMessage?> uidFetchFullMessage(int uid) async {
    _factory.uidFetchFullCalls++;
    final direct = _factory.fullMessages[uid];
    if (direct != null) return direct;
    for (final messages in _factory.headers.values) {
      for (final message in messages) {
        if (message.uid == uid) return message;
      }
    }
    return null;
  }

  @override
  Future<Uint8List?> uidFetchAttachmentPart({
    required int uid,
    required String partId,
  }) async {
    _factory.attachmentFetchCalls++;
    return _factory.attachmentParts['$uid:$partId'] ??
        _factory.attachmentParts[partId];
  }

  @override
  Future<void> uidStoreFlags({
    required int uid,
    required List<String> flags,
    required bool add,
  }) async {
    _factory.flagStoreCalls++;
    _factory.flagStores.add((uid, List<String>.of(flags), add));
    _factory.protocolLog.add(
      'flags:$index:$uid:${add ? '+' : '-'}:${flags.join(",")}',
    );
    if (_factory.failFlagStore) {
      throw StateError('simulated remote flag store failure');
    }
  }

  @override
  Future<void> startIdle() async {
    startIdleCount++;
    if (!_factory.supportsIdle || _factory.failStartIdle) {
      throw StateError('simulated IDLE failure');
    }
    _idle = true;
    _factory.protocolLog.add('idle:$index');
  }

  @override
  Future<void> stopIdle() async {
    stopIdleCount++;
    _idle = false;
  }

  @override
  Future<void> noop() async {}

  @override
  Future<void> logoutAndDisconnect({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!_connected) return;
    _factory.protocolLog.add('logout:$index');
    if (_factory.logoutDelay > Duration.zero) {
      await Future<void>.delayed(_factory.logoutDelay);
    }
    logoutCount++;
    _connected = false;
    _idle = false;
    _selectedFolder = null;
  }

  @override
  Future<void> forceClose() async {
    if (!_connected) return;
    forceCloseCount++;
    _factory.protocolLog.add('forceClose:$index');
    _connected = false;
    _idle = false;
    _selectedFolder = null;
  }
}

MailAccount buildTestAccount({
  String id = 'acc-1',
  String email = 'alice@gmail.com',
}) {
  final preset = ProviderPresets.inferFromEmail(email);
  return MailAccount(
    id: id,
    email: email,
    displayName: id,
    providerType: preset.type,
    authType: MailAuthType.passwordOrAuthCode,
    colorValue: preset.defaultColorValue,
    imapHost: preset.imapHost,
    imapPort: preset.imapPort,
    imapImplicitTls: preset.imapImplicitTls,
    smtpHost: preset.smtpHost,
    smtpPort: preset.smtpPort,
    smtpImplicitTls: preset.smtpImplicitTls,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Future<ResolvedAccountCredential> fakeCredentialResolver(
  MailAccount account,
) async {
  return const PasswordCredential('fake-secret');
}
