import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../auth/domain/entities/mail_account.dart';
import 'unified_email.dart';

enum ComposeMode {
  newMail('newMail', '写邮件'),
  reply('reply', '回复'),
  replyAll('replyAll', '全部回复'),
  forward('forward', '转发');

  const ComposeMode(this.storageKey, this.labelZh);

  final String storageKey;
  final String labelZh;

  bool get isReply => this == reply || this == replyAll;

  static ComposeMode fromStorageKey(String key) {
    return ComposeMode.values.firstWhere(
      (value) => value.storageKey == key,
      orElse: () => ComposeMode.newMail,
    );
  }
}

enum OutboxStatus {
  draft('draft', '草稿'),
  queued('queued', '等待发送'),
  sending('sending', '发送中'),
  failed('failed', '发送失败'),
  uncertain('uncertain', '待确认'),
  sent('sent', '已发送');

  const OutboxStatus(this.storageKey, this.labelZh);

  final String storageKey;
  final String labelZh;

  static OutboxStatus fromStorageKey(String key) {
    return OutboxStatus.values.firstWhere(
      (value) => value.storageKey == key,
      orElse: () => OutboxStatus.draft,
    );
  }
}

@immutable
class OutgoingAttachment {
  const OutgoingAttachment({
    required this.fileName,
    required this.mimeType,
    required this.localPath,
    required this.sizeBytes,
  });

  final String fileName;
  final String mimeType;
  final String localPath;
  final int sizeBytes;

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'mimeType': mimeType,
        'localPath': localPath,
        'sizeBytes': sizeBytes,
      };

  factory OutgoingAttachment.fromJson(Map<String, dynamic> json) {
    return OutgoingAttachment(
      fileName: (json['fileName'] as String?) ?? 'attachment.bin',
      mimeType: (json['mimeType'] as String?) ?? 'application/octet-stream',
      localPath: (json['localPath'] as String?) ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OutgoingAttachment &&
        other.fileName == fileName &&
        other.mimeType == mimeType &&
        other.localPath == localPath &&
        other.sizeBytes == sizeBytes;
  }

  @override
  int get hashCode =>
      Object.hash(fileName, mimeType, localPath, sizeBytes);
}

@immutable
class OutgoingMailEnvelope {
  const OutgoingMailEnvelope({
    required this.fromEmail,
    required this.fromName,
    required this.to,
    required this.cc,
    required this.bcc,
    required this.subject,
    required this.plainBody,
    required this.attachments,
    this.htmlBody,
    this.inReplyTo,
    this.referencesHeader,
    this.messageId,
  });

  final String fromEmail;
  final String fromName;
  final List<EmailAddressEntry> to;
  final List<EmailAddressEntry> cc;
  final List<EmailAddressEntry> bcc;
  final String subject;
  final String plainBody;
  final String? htmlBody;
  final String? inReplyTo;
  final String? referencesHeader;

  /// Stable RFC 5322 Message-ID persisted with the outbox row so that a retry
  /// can never produce a second logical message with a different identity.
  final String? messageId;
  final List<OutgoingAttachment> attachments;

  List<EmailAddressEntry> get allRecipients => <EmailAddressEntry>[
        ...to,
        ...cc,
        ...bcc,
      ];

  static OutgoingMailEnvelope fromComposeDraft(
    ComposeDraft draft,
    MailAccount account, {
    String? messageId,
  }) {
    return OutgoingMailEnvelope(
      fromEmail: account.email,
      fromName: account.displayName,
      to: draft.to,
      cc: draft.cc,
      bcc: draft.bcc,
      subject: draft.subject,
      plainBody: draft.plainBody,
      htmlBody: draft.htmlBody,
      inReplyTo: draft.inReplyTo,
      referencesHeader: draft.referencesHeader,
      messageId: messageId,
      attachments: draft.attachments,
    );
  }
}

@immutable
class ComposeDraft {
  const ComposeDraft({
    required this.accountId,
    required this.mode,
    required this.to,
    required this.cc,
    required this.bcc,
    required this.subject,
    required this.plainBody,
    this.originEmailLocalId,
    this.inReplyTo,
    this.referencesHeader,
    this.htmlBody,
    this.attachments = const [],
    this.missingAttachmentCount = 0,
  });

  final String accountId;
  final ComposeMode mode;
  final int? originEmailLocalId;
  final String? inReplyTo;
  final String? referencesHeader;
  final List<EmailAddressEntry> to;
  final List<EmailAddressEntry> cc;
  final List<EmailAddressEntry> bcc;
  final String subject;
  final String plainBody;
  final String? htmlBody;
  final List<OutgoingAttachment> attachments;

  /// Forwarded remote attachments that have no local cache yet.
  final int missingAttachmentCount;

  ComposeDraft copyWith({
    String? accountId,
    ComposeMode? mode,
    int? originEmailLocalId,
    String? inReplyTo,
    String? referencesHeader,
    List<EmailAddressEntry>? to,
    List<EmailAddressEntry>? cc,
    List<EmailAddressEntry>? bcc,
    String? subject,
    String? plainBody,
    String? htmlBody,
    List<OutgoingAttachment>? attachments,
    int? missingAttachmentCount,
  }) {
    return ComposeDraft(
      accountId: accountId ?? this.accountId,
      mode: mode ?? this.mode,
      originEmailLocalId: originEmailLocalId ?? this.originEmailLocalId,
      inReplyTo: inReplyTo ?? this.inReplyTo,
      referencesHeader: referencesHeader ?? this.referencesHeader,
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      subject: subject ?? this.subject,
      plainBody: plainBody ?? this.plainBody,
      htmlBody: htmlBody ?? this.htmlBody,
      attachments: attachments ?? this.attachments,
      missingAttachmentCount:
          missingAttachmentCount ?? this.missingAttachmentCount,
    );
  }
}

