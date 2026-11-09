import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../auth/domain/entities/mail_account.dart';
import '../../../../core/security/html_email_sanitizer.dart';
import 'attachment_picker.dart';
import '../entities/outbox_message.dart';
import '../entities/unified_email.dart';

@immutable
class RecipientParseResult {
  const RecipientParseResult({required this.valid, required this.invalid});

  final List<EmailAddressEntry> valid;
  final List<String> invalid;

  bool get hasInvalid => invalid.isNotEmpty;
}

/// Pure compose/reply/forward domain builder.
class ComposeDraftFactory {
  ComposeDraftFactory({
    HtmlEmailSanitizer? sanitizer,
    AttachmentStore? attachmentStore,
  })  : _sanitizer = sanitizer ?? const HtmlEmailSanitizer(),
        _attachmentStore = attachmentStore ?? AttachmentStore();

  final HtmlEmailSanitizer _sanitizer;
  final AttachmentStore _attachmentStore;

  ComposeDraft newMail({
    required MailAccount account,
    String? subject,
    String? plainBody,
    String? htmlBody,
    List<EmailAddressEntry> to = const [],
    List<EmailAddressEntry> cc = const [],
    List<EmailAddressEntry> bcc = const [],
    List<OutgoingAttachment> attachments = const [],
  }) {
    return ComposeDraft(
      accountId: account.id,
      mode: ComposeMode.newMail,
      to: to,
      cc: cc,
      bcc: bcc,
      subject: subject ?? '',
      plainBody: plainBody ?? '',
      htmlBody: htmlBody,
      attachments: attachments,
    );
  }

  ComposeDraft reply({
    required MailAccount account,
    required UnifiedEmail original,
    bool replyAll = false,
  }) {
    final recipients = replyAll
        ? _replyAllRecipients(account, original)
        : _dedupe(<EmailAddressEntry>[
            if (original.fromAddress.isNotEmpty)
              EmailAddressEntry(
                email: original.fromAddress,
                name: original.fromName,
              ),
          ], excludeEmail: null);
    final body = _quote(original);
    return ComposeDraft(
      accountId: account.id,
      mode: replyAll ? ComposeMode.replyAll : ComposeMode.reply,
      originEmailLocalId: original.localId,
      inReplyTo: original.messageId,
      referencesHeader: original.messageId,
      to: recipients,
      cc: replyAll ? _replyAllCc(account, original, recipients) : const [],
      bcc: const [],
      subject: _replySubject(original.subject),
      plainBody: body.plain,
      htmlBody: body.html,
      attachments: const [],
    );
  }

  /// Builds the forward envelope without touching attachment files.
  ComposeDraft forwardShell({
    required MailAccount account,
    required UnifiedEmail original,
  }) {
    final body = _quote(original, forward: true);
    var missing = 0;
    for (final attachment in original.attachments) {
      final path = attachment.localCachePath;
      if (path == null || path.isEmpty || !File(path).existsSync()) {
        missing++;
      }
    }
    return ComposeDraft(
      accountId: account.id,
      mode: ComposeMode.forward,
      originEmailLocalId: original.localId,
      to: const [],
      cc: const [],
      bcc: const [],
      subject: _forwardSubject(original.subject),
      plainBody: body.plain,
      htmlBody: body.html,
      attachments: const [],
      missingAttachmentCount: missing,
    );
  }

  /// Copies cached received attachments into the outbox staging directory so
  /// the forward draft survives received-mail cache cleanup.
  Future<ComposeDraft> forward({
    required MailAccount account,
    required UnifiedEmail original,
  }) async {
    final shell = forwardShell(account: account, original: original);
    final attachments = <OutgoingAttachment>[];
    var missing = 0;
    for (final attachment in original.attachments) {
      final path = attachment.localCachePath;
      if (path == null || path.isEmpty || !File(path).existsSync()) {
        missing++;
        continue;
      }
      try {
        attachments.add(
          await _attachmentStore.stage(
            PickedAttachment(
              path: path,
              fileName: attachment.filename,
              sizeBytes: attachment.sizeBytes,
              mimeType: attachment.mimeType,
            ),
          ),
        );
      } catch (_) {
        missing++;
      }
    }
    return shell.copyWith(
      attachments: attachments,
      missingAttachmentCount: missing,
    );
  }

