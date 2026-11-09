import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/core_providers.dart';
import '../../domain/entities/mail_attachment.dart';
import '../../domain/entities/outbox_message.dart';
import '../../domain/entities/unified_email.dart';
import '../providers/email_detail_provider.dart';
import '../providers/mail_providers.dart';
import '../widgets/attachment_preview_sheet.dart';
import '../widgets/safe_html_email_view.dart';
import 'compose_email_page.dart';

class EmailDetailPage extends ConsumerStatefulWidget {
  const EmailDetailPage({
    super.key,
    this.emailLocalId,
    this.embedded = false,
  });

  final int? emailLocalId;
  final bool embedded;

  @override
  ConsumerState<EmailDetailPage> createState() => _EmailDetailPageState();
}

class _EmailDetailPageState extends ConsumerState<EmailDetailPage> {
  bool _headerExpanded = false;

  @override
  void initState() {
    super.initState();
    _openCurrent();
  }

  @override
  void didUpdateWidget(covariant EmailDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emailLocalId != widget.emailLocalId) {
      _openCurrent();
    }
  }

  void _openCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(emailDetailProvider.notifier).open(widget.emailLocalId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.emailLocalId;
    if (id == null) {
      return _empty(context, embedded: widget.embedded);
    }

    final emailAsync = ref.watch(emailByIdProvider(id));
    final detail = ref.watch(emailDetailProvider);
    final notifier = ref.read(emailDetailProvider.notifier);
    final email = emailAsync.value;

    final content = emailAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '加载邮件失败：$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (email) => email == null
          ? const Center(child: Text('邮件已不存在或已被删除'))
          : _buildContent(context, email, detail, notifier),
    );

    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text(email?.subject ?? '邮件详情')),
      body: SafeArea(child: content),
    );
  }

  Widget _buildContent(
    BuildContext context,
    UnifiedEmail email,
    EmailDetailState detail,
    EmailDetail notifier,
  ) {
    final hasHtml = email.htmlBody != null && email.htmlBody!.trim().isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(
            email: email,
            expanded: _headerExpanded,
            onToggle: () => setState(() => _headerExpanded = !_headerExpanded),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              OutlinedButton.icon(
                key: const Key('reply-mail'),
                onPressed: () => _openCompose(ComposeMode.reply, email),
                icon: const Icon(Icons.reply, size: 16),
                label: const Text('回复'),
              ),
              OutlinedButton.icon(
                key: const Key('reply-all-mail'),
                onPressed: () => _openCompose(ComposeMode.replyAll, email),
                icon: const Icon(Icons.reply_all, size: 16),
                label: const Text('全部回复'),
              ),
              OutlinedButton.icon(
                key: const Key('forward-mail'),
                onPressed: () => _openCompose(ComposeMode.forward, email),
                icon: const Icon(Icons.forward, size: 16),
                label: const Text('转发'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (hasHtml)
                SegmentedButton<EmailBodyViewMode>(
                  key: const Key('email-view-mode'),
                  segments: const [
                    ButtonSegment(
                      value: EmailBodyViewMode.html,
                      label: Text('HTML'),
                      icon: Icon(Icons.html, size: 16),
                    ),
                    ButtonSegment(
                      value: EmailBodyViewMode.plain,
                      label: Text('纯文本'),
                      icon: Icon(Icons.text_snippet_outlined, size: 16),
                    ),
                  ],
                  selected: {detail.viewMode},
                  onSelectionChanged: (value) =>
                      notifier.setViewMode(value.first),
                ),
              const Spacer(),
              if (detail.isLoadingAttachments)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (email.attachments.any(
            (attachment) =>
                attachment.isInline && attachment.contentId != null,
          ) &&
              detail.cidLocalPaths.length <
                  email.attachments
                      .where(
                        (attachment) =>
                            attachment.isInline &&
                            attachment.contentId != null,
                      )
                      .length)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('load-inline-images'),
                onPressed: detail.isLoadingAttachments
                    ? null
                    : notifier.downloadInlineAttachments,
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('加载内嵌图片'),
              ),
            ),
          if (detail.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                detail.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          if (detail.isLoadingBody && !email.bodyDownloaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasHtml && detail.viewMode == EmailBodyViewMode.html)
            SafeHtmlEmailView(
              html: email.htmlBody!,
              senderEmail: email.fromAddress,
              allowRemoteImages: detail.allowRemoteImages,
              trustedSender: detail.trustedSender,
              cidToLocalPath: detail.cidLocalPaths,
              onShowRemoteImages: notifier.allowRemoteImagesOnce,
              onTrustSender: () => unawaited(
                notifier.trustSender(email.fromAddress),
              ),
            )
          else
            SelectableText(
              (email.plainBody ?? email.snippet).trim().isEmpty
                  ? '(无正文)'
                  : (email.plainBody ?? email.snippet),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (email.attachments.where((a) => !a.isInline).isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('附件', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final attachment
                in email.attachments.where((a) => !a.isInline))
              _AttachmentTile(
                attachment: attachment,
                onTap: () => unawaited(_openAttachment(email, attachment)),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _openCompose(ComposeMode mode, UnifiedEmail email) async {
    final account = await ref
        .read(authRepositoryProvider)
        .getAccount(email.accountId);
    if (!mounted || account == null) return;
    ComposeDraft? draft;
    if (mode == ComposeMode.forward) {
      final factory = ref.read(composeDraftFactoryProvider);
      draft = await factory.forward(account: account, original: email);
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ComposeEmailPage(
          draft: draft,
          originEmail: draft == null ? email : null,
          account: account,
          mode: mode,
        ),
      ),
    );
  }

  Future<void> _openAttachment(
    UnifiedEmail email,
    MailAttachment attachment,
  ) async {
    final account = await ref
        .read(authRepositoryProvider)
        .getAccount(email.accountId);
    final localId = email.localId;
    if (!mounted || account == null || localId == null) return;
    await showAttachmentPreviewSheet(
      context: context,
      account: account,
      emailLocalId: localId,
      attachment: attachment,
    );
  }

  Widget _empty(BuildContext context, {required bool embedded}) {
    final body = const Center(child: Text('选择一封邮件开始阅读'));
    if (embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('邮件详情')), body: body);
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.email,
    required this.expanded,
    required this.onToggle,
  });

  final UnifiedEmail email;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      email.subject.isEmpty ? '(无主题)' : email.subject,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                email.fromName.isEmpty
                    ? email.fromAddress
                    : '${email.fromName} <${email.fromAddress}>',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(email.sentAt.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (expanded) ...[
                const Divider(height: 20),
                _RecipientsLine(label: '收件人', entries: email.toAddresses),
                if (email.ccAddresses.isNotEmpty)
                  _RecipientsLine(label: '抄送', entries: email.ccAddresses),
                const SizedBox(height: 4),
                Text(
                  '账户：${email.accountEmail}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipientsLine extends StatelessWidget {
  const _RecipientsLine({required this.label, required this.entries});

  final String label;
  final List<EmailAddressEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label：${entries.map((e) => e.displayLabel).join(', ')}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment, required this.onTap});

  final MailAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(
          attachment.isImage ? Icons.image_outlined : Icons.attach_file,
        ),
        title: Text(
          attachment.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${attachment.formattedSize}${attachment.isDownloaded ? ' · 已缓存' : ''}',
        ),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: onTap,
      ),
    );
  }
}
