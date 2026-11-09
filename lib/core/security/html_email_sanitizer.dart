import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

/// Result of applying the zero-trust HTML email policy.
class HtmlSanitizeResult {
  const HtmlSanitizeResult({
    required this.html,
    this.remoteImageCount = 0,
    this.blockedRemoteImages = 0,
    this.remoteCssCount = 0,
    this.blockedRemoteCss = 0,
  });

  final String html;
  final int remoteImageCount;
  final int blockedRemoteImages;
  final int remoteCssCount;
  final int blockedRemoteCss;

  bool get hasRemoteContent => remoteImageCount + remoteCssCount > 0;

  int get blockedRemoteContent => blockedRemoteImages + blockedRemoteCss;
}

/// Pure-Dart HTML sanitizer used before HTML is handed to a renderer.
///
/// Resource URLs use a strict allow-list: CID, safe raster data images, and
/// (only after explicit consent) strictly parsed http/https URLs. Everything
/// else is removed, including backslash and malformed URL variants.
class HtmlEmailSanitizer {
  const HtmlEmailSanitizer();

  static const Set<String> _forbiddenTags = <String>{
    'script',
    'iframe',
    'object',
    'embed',
    'form',
    'input',
    'button',
    'textarea',
    'select',
    'option',
    'base',
    'link',
    'meta',
    'style',
    'svg',
    'math',
    'template',
    'noscript',
  };

  static const Set<String> _resourceAttributes = <String>{
    'src',
    'poster',
    'background',
    'xlink:href',
    'lowsrc',
    'dynsrc',
  };

