import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../entities/outbox_message.dart';

class PickedAttachment {
  const PickedAttachment({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    this.mimeType = 'application/octet-stream',
  });

  final String path;
  final String fileName;
  final int sizeBytes;
  final String mimeType;
}

/// Test-injectable file picker port.
abstract interface class AttachmentPicker {
  Future<List<PickedAttachment>> pickAttachments();
}

class FilePickerAttachmentPicker implements AttachmentPicker {
  const FilePickerAttachmentPicker();

  @override
  Future<List<PickedAttachment>> pickAttachments() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    final result = <PickedAttachment>[];
    for (final file in files) {
      final path = file.path;
      if (path == null || path.isEmpty) continue;
      final length = file.lengthSync() ?? await file.length() ?? 0;
      result.add(
        PickedAttachment(
          path: path,
          fileName: p.basename(path),
          sizeBytes: length,
          mimeType: _guessMimeType(path),
        ),
      );
    }
    return result;
  }

  static String _guessMimeType(String path) {
    final extension = p.extension(path).toLowerCase();
    return switch (extension) {
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.pdf' => 'application/pdf',
      '.txt' => 'text/plain',
      '.zip' => 'application/zip',
      '.doc' => 'application/msword',
      '.docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls' => 'application/vnd.ms-excel',
      '.xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => 'application/octet-stream',
    };
  }
}

/// Copies picked files into a private outbox staging directory.
class AttachmentStore {
  AttachmentStore({
    Future<Directory> Function()? rootProvider,
    String Function()? idGenerator,
  })  : _rootProvider = rootProvider ?? _defaultRootProvider,
        _idGenerator = idGenerator ?? _defaultId;

  final Future<Directory> Function() _rootProvider;
  final String Function() _idGenerator;
  Directory? _cachedRoot;

  Future<OutgoingAttachment> stage(PickedAttachment source) async {
    final sourceFile = File(source.path);
    if (!sourceFile.existsSync()) {
      throw StateError('附件文件不存在：${source.path}');
    }
    try {
      final handle = sourceFile.openSync(mode: FileMode.read);
      handle.closeSync();
    } catch (_) {
      throw StateError('附件文件不可读取：${source.path}');
    }

    final root = await _ensureRoot();
    final targetDir = Directory(
      p.join(root.path, _idGenerator()),
    );
    targetDir.createSync(recursive: true);

    final safeName = sanitizeOutgoingFileName(source.fileName);
    final targetPath = p.normalize(p.join(targetDir.path, safeName));
    if (!p.isWithin(root.path, targetPath)) {
      throw StateError('拒绝将附件写出私有缓存目录');
    }
    sourceFile.copySync(targetPath);
    return OutgoingAttachment(
      fileName: safeName,
      mimeType: source.mimeType,
      localPath: targetPath,
      sizeBytes: File(targetPath).lengthSync(),
    );
  }

  Future<void> cleanup(Iterable<OutgoingAttachment> attachments) {
    return cleanupPaths(attachments.map((item) => item.localPath));
  }

  /// Removes staged files by absolute path. Resolves the root first so cleanup
  /// still works after a process restart (the in-memory cache is empty then).
  Future<void> cleanupPaths(Iterable<String> paths) async {
    final candidates = paths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (candidates.isEmpty) return;
    final root = await _ensureRoot();
    for (final path in candidates) {
      final normalized = p.normalize(path);
      if (!p.isWithin(root.path, normalized)) continue;
      try {
        final file = File(normalized);
        if (file.existsSync()) file.deleteSync();
        final parent = file.parent;
        if (parent.existsSync() &&
            p.isWithin(root.path, parent.path) &&
            parent.listSync().isEmpty) {
          parent.deleteSync(recursive: true);
        }
      } catch (_) {
        // Best-effort cleanup only.
      }
    }
  }

  Future<Directory> _ensureRoot() async {
    final cached = _cachedRoot;
    if (cached != null) return cached;
    final base = await _rootProvider();
    final root = Directory(p.join(base.path, 'mail_outbox_attachments'));
    root.createSync(recursive: true);
    _cachedRoot = root;
    return root;
  }

  static Future<Directory> _defaultRootProvider() async {
    // Persistent application-support directory: drafts and queued mail must
    // survive restarts, unlike the old system temp directory.
    return getApplicationSupportDirectory();
  }

  static String _defaultId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().hashCode}';
}

String sanitizeOutgoingFileName(String input) {
  var name = input.replaceAll('\\', '/');
  final lastSlash = name.lastIndexOf('/');
  if (lastSlash != -1) name = name.substring(lastSlash + 1);
  name = name.replaceAll(RegExp(r'[\u0000-\u001f<>:"|?*]'), '_').trim();
  name = name.replaceAll(RegExp(r'^\.+'), '');
  if (name.isEmpty || name == '.' || name == '..') return 'attachment.bin';
  if (name.length > 180) {
    final dot = name.lastIndexOf('.');
    final extension = dot > 0 && name.length - dot <= 10
        ? name.substring(dot)
        : '';
    return '${name.substring(0, 180 - extension.length)}$extension';
  }
  return name;
}
