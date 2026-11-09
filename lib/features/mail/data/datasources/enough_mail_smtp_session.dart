// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart' hide MailAccount;
import 'package:flutter/foundation.dart';

import '../../../../core/constants/provider_presets.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/logging/sanitized_logger.dart';
import '../../../../core/network/imap_session.dart';
import '../../../auth/domain/entities/mail_account.dart';
import '../../domain/entities/outbox_message.dart';
import 'smtp_session.dart';

typedef SmtpClientFactory = SmtpClient Function();

/// `enough_mail` SMTP client with all wire logs passed through
/// [SanitizedLogger.sanitize] before reaching stdout or the diagnostic buffer.
class SanitizedSmtpClient extends SmtpClient {
  SanitizedSmtpClient({
    required String clientDomain,
    required SanitizedLogger logger,
    super.isLogEnabled,
    super.logName,
    super.onBadCertificate,
    super.securityContext,
  })  : _logger = logger,
        super(clientDomain);

  final SanitizedLogger _logger;
  bool _authInProgress = false;

  static final RegExp _authCommand = RegExp(
    r'^(?:[A-Z][A-Z0-9-]*[ \t]+)?AUTH(?:ENTICATE)?[ \t]+'
    r'(?:PLAIN|LOGIN|XOAUTH2|CRAM-MD5|[A-Z0-9._-]+)\b',
    caseSensitive: false,
  );
  static final RegExp _nonAuthCommand = RegExp(
    r'^(?:EHLO|HELO|MAIL|RCPT|DATA|QUIT|RSET|NOOP|STARTTLS)\b',
    caseSensitive: false,
  );

  /// True while the client is inside an SMTP AUTH exchange. Exposed for tests
  /// and diagnostics only; credentials are never retained here.
  @visibleForTesting
  bool get isAuthInProgress => _authInProgress;

  @override
  void log(dynamic logObject, {bool isClient = true, String? initial}) {
    if (!isLogEnabled) return;
    final direction = initial ?? (isClient ? 'C' : 'S');
    final text = '$logObject';

    if (!isClient) {
      _handleServerLine(text);
      _logger.debug(
        'SmtpWire',
        SanitizedLogger.sanitize('$direction: $text'),
      );
      return;
    }

    final trimmed = text.trim();
    if (_authCommand.hasMatch(trimmed)) {
      _authInProgress = true;
      _logger.debug('SmtpWire', '$direction: [REDACTED_AUTH_DATA]');
      return;
    }
    if (_authInProgress) {
      if (trimmed.isNotEmpty && _nonAuthCommand.hasMatch(trimmed)) {
        // A new non-auth command terminates the AUTH exchange.
        _authInProgress = false;
      } else {
        // AUTH LOGIN / XOAUTH2 continuation lines are bare Base64 or empty;
        // never let them reach the logger even when log() is called directly.
        _logger.debug('SmtpWire', '$direction: [REDACTED_AUTH_DATA]');
        return;
      }
    }
    _logger.debug(
      'SmtpWire',
      SanitizedLogger.sanitize('$direction: $text'),
    );
  }

  void _handleServerLine(String text) {
    if (!_authInProgress) return;
    final match = RegExp(r'^(\d{3})\b').firstMatch(text.trim());
    if (match == null) {
      // Malformed/EOF during AUTH can no longer continue the exchange.
      if (text.trim().isNotEmpty) _authInProgress = false;
      return;
    }
    final code = int.parse(match.group(1)!);
    if (code != 334) {
      // 235 success, 535 failure, or any other terminal reply.
      _authInProgress = false;
    }
  }
}

/// Real enough_mail SMTP transport. One instance owns exactly one transient
/// socket; no IMAP/ConnectionPool object is touched here.
class EnoughMailSmtpSession implements SmtpSession {
  EnoughMailSmtpSession({
    required SmtpClient client,
    SanitizedLogger? logger,
    Duration commandTimeout = const Duration(seconds: 20),
  })  : _client = client,
        _logger = logger ?? SanitizedLogger.instance,
        _commandTimeout = commandTimeout;

  final SmtpClient _client;
  final SanitizedLogger _logger;
  final Duration _commandTimeout;

  @override
  bool get isConnected => _client.isConnected;

  @visibleForTesting
  bool get isWireLogEnabledForTesting => _client.isLogEnabled;

