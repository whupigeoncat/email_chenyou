import 'package:flutter/foundation.dart';

import 'mail_attachment.dart';
import 'mail_folder.dart';

@immutable
class EmailAddressEntry {
  const EmailAddressEntry({required this.email, this.name = ''});

  final String name;
  final String email;

  String get displayLabel => name.isNotEmpty ? '$name <$email>' : email;

  Map<String, dynamic> toJson() => {'name': name, 'email': email};

  factory EmailAddressEntry.fromJson(Map<String, dynamic> json) {
    return EmailAddressEntry(
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
    );
  }
}

/// Unified domain entity representing a cached or synced email across all accounts.
@immutable
class UnifiedEmail {
  const UnifiedEmail({
    required this.accountId,
    required this.accountEmail,
    required this.accountDisplayName,
    required this.accountColorValue,
    required this.folderId,
    required this.folderRole,
    required this.uid,
    required this.subject,
    required this.fromName,
    required this.fromAddress,
    required this.toAddresses,
    required this.ccAddresses,
    required this.snippet,
    required this.sentAt,
    required this.isRead,
    required this.isFlagged,
    required this.isAnswered,
    required this.hasAttachments,
    required this.bodyDownloaded,
    this.localId,
    this.messageId,
    this.plainBody,
    this.htmlBody,
    this.attachments = const [],
  });

  final int? localId;
  final String accountId;
  final String accountEmail;
  final String accountDisplayName;
  final int accountColorValue;
  final String folderId;
  final FolderRole folderRole;
  final int uid;
  final String? messageId;
  final String subject;
  final String fromName;
  final String fromAddress;
  final List<EmailAddressEntry> toAddresses;
  final List<EmailAddressEntry> ccAddresses;
  final String snippet;
  final String? plainBody;
  final String? htmlBody;
  final DateTime sentAt;
  final bool isRead;
  final bool isFlagged;
  final bool isAnswered;
  final bool hasAttachments;
  final bool bodyDownloaded;
  final List<MailAttachment> attachments;

  String get senderDisplay => fromName.isNotEmpty ? fromName : fromAddress;

  static const int flagSeen = 1 << 0;
  static const int flagFlagged = 1 << 1;
  static const int flagAnswered = 1 << 2;

  int get flagsBitmask {
    var mask = 0;
    if (isRead) mask |= flagSeen;
    if (isFlagged) mask |= flagFlagged;
    if (isAnswered) mask |= flagAnswered;
    return mask;
  }

  UnifiedEmail copyWith({
    int? localId,
    String? plainBody,
    String? htmlBody,
    bool? isRead,
    bool? isFlagged,
    bool? isAnswered,
    bool? hasAttachments,
    bool? bodyDownloaded,
    List<MailAttachment>? attachments,
  }) {
    return UnifiedEmail(
      localId: localId ?? this.localId,
      accountId: accountId,
      accountEmail: accountEmail,
      accountDisplayName: accountDisplayName,
      accountColorValue: accountColorValue,
      folderId: folderId,
      folderRole: folderRole,
      uid: uid,
      messageId: messageId,
      subject: subject,
      fromName: fromName,
      fromAddress: fromAddress,
      toAddresses: toAddresses,
      ccAddresses: ccAddresses,
      snippet: snippet,
      plainBody: plainBody ?? this.plainBody,
      htmlBody: htmlBody ?? this.htmlBody,
      sentAt: sentAt,
      isRead: isRead ?? this.isRead,
      isFlagged: isFlagged ?? this.isFlagged,
      isAnswered: isAnswered ?? this.isAnswered,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      bodyDownloaded: bodyDownloaded ?? this.bodyDownloaded,
      attachments: attachments ?? this.attachments,
    );
  }
}