  static final RegExp _cssUrl = RegExp(
    r'''url\(\s*(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'|([^)]*))\s*\)''',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _safeDataImage = RegExp(
    r'^data:image/(?:png|jpe?g|gif|webp|bmp);base64,',
    caseSensitive: false,
  );

  /// Normalizes URL-ish text before any security decision.
  ///
  /// Removes ASCII controls including spaces/DEL and converts every backslash
  /// to `/`. This deliberately makes `https:\\evil` and `http:\evil`
  /// indistinguishable from their slash-based variants before validation.
  static String normalizeUrl(String input) {
    return input
        .replaceAll(RegExp(r'[\u0000-\u0020\u007f]'), '')
        .replaceAll('\\', '/')
        .trim();
  }

  HtmlSanitizeResult sanitize({
    required String html,
    bool allowRemoteImages = false,
    bool trustedSender = false,
    Map<String, String> cidToLocalPath = const <String, String>{},
  }) {
    final allowRemote = allowRemoteImages || trustedSender;
    var remoteImageCount = 0;
    var blockedRemoteImages = 0;
    var remoteCssCount = 0;
    var blockedRemoteCss = 0;

    final document = html_parser.parse(html);
    final body = document.body;
    final root = body ?? document.documentElement;
    if (root == null) {
      return const HtmlSanitizeResult(html: '');
    }

    for (final element in root.querySelectorAll(_forbiddenTags.join(','))) {
      if (element.localName == 'style') {
        _sanitizeCss(
          element.text,
          allowRemote: allowRemote,
          onRemote: () => remoteCssCount++,
          onBlocked: () => blockedRemoteCss++,
        );
      }
      element.remove();
    }

    for (final element in root.querySelectorAll('*')) {
      final tag = element.localName?.toLowerCase() ?? '';
      for (final attribute in element.attributes.keys.toList()) {
        final name = attribute.toString().toLowerCase();
        final value = element.attributes[attribute] ?? '';

        if (name.startsWith('on') ||
            name == 'srcdoc' ||
            name == 'formaction' ||
            name == 'action' ||
            name == 'method') {
          element.attributes.remove(attribute);
          continue;
        }

        if (name == 'style') {
          final sanitized = _sanitizeCss(
            value,
            allowRemote: allowRemote,
            onRemote: () => remoteCssCount++,
            onBlocked: () => blockedRemoteCss++,
          );
          if (sanitized.trim().isEmpty) {
            element.attributes.remove(attribute);
          } else {
            element.attributes[attribute] = sanitized;
          }
          continue;
        }

        if (name == 'srcset') {
          final sanitized = _sanitizeSrcset(
            value,
            allowRemote: allowRemote,
            cidToLocalPath: cidToLocalPath,
            onRemote: () => remoteImageCount++,
            onBlocked: () => blockedRemoteImages++,
          );
          if (sanitized == null || sanitized.trim().isEmpty) {
            element.attributes.remove(attribute);
          } else {
            element.attributes[attribute] = sanitized;
          }
          continue;
        }

        if (name == 'href') {
          final normalized = normalizeUrl(value);
          final lower = normalized.toLowerCase();
          if (_isDangerousScheme(lower)) {
            element.attributes.remove(attribute);
            continue;
          }
          final remoteUri = _tryRemoteUri(normalized);
          if (remoteUri != null) {
            element.attributes[attribute] = remoteUri.toString();
            continue;
          }
          if (normalized.startsWith('#')) {
            element.attributes[attribute] = normalized;
            continue;
          }
          // Relative links carry no remote-load risk. Keep them for anchors
          // and ordinary relative navigation; tapping still goes through the
          // LinkPhishingGuard.
          if (!normalized.contains(':')) {
            element.attributes[attribute] = normalized;
          } else {
            element.attributes.remove(attribute);
          }
          continue;
        }

        if (!_resourceAttributes.contains(name)) {
          continue;
        }

        final sanitized = _sanitizeResourceUrl(
          value,
          allowRemote: allowRemote,
          allowDataImage: name == 'src',
          onRemote: () => remoteImageCount++,
          onBlocked: () => blockedRemoteImages++,
          cidToLocalPath: cidToLocalPath,
        );
        if (sanitized == null) {
          element.attributes.remove(attribute);
        } else {
          element.attributes[attribute] = sanitized;
        }
      }

      if (tag == 'img' && !element.attributes.containsKey('src')) {
        element.attributes['alt'] = element.attributes['alt'] ?? '';
      }
    }

    return HtmlSanitizeResult(
      html: body?.innerHtml ?? document.documentElement?.outerHtml ?? '',
      remoteImageCount: remoteImageCount,
      blockedRemoteImages: blockedRemoteImages,
      remoteCssCount: remoteCssCount,
      blockedRemoteCss: blockedRemoteCss,
    );
  }

  String? _sanitizeResourceUrl(
    String value, {
    required bool allowRemote,
    required bool allowDataImage,
    required VoidCallback onRemote,
    required VoidCallback onBlocked,
    required Map<String, String> cidToLocalPath,
  }) {
    final normalized = normalizeUrl(value);
    if (normalized.isEmpty) return null;
    final lower = normalized.toLowerCase();

    if (lower.startsWith('cid:')) {
      final cid = _normalizeCid(normalized.substring(4));
      final local = _findCidCaseInsensitive(cidToLocalPath, cid);
      if (local == null || local.isEmpty) return null;
      return local.startsWith('file:') ? local : Uri.file(local).toString();
    }

    if (lower.startsWith('data:')) {
      if (allowDataImage && _safeDataImage.hasMatch(lower)) {
        return normalized;
      }
      return null;
    }

    if (_isDangerousScheme(lower)) {
      onBlocked();
      return null;
    }

    final remoteUri = _tryRemoteUri(normalized);
    if (remoteUri != null) {
      onRemote();
      if (allowRemote) return remoteUri.toString();
      onBlocked();
      return null;
    }

    final remoteLike = _looksRemote(normalized);
    if (remoteLike) {
      onRemote();
      if (!allowRemote) onBlocked();
    } else if (!allowRemote) {
      // Unknown/relative resource: strict deny-list plus explicit remote
      // accounting, as required for tracking pixels and malformed URLs.
      onRemote();
      onBlocked();
    }
    return null;
  }

  String? _sanitizeSrcset(
    String value, {
    required bool allowRemote,
    required Map<String, String> cidToLocalPath,
    required VoidCallback onRemote,
    required VoidCallback onBlocked,
  }) {
    final candidates = _parseSrcset(value);
    final safe = <String>[];
    for (final candidate in candidates) {
      final sanitized = _sanitizeResourceUrl(
        candidate.url,
        allowRemote: allowRemote,
        allowDataImage: true,
        onRemote: onRemote,
        onBlocked: onBlocked,
        cidToLocalPath: cidToLocalPath,
      );
      if (sanitized != null) {
        safe.add(
          candidate.descriptor.isEmpty
              ? sanitized
              : '$sanitized ${candidate.descriptor}',
        );
      }
    }
    return safe.isEmpty ? null : safe.join(', ');
  }

  List<_SrcsetCandidate> _parseSrcset(String value) {
    final result = <_SrcsetCandidate>[];
    var index = 0;
    final length = value.length;

    while (index < length) {
      while (index < length &&
          (value[index] == ',' || _isCssWhitespace(value[index]))) {
        index++;
      }
      if (index >= length) break;

      final urlStart = index;
      final isData = value.substring(index).toLowerCase().startsWith('data:');
      if (isData) {
        while (index < length && !_isCssWhitespace(value[index])) {
          index++;
        }
      } else {
        while (index < length &&
            value[index] != ',' &&
            !_isCssWhitespace(value[index])) {
          index++;
        }
      }
      final url = value.substring(urlStart, index);
      while (index < length &&
          value[index] != ',' &&
          value[index] != '\n' &&
          value[index] != '\r') {
        index++;
      }
      final descriptor = value
          .substring(
            urlStart + url.length,
            index,
          )
          .trim();
      if (url.isNotEmpty) {
        result.add(_SrcsetCandidate(url, descriptor));
      }
      if (index < length && value[index] == ',') index++;
    }
    return result;
  }

  String _sanitizeCss(
    String css, {
    required bool allowRemote,
    required VoidCallback onRemote,
    required VoidCallback onBlocked,
  }) {
    var sanitized = css.replaceAllMapped(_cssUrl, (match) {
      final raw = match.group(1) ?? match.group(2) ?? match.group(3) ?? '';
      final normalized = _normalizeCssTarget(raw);
      final lower = normalized.toLowerCase();

      if (_isDangerousScheme(lower) || normalized.contains('expression(')) {
        onBlocked();
        return 'none';
      }

      if (lower.startsWith('data:')) {
        if (_safeDataImage.hasMatch(lower)) {
          return 'url("${_escapeCssUrl(normalized)}")';
        }
        onBlocked();
        return 'none';
      }

      if (lower.startsWith('cid:')) {
        return 'none';
      }

      final remoteUri = _tryRemoteUri(normalized);
      if (remoteUri != null) {
        onRemote();
        if (allowRemote) {
          return 'url("${_escapeCssUrl(remoteUri.toString())}")';
        }
        onBlocked();
        return 'none';
      }

      if (normalized.isNotEmpty) {
        if (!allowRemote) {
          onRemote();
          onBlocked();
        }
        return 'none';
      }
      return 'none';
    });

    // CSS expressions are never needed for email rendering and are dangerous
    // even when they do not contain a url(...) token.
    sanitized = sanitized.replaceAll(
      RegExp(r'expression\s*\([^)]*\)', caseSensitive: false),
      'none',
    );
    return sanitized;
  }

  static String _normalizeCssTarget(String raw) {
    var value = raw;
    // Decode simple CSS hexadecimal escapes before normalizing slashes.
    value = value.replaceAllMapped(
      RegExp(r'\\([0-9a-fA-F]{1,6})\s?'),
      (match) {
        final codePoint = int.tryParse(match.group(1)!, radix: 16);
        return codePoint == null ? '' : String.fromCharCode(codePoint);
      },
    );
    value = value.replaceAll(RegExp(r'\\(.)'), r'$1');
    return normalizeUrl(value);
  }

  static String _escapeCssUrl(String value) =>
      value.replaceAll('"', '%22').replaceAll(')', '%29');

  static bool _isCssWhitespace(String char) =>
      char == ' ' || char == '\t' || char == '\r' || char == '\n';

  static bool _isDangerousScheme(String lower) {
    return lower.startsWith('javascript:') ||
        lower.startsWith('vbscript:') ||
        lower.startsWith('file:') ||
        lower.startsWith('content:') ||
        lower.contains('expression(');
  }

  static Uri? _tryRemoteUri(String normalized) {
    var candidate = normalized;
    if (candidate.startsWith('//')) {
      candidate = 'https:$candidate';
    }
    final uri = Uri.tryParse(candidate);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    return uri;
  }

  static bool _looksRemote(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http:') ||
        lower.startsWith('https:') ||
        lower.startsWith('//') ||
        lower.contains('://');
  }

  static String _normalizeCid(String value) {
    var cid = value.trim();
    if (cid.startsWith('<')) cid = cid.substring(1);
    if (cid.endsWith('>')) cid = cid.substring(0, cid.length - 1);
    return cid.trim();
  }

  static String? _findCidCaseInsensitive(
    Map<String, String> map,
    String cid,
  ) {
    final lower = cid.toLowerCase();
    for (final entry in map.entries) {
      if (_normalizeCid(entry.key).toLowerCase() == lower) {
        return entry.value;
      }
    }
    return null;
  }
}

class _SrcsetCandidate {
  const _SrcsetCandidate(this.url, this.descriptor);