  @override
  Future<void> connectAndAuthenticate({
    required MailAccount account,
    required ResolvedAccountCredential credential,
  }) async {
    try {
      await _client
          .connectToServer(
            account.smtpHost,
            account.smtpPort,
            isSecure: account.smtpImplicitTls,
          )
          .timeout(_commandTimeout);
      await _client.ehlo().timeout(_commandTimeout);

      if (!account.smtpImplicitTls) {
        if (!_client.serverInfo.supportsStartTls) {
          throw const SmtpFailure(
            reason: SmtpFailureReason.startTlsUnavailable,
            retryable: false,
            userMessage:
                'SMTP 服务器未声明 STARTTLS，已阻止在未加密连接上发送邮件凭据。',
          );
        }
        await _client.startTls().timeout(_commandTimeout);
      }

      switch (credential) {
        case PasswordCredential(:final secret):
          final mechanism = _client.serverInfo
                  .supportsAuth(AuthMechanism.login)
              ? AuthMechanism.login
              : AuthMechanism.plain;
          await _client
              .authenticate(account.email, secret, mechanism)
              .timeout(_commandTimeout);
        case OAuthCredential(:final accessToken):
          if (!_client.serverInfo.supportsAuth(AuthMechanism.xoauth2)) {
            throw const AuthFailure(
              reason: AuthFailureReason.oauthRequired,
              userMessage: 'SMTP 服务器未声明 XOAUTH2 支持，无法使用 OAuth2 发信。',
            );
          }
          await _client
              .authenticate(account.email, accessToken, AuthMechanism.xoauth2)
              .timeout(_commandTimeout);
      }
    } on AppFailure {
      rethrow;
    } catch (error, stackTrace) {
      throw mapSmtpExceptionToFailure(
        error,
        stackTrace: stackTrace,
        authType: account.authType,
      );
    }
  }

  @override
  Future<void> send(OutgoingMailEnvelope envelope) async {
    try {
      _validateEnvelopeHeaders(envelope);
      final message = await buildMimeMessage(envelope);
      final recipients = envelope.allRecipients
          .map((entry) => MailAddress(entry.name, entry.email))
          .toList(growable: false);
      final response = await _client
          .sendMessage(
            message,
            from: MailAddress(envelope.fromName, envelope.fromEmail),
            recipients: recipients,
          )
          .timeout(_commandTimeout);
      if (response.isFailedStatus) {
        throw SmtpException(_client, response);
      }
    } on AppFailure {
      rethrow;
    } catch (error, stackTrace) {
      throw mapSmtpExceptionToFailure(
        error,
        stackTrace: stackTrace,
        authType: null,
      );
    }
  }

  /// Builds a standards-compliant RFC 5322 message and removes the Bcc header
  /// from the transmitted payload while keeping Bcc recipients in the envelope.
  Future<MimeMessage> buildMimeMessage(OutgoingMailEnvelope envelope) async {
    final hasHtml = envelope.htmlBody?.trim().isNotEmpty == true;
    final builder = hasHtml
        ? MessageBuilder.prepareMultipartAlternativeMessage(
            plainText: envelope.plainBody,
            htmlText: envelope.htmlBody!,
          )
        : MessageBuilder(text: envelope.plainBody);

    builder
      ..subject = envelope.subject
      ..subjectEncoding = HeaderEncoding.Q
      ..date = DateTime.now()
      ..from = <MailAddress>[
        MailAddress(envelope.fromName, envelope.fromEmail),
      ]
      ..to = envelope.to
          .map((entry) => MailAddress(entry.name, entry.email))
          .toList(growable: false)
      ..cc = envelope.cc
          .map((entry) => MailAddress(entry.name, entry.email))
          .toList(growable: false)
      ..bcc = envelope.bcc
          .map((entry) => MailAddress(entry.name, entry.email))
          .toList(growable: false);

    if (envelope.messageId != null && envelope.messageId!.trim().isNotEmpty) {
      builder.messageId = requireSafeHeader('Message-ID', envelope.messageId!);
    }
    if (envelope.inReplyTo != null && envelope.inReplyTo!.trim().isNotEmpty) {
      builder.setHeader(
        'In-Reply-To',
        requireSafeHeader('In-Reply-To', envelope.inReplyTo!),
      );
    }
    if (envelope.referencesHeader != null &&
        envelope.referencesHeader!.trim().isNotEmpty) {
      builder.setHeader(
        'References',
        requireSafeHeader('References', envelope.referencesHeader!),
      );
    }

    for (final attachment in envelope.attachments) {
      final safeName = sanitizeAttachmentFileName(attachment.fileName);
      final file = File(attachment.localPath);
      if (!await file.exists()) {
        throw const SmtpFailure(
          reason: SmtpFailureReason.attachmentMissing,
          retryable: false,
          userMessage: '附件文件已不存在，请重新选择附件后再发送。',
        );
      }
      try {
        final reader = await file.open(mode: FileMode.read);
        await reader.close();
      } catch (_) {
        throw const SmtpFailure(
          reason: SmtpFailureReason.attachmentMissing,
          retryable: false,
          userMessage: '附件文件不可读取，请重新选择附件后再发送。',
        );
      }
      await builder.addFile(
        file,
        MediaType.fromText(attachment.mimeType),
        disposition: ContentDispositionHeader.from(
          ContentDisposition.attachment,
          filename: safeName,
          size: attachment.sizeBytes,
        ),
      );
    }

    final message = builder.buildMimeMessage();
    // Never transmit Bcc addresses in the message header.
    message.removeHeader('Bcc');
    return message;
  }

