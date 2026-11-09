// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/logging/sanitized_logger.dart';
import '../../domain/entities/outbox_message.dart';
import '../../domain/repositories/outbox_repository.dart';
import '../../domain/services/attachment_picker.dart';
import '../datasources/outbox_local_datasource.dart';

class OutboxRepositoryImpl implements OutboxRepository {
  OutboxRepositoryImpl({
    required OutboxLocalDataSource dataSource,
    AttachmentStore? attachmentStore,
    Uuid? uuid,
    DateTime Function()? clock,
    SanitizedLogger? logger,
  }) : _dataSource = dataSource,
       _attachmentStore = attachmentStore,
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now,
       _logger = logger ?? SanitizedLogger.instance;

  final OutboxLocalDataSource _dataSource;
  final AttachmentStore? _attachmentStore;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final SanitizedLogger _logger;

  @override
  Stream<List<OutboxMessage>> watchMessages({String? accountId}) {
    return _dataSource
        .watchMessages(accountId: accountId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<List<OutboxMessage>> watchDrafts({String? accountId}) {
    return watchMessages(accountId: accountId).map(
      (messages) => messages
          .where((message) => message.status == OutboxStatus.draft)
          .toList(growable: false),
    );
  }

  @override
  Stream<OutboxCounts> watchCounts({String? accountId}) {
    return watchMessages(accountId: accountId).map(OutboxCounts.fromMessages);
  }

  @override
  Future<List<OutboxMessage>> getMessages({
    String? accountId,
    Set<OutboxStatus>? statuses,
  }) async {
    final rows = await _dataSource.getMessages(
      accountId: accountId,
      statuses: statuses?.map((status) => status.storageKey).toSet(),
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<OutboxMessage?> getById(String id) async {
    final row = await _dataSource.getById(id);
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<OutboxMessage> saveDraft({
    required ComposeDraft draft,
    String? id,
  }) async {
    final now = _clock().toUtc().millisecondsSinceEpoch;
    final messageId = id ?? _uuid.v4();
    final existing = id == null ? null : await _dataSource.getById(id);
    if (existing != null) {
      final status = OutboxStatus.fromStorageKey(existing.status);
      if (status == OutboxStatus.sent ||
          status == OutboxStatus.sending ||
          status == OutboxStatus.uncertain) {
        throw StorageFailure(
          userMessage: switch (status) {
            OutboxStatus.sent => '该邮件已发送，不能再次修改或重复发送。',
            OutboxStatus.sending => '该邮件正在发送中，请等待发送结果。',
            OutboxStatus.uncertain => '该邮件投递状态待确认，请先到发件箱确认后再操作。',
            _ => '当前状态不允许修改该邮件。',
          },
        );
      }
    }
    if (existing == null) {
      await _dataSource.insert(
        DbOutboxMessagesCompanion.insert(
          id: messageId,
          accountId: draft.accountId,
          mode: draft.mode.storageKey,
          outgoingMessageId: Value(_newMessageId()),
          originEmailLocalId: Value(draft.originEmailLocalId),
          inReplyTo: Value(draft.inReplyTo),
          referencesHeader: Value(draft.referencesHeader),
          toRecipientsJson: OutboxCodec.encodeAddresses(draft.to),
          ccJson: OutboxCodec.encodeAddresses(draft.cc),
          bccJson: OutboxCodec.encodeAddresses(draft.bcc),
          subject: draft.subject,
          plainBody: draft.plainBody,
          htmlBody: Value(draft.htmlBody),
          attachmentsJson: OutboxCodec.encodeAttachments(draft.attachments),
          status: OutboxStatus.draft.storageKey,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await _dataSource.update(
        messageId,
        DbOutboxMessagesCompanion(
          accountId: Value(draft.accountId),
          mode: Value(draft.mode.storageKey),
          outgoingMessageId: Value(
            existing.outgoingMessageId ?? _newMessageId(),
          ),
          originEmailLocalId: Value(draft.originEmailLocalId),
          inReplyTo: Value(draft.inReplyTo),
          referencesHeader: Value(draft.referencesHeader),
          toRecipientsJson: Value(OutboxCodec.encodeAddresses(draft.to)),
          ccJson: Value(OutboxCodec.encodeAddresses(draft.cc)),
          bccJson: Value(OutboxCodec.encodeAddresses(draft.bcc)),
          subject: Value(draft.subject),
          plainBody: Value(draft.plainBody),
          htmlBody: Value(draft.htmlBody),
          attachmentsJson: Value(
            OutboxCodec.encodeAttachments(draft.attachments),
          ),
          status: Value(OutboxStatus.draft.storageKey),
          retryable: const Value(true),
          nextRetryAt: const Value(null),
          lastError: const Value(null),
          updatedAt: Value(now),
        ),
      );
      final oldAttachments = OutboxCodec.decodeAttachments(
        existing.attachmentsJson,
      );
      final keepPaths = draft.attachments.map((item) => item.localPath).toSet();
      await _attachmentStore?.cleanup(
        oldAttachments.where((item) => !keepPaths.contains(item.localPath)),
      );
    }
    return (await getById(messageId))!;
  }

  @override
  Future<void> enqueue(String id) async {
    final row = await _dataSource.getById(id);
    if (row == null) {
      throw const StorageFailure(userMessage: '邮件不存在或已被删除。');
    }
    final status = OutboxStatus.fromStorageKey(row.status);
    if (status == OutboxStatus.sent ||
        status == OutboxStatus.sending ||
        status == OutboxStatus.uncertain) {
      throw StorageFailure(
        userMessage: status == OutboxStatus.uncertain
            ? '该邮件投递状态待确认，请先人工确认是否重发。'
            : '当前邮件状态不允许重复发送。',
      );
    }
    await _dataSource.update(
      id,
      DbOutboxMessagesCompanion(
        status: Value(OutboxStatus.queued.storageKey),
        retryable: const Value(true),
        nextRetryAt: const Value(null),
        lastError: const Value(null),
        updatedAt: Value(_clock().toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<void> confirmResend(String id) async {
    final row = await _dataSource.getById(id);
    if (row == null) {
      throw const StorageFailure(userMessage: '邮件不存在或已被删除。');
    }
    final status = OutboxStatus.fromStorageKey(row.status);
    if (status == OutboxStatus.sent || status == OutboxStatus.sending) {
      throw const StorageFailure(userMessage: '当前邮件状态不允许重新发送。');
    }
    await _dataSource.update(
      id,
      DbOutboxMessagesCompanion(
        status: Value(OutboxStatus.queued.storageKey),
        retryable: const Value(true),
        nextRetryAt: const Value(null),
        lastError: const Value(null),
        updatedAt: Value(_clock().toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<bool> markSending(String id) async {
    final row = await _dataSource.getById(id);
    if (row == null) return false;
    final marked = await _dataSource.markSendingIfSendable(id);
    if (!marked) return false;
    if (row.outgoingMessageId == null) {
      await _dataSource.update(
        id,
        DbOutboxMessagesCompanion(outgoingMessageId: Value(_newMessageId())),
      );
    }
    return true;
  }

  @override
  Future<void> markQueued(String id) {
    return _dataSource.update(
      id,
      DbOutboxMessagesCompanion(
        status: Value(OutboxStatus.queued.storageKey),
        retryable: const Value(true),
        nextRetryAt: const Value(null),
        updatedAt: Value(_clock().toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<void> markSent(String id) async {
    final now = _clock().toUtc().millisecondsSinceEpoch;
    await _dataSource.update(
      id,
      DbOutboxMessagesCompanion(
        status: Value(OutboxStatus.sent.storageKey),
        retryable: const Value(false),
        nextRetryAt: const Value(null),
        lastError: const Value(null),
        updatedAt: Value(now),
        sentAt: Value(now),
      ),
    );
  }

  @override
  Future<void> recordSentCopy(
    String id, {
    required bool saved,
    String? error,
  }) async {
    final row = await _dataSource.getById(id);
    if (row == null || row.status != OutboxStatus.sent.storageKey) return;
    await _dataSource.update(
      id,
      DbOutboxMessagesCompanion(
        sentCopySaved: Value(saved),
        lastError: Value(
          error == null ? null : SanitizedLogger.sanitize(error),
        ),
      ),
    );
    if (saved) {
      await _attachmentStore?.cleanup(
        OutboxCodec.decodeAttachments(row.attachmentsJson),
      );
    }
  }

  @override
  Future<void> markFailed(
    String id, {
    required String error,
    required bool retryable,
    required int retryCount,
    DateTime? nextRetryAt,
  }) {
    return _dataSource.update(
      id,
      DbOutboxMessagesCompanion(
        status: Value(OutboxStatus.failed.storageKey),
        retryable: Value(retryable),
        retryCount: Value(retryCount),
        nextRetryAt: Value(nextRetryAt?.toUtc().millisecondsSinceEpoch),
        lastError: Value(SanitizedLogger.sanitize(error)),
        updatedAt: Value(_clock().toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<void> markUncertain(String id, {required String error}) {
    return _dataSource.update(
      id,
      DbOutboxMessagesCompanion(
        status: Value(OutboxStatus.uncertain.storageKey),
        retryable: const Value(false),
        nextRetryAt: const Value(null),
        lastError: Value(SanitizedLogger.sanitize(error)),
        updatedAt: Value(_clock().toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    final existing = await _dataSource.getById(id);
    if (existing != null &&
        OutboxStatus.fromStorageKey(existing.status) == OutboxStatus.sending) {
      throw const StorageFailure(userMessage: '邮件正在发送中，暂不可删除，请等待发送完成。');
    }

    final deleted = await _dataSource.deleteNonSending(id);
    if (deleted == 0) {
      final latest = await _dataSource.getById(id);
      if (latest != null &&
          OutboxStatus.fromStorageKey(latest.status) == OutboxStatus.sending) {
        throw const StorageFailure(userMessage: '邮件正在发送中，暂不可删除，请等待发送完成。');
      }
      return;
    }
    _logger.debug('OutboxRepository', 'Deleted outbox message $id');
    if (existing != null) {
      await _attachmentStore?.cleanup(
        OutboxCodec.decodeAttachments(existing.attachmentsJson),
      );
    }
  }

  @override
  Future<void> resetStuckSending() => _dataSource.resetStuckSending();

  String _newMessageId() => '<${_uuid.v4()}@local-mail.local>';

  @override
  Future<List<OutboxMessage>> getSendable() async {
    final rows = await _dataSource.getSendable();
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<List<OutboxMessage>> getRetryable() async {
    final rows = await _dataSource.getRetryable();
    return rows.map(_fromRow).toList(growable: false);
  }

  OutboxMessage _fromRow(DbOutboxMessage row) {
    return OutboxMessage(
      id: row.id,
      accountId: row.accountId,
      mode: ComposeMode.fromStorageKey(row.mode),
      outgoingMessageId: row.outgoingMessageId,
      originEmailLocalId: row.originEmailLocalId,
      inReplyTo: row.inReplyTo,
      referencesHeader: row.referencesHeader,
      to: OutboxCodec.decodeAddresses(row.toRecipientsJson),
      cc: OutboxCodec.decodeAddresses(row.ccJson),
      bcc: OutboxCodec.decodeAddresses(row.bccJson),
      subject: row.subject,
      plainBody: row.plainBody,
      htmlBody: row.htmlBody,
      attachments: OutboxCodec.decodeAttachments(row.attachmentsJson),
      status: OutboxStatus.fromStorageKey(row.status),
      retryCount: row.retryCount,
      retryable: row.retryable,
      nextRetryAt: row.nextRetryAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.nextRetryAt!, isUtc: true),
      lastError: row.lastError,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAt,
        isUtc: true,
      ),
      sentCopySaved: row.sentCopySaved,
      sentAt: row.sentAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.sentAt!, isUtc: true),
    );
  }
}
