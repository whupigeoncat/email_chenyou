import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../error/failures.dart';
import '../logging/sanitized_logger.dart';

@immutable
class OAuthTokenBundle {
  const OAuthTokenBundle({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.clientId,
    required this.tokenEndpoint,
    required this.scopes,
    this.accountEmail,
    this.deviceAuthorization = false,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final String clientId;
  final String tokenEndpoint;
  final List<String> scopes;

  /// Account this token was verified against, used to bind Android's silent
  /// Google re-authorization to the same Google account.
  final String? accountEmail;

  /// True for Android Google Play Services tokens: there is no refresh token
  /// and expiry is renewed through the platform, never against a token endpoint.
  final bool deviceAuthorization;

  bool get isExpiringSoon => DateTime.now().toUtc().isAfter(
    expiresAt.toUtc().subtract(const Duration(seconds: 90)),
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'clientId': clientId,
    'tokenEndpoint': tokenEndpoint,
    'scopes': scopes,
    'accountEmail': accountEmail,
    'deviceAuthorization': deviceAuthorization,
  };

  factory OAuthTokenBundle.fromJson(Map<String, dynamic> json) {
    return OAuthTokenBundle(
      accessToken: (json['accessToken'] as String?) ?? '',
      refreshToken: json['refreshToken'] as String?,
      expiresAt:
          DateTime.tryParse((json['expiresAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      clientId: (json['clientId'] as String?) ?? '',
      tokenEndpoint: (json['tokenEndpoint'] as String?) ?? '',
      scopes: ((json['scopes'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      // Older JSON bundles predate these fields; missing values are safe.
      accountEmail: json['accountEmail'] as String?,
      deviceAuthorization: (json['deviceAuthorization'] as bool?) ?? false,
    );
  }
}

/// Hardware/OS-backed credential storage service.
///
/// All secrets, IMAP/SMTP authorization codes, and OAuth refresh/access tokens
/// MUST go exclusively through this service and NEVER touch SQLite or logs.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage, SanitizedLogger? logger})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.first_unlock,
              usesDataProtectionKeychain: false,
            ),
            aOptions: AndroidOptions(),
            wOptions: WindowsOptions(),
          ),
      _logger = logger ?? SanitizedLogger.instance;

  final FlutterSecureStorage _storage;
  final SanitizedLogger _logger;

  static String _secretKey(String accountId) => 'mail_cred_${accountId}_secret';
  static String _oauthKey(String accountId) => 'mail_cred_${accountId}_oauth';

  Future<void> savePasswordSecret(String accountId, String secret) async {
    try {
      await _storage.write(key: _secretKey(accountId), value: secret);
      _logger.debug('SecureStorage', 'Saved secret for account $accountId');
    } catch (e, st) {
      _logger.error('SecureStorage', 'Failed to write secret', e, st);
      throw StorageFailure(
        userMessage: '无法将邮箱授权码写入系统安全存储',
        technicalDetail: e.toString(),
        cause: e,
      );
    }
  }

  Future<String?> readPasswordSecret(String accountId) async {
    try {
      return await _storage.read(key: _secretKey(accountId));
    } catch (e, st) {
      _logger.error('SecureStorage', 'Failed to read secret', e, st);
      throw StorageFailure(
        userMessage: '无法从系统安全存储读取邮箱凭据',
        technicalDetail: e.toString(),
        cause: e,
      );
    }
  }

  Future<void> saveOAuthTokens(
    String accountId,
    OAuthTokenBundle bundle,
  ) async {
    try {
      final encoded = jsonEncode(bundle.toJson());
      await _storage.write(key: _oauthKey(accountId), value: encoded);
      _logger.debug('SecureStorage', 'Saved OAuth tokens for $accountId');
    } catch (e, st) {
      _logger.error('SecureStorage', 'Failed to write OAuth bundle', e, st);
      throw StorageFailure(
        userMessage: '无法将 OAuth 令牌写入系统安全存储',
        technicalDetail: e.toString(),
        cause: e,
      );
    }
  }

  Future<OAuthTokenBundle?> readOAuthTokens(String accountId) async {
    try {
      final raw = await _storage.read(key: _oauthKey(accountId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return OAuthTokenBundle.fromJson(decoded);
    } catch (e, st) {
      _logger.error('SecureStorage', 'Failed to read OAuth bundle', e, st);
      throw StorageFailure(
        userMessage: '无法从系统安全存储读取 OAuth 令牌',
        technicalDetail: e.toString(),
        cause: e,
      );
    }
  }

  Future<bool> hasAnyCredential(String accountId) async {
    final hasSecret = await _storage.containsKey(key: _secretKey(accountId));
    if (hasSecret) return true;
    return _storage.containsKey(key: _oauthKey(accountId));
  }

  Future<void> deleteAccountCredentials(String accountId) async {
    try {
      await _storage.delete(key: _secretKey(accountId));
      await _storage.delete(key: _oauthKey(accountId));
      _logger.info('SecureStorage', 'Deleted credentials for $accountId');
    } catch (e, st) {
      _logger.error('SecureStorage', 'Failed to delete credentials', e, st);
      throw StorageFailure(
        userMessage: '清理安全凭据失败',
        technicalDetail: e.toString(),
        cause: e,
      );
    }
  }
}