  @override
  Future<void> quitAndDisconnect({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      if (_client.isConnected) {
        await _client.quit().timeout(timeout);
      }
    } catch (error) {
      _logger.warn(
        'SmtpSession',
        'QUIT failed; forcing socket disconnect',
        error,
      );
    } finally {
      try {
        await _client.disconnect().timeout(timeout);
      } catch (error) {
        _logger.warn(
          'SmtpSession',
          'SMTP disconnect failed; socket is already gone',
          error,
        );
      }
      if (_client.isConnected) {
        await forceClose();
        _logger.debug(
          'SmtpSession',
          'SMTP socket force-closed after QUIT/disconnect',
        );
      }
    }
  }

  @override
  Future<void> forceClose() async {
    try {
      await _client.disconnect().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Socket is already gone.
    }
  }
}

/// Factory used by the outbox queue.
class EnoughMailSmtpSessionFactory implements SmtpSessionFactory {
  EnoughMailSmtpSessionFactory({
    SmtpClientFactory? clientFactory,
    SanitizedLogger? logger,
    Duration commandTimeout = const Duration(seconds: 20),
    String clientDomain = 'local-mail-client',
  })  : _logger = logger ?? SanitizedLogger.instance,
        _commandTimeout = commandTimeout,
        _clientFactory = clientFactory ??
            (() => SanitizedSmtpClient(
                  clientDomain: clientDomain,
                  logger: logger ?? SanitizedLogger.instance,
                  // Production must never print SMTP wire data.
                  isLogEnabled: false,
                ));

  final SmtpClientFactory _clientFactory;
  final SanitizedLogger _logger;
  final Duration _commandTimeout;

  @override
  SmtpSession createSession() {
    return EnoughMailSmtpSession(
      client: _clientFactory(),
      logger: _logger,
      commandTimeout: _commandTimeout,
    );
  }
}

/// Strips/rejects CRLF and NUL from any header value to prevent header
/// injection. The safe filename helper is shared with the SMTP attachment part.
String requireSafeHeader(String name, String value) {
  if (value.contains('\r') || value.contains('\n') || value.contains('\u0000')) {
    throw SmtpFailure(
      reason: SmtpFailureReason.protocolError,
      retryable: false,
      userMessage: '邮件头字段 $name 包含非法换行或控制字符，已拒绝发送。',
    );
  }
  return value.trim();
}

String sanitizeAttachmentFileName(String input) {
  var name = input.replaceAll('\\', '/');
  final lastSlash = name.lastIndexOf('/');
  if (lastSlash != -1) name = name.substring(lastSlash + 1);
  name = name.replaceAll(RegExp(r'[\u0000-\u001f<>:"|?*]'), '_').trim();
  name = name.replaceAll(RegExp(r'^\.+'), '');
  if (name.isEmpty || name == '.' || name == '..') return 'attachment.bin';
  return name.length > 180 ? name.substring(0, 180) : name;
}

