import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/mail_account.dart';
import '../../domain/entities/outbox_message.dart';
import '../../domain/entities/unified_email.dart';
import '../../domain/services/attachment_picker.dart';
import '../../domain/services/compose_draft_factory.dart';
import '../../domain/usecases/outbox_usecases.dart';
import '../providers/mail_providers.dart';
import '../widgets/account_color_badge.dart';
import '../services/compose_route_guard.dart';

enum _ComposeViewMode { plain, html }

enum _CloseAction { save, discard, continueEditing }

class ComposeEmailPage extends ConsumerStatefulWidget {
  const ComposeEmailPage({
    super.key,
    this.draft,
    this.account,
    this.draftId,
    this.originEmail,
    this.mode = ComposeMode.newMail,
  });

  final ComposeDraft? draft;
  final MailAccount? account;
  final String? draftId;
  final UnifiedEmail? originEmail;
  final ComposeMode mode;

  @override
  ConsumerState<ComposeEmailPage> createState() => _ComposeEmailPageState();
}

class _ComposeEmailPageState extends ConsumerState<ComposeEmailPage> {
  late ComposeDraft _initialDraft;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _plainController = TextEditingController();
  final TextEditingController _htmlController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _ccController = TextEditingController();
  final TextEditingController _bccController = TextEditingController();
  final List<EmailAddressEntry> _to = <EmailAddressEntry>[];
  final List<EmailAddressEntry> _cc = <EmailAddressEntry>[];
  final List<EmailAddressEntry> _bcc = <EmailAddressEntry>[];
  final List<OutgoingAttachment> _attachments = <OutgoingAttachment>[];
  final Set<String> _persistedAttachmentPaths = <String>{};

  String? _selectedAccountId;
  String? _draftId;
  Future<void>? _stagingFuture;
  bool _stagingInProgress = false;
  _ComposeViewMode _viewMode = _ComposeViewMode.plain;
  bool _dirty = false;
  bool _saving = false;
  bool _sending = false;
  String? _error;
  String? _recipientError;
  final Object _routeGuardToken = Object();

