import 'dart:async';

import 'package:flutter/foundation.dart' show Factory, mapEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import 'html_email_sanitizer.dart';

/// Block-level containers that must never force the reader wider than the
/// available width because an email author used a fixed pixel width.
const Set<String> _constrainedBlockTags = <String>{
  'div',
  'section',
  'article',
  'main',
  'header',
  'footer',
  'center',
  'blockquote',
  'p',
  'pre',
  'ul',
  'ol',
  'dl',
  'dd',
  'figure',
  'address',
  'aside',
  'nav',
  'form',
};

/// Injectable advanced renderer used by widget tests to avoid a native WebView.
typedef SafeWebViewBuilder = Widget Function(
  BuildContext context,
  String sanitizedHtml,
  Future<bool> Function(String url) onOpenLink,
);

/// Safe HTML renderer with remote-content consent, CID replacement and
/// phishing-aware external link mediation.
class SafeHtmlEmailView extends StatefulWidget {
  const SafeHtmlEmailView({
    super.key,
    required this.html,
    this.senderEmail = '',
    this.allowRemoteImages = false,
    this.trustedSender = false,
    this.cidToLocalPath = const <String, String>{},
    this.onShowRemoteImages,
    this.onTrustSender,
    this.webViewBuilder,
    this.onOpenLink,
    this.autoUseWebViewForComplexTables = true,
  });

  final String html;
  final String senderEmail;
  final bool allowRemoteImages;
  final bool trustedSender;
  final Map<String, String> cidToLocalPath;
  final VoidCallback? onShowRemoteImages;
  final VoidCallback? onTrustSender;
  final SafeWebViewBuilder? webViewBuilder;

  /// Final external-link opener. Called only after the confirmation dialog.
  /// Tests can inject a recording callback; production defaults to url_launcher.
  final Future<bool> Function(String url)? onOpenLink;
  final bool autoUseWebViewForComplexTables;

  /// Finite frame height for the native advanced renderer.
  ///
  /// The widget is commonly placed inside a parent `SingleChildScrollView`,
  /// which gives it an unbounded height. A native WebView must be given a
  /// bounded box so its own scrolling can work; this returns a stable,
  /// viewport-relative height that stays usable on small phones.
  @visibleForTesting
  static double webViewHeightFor(Size viewport) {
    final height = viewport.height;
    if (!height.isFinite || height <= 0) return 480;
    // Short landscape windows still get a usable but not full-screen box.
    return (height * 0.62).clamp(200.0, 720.0);
  }