@immutable
class OutboxMessage {
  const OutboxMessage({
    required this.id,
    required this.accountId,
    required this.mode,
    required this.to,
    required this.cc,
    required this.bcc,
    required this.subject,
    required this.plainBody,
    required this.attachments,
    required this.status,
    required this.retryCount,
    required this.retryable,
    required this.createdAt,
    required this.updatedAt,
    this.outgoingMessageId,
    this.originEmailLocalId,
    this.inReplyTo,
    this.referencesHeader,
    this.htmlBody,
    this.nextRetryAt,
    this.lastError,
    this.sentAt,
  });

  final String id;
  final String accountId;
  final ComposeMode mode;

  /// Persisted idempotency key used for the RFC 5322 `Message-ID` header.
  final String? outgoingMessageId;
  final int? originEmailLocalId;
  final String? inReplyTo;
  final String? referencesHeader;
  final List<EmailAddressEntry> to;
  final List<EmailAddressEntry> cc;
  final List<EmailAddressEntry> bcc;
  final String subject;
  final String plainBody;
  final String? htmlBody;
  final List<OutgoingAttachment> attachments;
  final OutboxStatus status;
  final int retryCount;
  final bool retryable;
  final DateTime? nextRetryAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? sentAt;

  bool get isDraft => status == OutboxStatus.draft;
  bool get isTerminal =>
      status == OutboxStatus.sent || status == OutboxStatus.uncertain;
  bool get canRetry => retryable && status == OutboxStatus.failed;
  bool get isUncertain => status == OutboxStatus.uncertain;

  ComposeDraft toComposeDraft() {
    return ComposeDraft(
      accountId: accountId,
      mode: mode,
      originEmailLocalId: originEmailLocalId,
      inReplyTo: inReplyTo,
      referencesHeader: referencesHeader,
      to: to,
      cc: cc,
      bcc: bcc,
      subject: subject,
      plainBody: plainBody,
      htmlBody: htmlBody,
      attachments: attachments,
    );
  }

  OutboxMessage copyWith({
    String? id,
    String? accountId,
    ComposeMode? mode,
    String? outgoingMessageId,
    int? originEmailLocalId,
    String? inReplyTo,
    String? referencesHeader,
    List<EmailAddressEntry>? to,
    List<EmailAddressEntry>? cc,
    List<EmailAddressEntry>? bcc,
    String? subject,
    String? plainBody,
    String? htmlBody,
    List<OutgoingAttachment>? attachments,
    OutboxStatus? status,
    int? retryCount,
    bool? retryable,
    DateTime? nextRetryAt,
    bool clearNextRetryAt = false,
    String? lastError,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? sentAt,
  }) {
    return OutboxMessage(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      mode: mode ?? this.mode,
      outgoingMessageId: outgoingMessageId ?? this.outgoingMessageId,
      originEmailLocalId: originEmailLocalId ?? this.originEmailLocalId,
      inReplyTo: inReplyTo ?? this.inReplyTo,
      referencesHeader: referencesHeader ?? this.referencesHeader,
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      subject: subject ?? this.subject,
      plainBody: plainBody ?? this.plainBody,
      htmlBody: htmlBody ?? this.htmlBody,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      retryable: retryable ?? this.retryable,
      nextRetryAt: clearNextRetryAt ? null : (nextRetryAt ?? this.nextRetryAt),
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sentAt: sentAt ?? this.sentAt,
    );
  }
}

@immutable
class OutboxCounts {
  const OutboxCounts({
    this.drafts = 0,
    this.queued = 0,
    this.sending = 0,
    this.failed = 0,
    this.uncertain = 0,
    this.sent = 0,
  });

  final int drafts;
  final int queued;
  final int sending;
  final int failed;
  final int uncertain;
  final int sent;

  int get pending => queued + sending + failed + uncertain;

  static OutboxCounts fromMessages(Iterable<OutboxMessage> messages) {
    var drafts = 0;
    var queued = 0;
    var sending = 0;
    var failed = 0;
    var uncertain = 0;
    var sent = 0;
    for (final message in messages) {
      switch (message.status) {
        case OutboxStatus.draft:
          drafts++;
        case OutboxStatus.queued:
          queued++;
        case OutboxStatus.sending:
          sending++;
        case OutboxStatus.failed:
          failed++;
        case OutboxStatus.uncertain:
          uncertain++;
        case OutboxStatus.sent:
          sent++;
      }
    }
    return OutboxCounts(
      drafts: drafts,
      queued: queued,
      sending: sending,
      failed: failed,
      uncertain: uncertain,
      sent: sent,
    );
  }
}

abstract final class OutboxCodec {
  static String encodeAddresses(List<EmailAddressEntry> entries) {
    return jsonEncode(entries.map((entry) => entry.toJson()).toList());
  }

  static List<EmailAddressEntry> decodeAddresses(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(EmailAddressEntry.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static String encodeAttachments(List<OutgoingAttachment> attachments) {
    return jsonEncode(attachments.map((item) => item.toJson()).toList());
  }

  static List<OutgoingAttachment> decodeAttachments(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(OutgoingAttachment.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
