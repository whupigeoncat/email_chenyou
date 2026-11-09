import 'package:flutter/foundation.dart';

enum FolderRole {
  inbox('inbox', '收件箱'),
  sent('sent', '已发送'),
  drafts('drafts', '草稿箱'),
  trash('trash', '已删除'),
  junk('junk', '垃圾邮件'),
  archive('archive', '归档'),
  custom('custom', '文件夹');

  const FolderRole(this.storageKey, this.labelZh);
  final String storageKey;
  final String labelZh;

  static FolderRole fromStorageKey(String key) {
    return FolderRole.values.firstWhere(
      (e) => e.storageKey == key,
      orElse: () => FolderRole.custom,
    );
  }
}

@immutable
class MailFolder {
  const MailFolder({
    required this.id,
    required this.accountId,
    required this.remoteName,
    required this.displayName,
    required this.role,
    this.uidValidity,
    this.highestModSeq,
    this.unreadCount = 0,
    this.lastSyncAt,
  });

  final String id;
  final String accountId;
  final String remoteName;
  final String displayName;
  final FolderRole role;
  final int? uidValidity;
  final int? highestModSeq;
  final int unreadCount;
  final DateTime? lastSyncAt;

  MailFolder copyWith({
    String? displayName,
    FolderRole? role,
    int? uidValidity,
    int? highestModSeq,
    int? unreadCount,
    DateTime? lastSyncAt,
  }) {
    return MailFolder(
      id: id,
      accountId: accountId,
      remoteName: remoteName,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      uidValidity: uidValidity ?? this.uidValidity,
      highestModSeq: highestModSeq ?? this.highestModSeq,
      unreadCount: unreadCount ?? this.unreadCount,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}