  /// Content identity for the native renderer. Changing HTML (for example
  /// after remote-image consent or switching messages) must recreate the
  /// WebView because `initialData` is only applied at creation time.
  @visibleForTesting
  static String contentSignature(String html) {
    var hash = 0x811c9dc5;
    for (final unit in html.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return '${html.length}:$hash';
  }

  /// Test-visible counters that prove the per-State processing cache actually
  /// avoids repeating the expensive sanitize/DOM/table work on unrelated
  /// rebuilds. They only increment while asserts are enabled (tests).
  @visibleForTesting
  static int debugSanitizeRuns = 0;

  @visibleForTesting
  static int debugLinkParseRuns = 0;

  @visibleForTesting
  static int debugTableScanRuns = 0;

  @visibleForTesting
  static void resetDebugCounters() {
    debugSanitizeRuns = 0;
    debugLinkParseRuns = 0;
    debugTableScanRuns = 0;
  }

  /// Gives the native platform view the gesture directly.
  ///
  /// The reader is embedded in a parent scroll view. Without an eager
  /// recognizer the parent's vertical drag can win the gesture arena and the
  /// WebView never receives the touch, so long email bodies cannot be
  /// scrolled even though the frame has a finite height.
  @visibleForTesting
  static Set<Factory<OneSequenceGestureRecognizer>>
  buildWebViewGestureRecognizers() {
    return <Factory<OneSequenceGestureRecognizer>>{
      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
    };
  }

  /// Test-visible production WebView baseline.
  @visibleForTesting
  static InAppWebViewSettings buildWebViewSettings() {
    return InAppWebViewSettings(
      javaScriptEnabled: false,
      javaScriptCanOpenWindowsAutomatically: false,
      allowsInlineMediaPlayback: false,
      mediaPlaybackRequiresUserGesture: true,
      // Pinch zoom is a native, script-free escape hatch for wide tables.
      supportZoom: true,
      // Required by the plugin for `shouldOverrideUrlLoading` to fire.
      useShouldOverrideUrlLoading: true,
      allowFileAccess: true,
      allowContentAccess: false,
      allowFileAccessFromFileURLs: false,
      allowUniversalAccessFromFileURLs: false,
      disableContextMenu: true,
      verticalScrollBarEnabled: true,
      horizontalScrollBarEnabled: true,
      // Android hybrid composition inserts a native view whose opacity and
      // transform do not follow the Flutter route transition: during a back
      // gesture the HTML can remain an opaque white rectangle after the
      // header has faded. Texture composition participates in the Flutter
      // layer tree, so the existing route animation and system back gesture
      // stay untouched. The option is ignored on non-Android platforms.
      useHybridComposition: false,
    );
  }

  /// Test-visible CSP wrapper shared by the production WebView and tests.
  @visibleForTesting
  static String buildCspDocument(
    String body, {
    required bool allowRemoteImages,
    String? backgroundColor,
    String? textColor,
  }) {
    final imageSources = allowRemoteImages
        ? "img-src 'self' data: file: http: https:;"
        : "img-src 'self' data: file:;";
    final canvas = <String>[
      if (backgroundColor != null) 'background-color:$backgroundColor;',
      if (textColor != null) 'color:$textColor;',
    ].join();
    return '<!doctype html><html><head><meta charset="utf-8">'
        '<meta name="viewport" '
        'content="width=device-width, initial-scale=1">'
        '<meta http-equiv="Content-Security-Policy" '
        'content="default-src \'none\'; script-src \'none\'; '
        'object-src \'none\'; frame-src \'none\'; base-uri \'none\'; '
        'form-action \'none\'; $imageSources '
        'style-src \'unsafe-inline\';"></head><body style="$canvas">'
        '<style>*{box-sizing:border-box;}'
        'html,body{margin:0;padding:0;}'
        'body{padding:12px;overflow-x:auto;overflow-wrap:anywhere;'
        'word-break:break-word;}'
        'div,section,article,main,header,footer,center,blockquote,p,pre,ul,'
        'ol,dl,dd,figure,address,aside,nav,form{max-width:100%;}'
        'img{max-width:100%;height:auto;}'
        'table{border-collapse:collapse;max-width:100%;}'
        'td,th{word-break:break-word;overflow-wrap:anywhere;}'
        'pre{white-space:pre-wrap;overflow-wrap:anywhere;}</style>'
        '$body</body></html>';
  }

  /// Test-visible navigation policy. The callback always runs and the WebView
  /// navigation itself is always cancelled because external links are opened
  /// by the platform launcher after the phishing confirmation dialog.
  @visibleForTesting
  static Future<NavigationActionPolicy> handleNavigation({
    required String? url,
    required Future<bool> Function(String url) onOpenLink,
  }) async {
    if (url != null && url.isNotEmpty) {
      await onOpenLink(url);
    }
    return NavigationActionPolicy.CANCEL;
  }

  @override
  State<SafeHtmlEmailView> createState() => _SafeHtmlEmailViewState();
}

class _SafeHtmlEmailViewState extends State<SafeHtmlEmailView> {
  final HtmlEmailSanitizer _sanitizer = const HtmlEmailSanitizer();
  final LinkPhishingGuard _linkGuard = const LinkPhishingGuard();
  bool? _webViewOverride;
  Map<String, List<String>> _visibleLinkTexts = const {};
  _ProcessedHtml? _processed;

  bool get _allowRemote => widget.allowRemoteImages || widget.trustedSender;