void _validateEnvelopeHeaders(OutgoingMailEnvelope envelope) {
  requireSafeHeader('From name', envelope.fromName);
  requireSafeHeader('From address', envelope.fromEmail);
  requireSafeHeader('Subject', envelope.subject);
  if (envelope.messageId != null) {
    requireSafeHeader('Message-ID', envelope.messageId!);
  }
  if (envelope.inReplyTo != null) {
    requireSafeHeader('In-Reply-To', envelope.inReplyTo!);
  }
  if (envelope.referencesHeader != null) {
    requireSafeHeader('References', envelope.referencesHeader!);
  }
  for (final entry in envelope.allRecipients) {
    requireSafeHeader('Recipient name', entry.name);
    requireSafeHeader('Recipient address', entry.email);
  }
  for (final attachment in envelope.attachments) {
    requireSafeHeader('Attachment filename', attachment.fileName);
  }
}

/// Maps enough_mail SMTP exceptions to stable Chinese failures and a
/// retryable classification consumed by the outbox queue.
AppFailure mapSmtpExceptionToFailure(
  Object error, {
  StackTrace? stackTrace,
  MailAuthType? authType,
}) {
  final code = error is SmtpException ? error.response.code : null;
  final rawText = error is SmtpException
      ? error.response.responseLines
          .map((line) => '${line.code} ${line.message}')
          .join(' ')
      : error.toString();
  final detail = SanitizedLogger.sanitize(rawText);
  final lower = rawText.toLowerCase();

  if (error is TimeoutException ||
      lower.contains('timeout') ||
      lower.contains('timed out')) {
    return const SmtpFailure(
      reason: SmtpFailureReason.timeout,
      retryable: true,
      userMessage: 'SMTP 服务器响应超时，邮件将按策略自动重试。',
    );
  }
  if (error is SocketException ||
      lower.contains('connection closed') ||
      lower.contains('connection lost') ||
      lower.contains('socket')) {
    return NetworkFailure(
      userMessage: 'SMTP 连接意外中断，邮件将按策略自动重试。',
      technicalDetail: detail,
      cause: error,
    );
  }
  if (lower.contains('starttls') || code == 454) {
    return const SmtpFailure(
      reason: SmtpFailureReason.startTlsUnavailable,
      retryable: false,
      userMessage: 'SMTP 服务器 STARTTLS 升级失败，已阻止明文发送。',
    );
  }
  if (code == 535 || code == 534 || code == 530 || code == 530 ||
      lower.contains('authentication failed') ||
      lower.contains('invalid credentials')) {
    if (authType == MailAuthType.oauth2Pkce || lower.contains('xoauth2')) {
      return AuthFailure(
        reason: AuthFailureReason.oauthTokenExpired,
        userMessage: 'SMTP OAuth2 授权已被拒绝，请重新授权该邮箱账户。',
        technicalDetail: detail,
        cause: error,
      );
    }
    return AuthFailure(
      reason: AuthFailureReason.invalidCredentials,
      userMessage: 'SMTP 认证失败：请检查授权码或应用专用密码是否正确。',
      technicalDetail: detail,
      cause: error,
    );
  }
  if (code == 550 || code == 553 || code == 554) {
    return SmtpFailure(
      reason: SmtpFailureReason.recipientRejected,
      retryable: false,
      userMessage: '收件人地址被 SMTP 服务器拒绝，请检查地址后重试。',
      technicalDetail: detail,
      cause: error,
    );
  }
  if (code == 552 || code == 452 || lower.contains('message size') ||
      lower.contains('too large') ||
      lower.contains('exceeded')) {
    return SmtpFailure(
      reason: SmtpFailureReason.attachmentTooLarge,
      retryable: false,
      userMessage: '邮件或附件超过 SMTP 服务器大小限制，请减小附件后重试。',
      technicalDetail: detail,
      cause: error,
    );
  }
  if (code != null && code >= 400 && code < 500) {
    return SmtpFailure(
      reason: SmtpFailureReason.protocolError,
      retryable: true,
      userMessage: 'SMTP 服务器暂时拒绝发送，邮件将按策略自动重试。',
      technicalDetail: detail,
      cause: error,
    );
  }
  return SmtpFailure(
    reason: SmtpFailureReason.protocolError,
    retryable: false,
    userMessage: 'SMTP 发信失败，请检查服务器地址、端口与加密设置。',
    technicalDetail: detail,
    cause: error,
  );
}
