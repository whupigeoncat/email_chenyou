import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/features/mail/presentation/widgets/safe_html_email_view.dart';

void main() {
  testWidgets('blocks remote content and offers explicit consent', (
    tester,
  ) async {
    var shown = 0;
    var trusted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeHtmlEmailView(
            html: '<p>Hello</p><img src="https://tracker.example/pixel.png">',
            senderEmail: 'sender@example.com',
            onShowRemoteImages: () => shown++,
            onTrustSender: () => trusted++,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('remote-content-banner')), findsOneWidget);
    expect(find.textContaining('已拦截'), findsOneWidget);
    await tester.tap(find.byKey(const Key('show-remote-images')));
    await tester.tap(find.byKey(const Key('trust-sender')));
    expect(shown, 1);
    expect(trusted, 1);
  });

  testWidgets('sanitizes HTML and confirms external links through the guard', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeHtmlEmailView(
            html:
                '<p>Hello</p><script>alert(1)</script>'
                '<a href="https://example.com.evil.test/x">open link</a>',
            senderEmail: 'sender@example.com',
            onOpenLink: (url) async {
              opened = url;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('open link', findRichText: true), findsOneWidget);
    await tester.tap(find.text('open link', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('疑似钓鱼'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-open-link')));
    await tester.pumpAndSettle();
    expect(opened, 'https://example.com.evil.test/x');
  });

  testWidgets('blocked remote resources make zero real HTTP requests', (
    tester,
  ) async {
    var requests = 0;
    await HttpOverrides.runZoned(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SafeHtmlEmailView(
                html: r'''
                  <img src="https:\\evil.test\pixel.png">
                  <img src="http:\evil.test\second.png">
                  <img src="\\evil.test\third.png">
                  <img src="https:\n//evil.test/control.png">
                  <video poster="https:\\evil.test\poster.png"></video>
                  <td background="https:\\evil.test\bg.png">x</td>
                  <img srcset="https:\\evil.test\2x.png 2x">
                  <p>safe</p>
                ''',
                senderEmail: 'sender@example.com',
                onShowRemoteImages: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      },
      createHttpClient: (context) {
        requests++;
        throw StateError('unexpected network request');
      },
    );

    expect(requests, 0);
    expect(find.byKey(const Key('remote-content-banner')), findsOneWidget);
  });

  testWidgets('visible link text overrides sender trust for phishing warning', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeHtmlEmailView(
            html: '<a href="http://evil.test/path">https://trusted.test/account</a>',
            senderEmail: 'sender@evil.test',
            onOpenLink: (url) async {
              opened = url;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final linkFinder = find.text(
      'https://trusted.test/account',
      findRichText: true,
    );
    final linkRect = tester.getRect(linkFinder);
    await tester.tapAt(linkRect.topLeft + const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('域名欺骗'), findsOneWidget);
    expect(find.text('显示文本：https://trusted.test/account'), findsOneWidget);
    expect(find.text('实际目标：http://evil.test/path'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-open-link')));
    await tester.pumpAndSettle();
    expect(opened, 'http://evil.test/path');
  });

  test(
    'production WebView settings, CSP and navigation policy are testable',
    () async {
      final settings = SafeHtmlEmailView.buildWebViewSettings();
      expect(settings.javaScriptEnabled, isFalse);
      expect(settings.javaScriptCanOpenWindowsAutomatically, isFalse);
      expect(settings.allowContentAccess, isFalse);
      expect(settings.allowFileAccessFromFileURLs, isFalse);
      expect(settings.allowUniversalAccessFromFileURLs, isFalse);
      expect(settings.mediaPlaybackRequiresUserGesture, isTrue);
      expect(settings.allowsInlineMediaPlayback, isFalse);
      expect(settings.useShouldOverrideUrlLoading, isTrue);
      expect(settings.supportZoom, isTrue);
      expect(
        settings.useHybridComposition,
        isFalse,
        reason:
            'texture composition keeps the native HTML in sync with the '
            'Flutter route fade/transform (Android only; ignored elsewhere)',
      );
      expect(
        SafeHtmlEmailView.buildWebViewGestureRecognizers(),
        isNotEmpty,
        reason: 'nested platform views need an eager recognizer to scroll',
      );

      final blockedCsp = SafeHtmlEmailView.buildCspDocument(
        '<p>x</p>',
        allowRemoteImages: false,
      );
      expect(blockedCsp, contains("img-src 'self' data: file:;"));
      expect(blockedCsp, contains("script-src 'none'"));

      final allowedCsp = SafeHtmlEmailView.buildCspDocument(
        '<p>x</p>',
        allowRemoteImages: true,
      );
      expect(allowedCsp, contains("img-src 'self' data: file: http: https:;"));

      String? opened;
      final policy = await SafeHtmlEmailView.handleNavigation(
        url: 'https://evil.test/path',
        onOpenLink: (url) async {
          opened = url;
          return true;
        },
      );
      expect(opened, 'https://evil.test/path');
      expect(policy, NavigationActionPolicy.CANCEL);
    },
  );

  testWidgets('complex tables can switch to an injected safe WebView builder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeHtmlEmailView(
            html:
                '<table><tr><td>a</td></tr></table>'
                '<table><tr><td>b</td></tr></table>',
            senderEmail: 'sender@example.com',
            webViewBuilder: (context, html, onOpenLink) =>
                const Text('injected-webview'),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('toggle-secure-webview')), findsOneWidget);
    expect(find.text('injected-webview'), findsOneWidget);
  });

  testWidgets(
    'advanced renderer gets finite height and resets across messages',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final seen = <String>[];
      double? frameHeight;
      var allowRemote = false;
      late StateSetter setHost;
      var html =
          '<table><tr><td>first-table</td></tr></table>'
          '<table><tr><td>a</td></tr></table>';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F766E),
              brightness: Brightness.dark,
            ),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, setState) {
                  setHost = setState;
                  return SafeHtmlEmailView(
                    html: html,
                    senderEmail: 'sender@example.com',
                    allowRemoteImages: allowRemote,
                    onShowRemoteImages: () =>
                        setState(() => allowRemote = true),
                    webViewBuilder: (context, sanitized, onOpenLink) {
                      seen.add(sanitized);
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          frameHeight = constraints.maxHeight;
                          return const SizedBox.expand();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(frameHeight, isNotNull);
      expect(frameHeight!.isFinite, isTrue);
      expect(frameHeight, greaterThanOrEqualTo(200));
      expect(seen.last, contains('first-table'));
      expect(find.byKey(const Key('safe-webview-frame')), findsOneWidget);

      // Manual safe-view choice is local to the current message state.
      await tester.tap(find.byKey(const Key('toggle-secure-webview')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safe-html-widget')), findsOneWidget);
      final beforeSwitch = seen.length;

      setHost(() {
        html =
            '<table><tr><td>second-table</td></tr></table>'
            '<table><tr><td>b</td></tr></table>'
            '<img src="https://tracker.example/pixel.png">';
      });
      await tester.pumpAndSettle();
      expect(
        seen.length,
        greaterThan(beforeSwitch),
        reason: 'a new message must not inherit the old renderer override',
      );
      expect(seen.last, contains('second-table'));
      expect(find.byKey(const Key('safe-webview-frame')), findsOneWidget);
      expect(seen.last, isNot(contains('tracker.example/pixel.png')));

      // Consent must update the native document as well.
      await tester.tap(find.byKey(const Key('show-remote-images')));
      await tester.pumpAndSettle();
      expect(seen.last, contains('tracker.example/pixel.png'));
    },
  );

  testWidgets(
    'native document keeps dark surface under white body/table text',
    (tester) async {
      String? document;
      Color? canvas;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F766E),
              brightness: Brightness.dark,
            ),
          ),
          home: Scaffold(
            body: SafeHtmlEmailView(
              html:
                  '<body style="color:#ffffff">'
                  '<table><tr><td style="color:#ffffff">white cell</td></tr>'
                  '</table>'
                  '<table><tr><td>second</td></tr></table></body>',
              senderEmail: 'sender@example.com',
              webViewBuilder: (context, html, onOpenLink) {
                document = html;
                canvas = Theme.of(context).colorScheme.surface;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(document, isNotNull);
      expect(
        document!,
        contains('background-color:${_cssHex(canvas!)}'),
        reason: 'native must not fall back to the WebView white default',
      );
      expect(document!, contains('color:#ffffff'));
      expect(find.byKey(const Key('safe-webview-frame')), findsOneWidget);
    },
  );

  testWidgets('bright native document paints the theme reading surface', (
    tester,
  ) async {
    String? document;
    Color? canvas;
    Color? ink;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F766E),
            brightness: Brightness.light,
          ),
        ),
        home: Scaffold(
          body: SafeHtmlEmailView(
            html:
                '<table><tr><td>a</td></tr></table>'
                '<table><tr><td>b</td></tr></table>',
            senderEmail: 'sender@example.com',
            webViewBuilder: (context, html, onOpenLink) {
              document = html;
              final theme = Theme.of(context);
              canvas = theme.colorScheme.surface;
              ink =
                  theme.textTheme.bodyMedium?.color ??
                  theme.colorScheme.onSurface;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(document, isNotNull);
    expect(document!, contains('background-color:${_cssHex(canvas!)}'));
    expect(document!, contains('color:${_cssHex(ink!)}'));
  });

  testWidgets(
    'dark theme keeps explicit body ink readable on an email canvas',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F766E),
              brightness: Brightness.dark,
            ),
          ),
          home: const Scaffold(
            body: SafeHtmlEmailView(
              html:
                  '<body style="background:#ffffff;color:#202020">'
                  '<p>Ink</p></body>',
              senderEmail: 'sender@example.com',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final canvas = _canvasColor(tester);
      expect(canvas, isNotNull);
      expect(canvas!.computeLuminance(), greaterThan(0.8));
      final ink = _renderedInkColor(tester);
      expect(ink, isNotNull);
      expect(ink!.computeLuminance(), lessThan(0.2));
    },
  );

  testWidgets('dark text without a body background gets a light canvas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F766E),
            brightness: Brightness.dark,
          ),
        ),
        home: const Scaffold(
          body: SafeHtmlEmailView(
            html: '<div style="color:#111111">Only inline ink</div>',
            senderEmail: 'sender@example.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final canvas = _canvasColor(tester);
    expect(canvas, isNotNull);
    expect(canvas!.computeLuminance(), greaterThan(0.8));
  });

  testWidgets('legacy font color probes for a contrasting canvas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F766E),
            brightness: Brightness.dark,
          ),
        ),
        home: const Scaffold(
          body: SafeHtmlEmailView(
            html: '<p><font color="#000000">Legacy ink</font></p>',
            senderEmail: 'sender@example.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final canvas = _canvasColor(tester);
    expect(canvas, isNotNull);
    expect(canvas!.computeLuminance(), greaterThan(0.8));
  });

  testWidgets('transparent and translucent body colors do not fake contrast', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F766E),
            brightness: Brightness.light,
          ),
        ),
        home: const Scaffold(
          body: SafeHtmlEmailView(
            html:
                '<body style="background-color:transparent;color:#ffffff">'
                '<p>Transparent</p></body>',
            senderEmail: 'sender@example.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Transparent is not white: with white body text and a light app surface
    // the reader must pick a dark canvas instead of pretending the email is
    // an opaque white sheet.
    final transparentCanvas = _canvasColor(tester);
    expect(transparentCanvas, isNotNull);
    expect(transparentCanvas!.computeLuminance(), lessThan(0.2));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F766E),
            brightness: Brightness.light,
          ),
        ),
        home: const Scaffold(
          body: SafeHtmlEmailView(
            html:
                '<body style="background-color:rgba(255,255,255,0.2);'
                'color:#ffffff"><p>Translucent</p></body>',
            senderEmail: 'sender@example.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final canvas = _canvasColor(tester);
    expect(canvas, isNotNull);
    // The translucent white was composited over the light surface, so white
    // text is not treated as readable just because the RGB channels are 255.
    expect(canvas!.a, 1);
    expect(canvas.computeLuminance(), greaterThan(0.8));
  });

  testWidgets('wide table, long text and remote banner fit at 320 and 390', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const html =
        '<body style="background:#ffffff;color:#202020">'
        '<img src="https://tracker.example/pixel.png">'
        '<table width="900"><tr><th>项目</th><th>说明</th></tr>'
        '<tr><td>本地邮箱</td><td>一个非常长且不能自然断开的描述文本'
        'SuperCalifragilisticExpialidociousSuperCalifragilistic</td></tr>'
        '</table>'
        '<p>https://example.com/a/very/long/unbroken/link/with/many/segments'
        '/that/needs/wrapping</p>'
        '<pre>preformatted preformatted preformatted preformatted</pre>'
        '</body>';

    for (final width in <double>[320, 390]) {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F766E),
              brightness: Brightness.dark,
            ),
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: SafeHtmlEmailView(
                html: html,
                senderEmail: 'sender@example.com',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(find.byKey(const Key('remote-content-banner')), findsOneWidget);
      expect(find.byKey(const Key('safe-html-canvas')), findsOneWidget);
    }
  });

  testWidgets('processing cache reuses HTML work but keeps theme canvas live', (
    tester,
  ) async {
    SafeHtmlEmailView.resetDebugCounters();
    addTearDown(SafeHtmlEmailView.resetDebugCounters);
    var brightness = Brightness.light;
    late StateSetter setRoot;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setRoot = setState;
          return MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0F766E),
                brightness: brightness,
              ),
            ),
            home: const Scaffold(
              body: SafeHtmlEmailView(
                html: '<div style="color:#111111">Static body</div>',
                senderEmail: 'sender@example.com',
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(SafeHtmlEmailView.debugSanitizeRuns, 1);
    expect(SafeHtmlEmailView.debugLinkParseRuns, 1);
    expect(SafeHtmlEmailView.debugTableScanRuns, 1);
    expect(_canvasColor(tester), isNull);

    setRoot(() {});
    await tester.pumpAndSettle();
    expect(
      SafeHtmlEmailView.debugSanitizeRuns,
      1,
      reason: 'an unrelated rebuild must not re-sanitize',
    );
    expect(SafeHtmlEmailView.debugLinkParseRuns, 1);
    expect(SafeHtmlEmailView.debugTableScanRuns, 1);

    setRoot(() => brightness = Brightness.dark);
    await tester.pumpAndSettle();
    expect(
      SafeHtmlEmailView.debugSanitizeRuns,
      1,
      reason: 'theme changes must recompute the canvas, not security parsing',
    );
    expect(_canvasColor(tester), isNotNull);
  });

  testWidgets('cache invalidates on consent, CID content and HTML changes', (
    tester,
  ) async {
    SafeHtmlEmailView.resetDebugCounters();
    addTearDown(SafeHtmlEmailView.resetDebugCounters);
    var allowRemote = false;
    var html =
        '<img src="cid:logo">'
        '<img src="https://tracker.example/pixel.png">'
        '<table><tr><td>a</td></tr></table>'
        '<table><tr><td>b</td></tr></table>';
    final cidPaths = <String, String>{'logo': '/tmp/old.png'};
    final documents = <String>[];
    late StateSetter setHost;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHost = setState;
              return SafeHtmlEmailView(
                html: html,
                senderEmail: 'sender@example.com',
                allowRemoteImages: allowRemote,
                cidToLocalPath: cidPaths,
                webViewBuilder: (context, document, onOpenLink) {
                  documents.add(document);
                  return const SizedBox.expand();
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(SafeHtmlEmailView.debugSanitizeRuns, 1);
    expect(documents.last, contains('old.png'));
    expect(documents.last, isNot(contains('tracker.example')));

    // Mutating the same Map in place must still invalidate the cache.
    cidPaths['logo'] = '/tmp/new.png';
    setHost(() {});
    await tester.pumpAndSettle();
    expect(SafeHtmlEmailView.debugSanitizeRuns, 2);
    expect(documents.last, contains('new.png'));

    setHost(() => allowRemote = true);
    await tester.pumpAndSettle();
    expect(SafeHtmlEmailView.debugSanitizeRuns, 3);
    expect(documents.last, contains('tracker.example'));

    setHost(() {
      html =
          '<p>changed</p>'
          '<table><tr><td>c</td></tr></table>'
          '<table><tr><td>d</td></tr></table>';
    });
    await tester.pumpAndSettle();
    expect(SafeHtmlEmailView.debugSanitizeRuns, 4);
    expect(documents.last, contains('changed'));
  });
}

String _cssHex(Color color) {
  final rgb = (color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '#$rgb';
}

Color? _canvasColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.byKey(const Key('safe-html-canvas')),
  );
  final decoration = container.decoration;
  return decoration is BoxDecoration ? decoration.color : null;
}

Color? _renderedInkColor(WidgetTester tester) {
  final finder = find.text('Ink', findRichText: true);
  if (finder.evaluate().isEmpty) return null;
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  return paragraph.text.style?.color;
}