  @override
  void didUpdateWidget(covariant SafeHtmlEmailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Never let a manual renderer choice leak into another message. The
    // detail page also keys this widget by message id; this is the second
    // line of defence for callers that reuse the state.
    if (oldWidget.html != widget.html ||
        oldWidget.senderEmail != widget.senderEmail) {
      _webViewOverride = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final processed = _processForWidget();
    final result = processed.result;
    _visibleLinkTexts = processed.visibleLinkTexts;
    final complex =
        widget.autoUseWebViewForComplexTables && processed.isComplex;
    final useWebView = _webViewOverride ?? complex;
    final palette = _resolveReadingPalette(context, result);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (result.blockedRemoteContent > 0 && !_allowRemote)
          _RemoteContentBanner(
            blockedCount: result.blockedRemoteContent,
            onShowImages: widget.onShowRemoteImages,
            onTrustSender: widget.onTrustSender,
          ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            if (complex || _webViewOverride != null)
              TextButton.icon(
                key: const Key('toggle-secure-webview'),
                onPressed: () => setState(() => _webViewOverride = !useWebView),
                icon: Icon(
                  useWebView ? Icons.article_outlined : Icons.web_outlined,
                  size: 16,
                ),
                label: Text(useWebView ? '切回安全阅读视图' : '高级表格视图'),
              ),
            if (result.hasRemoteContent)
              Text(
                '远程内容：${result.remoteImageCount + result.remoteCssCount}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        if (useWebView)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              key: const Key('safe-webview-frame'),
              height: SafeHtmlEmailView.webViewHeightFor(
                MediaQuery.sizeOf(context),
              ),
              child: _buildAdvancedRenderer(context, processed, palette),
            ),
          )
        else
          Container(
            key: const Key('safe-html-canvas'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(12),
              border: palette.background == null
                  ? null
                  : Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
            ),
            child: HtmlWidget(
              result.html,
              key: const Key('safe-html-widget'),
              textStyle:
                  (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
                      .copyWith(color: palette.foreground),
              // Email templates commonly set a fixed pixel width (for example
              // a 680px wrapper). Cap block containers so ordinary paragraphs
              // are not forced to scroll sideways just because one table is
              // wide; tables and images keep their own horizontal fallback.
              customStylesBuilder: (element) {
                final tag = element.localName?.toLowerCase();
                if (tag == null) return null;
                if (_constrainedBlockTags.contains(tag)) {
                  return const <String, String>{
                    'max-width': '100%',
                    'box-sizing': 'border-box',
                  };
                }
                if (tag == 'table' || tag == 'img') {
                  return const <String, String>{'max-width': '100%'};
                }
                return null;
              },
              factoryBuilder: () => _SafeLinkWidgetFactory(
                onOpen: (url, text) {
                  unawaited(_confirmAndOpenLink(url, displayText: text));
                },
              ),
              onTapUrl: (url) {
                if (url.startsWith('#')) return false;
                final texts = _visibleLinkTexts[url];
                unawaited(
                  _confirmAndOpenLink(
                    url,
                    displayText: texts != null && texts.isNotEmpty
                        ? texts.first
                        : null,
                  ),
                );
                return true;
              },
            ),
          ),
      ],
    );
  }

  /// Reuses the expensive HTML work for this widget State only.
  ///
  /// Message switches, remote-consent changes and any CID content change must
  /// invalidate it immediately. The CID snapshot is a value copy so a caller
  /// that mutates the same Map in place is still detected.
  _ProcessedHtml _processForWidget() {
    final cached = _processed;
    if (cached != null &&
        (identical(cached.sourceHtml, widget.html) ||
            cached.sourceHtml == widget.html) &&
        cached.allowRemoteImages == widget.allowRemoteImages &&
        cached.trustedSender == widget.trustedSender &&
        mapEquals(cached.cidSnapshot, widget.cidToLocalPath)) {
      return cached;
    }

    final cidSnapshot = Map<String, String>.unmodifiable(
      Map<String, String>.of(widget.cidToLocalPath),
    );
    final result = _sanitizer.sanitize(
      html: widget.html,
      allowRemoteImages: widget.allowRemoteImages,
      trustedSender: widget.trustedSender,
      cidToLocalPath: cidSnapshot,
    );
    assert(() {
      SafeHtmlEmailView.debugSanitizeRuns++;
      return true;
    }());
    final visibleLinkTexts = _extractVisibleLinkTexts(result.html);
    assert(() {
      SafeHtmlEmailView.debugLinkParseRuns++;
      return true;
    }());
    final isComplex = _isComplex(result.html);
    assert(() {
      SafeHtmlEmailView.debugTableScanRuns++;
      return true;
    }());

    final processed = _ProcessedHtml(
      sourceHtml: widget.html,
      allowRemoteImages: widget.allowRemoteImages,
      trustedSender: widget.trustedSender,
      cidSnapshot: cidSnapshot,
      result: result,
      visibleLinkTexts: visibleLinkTexts,
      isComplex: isComplex,
    );
    _processed = processed;
    return processed;
  }

  Widget _buildAdvancedRenderer(
    BuildContext context,
    _ProcessedHtml processed,
    _ReadingPalette palette,
  ) {
    // Native must use the same reading surface as Flutter. Without this, a
    // dark app + white body text would fall back to the WebView's white
    // default and become unreadable.
    final document = processed.nativeDocument(
      allowRemoteImages: _allowRemote,
      backgroundColor: _cssColorOf(
        palette.background ?? Theme.of(context).colorScheme.surface,
      ),
      textColor: _cssColorOf(
        palette.foreground ??
            Theme.of(context).textTheme.bodyMedium?.color ??
            Theme.of(context).colorScheme.onSurface,
      ),
    );
    final builder = widget.webViewBuilder;
    if (builder != null) return builder(context, document, _confirmAndOpenLink);
    return _defaultWebView(
      context,
      document,
      _confirmAndOpenLink,
      signature: processed.nativeSignature,
    );
  }