  RecipientParseResult parseRecipients(String input) {
    final valid = <EmailAddressEntry>[];
    final invalid = <String>[];
    for (final token in input.split(RegExp(r'[,;]'))) {
      final trimmed = token.trim();
      if (trimmed.isEmpty) continue;
      final entry = _parseAddress(trimmed);
      if (entry == null) {
        invalid.add(trimmed);
      } else {
        valid.add(entry);
      }
    }
    return RecipientParseResult(
      valid: _dedupe(valid, excludeEmail: null),
      invalid: invalid,
    );
  }

  static bool isValidEmail(String value) {
    final email = value.trim();
    if (email.length > 254 || email.contains(RegExp(r'[\r\n\u0000]'))) {
      return false;
    }
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  List<EmailAddressEntry> _replyAllRecipients(
    MailAccount account,
    UnifiedEmail original,
  ) {
    return _dedupe(
      <EmailAddressEntry>[
        if (original.fromAddress.isNotEmpty)
          EmailAddressEntry(
            email: original.fromAddress,
            name: original.fromName,
          ),
        ...original.toAddresses,
      ],
      excludeEmail: account.email,
    );
  }

  List<EmailAddressEntry> _replyAllCc(
    MailAccount account,
    UnifiedEmail original,
    List<EmailAddressEntry> to,
  ) {
    final toEmails = to.map((entry) => entry.email.toLowerCase()).toSet();
    final candidates = _dedupe(
      original.ccAddresses,
      excludeEmail: account.email,
    );
    return candidates
        .where((entry) => !toEmails.contains(entry.email.toLowerCase()))
        .toList(growable: false);
  }

  static List<EmailAddressEntry> _dedupe(
    Iterable<EmailAddressEntry> entries, {
    String? excludeEmail,
  }) {
    final seen = <String>{};
    final excluded = excludeEmail?.trim().toLowerCase();
    final result = <EmailAddressEntry>[];
    for (final entry in entries) {
      final email = entry.email.trim();
      final key = email.toLowerCase();
      if (email.isEmpty || key == excluded || !seen.add(key)) continue;
      result.add(EmailAddressEntry(email: email, name: entry.name.trim()));
    }
    return result;
  }

  static EmailAddressEntry? _parseAddress(String token) {
    final angle = RegExp(r'^(.*?)\s*<([^>]+)>\s*$').firstMatch(token);
    if (angle != null) {
      final email = angle.group(2)!.trim();
      if (!isValidEmail(email)) return null;
      final name = angle
          .group(1)!
          .trim()
          .replaceAll(RegExp(r'^["\x27]|["\x27]$'), '');
      return EmailAddressEntry(email: email, name: name);
    }
    if (!isValidEmail(token)) return null;
    return EmailAddressEntry(email: token);
  }

  static String _replySubject(String subject) {
    final trimmed = subject.trim();
    if (RegExp(r'^re\s*:', caseSensitive: false).hasMatch(trimmed)) {
      return trimmed;
    }
    return 'Re: $trimmed';
  }

  static String _forwardSubject(String subject) {
    final trimmed = subject.trim();
    if (RegExp(r'^(fwd|fw)\s*:', caseSensitive: false).hasMatch(trimmed)) {
      return trimmed;
    }
    return 'Fwd: $trimmed';
  }

  _QuoteBody _quote(UnifiedEmail original, {bool forward = false}) {
    final sender = original.fromName.isEmpty
        ? original.fromAddress
        : '${original.fromName} <${original.fromAddress}>';
    final date = original.sentAt.toLocal();
    final header = forward
        ? '---------- 转发邮件 ----------\n发件人：$sender\n日期：$date\n'
            '主题：${original.subject}'
        : '在 $date，$sender 写道：';
    final plain = original.plainBody?.trim().isNotEmpty == true
        ? original.plainBody!
        : original.snippet;
    final sanitizedHtml = original.htmlBody == null
        ? null
        : _sanitizer
            .sanitize(
              html: original.htmlBody!,
              allowRemoteImages: false,
            )
            .html;
    final htmlBody = sanitizedHtml ??
        '<p>${const HtmlEscape(HtmlEscapeMode.element).convert(plain)}</p>';
    final escapedHtmlHeader =
        const HtmlEscape(HtmlEscapeMode.element).convert(header);
    return _QuoteBody(
      plain: '\n\n$header\n$plain',
      html: '<p>$escapedHtmlHeader</p><blockquote>$htmlBody</blockquote>',
    );
  }
}

class _QuoteBody {
  const _QuoteBody({required this.plain, required this.html});

  final String plain;
  final String html;
}
