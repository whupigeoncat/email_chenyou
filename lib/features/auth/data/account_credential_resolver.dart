// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../../../../core/constants/provider_presets.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/logging/sanitized_logger.dart';
import '../../../../core/network/imap_session.dart';
import '../../../../core/security/oauth_pkce_service.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../domain/entities/mail_account.dart';

/// Runs a resolver/network action under a process-wide foreground lease so the
/// headless notification job cannot refresh the same token concurrently.
typedef CredentialResolutionGuard = Future<T> Function<T>(
  Future<T> Function() action,
);

/// Resolves an account's secret just-in-time for a new IMAP socket.
///
/// OAuth access tokens are refreshed proactively when they are within the
/// [OAuthTokenBundle.isExpiringSoon] window. Refresh operations for the same
/// account are serialized by an in-process mutex, and the token bundle is
/// re-read inside the lock so two concurrent resolvers cause exactly one
/// network refresh and one secure-storage write.
class AccountCredentialResolver {
  AccountCredentialResolver({
    required SecureStorageService secureStorage,
    required OAuthPkceService oauthPkceService,
    SanitizedLogger? logger,
    CredentialResolutionGuard? foregroundGuard,
  }) : _secureStorage = secureStorage,
       _oauthPkceService = oauthPkceService,
       _logger = logger ?? SanitizedLogger.instance,
       _foregroundGuard = foregroundGuard;

  final SecureStorageService _secureStorage;
  final OAuthPkceService _oauthPkceService;
  final SanitizedLogger _logger;
  final CredentialResolutionGuard? _foregroundGuard;

  /// One serialized tail future per account ID.
  final Map<String, Future<void>> _accountLocks = <String, Future<void>>{};

  Future<ResolvedAccountCredential> call(MailAccount account) {
    final guard = _foregroundGuard;
    if (guard == null) return _resolve(account);
    // Every foreground dependency (connection pool, outbox retry timers,
    // manual sync) must use the same native lease. A background job either
    // never started (UI visible) or is cancelled and awaited here.
    return guard(() => _resolve(account));
  }

  Future<ResolvedAccountCredential> _resolve(MailAccount account) async {
    switch (account.authType) {
      case MailAuthType.passwordOrAuthCode:
        return _resolvePassword(account);
      case MailAuthType.oauth2Pkce:
        return _resolveOAuth(account);
    }
  }

  Future<PasswordCredential> _resolvePassword(MailAccount account) async {
    final secret = await _secureStorage.readPasswordSecret(account.id);
    if (secret == null || secret.isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.authorizationCodeRequired,
        userMessage: '未找到该邮箱的授权码，请在账户管理中重新设置凭据。',
      );
    }
    return PasswordCredential(secret);
  }

  Future<OAuthCredential> _resolveOAuth(MailAccount account) async {
    final cached = await _secureStorage.readOAuthTokens(account.id);
    if (cached == null) {
      throw const AuthFailure(
        reason: AuthFailureReason.oauthRequired,
        userMessage: '未找到该邮箱的 OAuth 授权信息，请重新授权登录。',
      );
    }

    final needsRefresh = cached.isExpiringSoon || cached.accessToken.isEmpty;
    final bundle = needsRefresh
        ? await _serializedRefresh(account.id, account.providerType)
        : cached;

    return OAuthCredential(
      accessToken: bundle.accessToken,
      expiresAt: bundle.expiresAt,
    );
  }

  Future<OAuthTokenBundle> _serializedRefresh(
    String accountId,
    MailProviderType providerType,
  ) {
    return _serialize(accountId, () async {
      // Re-read inside the lock: a queued resolver may have already refreshed
      // while this call was waiting for the previous operation to finish.
      final current = await _secureStorage.readOAuthTokens(accountId);
      if (current == null) {
        throw const AuthFailure(
          reason: AuthFailureReason.oauthRequired,
          userMessage: '未找到该邮箱的 OAuth 授权信息，请重新授权登录。',
        );
      }
      if (!current.isExpiringSoon && current.accessToken.isNotEmpty) {
        return current;
      }

      _logger.info(
        'CredentialResolver',
        'Refreshing OAuth token for account $accountId',
      );
      final refreshed = current.deviceAuthorization
          ? await _oauthPkceService.refreshDeviceAuthorization(
              providerType: providerType,
              current: current,
            )
          : await _oauthPkceService.refreshToken(current);
      await _secureStorage.saveOAuthTokens(accountId, refreshed);
      _logger.info(
        'CredentialResolver',
        'OAuth token refreshed and persisted for account $accountId',
      );
      return refreshed;
    });
  }

  Future<T> _serialize<T>(String accountId, Future<T> Function() action) {
    final previous = _accountLocks[accountId] ?? Future<void>.value();
    final completer = Completer<T>();
    late final Future<void> next;

    next = previous
        .then((_) async {
          try {
            completer.complete(await action());
          } catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_accountLocks[accountId], next)) {
            _accountLocks.remove(accountId);
          }
        });

    _accountLocks[accountId] = next;
    return completer.future;
  }
}