  /// Resolves an email-local reading canvas. Explicit email colors win; when
  /// the email declares dark text but no background (common in HTML mail) a
  /// light canvas is used instead of forcing a global inversion.
  _ReadingPalette _resolveReadingPalette(
    BuildContext context,
    HtmlSanitizeResult result,
  ) {
    final theme = Theme.of(context);
    // The transparent Flutter canvas shows the Scaffold surface, so contrast
    // decisions use that same surface the native fallback paints.
    final surface = theme.colorScheme.surface;
    final rawBackground = _parseColor(result.backgroundColor);
    // A translucent email background must be composited over the app surface
    // before luminance/contrast decisions, and the same opaque canvas is sent
    // to the native renderer. Fully transparent colors are already `null`.
    final declaredBackground = rawBackground == null || rawBackground.a >= 1
        ? rawBackground
        : Color.alphaBlend(rawBackground, surface);
    final rawText = _parseColor(result.textColor);
    final declaredText = rawText == null || rawText.a >= 1
        ? rawText
        : Color.alphaBlend(rawText, declaredBackground ?? surface);
    final rawProbe = _parseColor(result.firstTextColor);
    final probeText = rawProbe == null || rawProbe.a >= 1
        ? rawProbe
        : Color.alphaBlend(rawProbe, surface);

    if (declaredBackground != null) {
      var foreground = declaredText;
      if (foreground == null ||
          _contrastRatio(foreground, declaredBackground) < 4.5) {
        foreground = _contrastColorFor(declaredBackground);
      }
      return _ReadingPalette(
        background: declaredBackground,
        foreground: foreground,
      );
    }

    if (probeText != null && _contrastRatio(probeText, surface) < 4.5) {
      final canvas = _isLight(probeText) ? Colors.black : Colors.white;
      return _ReadingPalette(
        background: canvas,
        foreground: _contrastColorFor(canvas),
      );
    }

    return _ReadingPalette(background: null, foreground: declaredText);
  }

  static Color? _parseColor(String? cssColor) {
    final argb = HtmlEmailSanitizer.parseCssColor(cssColor);
    // Fully transparent colors mean "no declared canvas"; treating them as
    // black would make contrast decisions wrong.
    if (argb == null || ((argb >> 24) & 0xFF) == 0) return null;
    return Color(argb);
  }

  static bool _isLight(Color color) => color.computeLuminance() > 0.5;

  static Color _contrastColorFor(Color background) =>
      _isLight(background) ? const Color(0xFF1B1B1B) : const Color(0xFFF4F4F4);

  static double _contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  static String? _cssColorOf(Color? color) {
    if (color == null) return null;
    final argb = color.toARGB32();
    final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final alpha = (argb >> 24) & 0xFF;
    if (alpha == 255) return '#$rgb';
    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;
    return 'rgba($red,$green,$blue,${(alpha / 255).toStringAsFixed(3)})';
  }

  Widget _defaultWebView(
    BuildContext context,
    String html,
    Future<bool> Function(String url) onOpenLink, {
    String? signature,
  }) {
    return InAppWebView(
      // `initialData` is only read when the native view is created, so the
      // key includes the content signature. Consent changes and message
      // switches then replace the native content and reset scroll position.
      key: ValueKey(
        'safe-inapp-webview-${signature ?? SafeHtmlEmailView.contentSignature(html)}',
      ),
      initialData: InAppWebViewInitialData(
        data: html,
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: WebUri('about:blank'),
      ),
      initialSettings: SafeHtmlEmailView.buildWebViewSettings(),
      gestureRecognizers: SafeHtmlEmailView.buildWebViewGestureRecognizers(),
      shouldOverrideUrlLoading: (controller, action) {
        return SafeHtmlEmailView.handleNavigation(
          url: action.request.url?.toString(),
          onOpenLink: onOpenLink,
        );
      },
    );
  }

  static Map<String, List<String>> _extractVisibleLinkTexts(String html) {
    final result = <String, List<String>>{};
    final document = html_parser.parse(html);
    for (final anchor in document.querySelectorAll('a')) {
      final href = anchor.attributes['href'];
      final text = anchor.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (href == null || text.isEmpty) continue;
      result.putIfAbsent(href, () => <String>[]).add(text);
    }
    return result;
  }

  bool _isComplex(String html) {
    final tableCount = RegExp(
      '<table[\\s>]',
      caseSensitive: false,
    ).allMatches(html).length;
    return tableCount >= 2 ||
        RegExp('colspan|rowspan', caseSensitive: false).hasMatch(html);
  }

