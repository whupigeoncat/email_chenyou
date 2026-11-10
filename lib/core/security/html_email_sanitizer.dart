import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Result of applying the zero-trust HTML email policy.
class HtmlSanitizeResult {
  const HtmlSanitizeResult({
    required this.html,
    this.remoteImageCount = 0,
    this.blockedRemoteImages = 0,
    this.remoteCssCount = 0,
    this.blockedRemoteCss = 0,
    this.backgroundColor,
    this.textColor,
    this.firstTextColor,
    this.direction,
  });

  final String html;
  final int remoteImageCount;
  final int blockedRemoteImages;
  final int remoteCssCount;
  final int blockedRemoteCss;

  /// Sanitized `<body>` background color, when the email declares one.
  final String? backgroundColor;

  /// Sanitized `<body>` text color, when the email declares one.
  final String? textColor;

  /// First explicit text color found in the document. Used only as a
  /// readability hint when the email has no body-level color.
  final String? firstTextColor;

  /// Sanitized body text direction: `ltr`, `rtl` or `auto`.
  final String? direction;

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

  static final RegExp _hexColor = RegExp(r'^#([0-9a-f]{3,8})$');
  static final RegExp _rgbColor = RegExp(
    r'^rgba?\(\s*([0-9.]+%?)\s*[, ]\s*([0-9.]+%?)\s*[, ]\s*([0-9.]+%?)'
    r'\s*(?:[,/]\s*([0-9.]+%?)\s*)?\)$',
    caseSensitive: false,
  );
  static final RegExp _anyColorToken = RegExp(
    r'#[0-9a-f]{3,8}\b|rgba?\([^)]*\)|\b(?:aqua|black|blue|fuchsia|gray|grey|'
    r'green|lime|maroon|navy|olive|orange|purple|red|silver|teal|white|'
    r'yellow)\b',
    caseSensitive: false,
  );

  static const Map<String, int> _namedColors = <String, int>{
    'black': 0xFF000000,
    'silver': 0xFFC0C0C0,
    'gray': 0xFF808080,
    'grey': 0xFF808080,
    'white': 0xFFFFFFFF,
    'maroon': 0xFF800000,
    'red': 0xFFFF0000,
    'purple': 0xFF800080,
    'fuchsia': 0xFFFF00FF,
    'green': 0xFF008000,
    'lime': 0xFF00FF00,
    'olive': 0xFF808000,
    'yellow': 0xFFFFFF00,
    'navy': 0xFF000080,
    'blue': 0xFF0000FF,
    'teal': 0xFF008080,
    'aqua': 0xFF00FFFF,
    'orange': 0xFFFFA500,
  };

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

    final elements = <dom.Element>[
      root,
      ...root.querySelectorAll('*').whereType<dom.Element>(),
    ];

    for (final element in elements) {
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
          allowDataImage: name == 'src' || name == 'background',
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

    // The body element itself is sanitized above, but its background, text
    // color and direction are otherwise lost when only `body.innerHtml` is
    // rendered. Re-emit them on a wrapper so the email keeps its original
    // reading canvas without restoring arbitrary head CSS.
    final bodyElement = body is dom.Element ? body : null;
    final presentation = bodyElement == null
        ? const _BodyPresentation()
        : _readBodyPresentation(bodyElement);
    // The reader paints the solid body color on its canvas (compositing any
    // alpha), so only non-solid decoration stays on the wrapper. Emitting the
    // background color here as well would blend a translucent color twice.
    final wrapperStyle = <String>[
      if (presentation.backgroundImage != null)
        'background-image:url("${_escapeCssUrl(presentation.backgroundImage!)}")',
    ];
    final inner = body?.innerHtml ?? document.documentElement?.outerHtml ?? '';
    String wrapped;
    if (wrapperStyle.isEmpty && presentation.direction == null) {
      wrapped = inner;
    } else {
      // Serialize through the DOM instead of interpolating attribute strings.
      // The HTML serializer owns attribute escaping, so malformed quotes in an
      // email-supplied URL cannot break out of `style` or inject attributes.
      final wrapper = dom.Element.tag('div');
      if (presentation.direction != null) {
        wrapper.attributes['dir'] = presentation.direction!;
      }
      if (wrapperStyle.isNotEmpty) {
        wrapper.attributes['style'] = wrapperStyle.join(';');
      }
      wrapper.innerHtml = inner;
      wrapped = wrapper.outerHtml;
    }

    return HtmlSanitizeResult(
      html: wrapped,
      remoteImageCount: remoteImageCount,
      blockedRemoteImages: blockedRemoteImages,
      remoteCssCount: remoteCssCount,
      blockedRemoteCss: blockedRemoteCss,
      backgroundColor: presentation.backgroundColor,
      textColor: presentation.textColor,
      firstTextColor:
          _firstDeclaredTextColor(elements) ?? presentation.textColor,
      direction: presentation.direction,
    );
  }

