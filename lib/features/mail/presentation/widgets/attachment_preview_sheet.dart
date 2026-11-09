import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../../auth/domain/entities/mail_account.dart';
import '../../domain/entities/mail_attachment.dart';
import '../providers/mail_providers.dart';

class AttachmentPreviewSheet extends ConsumerStatefulWidget {
  const AttachmentPreviewSheet({
    super.key,
    required this.account,
    required this.emailLocalId,
    required this.attachment,
    this.openFile,
  });

  final MailAccount account;
  final int emailLocalId;
  final MailAttachment attachment;

  /// Injectable system opener for tests.
  final Future<void> Function(String path)? openFile;

  @override
  ConsumerState<AttachmentPreviewSheet> createState() =>
      _AttachmentPreviewSheetState();
}

class _AttachmentPreviewSheetState
    extends ConsumerState<AttachmentPreviewSheet> {
  String? _path;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _download());
  }

  Future<void> _download() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path = await ref.read(downloadAttachmentUseCaseProvider).call(
            account: widget.account,
            emailLocalId: widget.emailLocalId,
            partId: widget.attachment.partId,
          );
      if (!mounted) return;
      setState(() {
        _path = path;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '附件下载失败：$error';
      });
    }
  }

  Future<void> _openWithSystem() async {
    final path = _path;
    if (path == null) return;
    try {
      final opener = widget.openFile;
      if (opener != null) {
        await opener(path);
      } else {
        final result = await OpenFilex.open(path);
        if (result.type != ResultType.done) {
          throw StateError(result.message);
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开附件：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    final isImage = attachment.mimeType.toLowerCase().startsWith('image/');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.attachment),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attachment.filename,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              '${attachment.mimeType} · ${attachment.formattedSize}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (isImage && _path != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 480),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Image.file(File(_path!), fit: BoxFit.contain),
                ),
              )
            else
              OutlinedButton.icon(
                key: const Key('open-attachment-external'),
                onPressed: _openWithSystem,
                icon: const Icon(Icons.open_in_new),
                label: const Text('使用系统应用打开'),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAttachmentPreviewSheet({
  required BuildContext context,
  required MailAccount account,
  required int emailLocalId,
  required MailAttachment attachment,
  Future<void> Function(String path)? openFile,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => AttachmentPreviewSheet(
      account: account,
      emailLocalId: emailLocalId,
      attachment: attachment,
      openFile: openFile,
    ),
  );
}
