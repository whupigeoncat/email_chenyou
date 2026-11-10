import 'dart:math' as math;

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Conservative, pure-Dart extraction of one-time verification codes.
///
/// The extractor only returns a code when the surrounding text carries explicit
/// verification semantics. Plain text is preferred; HTML is only used as a
/// fallback and is reduced to visible body text first. Multiple different
/// candidates are treated as ambiguous and deliberately produce no code.
class VerificationCodeExtractor {
  const VerificationCodeExtractor();

  static final RegExp _candidatePattern = RegExp(
    r'(?<![A-Za-z0-9])'
    r'(?:'
    r'G-(\d{6})'
    r'|(\d{3,4})[ \u00a0-](\d{3,4})'
    r'|(\d{4,8})'
    r'|([A-Z0-9]{5,8})'
    r')'
    r'(?![A-Za-z0-9])',
  );

  static final RegExp _strongKeyword = RegExp(
    r'验证码|校验码|确认码|认证码|动态码|动态密码|一次性密码|一次性验证码|'
    r'安全码|登录码|短信验证码|驗證碼|驗證代碼|'
    r'\b(?:verification|confirmation|security|authentication|login|'
    r'sign[\s-]?in|one[\s-]?time)\s+(?:code|pin|password)\b|'
    r'\b(?:otp|2fa|mfa|passcode)\b',
    caseSensitive: false,
  );

  static final RegExp _genericCodeWord = RegExp(
    r'\b(?:code|pin)\b',
    caseSensitive: false,
  );

  static final RegExp _verificationAction = RegExp(
    r'\b(?:sign[\s-]?in|log[\s-]?in|login|verify|confirm|'
    r'one[\s-]?time|otp|2fa|mfa|password)\b|'
    r'验证|校验|登录|登陆|认证|确认|动态|一次性',
    caseSensitive: false,
  );

  static final RegExp _disqualifyingLabel = RegExp(
    r'(?:订单(?:号|编号)?|单号|流水号|交易号|编号|快递单号|物流单号|运单号|'
    r'手机号|手机|电话号码|电话|座机|日期|时间|金额|价格|发票号|参考号|'
    r'链接|网址|'
    r'\b(?:order|coupon|promo|discount|zip|postal|phone|tel|date|time|'
    r'amount|price|invoice|tracking|reference|serial|booking|sku|product|'
    r'model|version)\b)'
    r'(?:\s*(?:number|no\.?|id|code|#|:|：|-))?'
    r'(?:\s*(?:is|are|was|were|为|是))?\s*$',
    caseSensitive: false,
  );

  static final RegExp _phoneNumber = RegExp(
    r'(?<!\d)(?:\+?\d{1,3}[\s-]?)?'
    r'(?:1[3-9]\d[\s-]?\d{4}[\s-]?\d{4}|'
    r'0\d{2,3}[\s-]?\d{7,8}|'
    r'400[\s-]?\d{3}[\s-]?\d{4}|'
    r'\d{3}[\s-]\d{3}[\s-]\d{4})'
    r'(?!\d)',
  );

  static final RegExp _url = RegExp(
    r'''(?:https?://|www\.)[^\s<>"']+''',
    caseSensitive: false,
  );

