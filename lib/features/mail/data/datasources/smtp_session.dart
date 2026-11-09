import '../../../../core/network/imap_session.dart';
import '../../../auth/domain/entities/mail_account.dart';
import '../../domain/entities/outbox_message.dart';

/// Protocol-neutral outbound SMTP session. Business/queue code never touches
/// `enough_mail` or a raw Socket directly.
abstract interface class SmtpSession {
  bool get isConnected;

  Future<void> connectAndAuthenticate({
    required MailAccount account,
    required ResolvedAccountCredential credential,
  });

  Future<void> send(OutgoingMailEnvelope envelope);

  /// Must send QUIT and always close the socket in `finally`, even if QUIT
  /// times out or the server already dropped the connection.
  Future<void> quitAndDisconnect({
    Duration timeout = const Duration(seconds: 5),
  });

  /// Immediate tear-down without waiting for the server ACK.
  Future<void> forceClose();
}

abstract interface class SmtpSessionFactory {
  SmtpSession createSession();
}
