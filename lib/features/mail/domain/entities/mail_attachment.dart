import 'package:flutter/foundation.dart';

@immutable
class MailAttachment {
  const MailAttachment({
    required this.id,
    required this.emailLocalId,
    required this.partId,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    this.contentId,
    this.localCachePath,
    this.isInline = false,
  });

  final String id;
  final int emailLocalId;
  final String partId;
  final String? contentId;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final String? localCachePath;
  final bool isInline;

  bool get isDownloaded => localCachePath != null && localCachePath!.isNotEmpty;

  bool get isImage => mimeType.toLowerCase().startsWith('image/');

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  MailAttachment copyWith({String? localCachePath}) {
    return MailAttachment(
      id: id,
      emailLocalId: emailLocalId,
      partId: partId,
      contentId: contentId,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      localCachePath: localCachePath ?? this.localCachePath,
      isInline: isInline,
    );
  }
}
