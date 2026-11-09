// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/provider_presets.dart';
import '../../../core/database/app_database.dart';
import '../../../core/error/failures.dart';
import '../../../core/logging/sanitized_logger.dart';
import '../../../core/network/connection_pool.dart';
import '../../../core/security/secure_storage_service.dart';
import '../domain/entities/account_setup_draft.dart';
import '../domain/entities/mail_account.dart';
import '../domain/repositories/auth_repository.dart';

/// Drift + secure-storage implementation of [AuthRepository].
///
/// SECURITY: `DbAccountsCompanion` only ever receives metadata columns. Secrets
/// are written through [SecureStorageService] before the metadata insert and
/// are deleted again if that insert fails.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AppDatabase database,
    required SecureStorageService secureStorage,
    required ConnectionPool connectionPool,
    Uuid? uuid,
    DateTime Function()? clock,
    SanitizedLogger? logger,
    Future<void> Function(Iterable<String> paths)? cleanupOutboxAttachments,
  }) : _database = database,
       _secureStorage = secureStorage,
       _connectionPool = connectionPool,
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now,
       _logger = logger ?? SanitizedLogger.instance,
       _cleanupOutboxAttachments = cleanupOutboxAttachments;

  final AppDatabase _database;
  final SecureStorageService _secureStorage;
  final ConnectionPool _connectionPool;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final SanitizedLogger _logger;
  final Future<void> Function(Iterable<String> paths)? _cleanupOutboxAttachments;

  @override
  Stream<List<MailAccount>> watchAccounts() {
    final query = _database.select(_database.dbAccounts)
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);
    return query.watch().map(
      (rows) => rows.map(_fromRow).toList(growable: false),
    );
  }

  @override
  Future<List<MailAccount>> getAccounts() async {
    final query = _database.select(_database.dbAccounts)
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);
    final rows = await query.get();
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<MailAccount?> getAccount(String accountId) async {
    final query = _database.select(_database.dbAccounts)
      ..where((table) => table.id.equals(accountId));
    final row = await query.getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<MailAccount> addAccount({
    required MailAccountDraft draft,
    required PendingAccountCredential credential,
  }) async {
    _validateDraft(draft);
    final account = draft.toAccount(
      id: _uuid.v4(),
      createdAt: _clock().toUtc(),
    );

    // Phase 1 of the atomic write: secret first, so a metadata row can never
    // exist without a usable credential.
    await _writeCredential(account.id, credential);

    try {
      // Phase 2: metadata only. NO secret column exists in DbAccounts.
      await _database
          .into(_database.dbAccounts)
          .insert(
            DbAccountsCompanion.insert(
              id: account.id,
              email: account.email,
              displayName: account.displayName,
              providerType: account.providerType.storageKey,
              authType: account.authType.storageKey,
              colorValue: account.colorValue,
              imapHost: account.imapHost,
              imapPort: account.imapPort,
              imapImplicitTls: account.imapImplicitTls,
              smtpHost: account.smtpHost,
              smtpPort: account.smtpPort,
              smtpImplicitTls: account.smtpImplicitTls,
              isEnabled: Value(account.isEnabled),
              createdAt: account.createdAt.millisecondsSinceEpoch,
            ),
          );
    } catch (error, stackTrace) {
      // Roll back the credential written above: no orphan secret may remain
      // when the metadata insert failed.
      await _deleteCredentialQuietly(account.id);
      _logger.error(
        'AuthRepository',
        'Account insert failed; credential rolled back',
        error,
        stackTrace,
      );
      throw StorageFailure(
        userMessage: '账户信息写入本地数据库失败，授权凭据已回滚，请重试。',
        technicalDetail: SanitizedLogger.sanitize(error.toString()),
        cause: error,
      );
    }

    await _syncPoolSafely();
    return account;
  }

  @override
  Future<MailAccount> updateAccount(MailAccount account) async {
    final updated =
        await (_database.update(
          _database.dbAccounts,
        )..where((table) => table.id.equals(account.id))).write(
          DbAccountsCompanion(
            email: Value(account.email),
            displayName: Value(account.displayName),
            providerType: Value(account.providerType.storageKey),
            authType: Value(account.authType.storageKey),
            colorValue: Value(account.colorValue),
            imapHost: Value(account.imapHost),
            imapPort: Value(account.imapPort),
            imapImplicitTls: Value(account.imapImplicitTls),
            smtpHost: Value(account.smtpHost),
            smtpPort: Value(account.smtpPort),
            smtpImplicitTls: Value(account.smtpImplicitTls),
            isEnabled: Value(account.isEnabled),
          ),
        );

    if (updated == 0) {
      throw const StorageFailure(userMessage: '账户不存在或已被删除，无法更新。');
    }

    await _syncPoolSafely();
    return account;
  }

  @override
  Future<void> setAccountEnabled(String accountId, bool isEnabled) async {
    final account = await getAccount(accountId);
    if (account == null) {
      throw const StorageFailure(userMessage: '账户不存在或已被删除。');
    }
    await updateAccount(account.copyWith(isEnabled: isEnabled));
  }

  @override
  Future<void> replaceCredential(
    String accountId,
    PendingAccountCredential credential,
  ) async {
    final account = await getAccount(accountId);
    if (account == null) {
      throw const StorageFailure(userMessage: '账户不存在或已被删除。');
    }
    await _writeCredential(accountId, credential);
    await _syncPoolSafely();
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    // Capture outbox attachment paths before the account cascade deletes the
    // rows. The files themselves are removed only after the DB delete succeeds.
    final outboxAttachmentPaths = <String>[];
    try {
      final rows = await (_database.select(_database.dbOutboxMessages)
            ..where((table) => table.accountId.equals(accountId)))
          .get();
      for (final row in rows) {
        try {
          final decoded = jsonDecode(row.attachmentsJson);
          if (decoded is! List) continue;
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final path = item['localPath'];
              if (path is String && path.trim().isNotEmpty) {
                outboxAttachmentPaths.add(path);
              }
            }
          }
        } catch (_) {
          // A corrupted attachment JSON must not block account deletion.
        }
      }
    } catch (error) {
      _logger.warn(
        'AuthRepository',
        'Failed to inspect outbox attachments for $accountId',
        error,
      );
    }

    // Metadata first: if this fails the account (and its credentials) remains
    // fully usable. Once it succeeds, credentials and pool slot are cleaned up
    // even if secure storage reports an error.
    await (_database.delete(
      _database.dbAccounts,
    )..where((table) => table.id.equals(accountId))).go();

    try {
      await _cleanupOutboxAttachments?.call(outboxAttachmentPaths);
    } catch (error) {
      _logger.warn(
        'AuthRepository',
        'Failed to delete outbox attachments for $accountId',
        error,
      );
    }

    Object? storageError;
    try {
      await _secureStorage.deleteAccountCredentials(accountId);
    } catch (error) {
      storageError = error;
      _logger.error(
        'AuthRepository',
        'Failed to delete secure credentials for $accountId',
        error,
      );
    }

    await _syncPoolSafely();

    if (storageError != null) {
      throw StorageFailure(
        userMessage: '账户已删除，但系统安全存储中的凭据清理失败，请稍后重试。',
        technicalDetail: SanitizedLogger.sanitize(storageError.toString()),
        cause: storageError,
      );
    }
  }

  @override
  Future<void> initialize() async {
    final accounts = await getAccounts();
    await _connectionPool.syncAccounts(accounts);
  }

  Future<void> _writeCredential(
    String accountId,
    PendingAccountCredential credential,
  ) async {
    switch (credential) {
      case PasswordAccountCredential(:final secret):
        if (secret.isEmpty) {
          throw const AuthFailure(
            reason: AuthFailureReason.authorizationCodeRequired,
            userMessage: '请填写邮箱授权码后再保存。',
          );
        }
        await _secureStorage.savePasswordSecret(accountId, secret);
      case OAuthAccountCredential(:final tokens):
        if (tokens.accessToken.isEmpty) {
          throw const AuthFailure(
            reason: AuthFailureReason.oauthRequired,
            userMessage: 'OAuth 访问令牌为空，请重新授权登录。',
          );
        }
        await _secureStorage.saveOAuthTokens(accountId, tokens);
    }
  }

  Future<void> _deleteCredentialQuietly(String accountId) async {
    try {
      await _secureStorage.deleteAccountCredentials(accountId);
    } catch (error) {
      _logger.error(
        'AuthRepository',
        'Credential rollback failed for $accountId',
        error,
      );
    }
  }

  Future<void> _syncPoolSafely() async {
    try {
      await _connectionPool.syncAccounts(await getAccounts());
    } catch (error) {
      // The account operation is already committed; a pool refresh failure
      // must not report the saved account as failed.
      _logger.error(
        'AuthRepository',
        'ConnectionPool.syncAccounts failed after account mutation',
        error,
      );
    }
  }

  void _validateDraft(MailAccountDraft draft) {
    final email = draft.email.trim();
    final at = email.indexOf('@');
    if (at <= 0 || at == email.length - 1) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: '请输入有效的邮箱地址。',
      );
    }
    if (draft.imapHost.trim().isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'IMAP 服务器地址不能为空。',
      );
    }
    if (draft.imapPort < 1 || draft.imapPort > 65535) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'IMAP 端口必须在 1 到 65535 之间。',
      );
    }
    if (draft.smtpHost.trim().isEmpty) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'SMTP 服务器地址不能为空。',
      );
    }
    if (draft.smtpPort < 1 || draft.smtpPort > 65535) {
      throw const AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: 'SMTP 端口必须在 1 到 65535 之间。',
      );
    }
    if (!draft.preset.supportedAuthTypes.contains(draft.authType)) {
      throw AuthFailure(
        reason: AuthFailureReason.unknown,
        userMessage: '${draft.preset.displayName} 不支持当前选择的认证方式，请重新选择。',
      );
    }
  }

  MailAccount _fromRow(DbAccount row) {
    return MailAccount(
      id: row.id,
      email: row.email,
      displayName: row.displayName,
      providerType: MailProviderType.fromStorageKey(row.providerType),
      authType: MailAuthType.fromStorageKey(row.authType),
      colorValue: row.colorValue,
      imapHost: row.imapHost,
      imapPort: row.imapPort,
      imapImplicitTls: row.imapImplicitTls,
      smtpHost: row.smtpHost,
      smtpPort: row.smtpPort,
      smtpImplicitTls: row.smtpImplicitTls,
      isEnabled: row.isEnabled,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
    );
  }
}
