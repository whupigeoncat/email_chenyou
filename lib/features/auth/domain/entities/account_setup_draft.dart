import 'package:flutter/foundation.dart';

import '../../../../core/constants/provider_presets.dart';
import '../../../../core/network/imap_session.dart';
import '../../../../core/security/secure_storage_service.dart';
import 'mail_account.dart';

/// Ephemeral credentials used during account setup or credential reset.
///
/// Never persisted in SQLite and never attached to [MailAccount]. The auth
/// repository writes these exclusively through `SecureStorageService`.
sealed class PendingAccountCredential {
  const PendingAccountCredential();

  ResolvedAccountCredential toResolvedCredential();
}

final class PasswordAccountCredential extends PendingAccountCredential {
  const PasswordAccountCredential(this.secret);

  final String secret;

  @override
  ResolvedAccountCredential toResolvedCredential() =>
      PasswordCredential(secret);
}

final class OAuthAccountCredential extends PendingAccountCredential {
  const OAuthAccountCredential(this.tokens);

  final OAuthTokenBundle tokens;

  @override
  ResolvedAccountCredential toResolvedCredential() => OAuthCredential(
        accessToken: tokens.accessToken,
        expiresAt: tokens.expiresAt,
      );
}

/// Non-persisted account form values used by the connection tester and wizard.
@immutable
class MailAccountDraft {
  const MailAccountDraft({
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
    this.isEnabled = true,
  });

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

  ProviderPreset get preset => ProviderPresets.byType(providerType);

  MailAccount toAccount({
    required String id,
    required DateTime createdAt,
  }) {
    return MailAccount(
      id: id,
      email: email.trim(),
      displayName: displayName.trim(),
      providerType: providerType,
      authType: authType,
      colorValue: colorValue,
      imapHost: imapHost.trim(),
      imapPort: imapPort,
      imapImplicitTls: imapImplicitTls,
      smtpHost: smtpHost.trim(),
      smtpPort: smtpPort,
      smtpImplicitTls: smtpImplicitTls,
      isEnabled: isEnabled,
      createdAt: createdAt,
    );
  }
}
