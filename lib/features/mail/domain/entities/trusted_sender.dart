import 'package:flutter/foundation.dart';

/// A sender address the user explicitly trusts for remote images.
@immutable
class TrustedSender {
  const TrustedSender({required this.senderEmail, required this.createdAt});

  final String senderEmail;
  final DateTime createdAt;

  String get normalizedEmail => senderEmail.trim().toLowerCase();

  @override
  bool operator ==(Object other) {
    return other is TrustedSender &&
        other.normalizedEmail == normalizedEmail &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(normalizedEmail, createdAt);
}
