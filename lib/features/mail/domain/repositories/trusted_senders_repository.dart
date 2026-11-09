import '../entities/trusted_sender.dart';

/// Persists the user's explicit remote-content trust decisions.
abstract interface class TrustedSendersRepository {
  Stream<Set<TrustedSender>> watchTrustedSenders();

  Future<Set<TrustedSender>> getTrustedSenders();

  Future<bool> isTrusted(String senderEmail);

  Future<void> trustSender(String senderEmail);

  Future<void> untrustSender(String senderEmail);
}