  Future<bool> _confirmAndOpenLink(String rawUrl, {String? displayText}) async {
    final effectiveDisplayText =
        displayText ??
        (_visibleLinkTexts[rawUrl] != null &&
                _visibleLinkTexts[rawUrl]!.isNotEmpty
            ? _visibleLinkTexts[rawUrl]!.first
            : null);
    final decision = _linkGuard.inspect(
      rawUrl,
      senderEmail: widget.senderEmail,
      displayText: effectiveDisplayText,
    );
    if (!mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(decision.blocked ? '已拦截链接' : '打开外部链接？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (effectiveDisplayText != null &&
                effectiveDisplayText.isNotEmpty &&
                effectiveDisplayText != rawUrl) ...[
              Text('显示文本：$effectiveDisplayText'),
              const SizedBox(height: 6),
            ],
            Text(
              '实际目标：${decision.uri?.toString() ?? rawUrl}',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              decision.reason,
              style: TextStyle(
                color: decision.suspicious || decision.blocked
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('cancel-open-link'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-open-link'),
            onPressed: decision.blocked
                ? null
                : () => Navigator.of(context).pop(true),
            child: const Text('打开链接'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || decision.uri == null) return false;

    final opener = widget.onOpenLink ?? _launchExternal;
    return opener(decision.uri.toString());
  }

  Future<bool> _launchExternal(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}

/// Captures the real visible text of the anchor that owns the tapped gesture.
/// This is the HtmlWidget branch's primary display-text source; the DOM map is
/// retained as a fallback for the JS-disabled WebView branch.
class _SafeLinkWidgetFactory extends WidgetFactory {
  _SafeLinkWidgetFactory({required this.onOpen});

  final void Function(String url, String? displayText) onOpen;

  @override
  GestureRecognizer? buildGestureRecognizer(
    BuildTree tree, {
    GestureTapCallback? onTap,
  }) {
    if (tree.element.localName?.toLowerCase() == 'a') {
      final href = tree.element.attributes['href'];
      if (href != null && href.isNotEmpty) {
        final text = tree.element.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        return super.buildGestureRecognizer(
          tree,
          onTap: () => onOpen(href, text.isEmpty ? null : text),
        );
      }
    }
    return super.buildGestureRecognizer(tree, onTap: onTap);
  }
}

class _ProcessedHtml {
  _ProcessedHtml({
    required this.sourceHtml,
    required this.allowRemoteImages,
    required this.trustedSender,
    required this.cidSnapshot,
    required this.result,
    required this.visibleLinkTexts,
    required this.isComplex,
  });

  final String sourceHtml;
  final bool allowRemoteImages;
  final bool trustedSender;
  final Map<String, String> cidSnapshot;
  final HtmlSanitizeResult result;
  final Map<String, List<String>> visibleLinkTexts;
  final bool isComplex;

  String? _nativeMemoKey;
  String? _nativeDocument;
  String? _nativeSignature;

  /// Rebuilds the native document only when the sanitized body or the resolved
  /// reading palette changed. The content signature drives the WebView key and
  /// must keep refreshing after consent/content changes.
  String nativeDocument({
    required bool allowRemoteImages,
    required String? backgroundColor,
    required String? textColor,
  }) {
    final memoKey =
        '$allowRemoteImages|${backgroundColor ?? ''}|${textColor ?? ''}';
    if (_nativeMemoKey == memoKey && _nativeDocument != null) {
      return _nativeDocument!;
    }
    final document = SafeHtmlEmailView.buildCspDocument(
      result.html,
      allowRemoteImages: allowRemoteImages,
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
    _nativeMemoKey = memoKey;
    _nativeDocument = document;
    _nativeSignature = SafeHtmlEmailView.contentSignature(document);
    return document;
  }

  String get nativeSignature => _nativeSignature!;
}

class _RemoteContentBanner extends StatelessWidget {
  const _RemoteContentBanner({
    required this.blockedCount,
    this.onShowImages,
    this.onTrustSender,
  });

  final int blockedCount;
  final VoidCallback? onShowImages;
  final VoidCallback? onTrustSender;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('remote-content-banner'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.visibility_off_outlined, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '已拦截 $blockedCount 个远程图片/样式请求，防止追踪像素。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              TextButton(
                key: const Key('show-remote-images'),
                onPressed: onShowImages,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('显示图片'),
              ),
              TextButton(
                key: const Key('trust-sender'),
                onPressed: onTrustSender,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('信任发件人'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadingPalette {
  const _ReadingPalette({required this.background, required this.foreground});

  final Color? background;
  final Color? foreground;
}
