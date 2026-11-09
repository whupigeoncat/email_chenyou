// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/error/failures.dart';
import '../../../core/logging/sanitized_logger.dart';
import '../../../core/network/imap_session.dart';
import '../../mail/data/datasources/enough_mail_imap_session.dart';
import '../domain/entities/mail_account.dart';

@immutable
class ImapConnectionTestResult {
  const ImapConnectionTestResult({
    required this.imapHost,
    required this.selectedFolder,
    required this.elapsed,
  });

  final String imapHost;
  final String selectedFolder;
  final Duration elapsed;
}

/// Verifies an unsaved account draft with a real, short-lived IMAP session.
///
/// The full sequence is:
/// `connect -> auth -> [RFC 2971 ID for 163/126/yeah.net] -> SELECT INBOX`.
///
/// No matter whether any step succeeds or throws, `finally` attempts LOGOUT and
/// always tears the socket down. A failed LOGOUT falls back to `forceClose()`
/// so a diagnostic run can never leave an orphaned connection behind.
class ImapConnectionTester {
  ImapConnectionTester({
    required ImapSessionFactory sessionFactory,
    SanitizedLogger? logger,
  })  : _sessionFactory = sessionFactory,
        _logger = logger ?? SanitizedLogger.instance;

  final ImapSessionFactory _sessionFactory;
  final SanitizedLogger _logger;

  Future<ImapConnectionTestResult> testConnection({
    required MailAccount account,
    required ResolvedAccountCredential credential,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final session = _sessionFactory.createSession();
    final startedAt = DateTime.now();

    try {
      await session
          .connectAndAuthenticate(account: account, credential: credential)
          .timeout(
            timeout,
            onTimeout: () => throw TimeoutException(
              'IMAP connection test timed out',
              timeout,
            ),
          );

      await session.selectFolder('INBOX').timeout(
            timeout,
            onTimeout: () => throw TimeoutException(
              'IMAP INBOX selection timed out',
              timeout,
            ),
          );

      return ImapConnectionTestResult(
        imapHost: account.imapHost,
        selectedFolder: session.selectedFolder ?? 'INBOX',
        elapsed: DateTime.now().difference(startedAt),
      );
    } on AppFailure {
      rethrow;
    } catch (error, stackTrace) {
      throw mapImapExceptionToFailure(
        error,
        stackTrace: stackTrace,
        authType: account.authType,
      );
    } finally {
      try {
        await session.logoutAndDisconnect(
          timeout: const Duration(seconds: 3),
        );
      } catch (error) {
        _logger.warn(
          'ImapTester',
          'LOGOUT cleanup failed; forcing socket close',
          error,
        );
        try {
          await session.forceClose();
        } catch (_) {
          // Socket is already gone.
        }
      } finally {
        // A session implementation must report a closed socket after cleanup.
        // If it does not, force the final tear-down exactly once more.
        if (session.isConnected) {
          try {
            await session.forceClose();
          } catch (_) {
            // Socket is already gone.
          }
        }
      }
    }
  }
}