  static final RegExp _contactAddress = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
  );

  static final RegExp _queryPair = RegExp(
    r'''[?&][A-Za-z0-9_.~%-]+=[^\s&<>"']*''',
  );

  static final RegExp _quoteStart = RegExp(
    r'^\s*(?:>|--+\s*(?:Original Message|原始邮件|转发的邮件|转发邮件|'
    r'Forwarded message)\s*--+|On\b[^\n]{0,160}\bwrote\s*:|'
    r'在\s*[^\n]{0,120}\s*写道\s*[:：])',
    caseSensitive: false,
    multiLine: true,
  );

  static final RegExp _quotedHeader = RegExp(
    r'^\s*(?:From|发件人)\s*[:：][^\n]*\n'
    r'(?:[^\n]*\n){0,4}?\s*(?:Sent|Date|发送时间|时间|To|收件人|Subject|主题)'
    r'\s*[:：]',
    caseSensitive: false,
    multiLine: true,
  );

  static final RegExp _dateLikeDigits = RegExp(
    r'^(?:19|20)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])$',
  );

  static final RegExp _hiddenStyle = RegExp(
    r'(?:^|;)\s*(?:display\s*:\s*none|visibility\s*:\s*hidden|'
    r'opacity\s*:\s*0(?:\.0+)?\s*(?:;|$)|'
    r'max-height\s*:\s*0(?:px)?\s*(?:;|$)|'
    r'mso-hide\s*:\s*all)',
    caseSensitive: false,
  );

  static const Set<String> _hiddenTags = <String>{
    'head',
    'script',
    'style',
    'title',
    'meta',
    'link',
    'base',
    'noscript',
    'template',
    'svg',
    'math',
    'iframe',
    'object',
    'embed',
    'canvas',
  };

  static const Set<String> _blockTags = <String>{
    'address',
    'article',
    'aside',
    'blockquote',
    'dd',
    'div',
    'dl',
    'dt',
    'fieldset',
    'figcaption',
    'figure',
    'footer',
    'form',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'header',
    'li',
    'main',
    'nav',
    'ol',
    'p',
    'pre',
    'section',
    'table',
    'tbody',
    'td',
    'tfoot',
    'th',
    'thead',
    'tr',
    'ul',
  };

  /// Returns the single unambiguous verification code, or `null`.
  ///
  /// [plainBody] is the complete plain-text body when available. [htmlBody] is
  /// only consulted when plain text does not yield a usable code, and never
  /// contributes hidden or quoted content. Callers must not pass a truncated
  /// snippet as [plainBody].
  String? extract({
    required String subject,
    String? plainBody,
    String? htmlBody,
  }) {
    final plain = plainBody?.trim();
    if (plain != null && plain.isNotEmpty) {
      final result = _extractFromText('$subject\n$plain');
      if (result.ambiguous) return null;
      if (result.code != null) return result.code;
    }

    final html = htmlBody?.trim();
    if (html != null && html.isNotEmpty) {
      final visible = visibleTextFromHtml(html);
      final result = _extractFromText('$subject\n$visible');
      if (result.ambiguous) return null;
      if (result.code != null) return result.code;
    }

    if (plain == null || plain.isEmpty) {
      final result = _extractFromText(subject);
      if (result.ambiguous) return null;
      return result.code;
    }
    return null;
  }

  /// Extracts visible body text for HTML mail.
  ///
  /// Head, script, style, hidden nodes and non-body scaffolding are excluded.
  /// Block boundaries become line breaks so adjacent table cells cannot merge
  /// into a fake code.
  static String visibleTextFromHtml(String html) {
    final document = html_parser.parse(html);
    final root = document.body ?? document.documentElement;
    if (root == null) return '';
    final buffer = StringBuffer();
    _writeVisibleText(root, buffer);
    final normalized = buffer
        .toString()
        .replaceAll(RegExp(r'[ \t\f\v\u00a0]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return normalized;
  }

  static void _writeVisibleText(dom.Node node, StringBuffer buffer) {
    if (node is dom.Text) {
      buffer.write(node.data);
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName?.toLowerCase();
    if (tag == null ||
        _hiddenTags.contains(tag) ||
        _isQuotedContainer(node) ||
        _isHidden(node)) {
      return;
    }
    if (tag == 'br') {
      buffer.write('\n');
      return;
    }
    final block = _blockTags.contains(tag);
    if (block) buffer.write('\n');
    for (final child in node.nodes) {
      _writeVisibleText(child, buffer);
    }
    if (block) buffer.write('\n');
  }

  static bool _isHidden(dom.Element element) {
    if (element.attributes.containsKey('hidden')) return true;
    if (element.attributes['aria-hidden']?.toLowerCase() == 'true') {
      return true;
    }
    final style = element.attributes['style'];
    return style != null && _hiddenStyle.hasMatch(style);
  }

  static bool _isQuotedContainer(dom.Element element) {
    final tag = element.localName?.toLowerCase();
    if (tag == 'blockquote') return true;
    final classes = element.attributes['class']?.toLowerCase() ?? '';
    if (classes.isEmpty) return false;
    return classes.contains('gmail_quote') ||
        classes.contains('yahoo_quoted') ||
        classes.contains('moz-cite-prefix');
  }

  static _TextExtraction _extractFromText(String input) {
    var text = input;
    final quote = _quoteStart.firstMatch(text);
    if (quote != null) {
      text = text.substring(0, quote.start);
    }
    final quotedHeader = _quotedHeader.firstMatch(text);
    if (quotedHeader != null) {
      text = text.substring(0, quotedHeader.start);
    }

    text = text
        .replaceAll(_url, ' ')
        .replaceAll(_contactAddress, ' ')
        .replaceAll(_queryPair, ' ')
        .replaceAll(_phoneNumber, ' ');

    final codes = <String>{};
    for (final match in _candidatePattern.allMatches(text)) {
      final google = match.group(1);
      final firstGroup = match.group(2);
      final secondGroup = match.group(3);
      final numeric = match.group(4);
      final mixed = match.group(5);

      late final String canonical;
      var googleFormat = false;
      var mixedFormat = false;
      if (google != null) {
        canonical = google;
        googleFormat = true;
      } else if (firstGroup != null && secondGroup != null) {
        canonical = '$firstGroup$secondGroup';
      } else if (numeric != null) {
        canonical = numeric;
      } else if (mixed != null) {
        canonical = mixed;
        mixedFormat = true;
      } else {
        continue;
      }

      if (canonical.length < 4 || canonical.length > 8) continue;
      if (mixedFormat && !_isMixedCode(canonical)) continue;
      if (_looksLikeDate(text, match.start, match.end)) continue;
      if (_dateLikeDigits.hasMatch(canonical)) continue;
      if (_hasDisqualifyingLabel(text, match.start)) continue;
      if (!_hasVerificationContext(
        text,
        match.start,
        match.end,
        googleFormat: googleFormat,
      )) {
        continue;
      }
      codes.add(canonical);
    }

    if (codes.length > 1) return const _TextExtraction(ambiguous: true);
    return _TextExtraction(code: codes.isEmpty ? null : codes.first);
  }

  static bool _isMixedCode(String token) {
    var letters = 0;
    var digits = 0;
    for (final unit in token.codeUnits) {
      if (unit >= 0x41 && unit <= 0x5A) {
        letters++;
      } else if (unit >= 0x30 && unit <= 0x39) {
        digits++;
      } else {
        return false;
      }
    }
    return letters >= 1 && digits >= 2;
  }

  static bool _hasVerificationContext(
    String text,
    int start,
    int end, {
    required bool googleFormat,
  }) {
    final from = math.max(0, start - 60);
    final to = math.min(text.length, end + 60);
    final context = text.substring(from, to);
    if (_strongKeyword.hasMatch(context)) return true;
    final hasCodeWord = googleFormat || _genericCodeWord.hasMatch(context);
    return hasCodeWord && _verificationAction.hasMatch(context);
  }

  static bool _hasDisqualifyingLabel(String text, int start) {
    final from = math.max(0, start - 40);
    return _disqualifyingLabel.hasMatch(text.substring(from, start));
  }

  static bool _looksLikeDate(String text, int start, int end) {
    final before = text.substring(math.max(0, start - 8), start);
    final after = text.substring(end, math.min(text.length, end + 8));
    if (RegExp(r'\d{2,4}\s*[-/.年]\s*$').hasMatch(before)) return true;
    if (RegExp(r'^\s*[-/.月]\s*\d{1,2}').hasMatch(after)) return true;
    if (RegExp(r'^\s*年\s*\d{1,2}\s*月').hasMatch(after)) return true;
    return false;
  }
}

class _TextExtraction {
  const _TextExtraction({this.code, this.ambiguous = false});

  final String? code;
  final bool ambiguous;
}
