/// Core domain failure hierarchy for the local-direct mail client.
sealed class AppFailure implements Exception {
  const AppFailure({
    required this.userMessage,
    this.technicalDetail,
    this.cause,
  });

  /// Human-readable guidance suitable for displaying in UI (Chinese).
  final String userMessage;

  /// Redacted diagnostic detail (must never include secrets or tokens).
  final String? technicalDetail;

  final Object? cause;

  @override
  String toString() => '$runtimeType($userMessage, detail=$technicalDetail)';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    required super.userMessage,
    super.technicalDetail,
    super.cause,
  });
}

enum AuthFailureReason {
  invalidCredentials,
  authorizationCodeRequired,
  imapDisabled,
  oauthRequired,
  oauthTokenExpired,
  oauthCancelled,
  unknown,
}

final class AuthFailure extends AppFailure {
  const AuthFailure({
    required this.reason,
    required super.userMessage,
    super.technicalDetail,
    super.cause,
  });

  final AuthFailureReason reason;
}

enum ImapFailureReason {
  unsafeLoginMissingId,
  tooManyConnections,
  connectionClosed,
  timeout,
  uidValidityChanged,
  protocolError,
}

final class ImapProtocolFailure extends AppFailure {
  const ImapProtocolFailure({
    required this.reason,
    required super.userMessage,
    super.technicalDetail,
    super.cause,
  });

  final ImapFailureReason reason;
}

enum SmtpFailureReason {
  authenticationFailed,
  recipientRejected,
  attachmentTooLarge,
  attachmentMissing,
  startTlsUnavailable,
  timeout,
  connectionClosed,
  protocolError,
  unknown,
}

final class SmtpFailure extends AppFailure {
  const SmtpFailure({
    required super.userMessage,
    super.technicalDetail,
    super.cause,
    this.reason = SmtpFailureReason.unknown,
    this.retryable = false,
  });

  final SmtpFailureReason reason;
  final bool retryable;
}

/// Classifies a failure for the outbox retry policy. Auth and validation
/// failures are deliberately non-retryable; transient network/protocol errors
/// are retryable.
bool isRetryableOutboxFailure(Object error) {
  if (error is SmtpFailure) return error.retryable;
  if (error is NetworkFailure) return true;
  if (error is AuthFailure) return false;
  if (error is StorageFailure) return false;
  return false;
}

final class StorageFailure extends AppFailure {
  const StorageFailure({
    required super.userMessage,
    super.technicalDetail,
    super.cause,
  });
}