  final String url;
  final String descriptor;
}

class LinkPhishingDecision {
  const LinkPhishingDecision({
    required this.uri,
    required this.host,
    required this.suspicious,
    required this.blocked,
    required this.reason,
    this.displayDomains = const <String>[],
  });

  final Uri? uri;
  final String host;
  final bool suspicious;
  final bool blocked;
  final String reason;
  final List<String> displayDomains;
}

/// Conservative external-link comparison against the sender domain and the
/// visible anchor text. A display/href domain mismatch wins over sender-domain
/// trust because it is a classic phishing technique.
class LinkPhishingGuard {
  const LinkPhishingGuard();

  static final RegExp _ipLiteral = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$');
  static final RegExp _explicitUrl = RegExp(
    r'''https?://[^\s<>"']+''',
    caseSensitive: false,
  );
  static final RegExp _bareDomain = RegExp(
    r'(?<![A-Za-z0-9@._-])((?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,})(?![A-Za-z0-9._-])',
    caseSensitive: false,
  );

  LinkPhishingDecision inspect(
    String rawUrl, {
    required String senderEmail,
    String? displayText,
  }) {
    final trimmed = HtmlEmailSanitizer.normalizeUrl(rawUrl);
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme.toLowerCase() != 'http' &&
            uri.scheme.toLowerCase() != 'https')) {
      return LinkPhishingDecision(
        uri: uri,
        host: uri?.host ?? '',
        suspicious: true,
        blocked: true,
        reason: '仅允许打开 http/https 链接',
      );
    }

    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (host.isEmpty) {
      return LinkPhishingDecision(
        uri: uri,
        host: host,
        suspicious: true,
        blocked: true,
        reason: '链接缺少有效域名',
      );
    }

