import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart' hide MailAccount;
import 'package:enough_mail/src/private/util/client_base.dart'
    show ConnectionInfo;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/logging/sanitized_logger.dart';
import 'package:local_mail_client/core/network/imap_session.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/datasources/enough_mail_smtp_session.dart';
import 'package:local_mail_client/features/mail/domain/entities/outbox_message.dart';
import 'package:local_mail_client/features/mail/domain/entities/unified_email.dart';

class FakeSmtpClient extends SmtpClient {
  FakeSmtpClient({
    required this.capabilities,
    required this.authMechanisms,
    this.failSendCode,
    this.failAuthCode,
  }) : super('test.local') {
    serverInfo = SmtpServerInfo('smtp.example.com', 465, isSecure: true)
      ..capabilities = capabilities
      ..authMechanisms = authMechanisms;
  }

  final List<String> capabilities;
  final List<AuthMechanism> authMechanisms;
  final int? failSendCode;
  final int? failAuthCode;
  final List<String> protocol = <String>[];
  MimeMessage? lastMessage;
  List<MailAddress>? lastRecipients;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<ConnectionInfo> connectToServer(
    String host,
    int port, {
    bool isSecure = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    protocol.add('connect:secure=$isSecure');
    _connected = true;
    serverInfo = SmtpServerInfo(host, port, isSecure: isSecure)
      ..capabilities = List<String>.of(capabilities)
      ..authMechanisms = List<AuthMechanism>.of(authMechanisms);
    return ConnectionInfo(host, port, isSecure: isSecure);
  }

  @override
  Future<SmtpResponse> ehlo() async {
    protocol.add('ehlo');
    return SmtpResponse(<String>['250 OK']);
  }

  @override
  Future<SmtpResponse> startTls() async {
    protocol.add('startTls');
    return SmtpResponse(<String>['220 Ready to start TLS']);
  }

  @override
  Future<SmtpResponse> authenticate(
    String name,
    String password, [
    AuthMechanism authMechanism = AuthMechanism.plain,
  ]) async {
    protocol.add('auth:${authMechanism.name}');
    if (failAuthCode != null) {
      throw SmtpException(
        this,
        SmtpResponse(<String>['$failAuthCode authentication failed']),
      );
    }
    isLoggedIn = true;
    return SmtpResponse(<String>['235 Authentication successful']);
  }

  @override
  Future<SmtpResponse> sendMessage(
    MimeMessage message, {
    bool use8BitEncoding = false,
    MailAddress? from,
    List<MailAddress>? recipients,
  }) async {
    protocol.add('send');
    lastMessage = message;
    lastRecipients = recipients;
    if (failSendCode != null) {
      throw SmtpException(this, SmtpResponse(<String>['$failSendCode rejected']));
    }
    return SmtpResponse(<String>['250 Queued']);
  }

  @override
  Future<SmtpResponse> quit() async {
    protocol.add('quit');
    _connected = false;
    return SmtpResponse(<String>['221 Bye']);
  }

  @override
  Future<void> disconnect() async {
    protocol.add('disconnect');
    _connected = false;
  }
}

MailAccount _account({
  bool smtpImplicitTls = true,
  MailAuthType authType = MailAuthType.passwordOrAuthCode,
}) {
  return MailAccount(
    id: 'acc',
    email: 'alice@example.com',
    displayName: 'Alice',
    providerType: MailProviderType.gmail,
    authType: authType,
    colorValue: 1,
    imapHost: 'imap.example.com',
    imapPort: 993,
    imapImplicitTls: true,
    smtpHost: 'smtp.example.com',
    smtpPort: smtpImplicitTls ? 465 : 587,
    smtpImplicitTls: smtpImplicitTls,
    createdAt: DateTime.utc(2026),
  );
}

OutgoingMailEnvelope _envelope({
  String subject = 'Hello',
  String fromName = 'Alice',
  String fromEmail = 'alice@example.com',
  String toName = 'Bob',
  String toEmail = 'bob@example.com',
  String? inReplyTo = '<original@example.com>',
  String? referencesHeader = '<original@example.com>',
  String? messageId = '<stable@local-mail.local>',
  String? attachmentName,
}) {
  return OutgoingMailEnvelope(
    fromEmail: fromEmail,
    fromName: fromName,
    to: [EmailAddressEntry(email: toEmail, name: toName)],
    cc: const [],
    bcc: const [EmailAddressEntry(email: 'hidden@example.com')],
    subject: subject,
    plainBody: 'Plain body',
    htmlBody: '<p>HTML body</p>',
    inReplyTo: inReplyTo,
    referencesHeader: referencesHeader,
    messageId: messageId,
    attachments: [
      if (attachmentName != null)
        OutgoingAttachment(
          fileName: attachmentName,
          mimeType: 'text/plain',
          localPath: '/definitely/not/here/note.txt',
          sizeBytes: 1,
        ),
    ],
  );
}

void main() {
  test('implicit TLS connects, authenticates and uses LOGIN', () async {
    final client = FakeSmtpClient(
      capabilities: <String>['AUTH PLAIN LOGIN'],
      authMechanisms: <AuthMechanism>[AuthMechanism.plain, AuthMechanism.login],
    );
    final session = EnoughMailSmtpSession(client: client);

    await session.connectAndAuthenticate(
      account: _account(),
      credential: const PasswordCredential('secret-code'),
    );
    expect(client.protocol, <String>[
      'connect:secure=true',
      'ehlo',
      'auth:login',
    ]);

    await session.send(_envelope());
    expect(client.protocol, contains('send'));
    expect(
      client.lastMessage?.getHeaderValue('Message-Id'),
      '<stable@local-mail.local>',
    );
    expect(client.lastRecipients?.map((a) => a.email), <String>[
      'bob@example.com',
      'hidden@example.com',
    ]);
    expect(client.lastMessage?.getHeaderValue('Bcc'), isNull);
    await session.quitAndDisconnect();
    expect(client.protocol, contains('quit'));
    expect(client.protocol, contains('disconnect'));
    expect(client.isConnected, isFalse);
  });

  test('STARTTLS upgrades before credentials are sent', () async {
    final client = FakeSmtpClient(
      capabilities: <String>['STARTTLS', 'AUTH PLAIN LOGIN'],
      authMechanisms: <AuthMechanism>[AuthMechanism.plain, AuthMechanism.login],
    );
    final session = EnoughMailSmtpSession(client: client);

    await session.connectAndAuthenticate(
      account: _account(smtpImplicitTls: false),
      credential: const PasswordCredential('secret-code'),
    );

    expect(client.protocol, <String>[
      'connect:secure=false',
      'ehlo',
      'startTls',
      'auth:login',
    ]);
    final startTlsIndex = client.protocol.indexOf('startTls');
    final authIndex = client.protocol.indexOf('auth:login');
    expect(startTlsIndex, lessThan(authIndex));
    await session.quitAndDisconnect();
  });

  test('missing STARTTLS fails closed before authentication', () async {
    final client = FakeSmtpClient(
      capabilities: <String>['AUTH PLAIN'],
      authMechanisms: <AuthMechanism>[AuthMechanism.plain],
    );
    final session = EnoughMailSmtpSession(client: client);

    await expectLater(
      session.connectAndAuthenticate(
        account: _account(smtpImplicitTls: false),
        credential: const PasswordCredential('secret-code'),
      ),
      throwsA(
        isA<SmtpFailure>().having(
          (failure) => failure.reason,
          'reason',
          SmtpFailureReason.startTlsUnavailable,
        ),
      ),
    );
    expect(client.protocol, isNot(contains('auth:plain')));
    expect(client.protocol, isNot(contains('auth:login')));
    await session.forceClose();
  });

  test('OAuth uses XOAUTH2', () async {
    final client = FakeSmtpClient(
      capabilities: <String>['AUTH XOAUTH2'],
      authMechanisms: <AuthMechanism>[AuthMechanism.xoauth2],
    );
    final session = EnoughMailSmtpSession(client: client);

    await session.connectAndAuthenticate(
      account: _account(authType: MailAuthType.oauth2Pkce),
      credential: OAuthCredential(
        accessToken: 'oauth-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    expect(client.protocol, contains('auth:xoauth2'));
    await session.quitAndDisconnect();
  });

  test('header CRLF injection is rejected before SMTP send', () async {
    final client = FakeSmtpClient(
      capabilities: <String>['AUTH PLAIN'],
      authMechanisms: <AuthMechanism>[AuthMechanism.plain],
    );
    final session = EnoughMailSmtpSession(client: client);
    await session.connectAndAuthenticate(
      account: _account(),
      credential: const PasswordCredential('secret-code'),
    );

    await expectLater(
      session.send(_envelope(subject: 'Hello\r\nBcc: evil@example.com')),
      throwsA(
        isA<SmtpFailure>().having(
          (failure) => failure.reason,
          'reason',
          SmtpFailureReason.protocolError,
        ),
      ),
    );
    expect(client.protocol, isNot(contains('send')));
    await session.quitAndDisconnect();
  });

  test('error codes map to non-retryable authentication/recipient failures',
      () {
    final client = FakeSmtpClient(
      capabilities: const <String>[],
      authMechanisms: const <AuthMechanism>[],
    );
    final auth = mapSmtpExceptionToFailure(
      SmtpException(client, SmtpResponse(<String>['535 authentication failed'])),
    );
    expect(auth, isA<AuthFailure>());
    expect((auth as AuthFailure).reason, AuthFailureReason.invalidCredentials);

    final recipient = mapSmtpExceptionToFailure(
      SmtpException(client, SmtpResponse(<String>['550 mailbox unavailable'])),
    );
    expect(recipient, isA<SmtpFailure>());
    expect((recipient as SmtpFailure).retryable, isFalse);

    final temporary = mapSmtpExceptionToFailure(
      SmtpException(client, SmtpResponse(<String>['451 try again later'])),
    );
    expect((temporary as SmtpFailure).retryable, isTrue);
  });

  test('SanitizedSmtpClient never logs plaintext auth data', () {
    final logger = SanitizedLogger.instance;
    logger.clear();
    final client = SanitizedSmtpClient(
      clientDomain: 'test',
      logger: logger,
      isLogEnabled: true,
    );
    client.log('AUTH PLAIN dXNlcjpwYXNzd29yZA==');
    final entries = logger.recentEntries.join('\n');
    expect(entries, isNot(contains('dXNlcjpwYXNzd29yZA==')));
    expect(entries, contains('[REDACTED_AUTH_DATA]'));
  });

  test('SanitizedSmtpClient redacts multi-line AUTH LOGIN credentials',
      () {
    final logger = SanitizedLogger.instance;
    logger.clear();
    final client = SanitizedSmtpClient(
      clientDomain: 'test',
      logger: logger,
      isLogEnabled: true,
    );
    const username = 'alice@example.com';
    const password = 'super-secret-password';
    final username64 = base64.encode(utf8.encode(username));
    final password64 = base64.encode(utf8.encode(password));

    client.log('AUTH LOGIN');
    client.log('334 VXNlcm5hbWU6', isClient: false);
    client.log(username64);
    client.log('334 UGFzc3dvcmQ6', isClient: false);
    client.log(password64);
    client.log('535 Authentication failed', isClient: false);
    client.log('MAIL FROM:<alice@example.com>');

    final entries = logger.recentEntries.join('\n');
    expect(entries, isNot(contains(username64)));
    expect(entries, isNot(contains(password64)));
    expect(entries, isNot(contains(password)));
    expect(entries, contains('[REDACTED_AUTH_DATA]'));
    expect(entries, contains('MAIL FROM:<alice@example.com>'));
  });

  test('SanitizedSmtpClient redacts AUTH PLAIN and XOAUTH2 continuations', () {
    final logger = SanitizedLogger.instance;
    logger.clear();
    final client = SanitizedSmtpClient(
      clientDomain: 'test',
      logger: logger,
      isLogEnabled: true,
    );
    final plain = base64.encode(utf8.encode('user@example.com'));
    final xoauthToken = base64.encode(utf8.encode('user=u\u0001auth=Bearer t'));
    client.log('AUTH PLAIN $plain');
    client.log('235 ok', isClient: false);
    client.log('AUTH XOAUTH2 $xoauthToken');
    client.log('235 ok', isClient: false);
    client.log('AUTH XOAUTH2');
    client.log('334 continue', isClient: false);
    client.log(xoauthToken);
    client.log('334 error-details', isClient: false);
    client.log('');
    client.log('235 ok', isClient: false);

    final entries = logger.recentEntries.join('\n');
    expect(entries, isNot(contains(plain)));
    expect(entries, isNot(contains(xoauthToken)));
    expect('AUTH WEIRD token123'.replaceAllMapped(
      RegExp(r'(AUTH[ \t]+[A-Za-z0-9._-]+[ \t]+)[^\s]+'),
      (m) => '${m.group(1)}[REDACTED_TOKEN]',
    ), 'AUTH WEIRD [REDACTED_TOKEN]');
    expect(
      SanitizedLogger.sanitize('AUTH WEIRD token123'),
      contains('[REDACTED_TOKEN]'),
    );
  });

  test('all envelope header fields reject CRLF/NUL injection', () async {
    final client = FakeSmtpClient(
      capabilities: const <String>[],
      authMechanisms: const <AuthMechanism>[],
    );
    final session = EnoughMailSmtpSession(client: client);
    final injected = <String, OutgoingMailEnvelope>{
      'fromName': _envelope(fromName: 'Alice\r\nBcc: evil@example.com'),
      'fromEmail': _envelope(fromEmail: 'alice@example.com\nBcc: x@y.z'),
      'recipientName': _envelope(toName: 'Bob\u0000Evil'),
      'recipientEmail': _envelope(toEmail: 'bob@example.com\r\nBcc: x@y.z'),
      'subject': _envelope(subject: 'Hello\nBcc: x@y.z'),
      'inReplyTo': _envelope(inReplyTo: '<x@y>\r\nBcc: x@y.z'),
      'references': _envelope(referencesHeader: '<x@y>\nBcc: x@y.z'),
      'messageIdCrlf': _envelope(messageId: '<x@y>\r\nBcc: x@y.z'),
      'messageIdNul': _envelope(messageId: '<x@y>\u0000z'),
      'attachmentName': _envelope(attachmentName: 'a.txt\r\nBcc: x@y.z'),
    };
    for (final entry in injected.entries) {
      await expectLater(
        session.send(entry.value),
        throwsA(
          isA<SmtpFailure>().having(
            (failure) => failure.reason,
            'reason',
            SmtpFailureReason.protocolError,
          ),
        ),
        reason: entry.key,
      );
    }
    expect(client.protocol, isNot(contains('send')));
  });

  test('production SMTP factory keeps wire logging disabled', () {
    final session = EnoughMailSmtpSessionFactory().createSession();
    expect(session, isA<EnoughMailSmtpSession>());
    expect(
      (session as EnoughMailSmtpSession).isWireLogEnabledForTesting,
      isFalse,
    );
  });

  test('timeout maps to retryable SMTP failure', () {
    final failure = mapSmtpExceptionToFailure(TimeoutException('timeout'));
    expect(failure, isA<SmtpFailure>());
    expect((failure as SmtpFailure).retryable, isTrue);
  });

  test('socket failure maps to retryable network failure', () {
    final failure = mapSmtpExceptionToFailure(
      const SocketException('connection reset'),
    );
    expect(failure, isA<NetworkFailure>());
  });
}
