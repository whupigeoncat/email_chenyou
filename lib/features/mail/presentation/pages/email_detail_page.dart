import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../app/theme/mail_theme.dart';
import '../../domain/entities/mail_attachment.dart';
import '../../domain/entities/outbox_message.dart';
import '../../domain/entities/unified_email.dart';
import '../../domain/services/verification_code_extractor.dart';
import '../providers/email_detail_provider.dart';
import '../providers/mail_providers.dart';
import '../widgets/attachment_preview_sheet.dart';
import '../widgets/safe_html_email_view.dart';
import 'compose_email_page.dart';

class EmailDetailPage extends ConsumerStatefulWidget {
  const EmailDetailPage({super.key, this.emailLocalId, this.embedded = false});

  final int? emailLocalId;
  final bool embedded;

  @override
  ConsumerState<EmailDetailPage> createState() => _EmailDetailPageState();
}

class _EmailDetailPageState extends ConsumerState<EmailDetailPage> {
  static const VerificationCodeExtractor _codeExtractor =
      VerificationCodeExtractor();

  final ScrollController _scrollController = ScrollController();
  bool _headerExpanded = false;

  int? _codeEmailId;
  String? _codeSubject;
  String? _codePlainBody;
  String? _codeHtmlBody;
  bool _codeBodyDownloaded = false;
  bool _codeComputed = false;
  String? _verificationCode;

  @override
  void initState() {
    super.initState();
    _openCurrent();
  }

  @override
  void didUpdateWidget(covariant EmailDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emailLocalId != widget.emailLocalId) {
      _headerExpanded = false;
      _scrollToTopAfterFrame();
      _openCurrent();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openCurrent() {
    final localId = widget.emailLocalId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Do not let a queued open from message A run after the page switched
      // to message B.
      if (!mounted || widget.emailLocalId != localId) return;
      ref.read(emailDetailProvider.notifier).open(localId);
    });
  }

  void _scrollToTopAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
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

    final content = emailAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('加载邮件失败：$error', textAlign: TextAlign.center),
        ),
      ),
      data: (email) => email == null
          ? const Center(child: Text('邮件已不存在或已被删除'))
          : _buildContent(context, email, detail, notifier),
    );

    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('邮件详情')),
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
    final verificationCode = _verificationCodeFor(email);
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderCard(
                email: email,
                expanded: _headerExpanded,
                onToggle: () =>
                    setState(() => _headerExpanded = !_headerExpanded),
              ),
              if (verificationCode != null) ...[
                const SizedBox(height: 12),
                _VerificationCodeCard(
                  code: verificationCode,
                  onCopy: () => _copyVerificationCode(
                    emailLocalId: email.localId,
                    code: verificationCode,
                  ),
                ),
              ],
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
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (hasHtml)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<EmailBodyViewMode>(
                            key: const Key('email-view-mode'),
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                            segments: const [
                              ButtonSegment(
                                value: EmailBodyViewMode.html,
                                label: Text('HTML'),
                                icon: Icon(Icons.html, size: 16),
                              ),
                              ButtonSegment(
                                value: EmailBodyViewMode.plain,
                                label: Text('纯文本'),
                                icon: Icon(
                                  Icons.text_snippet_outlined,
                                  size: 16,
                                ),
                              ),
                            ],
                            selected: {detail.viewMode},
                            onSelectionChanged: (value) =>
                                notifier.setViewMode(value.first),
                          ),
                        ),
                      ),
                    if (detail.isLoadingAttachments)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
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
                  // A new message must never inherit the previous message's
                  // renderer choice, link state or native WebView content.
                  key: ValueKey<String>(
                    'email-html-${email.localId ?? email.subject}',
                  ),
                  html: email.htmlBody!,
                  senderEmail: email.fromAddress,
                  allowRemoteImages: detail.allowRemoteImages,
                  trustedSender: detail.trustedSender,
                  cidToLocalPath: detail.cidLocalPaths,
                  onShowRemoteImages: notifier.allowRemoteImagesOnce,
                  onTrustSender: () =>
                      unawaited(notifier.trustSender(email.fromAddress)),
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
                for (final attachment in email.attachments.where(
                  (a) => !a.isInline,
                ))
                  _AttachmentTile(
                    attachment: attachment,
                    onTap: () => unawaited(_openAttachment(email, attachment)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Recomputes only when the message or its downloaded body actually changed.
  /// Snippet text is never used because a truncated number is not a code.
  String? _verificationCodeFor(UnifiedEmail email) {
    final plain = email.plainBody;
    final html = email.htmlBody;
    if (_codeComputed &&
        _codeEmailId == email.localId &&
        _codeSubject == email.subject &&
        _codePlainBody == plain &&
        _codeHtmlBody == html &&
        _codeBodyDownloaded == email.bodyDownloaded) {
      return _verificationCode;
    }

    _codeEmailId = email.localId;
    _codeSubject = email.subject;
    _codePlainBody = plain;
    _codeHtmlBody = html;
    _codeBodyDownloaded = email.bodyDownloaded;
    _codeComputed = true;
    _verificationCode = email.bodyDownloaded
        ? _codeExtractor.extract(
            subject: email.subject,
            plainBody: plain,
            htmlBody: html,
          )
        : null;
    return _verificationCode;
  }

  Future<void> _copyVerificationCode({
    required int? emailLocalId,
    required String code,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var copied = false;
    try {
      await Clipboard.setData(ClipboardData(text: code));
      copied = true;
    } on Object {
      // Never surface the code or the platform exception to logs or UI.
      copied = false;
    }
    // A copy started in message A must not surface feedback after the reader
    // has switched to message B.
    if (!mounted || widget.emailLocalId != emailLocalId) return;
    messenger?.showSnackBar(
      SnackBar(content: Text(copied ? '已复制验证码' : '复制失败，请长按验证码复制')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('邮件详情')),
      body: body,
    );
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
        borderRadius: BorderRadius.circular(MailShapes.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      email.subject.isEmpty ? '(无主题)' : email.subject,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: MailColors.muted(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                email.fromName.isEmpty
                    ? email.fromAddress
                    : '${email.fromName} <${email.fromAddress}>',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(email.sentAt.toLocal()),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: MailColors.muted(context)),
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

class _VerificationCodeCard extends StatelessWidget {
  const _VerificationCodeCard({required this.code, required this.onCopy});

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: const Key('verification-code-card'),
      margin: EdgeInsets.zero,
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '验证码',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    code,
                    key: const Key('verification-code-value'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filledTonal(
                key: const Key('copy-verification-code'),
                tooltip: '复制验证码',
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 20),
              ),
            ),
          ],
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
          maxLines: 2,
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
