import 'package:flutter/foundation.dart';

@immutable
class LocalCacheStats {
  const LocalCacheStats({
    required this.folders,
    required this.emails,
    required this.unread,
    this.lastSyncedAt,
  });

  final int folders;
  final int emails;
  final int unread;
  final DateTime? lastSyncedAt;
}
