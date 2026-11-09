import 'package:flutter/foundation.dart';

import '../../../../core/constants/provider_presets.dart';

/// Account metadata entity.
///
/// SECURITY: Passwords, authorization codes, and OAuth tokens are NEVER stored
/// on this entity or in SQLite; they live strictly in `SecureStorageService`.
@immutable
class MailAccount {
  const MailAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.providerType,
    required this.authType,
    required this.colorValue,
    required this.imapHost,
    required this.imapPort,
    required this.imapImplicitTls,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpImplicitTls,
    required this.createdAt,
    this.isEnabled = true,
  });

  final String id;
  final String email;
  final String displayName;
  final MailProviderType providerType;
  final MailAuthType authType;
  final int colorValue;
  final String imapHost;
  final int imapPort;
  final bool imapImplicitTls;
  final String smtpHost;
  final int smtpPort;
  final bool smtpImplicitTls;
  final bool isEnabled;
  final DateTime createdAt;

  ProviderPreset get preset => ProviderPresets.byType(providerType);

  String get shortLabel => displayName.isNotEmpty ? displayName : email;

  MailAccount copyWith({
    String? email,
    String? displayName,
    MailProviderType? providerType,
    MailAuthType? authType,
    int? colorValue,
    String? imapHost,
    int? imapPort,
    bool? imapImplicitTls,
    String? smtpHost,
    int? smtpPort,
    bool? smtpImplicitTls,
    bool? isEnabled,
  }) {
    return MailAccount(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      providerType: providerType ?? this.providerType,
      authType: authType ?? this.authType,
      colorValue: colorValue ?? this.colorValue,
      imapHost: imapHost ?? this.imapHost,
      imapPort: imapPort ?? this.imapPort,
      imapImplicitTls: imapImplicitTls ?? this.imapImplicitTls,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      smtpImplicitTls: smtpImplicitTls ?? this.smtpImplicitTls,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MailAccount &&
        other.id == id &&
        other.email == email &&
        other.displayName == displayName &&
        other.providerType == providerType &&
        other.authType == authType &&
        other.colorValue == colorValue &&
        other.imapHost == imapHost &&
        other.imapPort == imapPort &&
        other.imapImplicitTls == imapImplicitTls &&
        other.smtpHost == smtpHost &&
        other.smtpPort == smtpPort &&
        other.smtpImplicitTls == smtpImplicitTls &&
        other.isEnabled == isEnabled &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        email,
        displayName,
        providerType,
        authType,
        colorValue,
        imapHost,
        imapPort,
        imapImplicitTls,
        smtpHost,
        smtpPort,
        smtpImplicitTls,
        isEnabled,
        createdAt,
      );
}