  bool get _busy => _saving || _sending;

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId;
    final factory = ComposeDraftFactory();
    _initialDraft =
        widget.draft ??
        (widget.originEmail != null && widget.account != null
            ? switch (widget.mode) {
                ComposeMode.reply => factory.reply(
                  account: widget.account!,
                  original: widget.originEmail!,
                ),
                ComposeMode.replyAll => factory.reply(
                  account: widget.account!,
                  original: widget.originEmail!,
                  replyAll: true,
                ),
                ComposeMode.forward => factory.forwardShell(
                  account: widget.account!,
                  original: widget.originEmail!,
                ),
                ComposeMode.newMail => factory.newMail(
                  account: widget.account!,
                ),
              }
            : widget.account != null
            ? factory.newMail(account: widget.account!)
            : const ComposeDraft(
                accountId: '',
                mode: ComposeMode.newMail,
                to: [],
                cc: [],
                bcc: [],
                subject: '',
                plainBody: '',
              ));
    _selectedAccountId = _initialDraft.accountId.isEmpty
        ? widget.account?.id
        : _initialDraft.accountId;
    _subjectController.text = _initialDraft.subject;
    _plainController.text = _initialDraft.plainBody;
    _to.addAll(_initialDraft.to);
    _cc.addAll(_initialDraft.cc);
    _bcc.addAll(_initialDraft.bcc);
    _attachments.addAll(_initialDraft.attachments);
    if (widget.draftId != null && widget.draft != null) {
      _persistedAttachmentPaths.addAll(
        widget.draft!.attachments.map((item) => item.localPath),
      );
    }
    _htmlController.text = _initialDraft.htmlBody ?? '';
    if (_htmlController.text.isNotEmpty) _viewMode = _ComposeViewMode.html;
    _subjectController.addListener(_markDirty);
    _plainController.addListener(_markDirty);
    _htmlController.addListener(_markDirty);
    // Unsubmitted recipient text is also unsaved work.
    _toController.addListener(_markDirty);
    _ccController.addListener(_markDirty);
    _bccController.addListener(_markDirty);
    if (widget.draft == null &&
        widget.originEmail != null &&
        _initialDraft.mode == ComposeMode.forward) {
      _stagingInProgress = true;
      _stagingFuture = _stageForwardAttachments();
    }
  }

  @override
  void dispose() {
    ComposeRouteGuard.remove(_routeGuardToken);
    _subjectController.dispose();
    _plainController.dispose();
    _htmlController.dispose();
    _toController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final accountList = accounts.value ?? const <MailAccount>[];
    final selectedAccount = _findAccount(accountList);
    ComposeRouteGuard.setBlocking(
      _routeGuardToken,
      _dirty || _busy || _stagingInProgress,
    );

    return PopScope(
      canPop: !_dirty && !_busy && !_stagingInProgress,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _busy) return;
        await _awaitStaging();
        if (!mounted || _busy || _stagingInProgress) return;
        if (!_dirty) {
          await _cleanupUnpersistedAttachments();
          if (!context.mounted) return;
          Navigator.of(context).pop();
          return;
        }
        final action = await _askCloseAction();
        if (!mounted || _busy) return;
        await _handleCloseAction(action, selectedAccount);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('compose-close'),
            tooltip: '关闭',
            onPressed: _busy ? null : _requestClose,
            icon: const Icon(Icons.close),
          ),
          title: Text(switch (_initialDraft.mode) {
            ComposeMode.newMail => '写邮件',
            ComposeMode.reply => '回复',
            ComposeMode.replyAll => '全部回复',
            ComposeMode.forward => '转发',
          }),
          actions: [
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (widget.draft == null && widget.originEmail != null)
                MaterialBanner(
                  content: Text(
                    _initialDraft.mode == ComposeMode.forward
                        ? '转发邮件已填入原邮件内容。'
                        : '回复内容已填入原邮件引用。',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => _error = null),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              if (_initialDraft.missingAttachmentCount > 0)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    '有 ${_initialDraft.missingAttachmentCount} 个原邮件附件尚未缓存，'
                    '请在原邮件详情中下载后再转发。',
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _buildAccountRow(context, accountList, selectedAccount),
                    const SizedBox(height: 10),
                    _RecipientField(
                      key: const Key('compose-to'),
                      fieldKey: const Key('compose-to-input'),
                      label: '收件人',
                      entries: _to,
                      controller: _toController,
                      onAdd: (entry) => setState(() {
                        _to.add(entry);
                        _dirty = true;
                      }),
                      onRemove: (entry) => setState(() {
                        _to.remove(entry);
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _RecipientField(
                      key: const Key('compose-cc'),
                      fieldKey: const Key('compose-cc-input'),
                      label: '抄送',
                      entries: _cc,
                      controller: _ccController,
                      onAdd: (entry) => setState(() {
                        _cc.add(entry);
                        _dirty = true;
                      }),
                      onRemove: (entry) => setState(() {
                        _cc.remove(entry);
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _RecipientField(
                      key: const Key('compose-bcc'),
                      fieldKey: const Key('compose-bcc-input'),
                      label: '密送',
                      entries: _bcc,
                      controller: _bccController,
                      onAdd: (entry) => setState(() {
                        _bcc.add(entry);
                        _dirty = true;
                      }),
                      onRemove: (entry) => setState(() {
                        _bcc.remove(entry);
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('compose-subject'),
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: '主题',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SegmentedButton<_ComposeViewMode>(
                          key: const Key('compose-view-mode'),
                          segments: const [
                            ButtonSegment(
                              value: _ComposeViewMode.plain,
                              label: Text('纯文本'),
                            ),
                            ButtonSegment(
                              value: _ComposeViewMode.html,
                              label: Text('富文本'),
                            ),
                          ],
                          selected: {_viewMode},
                          onSelectionChanged: (value) {
                            setState(() {
                              _viewMode = value.first;
                              if (_viewMode == _ComposeViewMode.html &&
                                  _htmlController.text.isEmpty) {
                                _htmlController.text = _plainToHtml(
                                  _plainController.text,
                                );
                              }
                            });
                          },
                        ),
                        IconButton(
                          key: const Key('compose-attach'),
                          tooltip: '添加附件',
                          onPressed: _busy ? null : _pickAttachments,
                          icon: const Icon(Icons.attach_file),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildToolbar(context),
                    const SizedBox(height: 6),
                    if (_viewMode == _ComposeViewMode.plain)
                      TextField(
                        key: const Key('compose-body'),
                        controller: _plainController,
                        minLines: 10,
                        maxLines: 20,
                        decoration: const InputDecoration(
                          labelText: '正文',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      )
                    else
                      TextField(
                        key: const Key('compose-body'),
                        controller: _htmlController,
                        minLines: 10,
                        maxLines: 20,
                        decoration: const InputDecoration(
                          labelText: 'HTML 正文',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('附件', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      for (final attachment in _attachments)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.attach_file),
                          title: Text(
                            attachment.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(_formatBytes(attachment.sizeBytes)),
                          trailing: IconButton(
                            key: Key(
                              'remove-attachment-${attachment.fileName}',
                            ),
                            icon: const Icon(Icons.close),
                            onPressed: _busy
                                ? null
                                : () => _removeAttachment(attachment),
                          ),
                        ),
                    ],
                    if (_recipientError != null || _error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _recipientError ?? _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_recipientError != null || _error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      _recipientError ?? _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('compose-save-draft'),
                        onPressed: _busy ? null : _saveDraft,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('存草稿'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('compose-send'),
                        onPressed: _busy ? null : _send,
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('发送'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountRow(
    BuildContext context,
    List<MailAccount> accounts,
    MailAccount? selected,
  ) {
    return Row(
      children: [
        AccountColorBadge(
          colorValue: selected?.colorValue ?? 0xFF0F766E,
          size: 12,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: accounts.isEmpty
              ? Text(
                  widget.account == null ? '没有可用发件账户' : widget.account!.email,
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              : DropdownButtonFormField<String>(
                  key: const Key('compose-account'),
                  isExpanded: true,
                  initialValue: selected?.id,
                  decoration: const InputDecoration(
                    labelText: '发件账户',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          account.email,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                          _selectedAccountId = value;
                          _dirty = true;
                        }),
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Wrap(
      spacing: 2,
      children: [
        IconButton(
          key: const Key('compose-bold'),
          tooltip: '加粗',
          onPressed: _busy ? null : () => _insertFormat('**', '**'),
          icon: const Icon(Icons.format_bold),
        ),
        IconButton(
          key: const Key('compose-italic'),
          tooltip: '斜体',
          onPressed: _busy ? null : () => _insertFormat('_', '_'),
          icon: const Icon(Icons.format_italic),
        ),
        IconButton(
          key: const Key('compose-list'),
          tooltip: '列表',
          onPressed: _busy ? null : () => _insertFormat('\n- ', '\n'),
          icon: const Icon(Icons.format_list_bulleted),
        ),
        IconButton(
          key: const Key('compose-quote'),
          tooltip: '引用',
          onPressed: _busy ? null : () => _insertFormat('\n> ', '\n'),
          icon: const Icon(Icons.format_quote),
        ),
      ],
    );
  }

  void _insertFormat(String open, String close) {
    final controller = _viewMode == _ComposeViewMode.html
        ? _htmlController
        : _plainController;
    final selection = controller.selection;
    final text = controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selected = text.substring(start, end);
    final inserted = '$open$selected$close';
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, inserted),
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
    _markDirty();
  }

  /// Fallback for direct construction of a forward page: copy cached received
  /// attachments into the outbox staging directory before they can be sent.
  Future<void> _stageForwardAttachments() async {
    try {
      final origin = widget.originEmail;
      if (origin == null) return;
      final store = ref.read(attachmentStoreProvider);
      final staged = <OutgoingAttachment>[];
      var failed = 0;
      for (final attachment in origin.attachments) {
        final path = attachment.localCachePath;
        if (path == null || path.isEmpty) continue;
        try {
          staged.add(
            await store.stage(
              PickedAttachment(
                path: path,
                fileName: attachment.filename,
                sizeBytes: attachment.sizeBytes,
                mimeType: attachment.mimeType,
              ),
            ),
          );
        } catch (_) {
          failed++;
        }
      }
      if (!mounted || (staged.isEmpty && failed == 0)) return;
      setState(() {
        _attachments.addAll(staged);
        if (staged.isNotEmpty) _dirty = true;
        _initialDraft = _initialDraft.copyWith(
          attachments: List<OutgoingAttachment>.unmodifiable(_attachments),
          missingAttachmentCount: _initialDraft.missingAttachmentCount + failed,
        );
      });
    } finally {
      _stagingInProgress = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _awaitStaging() async {
    final staging = _stagingFuture;
    if (staging != null) await staging;
  }

  Future<void> _cleanupUnpersistedAttachments() {
    return ref
        .read(attachmentStoreProvider)
        .cleanup(
          _attachments.where(
            (item) => !_persistedAttachmentPaths.contains(item.localPath),
          ),
        );
  }

  Future<void> _pickAttachments() async {
    try {
      final picked = await ref.read(attachmentPickerProvider).pickAttachments();
      if (picked.isEmpty) return;
      final store = ref.read(attachmentStoreProvider);
      for (final item in picked) {
        final staged = await store.stage(item);
        if (!mounted) return;
        setState(() {
          _attachments.add(staged);
          _dirty = true;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '选择附件失败：$error');
    }
  }

  Future<void> _removeAttachment(OutgoingAttachment attachment) async {
    final persisted = _persistedAttachmentPaths.contains(attachment.localPath);
    setState(() {
      _attachments.remove(attachment);
      _dirty = true;
    });
    // Persisted attachments belong to the DB row. Only discard them after a
    // successful save/send; deleting now would corrupt a saved draft if the
    // user later chooses "discard changes".
    if (!persisted) {
      await ref.read(attachmentStoreProvider).cleanup([attachment]);
    }
  }

  void _rememberPersistedAttachments(Iterable<OutgoingAttachment> items) {
    _persistedAttachmentPaths
      ..clear()
      ..addAll(items.map((item) => item.localPath));
  }

  MailAccount? _findAccount(List<MailAccount> accounts) {
    final id = _selectedAccountId;
    if (id != null) {
      for (final account in accounts) {
        if (account.id == id) return account;
      }
    }
    if (widget.account != null) return widget.account;
    return accounts.isNotEmpty ? accounts.first : null;
  }

  ComposeDraft _buildDraft(MailAccount account) {
    final toResult = _mergeRecipients(_to, _toController.text);
    final ccResult = _mergeRecipients(_cc, _ccController.text);
    final bccResult = _mergeRecipients(_bcc, _bccController.text);
    _recipientError =
        <String>[
          ...toResult.invalid,
          ...ccResult.invalid,
          ...bccResult.invalid,
        ].isEmpty
        ? null
        : '收件人格式错误：${<String>[...toResult.invalid, ...ccResult.invalid, ...bccResult.invalid].join(', ')}';
    return ComposeDraft(
      accountId: account.id,
      mode: _initialDraft.mode,
      originEmailLocalId: _initialDraft.originEmailLocalId,
      inReplyTo: _initialDraft.inReplyTo,
      referencesHeader: _initialDraft.referencesHeader,
      to: toResult.valid,
      cc: ccResult.valid,
      bcc: bccResult.valid,
      subject: _subjectController.text,
      plainBody: _plainController.text,
      htmlBody: _viewMode == _ComposeViewMode.html
          ? (_htmlController.text.trim().isEmpty
                ? _plainToHtml(_plainController.text)
                : _htmlController.text)
          : null,
      attachments: List<OutgoingAttachment>.unmodifiable(_attachments),
    );
  }

  RecipientParseResult _mergeRecipients(
    List<EmailAddressEntry> existing,
    String pendingText,
  ) {
    final parser = ComposeDraftFactory();
    final parsed = parser.parseRecipients(pendingText);
    return RecipientParseResult(
      valid: _dedupe(<EmailAddressEntry>[...existing, ...parsed.valid]),
      invalid: parsed.invalid,
    );
  }

  static List<EmailAddressEntry> _dedupe(List<EmailAddressEntry> entries) {
    final seen = <String>{};
    return [
      for (final entry in entries)
        if (seen.add(entry.email.toLowerCase())) entry,
    ];
  }

  Future<void> _saveDraft() async {
    await _awaitStaging();
    final accounts = ref.read(accountsProvider).value ?? const [];
    final account = _findAccount(accounts);
    if (account == null) {
      setState(() => _error = '请先选择发件账户。');
      return;
    }
    final draft = _buildDraft(account);
    if (_recipientError != null) {
      setState(() => _error = _recipientError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(saveDraftUseCaseProvider)
          .call(draft: draft, id: _draftId);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _draftId = saved.id;
        _rememberPersistedAttachments(saved.attachments);
        _dirty = false;
        _error = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('草稿已保存')));
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = failure.userMessage;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存草稿失败：$error';
      });
    }
  }

  Future<void> _send() async {
    await _awaitStaging();
    final accounts = ref.read(accountsProvider).value ?? const [];
    final account = _findAccount(accounts);
    if (account == null) {
      setState(() => _error = '请先选择发件账户。');
      return;
    }
    final draft = _buildDraft(account);
    if (_recipientError != null || draft.to.isEmpty) {
      setState(() => _error = _recipientError ?? '请至少填写一个有效的收件人地址。');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(queueAndSendEmailUseCaseProvider)
          .call(draft: draft, id: _draftId);
      if (!mounted) return;
      // Always adopt the persisted row id and attachment set, regardless of
      // success/failure/uncertain. A later tap cannot create a second row.
      setState(() {
        _sending = false;
        _draftId = result.id;
        _rememberPersistedAttachments(result.attachments);
        _dirty = false;
      });
      if (result.status != OutboxStatus.sent) {
        setState(() {
          _error = result.status == OutboxStatus.uncertain
              ? (result.lastError ?? '邮件投递状态待确认，请到发件箱人工核对后处理。')
              : (result.lastError ?? '发送失败，已加入重试队列。');
        });
        return;
      }
      setState(() {
        _dirty = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('邮件已进入发件队列并完成发送尝试')));
      Navigator.of(context).pop();
    } on OutboxSendException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _draftId = error.persistedMessage.id;
        _rememberPersistedAttachments(error.persistedMessage.attachments);
        _dirty = false;
        _error = error.userMessage;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = failure.userMessage;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '发送失败：$error';
      });
    }
  }

  Future<void> _requestClose() async {
    if (_busy) return;
    await _awaitStaging();
    if (!mounted || _busy || _stagingInProgress) return;
    if (!_dirty) {
      await _cleanupUnpersistedAttachments();
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    final accounts = ref.read(accountsProvider).value ?? const [];
    final account = _findAccount(accounts);
    final action = await _askCloseAction();
    if (!mounted || _busy) return;
    await _handleCloseAction(action, account);
  }

  Future<_CloseAction?> _askCloseAction() {
    return showDialog<_CloseAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('有未保存的更改'),
        content: const Text('要保存草稿、放弃更改，还是继续编辑？'),
        actions: [
          TextButton(
            key: const Key('compose-continue-editing'),
            onPressed: () =>
                Navigator.of(context).pop(_CloseAction.continueEditing),
            child: const Text('继续编辑'),
          ),
          TextButton(
            key: const Key('compose-discard-changes'),
            onPressed: () => Navigator.of(context).pop(_CloseAction.discard),
            child: const Text('放弃更改'),
          ),
          FilledButton(
            key: const Key('compose-save-close'),
            onPressed: () => Navigator.of(context).pop(_CloseAction.save),
            child: const Text('保存草稿'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCloseAction(
    _CloseAction? action,
    MailAccount? account,
  ) async {
    switch (action) {
      case null:
      case _CloseAction.continueEditing:
        return;
      case _CloseAction.discard:
        if (_busy || !mounted) return;
        // Never delete files referenced by an already-persisted draft row.
        await _cleanupUnpersistedAttachments();
        if (!mounted) return;
        Navigator.of(context).pop();
      case _CloseAction.save:
        await _saveDraft();
        if (!mounted || _error != null) return;
        Navigator.of(context).pop();
    }
  }

  static String _plainToHtml(String plain) {
    return '<p>${const HtmlEscape(HtmlEscapeMode.element).convert(plain).replaceAll('\n', '<br>')}</p>';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _RecipientField extends StatelessWidget {
  const _RecipientField({
    super.key,
    required this.label,
    this.fieldKey,
    required this.entries,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  final String label;
  final Key? fieldKey;
  final List<EmailAddressEntry> entries;
  final TextEditingController controller;
  final ValueChanged<EmailAddressEntry> onAdd;
  final ValueChanged<EmailAddressEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    void submit() {
      final parser = ComposeDraftFactory();
      final parsed = parser.parseRecipients(controller.text);
      if (parsed.valid.isNotEmpty) {
        for (final entry in parsed.valid) {
          onAdd(entry);
        }
        controller.clear();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entries.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final entry in entries)
                InputChip(
                  label: Text(entry.displayLabel),
                  onDeleted: () => onRemove(entry),
                ),
            ],
          ),
        TextField(
          key: fieldKey,
          controller: controller,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: label,
            hintText: '多个地址用逗号或分号分隔',
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: submit,
            ),
          ),
          onSubmitted: (_) => submit(),
          onEditingComplete: submit,
        ),
      ],
    );
  }
}