    final displayDomains = _extractDisplayDomains(displayText);
    if (displayDomains.isNotEmpty &&
        !displayDomains.any((domain) => _isSameOrSubdomain(host, domain))) {
      return LinkPhishingDecision(
        uri: uri,
        host: host,
        suspicious: true,
        blocked: false,
        reason:
            '域名欺骗：显示链接文本与实际目标域名不一致 '
            '（显示 ${displayDomains.join(", ")}，实际 $host）',
        displayDomains: displayDomains,
      );
    }

    final senderDomain = _senderDomain(senderEmail);
    if (uri.userInfo.isNotEmpty) {
      return LinkPhishingDecision(
        uri: uri,
        host: host,
        suspicious: true,
        blocked: false,
        reason: '链接包含伪装用户名信息',
        displayDomains: displayDomains,
      );
    }
    if (_ipLiteral.hasMatch(host) || host.contains('xn--')) {
      return LinkPhishingDecision(
        uri: uri,
        host: host,
        suspicious:
            senderDomain.isEmpty || !_isSameOrSubdomain(host, senderDomain),
        blocked: false,
        reason: '链接使用 IP 地址或国际化域名，无法确认归属',
        displayDomains: displayDomains,
      );
    }
    if (senderDomain.isEmpty) {
      return LinkPhishingDecision(
        uri: uri,
        host: host,
        suspicious: false,
        blocked: false,
        reason: '发件人域名未知',
        displayDomains: displayDomains,
      );
    }

    final trusted = _isSameOrSubdomain(host, senderDomain);
    final resemblesSender =
        !trusted && host.contains(senderDomain) && senderDomain.contains('.');
    return LinkPhishingDecision(
      uri: uri,
      host: host,
      suspicious: resemblesSender,
      blocked: false,
      reason: trusted
          ? '与发件人域名一致'
          : resemblesSender
              ? '域名包含发件人域名但并非其子域名，疑似钓鱼'
              : '外部域名，请确认后再打开',
      displayDomains: displayDomains,
    );
  }

  bool isSuspicious(
    String rawUrl, {
    required String senderEmail,
    String? displayText,
  }) =>
      inspect(
        rawUrl,
        senderEmail: senderEmail,
        displayText: displayText,
      ).suspicious;

  static List<String> _extractDisplayDomains(String? displayText) {
    if (displayText == null || displayText.trim().isEmpty) return const [];
    final normalizedText = HtmlEmailSanitizer.normalizeUrl(displayText);
    final domains = <String>{};

    for (final match in _explicitUrl.allMatches(normalizedText)) {
      final uri = Uri.tryParse(match.group(0)!);
      final host = uri?.host.toLowerCase();
      if (host != null && host.isNotEmpty) {
        domains.add(_canonicalDomain(host));
      }
    }

    final withoutUrls = normalizedText.replaceAll(_explicitUrl, ' ');
    for (final match in _bareDomain.allMatches(withoutUrls)) {
      final domain = match.group(1);
      if (domain != null && domain.isNotEmpty) {
        domains.add(_canonicalDomain(domain));
      }
    }
    return domains.toList(growable: false);
  }

  static String _canonicalDomain(String domain) {
    final lower = domain.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    return lower.startsWith('www.') ? lower.substring(4) : lower;
  }

  static String _senderDomain(String senderEmail) {
    final at = senderEmail.lastIndexOf('@');
    if (at < 0 || at == senderEmail.length - 1) return '';
    return _canonicalDomain(senderEmail.substring(at + 1).trim());
  }

  static bool _isSameOrSubdomain(String host, String domain) {
    final canonicalHost = _canonicalDomain(host);
    return canonicalHost == domain ||
        canonicalHost.endsWith('.$domain');
  }
}
