import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/features/mail/presentation/widgets/safe_html_email_view.dart';

void main() {
  testWidgets('blocks remote content and offers explicit consent',
      (tester) async {
    var shown = 0;
    var trusted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeHtmlEmailView(
            html:
                '<p>Hello</p><img src="https://tracker.example/pixel.png">',
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

  testWidgets('sanitizes HTML and confirms external links through the guard',
      (tester) async {
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


  testWidgets('blocked remote resources make zero real HTTP requests',
      (tester) async {
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

  testWidgets('visible link text overrides sender trust for phishing warning',
      (tester) async {
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

    final linkFinder = find.text('https://trusted.test/account', findRichText: true);
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

  test('production WebView settings, CSP and navigation policy are testable',
      () async {
    final settings = SafeHtmlEmailView.buildWebViewSettings();
    expect(settings.javaScriptEnabled, isFalse);
    expect(settings.javaScriptCanOpenWindowsAutomatically, isFalse);
    expect(settings.allowContentAccess, isFalse);
    expect(settings.allowFileAccessFromFileURLs, isFalse);
    expect(settings.allowUniversalAccessFromFileURLs, isFalse);
    expect(settings.mediaPlaybackRequiresUserGesture, isTrue);
    expect(settings.allowsInlineMediaPlayback, isFalse);

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
  });

  testWidgets('complex tables can switch to an injected safe WebView builder',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeHtmlEmailView(
            html: '<table><tr><td>a</td></tr></table>'
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
}