  /// Parses a narrow, CSS-color-only syntax into an ARGB integer.
  ///
  /// Values outside the recognized color grammar return `null`; this is used
  /// to validate body colors before they are put back into rendered HTML.
  static int? parseCssColor(String? input) {
    if (input == null) return null;
    final value = input.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value == 'transparent') return 0x00000000;
    final named = _namedColors[value];
    if (named != null) return named;

    final hex = _hexColor.firstMatch(value);
    if (hex != null) {
      final digits = hex.group(1)!;
      int channel(int index, int length) {
        final part = digits.substring(index, index + length);
        return length == 1
            ? int.parse('$part$part', radix: 16)
            : int.parse(part, radix: 16);
      }

      switch (digits.length) {
        case 3:
          return 0xFF000000 |
              (channel(0, 1) << 16) |
              (channel(1, 1) << 8) |
              channel(2, 1);
        case 4:
          return (channel(3, 1) << 24) |
              (channel(0, 1) << 16) |
              (channel(1, 1) << 8) |
              channel(2, 1);
        case 6:
          return 0xFF000000 | int.parse(digits, radix: 16);
        case 8:
          // CSS #RRGGBBAA ordering.
          final rgb = int.parse(digits.substring(0, 6), radix: 16);
          final alpha = int.parse(digits.substring(6), radix: 16);
          return (alpha << 24) | rgb;
      }
    }

    final rgb = _rgbColor.firstMatch(value);
    if (rgb == null) return null;
    int? component(String? raw, {int max = 255}) {
      if (raw == null) return null;
      final isPercent = raw.endsWith('%');
      final number = double.tryParse(
        isPercent ? raw.substring(0, raw.length - 1) : raw,
      );
      if (number == null || number.isNaN || number.isInfinite) return null;
      final scaled = isPercent ? number * max / 100 : number;
      if (scaled < 0) return null;
      return scaled.round().clamp(0, max);
    }

