import 'dart:collection';
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warn, error }

/// Structured logger that strips passwords, auth codes, and OAuth tokens
/// before anything hits stdout or the in-memory diagnostic ring buffer.
class SanitizedLogger {
  SanitizedLogger._();

  static final SanitizedLogger instance = SanitizedLogger._();

  static const int _maxBufferSize = 400;
  final ListQueue<String> _recentLogs = ListQueue<String>(_maxBufferSize);

  static final List<_RedactionRule> _rules = [
    // IMAP LOGIN <user> <secret> (quoted strings or atoms).
    // Horizontal whitespace only, so redaction never spans unrelated log lines.
    _RedactionRule(
      RegExp(
        r'(\bLOGIN[ \t]+)("(?:[^"\\]|\\.)*"|[^ \t\r\n]+)([ \t]+)'
        r'("(?:[^"\\]|\\.)*"|[^ \t\r\n]+)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}[REDACTED_USER]${m.group(3)}[REDACTED_SECRET]',
    ),
    // IMAP / SMTP AUTHENTICATE XOAUTH2, AUTH PLAIN, AUTH LOGIN initial response.
    _RedactionRule(
      RegExp(
        r'(\b(?:AUTHENTICATE|AUTH)[ \t]+'
        r'(?:XOAUTH2|PLAIN|LOGIN|CRAM-MD5|[A-Za-z0-9._-]+)[ \t]+)'
        r'("(?:[^"\\]|\\.)*"|[A-Za-z0-9+/=._~-]+)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}[REDACTED_TOKEN]',
    ),
    // HTTP Authorization headers.
    _RedactionRule(
      RegExp(
        r'(Authorization[ \t]*:[ \t]*(?:Bearer|Basic)[ \t]+)[^\s,;]+',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}[REDACTED_AUTH]',
    ),
    // JSON bodies (snake_case and camelCase OAuth field names).
    _RedactionRule(
      RegExp(
        r'("(?:access_token|accessToken|refresh_token|refreshToken|id_token|'
        r'idToken|client_secret|clientSecret|code_verifier|codeVerifier|'
        r'authorization_code|auth_code|authCode|password|passwd|secret|token)"'
        r'[ \t]*:[ \t]*)"(?:[^"\\]|\\.)*"',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}"[REDACTED]"',
    ),
    // URL query strings and application/x-www-form-urlencoded bodies.
    _RedactionRule(
      RegExp(
        r'(^|[?&;\s])((?:authorization_code|access_token|refresh_token|'
        r'client_secret|code_verifier|auth_code|id_token|password|passwd|'
        r'secret|token|code)=)[^&\s]+',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}${m.group(2)}[REDACTED]',
    ),
  ];

  /// Redacts sensitive credential/token substrings from arbitrary log text.
  static String sanitize(String input) {
    var output = input;
    for (final rule in _rules) {
      output = output.replaceAllMapped(rule.pattern, rule.replacer);
    }
    return output;
  }

  List<String> get recentEntries => List.unmodifiable(_recentLogs);

  void debug(String tag, String message) => _log(LogLevel.debug, tag, message);
  void info(String tag, String message) => _log(LogLevel.info, tag, message);
  void warn(String tag, String message, [Object? error]) =>
      _log(LogLevel.warn, tag, error == null ? message : '$message ($error)');
  void error(String tag, String message, [Object? error, StackTrace? stack]) {
    final full = error == null ? message : '$message | $error';
    _log(LogLevel.error, tag, full);
    if (kDebugMode && stack != null) {
      debugPrint(sanitize(stack.toString()));
    }
  }

  void _log(LogLevel level, String tag, String message) {
    final clean = sanitize(message);
    final ts = DateTime.now().toIso8601String();
    final line = '[$ts][${level.name.toUpperCase()}][$tag] $clean';
    if (_recentLogs.length >= _maxBufferSize) {
      _recentLogs.removeFirst();
    }
    _recentLogs.addLast(line);
    if (kDebugMode) {
      debugPrint(line);
    }
  }

  void clear() => _recentLogs.clear();
}

class _RedactionRule {
  const _RedactionRule(this.pattern, this.replacer);
  final RegExp pattern;
  final String Function(Match) replacer;
}
