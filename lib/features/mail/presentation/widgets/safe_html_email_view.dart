import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import 'html_email_sanitizer.dart';

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

  /// Test-visible production WebView baseline.
  @visibleForTesting
  static InAppWebViewSettings buildWebViewSettings() {
    return InAppWebViewSettings(
      javaScriptEnabled: false,
      javaScriptCanOpenWindowsAutomatically: false,
      allowsInlineMediaPlayback: false,
      mediaPlaybackRequiresUserGesture: true,
      supportZoom: false,
      allowFileAccess: true,
      allowContentAccess: false,
      allowFileAccessFromFileURLs: false,
      allowUniversalAccessFromFileURLs: false,
      disableContextMenu: true,
    );
  }

  /// Test-visible CSP wrapper shared by the production WebView and tests.
  @visibleForTesting
  static String buildCspDocument(
    String body, {
    required bool allowRemoteImages,
  }) {
    final imageSources = allowRemoteImages
        ? "img-src 'self' data: file: http: https:;"
        : "img-src 'self' data: file:;";
    return '<!doctype html><html><head><meta charset="utf-8">'
        '<meta http-equiv="Content-Security-Policy" '
        'content="default-src \'none\'; script-src \'none\'; '
        'object-src \'none\'; frame-src \'none\'; base-uri \'none\'; '
        'form-action \'none\'; $imageSources '
        'style-src \'unsafe-inline\';"></head><body>$body</body></html>';
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

  bool get _allowRemote =>
      widget.allowRemoteImages || widget.trustedSender;

  @override
  Widget build(BuildContext context) {
    final result = _sanitizer.sanitize(
      html: widget.html,
      allowRemoteImages: widget.allowRemoteImages,
      trustedSender: widget.trustedSender,
      cidToLocalPath: widget.cidToLocalPath,
    );
    _visibleLinkTexts = _extractVisibleLinkTexts(result.html);
    final complex =
        widget.autoUseWebViewForComplexTables && _isComplex(result.html);
    final useWebView = _webViewOverride ?? complex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.blockedRemoteContent > 0 && !_allowRemote)
          _RemoteContentBanner(
            blockedCount: result.blockedRemoteContent,
            onShowImages: widget.onShowRemoteImages,
            onTrustSender: widget.onTrustSender,
          ),
        Row(
          children: [
            if (complex || _webViewOverride != null)
              TextButton.icon(
                key: const Key('toggle-secure-webview'),
                onPressed: () => setState(
                  () => _webViewOverride = !useWebView,
                ),
                icon: Icon(
                  useWebView ? Icons.article_outlined : Icons.web_outlined,
                  size: 16,
                ),
                label: Text(useWebView ? '切回安全阅读视图' : '高级表格视图'),
              ),
            const Spacer(),
            if (result.hasRemoteContent)
              Text(
                '远程内容：${result.remoteImageCount + result.remoteCssCount}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        if (useWebView)
          (widget.webViewBuilder ?? _defaultWebView)(
            context,
            SafeHtmlEmailView.buildCspDocument(
              result.html,
              allowRemoteImages: _allowRemote,
            ),
            _confirmAndOpenLink,
          )
        else
          HtmlWidget(
            result.html,
            key: const Key('safe-html-widget'),
            textStyle: Theme.of(context).textTheme.bodyMedium,
            factoryBuilder: () => _SafeLinkWidgetFactory(
              onOpen: (url, text) {
                unawaited(
                  _confirmAndOpenLink(url, displayText: text),
                );
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
      ],
    );
  }

  Widget _defaultWebView(
    BuildContext context,
    String html,
    Future<bool> Function(String url) onOpenLink,
  ) {
    return InAppWebView(
      key: const Key('safe-inapp-webview'),
      initialData: InAppWebViewInitialData(
        data: html,
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: WebUri('about:blank'),
      ),
      initialSettings: SafeHtmlEmailView.buildWebViewSettings(),
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

  Future<bool> _confirmAndOpenLink(
    String rawUrl, {
    String? displayText,
  }) async {
    final effectiveDisplayText = displayText ??
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
      child: Row(
        children: [
          const Icon(Icons.visibility_off_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '已拦截 $blockedCount 个远程图片/样式请求，防止追踪像素。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            key: const Key('show-remote-images'),
            onPressed: onShowImages,
            child: const Text('显示图片'),
          ),
          TextButton(
            key: const Key('trust-sender'),
            onPressed: onTrustSender,
            child: const Text('信任发件人'),
          ),
        ],
      ),
    );
  }
}