    final red = component(rgb.group(1));
    final green = component(rgb.group(2));
    final blue = component(rgb.group(3));
    if (red == null || green == null || blue == null) return null;
    final alphaRaw = rgb.group(4);
    final alpha = alphaRaw == null
        ? 255
        : alphaRaw.endsWith('%')
        ? component(alphaRaw, max: 255)
        : (double.tryParse(alphaRaw) ?? 1) * 255;
    final alphaByte = alpha == null ? 255 : alpha.round().clamp(0, 255);
    return (alphaByte << 24) | (red << 16) | (green << 8) | blue;
  }

  static String? _canonicalColor(String? value) {
    final argb = parseCssColor(value);
    if (argb == null) return null;
    final alpha = (argb >> 24) & 0xFF;
    if (alpha == 0) return 'transparent';
    final rgb = (argb & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toLowerCase();
    if (alpha == 255) return '#$rgb';
    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;
    return 'rgba($red,$green,$blue,${(alpha / 255).toStringAsFixed(3)})';
  }

  static String? _canonicalColorFromValue(String? value) {
    if (value == null || value.isEmpty) return null;
    // Color nodes in a shorthand background are outside `url(...)`; never
    // mistake a color-like word inside a URL path for the canvas color.
    final withoutUrls = value.replaceAll(_cssUrl, ' ');
    final direct = _canonicalColor(withoutUrls);
    if (direct != null) return direct;
    final match = _anyColorToken.firstMatch(withoutUrls);
    return match == null ? null : _canonicalColor(match.group(0));
  }

  /// Splits a style attribute without breaking `data:` URLs, whose payload
  /// contains semicolons inside `url(...)` / quoted strings.
  static Iterable<String> _splitDeclarations(String style) sync* {
    var start = 0;
    var quote = 0;
    var parentheses = 0;
    for (var index = 0; index < style.length; index++) {
      final char = style[index];
      final code = char.codeUnitAt(0);
      if (quote != 0) {
        if (code == 0x5C) {
          index++;
        } else if (code == quote) {
          quote = 0;
        }
        continue;
      }
      if (code == 0x22 || code == 0x27) {
        quote = code;
      } else if (code == 0x28) {
        parentheses++;
      } else if (code == 0x29 && parentheses > 0) {
        parentheses--;
      } else if (code == 0x3B && parentheses == 0) {
        yield style.substring(start, index);
        start = index + 1;
      }
    }
    if (start < style.length) yield style.substring(start);
  }

  static String? _declaration(String style, String property) {
    for (final part in _splitDeclarations(style)) {
      final separator = part.indexOf(':');
      if (separator <= 0) continue;
      if (part.substring(0, separator).trim().toLowerCase() != property) {
        continue;
      }
      final value = part.substring(separator + 1).trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static _BodyPresentation _readBodyPresentation(dom.Element body) {
    final style = body.attributes['style'] ?? '';
    var textColor = _canonicalColor(_declaration(style, 'color'));
    var backgroundColor = _canonicalColor(
      _declaration(style, 'background-color'),
    );
    backgroundColor ??= _canonicalColorFromValue(
      _declaration(style, 'background'),
    );

    String? backgroundImage;
    for (final declaration in <String?>[
      _declaration(style, 'background-image'),
      _declaration(style, 'background'),
    ]) {
      if (declaration == null) continue;
      final match = _cssUrl.firstMatch(declaration);
      if (match == null) continue;
      final candidate = _normalizeCssTarget(
        match.group(1) ?? match.group(2) ?? match.group(3) ?? '',
      );
      if (candidate.isNotEmpty) {
        backgroundImage = candidate;
        break;
      }
    }
    final attributeImage = body.attributes['background'];
    if (backgroundImage == null &&
        attributeImage != null &&
        attributeImage.isNotEmpty) {
      backgroundImage = attributeImage;
    }

    textColor ??= _canonicalColor(body.attributes['text']);
    backgroundColor ??= _canonicalColor(body.attributes['bgcolor']);

    String? direction;
    final styleDirection = _declaration(style, 'direction')?.toLowerCase();
    final attributeDirection = body.attributes['dir']?.trim().toLowerCase();
    for (final candidate in <String?>[styleDirection, attributeDirection]) {
      if (candidate == 'ltr' || candidate == 'rtl' || candidate == 'auto') {
        direction = candidate;
        break;
      }
    }

    return _BodyPresentation(
      backgroundColor: backgroundColor,
      textColor: textColor,
      backgroundImage: backgroundImage,
      direction: direction,
    );
  }

  static String? _firstDeclaredTextColor(List<dom.Element> elements) {
    for (final element in elements) {
      final style = element.attributes['style'];
      if (style != null && style.isNotEmpty) {
        final color = _canonicalColor(_declaration(style, 'color'));
        if (color != null) return color;
      }
      // Legacy mail uses <font color="#000">; it has no inline style.
      final legacy = _canonicalColor(element.attributes['color']);
      if (legacy != null) return legacy;
    }
    return null;
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
      final descriptor = value.substring(urlStart + url.length, index).trim();
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
    value = value.replaceAllMapped(RegExp(r'\\([0-9a-fA-F]{1,6})\s?'), (match) {
      final codePoint = int.tryParse(match.group(1)!, radix: 16);
      return codePoint == null ? '' : String.fromCharCode(codePoint);
    });
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

  static String? _findCidCaseInsensitive(Map<String, String> map, String cid) {
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

class _BodyPresentation {
  const _BodyPresentation({
    this.backgroundColor,
    this.textColor,
    this.backgroundImage,
    this.direction,
  });

  final String? backgroundColor;
  final String? textColor;
  final String? backgroundImage;
  final String? direction;
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
  }) => inspect(
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
    return canonicalHost == domain || canonicalHost.endsWith('.$domain');
  }
}
