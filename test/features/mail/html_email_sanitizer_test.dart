import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/features/mail/presentation/widgets/html_email_sanitizer.dart';

void main() {
  const sanitizer = HtmlEmailSanitizer();

  test('removes script-capable tags, event handlers and javascript URIs', () {
    final result = sanitizer.sanitize(
      html: '''
        <div onclick="steal()">
          <script>alert(1)</script>
          <iframe src="https://evil.example"></iframe>
          <object data="x"></object>
          <embed src="x">
          <form action="https://evil.example"><input></form>
          <a href="javascript:alert(1)">bad</a>
          <p onmouseover="x()">safe text</p>
        </div>
      ''',
    );

    expect(result.html, isNot(contains('<script')));
    expect(result.html, isNot(contains('<iframe')));
    expect(result.html, isNot(contains('<object')));
    expect(result.html, isNot(contains('<embed')));
    expect(result.html, isNot(contains('<form')));
    expect(result.html, isNot(contains('onclick')));
    expect(result.html, isNot(contains('onmouseover')));
    expect(result.html, isNot(contains('javascript:')));
    expect(result.html, contains('safe text'));
  });

  test('blocks remote images and CSS urls until explicitly allowed', () {
    final blocked = sanitizer.sanitize(
      html: '''
        <img src="https://tracker.example/pixel.gif">
        <div style="background-image: url('https://tracker.example/bg.png')">x</div>
        <style>.a { background: url(https://tracker.example/style.png) }</style>
      ''',
    );

    expect(blocked.blockedRemoteImages, 1);
    expect(blocked.blockedRemoteCss, 2);
    expect(blocked.html, isNot(contains('tracker.example/pixel.gif')));
    expect(blocked.html, isNot(contains('background-image: url')));

    final allowed = sanitizer.sanitize(
      html: '<img src="https://cdn.example/logo.png">',
      allowRemoteImages: true,
    );
    expect(allowed.remoteImageCount, 1);
    expect(allowed.blockedRemoteImages, 0);
    expect(allowed.html, contains('https://cdn.example/logo.png'));
  });

  test('replaces cid image sources with local file URIs', () {
    final result = sanitizer.sanitize(
      html: '<p>logo</p><img src="cid:logo@cid">',
      cidToLocalPath: const <String, String>{
        'logo@cid': '/tmp/cache/logo.png',
      },
    );

    expect(result.html, contains('file:///tmp/cache/logo.png'));
    expect(result.html, isNot(contains('cid:logo@cid')));

    final localFileAttack = sanitizer.sanitize(
      html: '<img src="file:///etc/passwd">',
    );
    expect(localFileAttack.html, isNot(contains('file:///etc/passwd')));

    final svgData = sanitizer.sanitize(
      html: '<img src="data:image/svg+xml;base64,PHN2Zz48c2NyaXB0PjE8L3NjcmlwdD48L3N2Zz4=">',
      allowRemoteImages: true,
    );
    expect(svgData.html, isNot(contains('data:image/svg+xml')));
  });

  test('strictly removes backslash, malformed and control-character resources',
      () {
    final result = sanitizer.sanitize(
      html: '\n'
          r'<img src="https:\\evil.test\pixel.png">'
          r'<img src="http:\evil.test\pixel.png">'
          r'<img src="\\evil.test\pixel.png">'
          '<img src="https:\n//evil.test/control.png">'
          r'<video poster="https:\\evil.test\poster.png"></video>'
          r'<td background="https:\\evil.test\background.png">x</td>'
          r'<img srcset="https:\\evil.test\2x.png 2x, /local.png 1x">',
    );

    expect(result.blockedRemoteImages, greaterThan(0));
    expect(result.remoteImageCount, greaterThan(0));
    expect(result.html, isNot(contains('evil.test')));
    expect(result.html, isNot(contains(r'https:\\')));
    expect(result.html, isNot(contains(r'http:\\')));
    expect(result.html, isNot(contains('control.png')));
    expect(result.html, isNot(contains('poster.png')));
    expect(result.html, isNot(contains('background.png')));
  });

  test('srcset sanitizes candidates independently and keeps only safe data',
      () {
    final result = sanitizer.sanitize(
      html:
          r'<img srcset="data:image/png;base64,AAAA 1x, https:\\evil.test\2x.png 2x">',
    );

    expect(result.remoteImageCount, greaterThan(0));
    expect(result.html, contains('data:image/png;base64,AAAA'));
    expect(result.html, isNot(contains('evil.test')));
  });

  test('CSS url sanitization always strips dangerous schemes even when remote is allowed',
      () {
    final result = sanitizer.sanitize(
      html: '\n'
          '<div style="background-image:url(javascript:alert(1));color:red">a</div>'
          '<div style="background-image:url(vbscript:msgbox(1))">b</div>'
          '<div style="background-image:url(file:///etc/passwd)">c</div>'
          r'<div style="background-image:url(https:\\evil.test\bg.png)">d</div>'
          '<style>.x{background-image:url(https:\\\\evil.test\\\\style.png)}</style>',
      allowRemoteImages: true,
    );

    expect(result.blockedRemoteCss, greaterThan(0));
    expect(result.html, isNot(contains('javascript:')));
    expect(result.html, isNot(contains('vbscript:')));
    expect(result.html, isNot(contains('file:///etc/passwd')));
    expect(result.html, isNot(contains('evil.test')));
    expect(result.html, isNot(contains('<style')));
  });

  test('phishing guard prioritizes visible link domain over sender domain', () {
    const guard = LinkPhishingGuard();
    final decision = guard.inspect(
      'http://evil.test/path',
      senderEmail: 'sender@evil.test',
      displayText: 'https://trusted.test/account',
    );
    expect(decision.suspicious, isTrue);
    expect(decision.reason, contains('域名欺骗'));
    expect(decision.reason, contains('显示链接文本与实际目标域名不一致'));
    expect(decision.displayDomains, contains('trusted.test'));
  });

  test('phishing guard compares host to the sender domain', () {
    const guard = LinkPhishingGuard();
    expect(
      guard.inspect(
        'https://example.com/invoice',
        senderEmail: 'billing@example.com',
      ).suspicious,
      isFalse,
    );
    final lookalike = guard.inspect(
      'https://example.com.evil.test/invoice',
      senderEmail: 'billing@example.com',
    );
    expect(lookalike.suspicious, isTrue);
    expect(lookalike.reason, contains('疑似钓鱼'));

    final userInfo = guard.inspect(
      'https://example.com@evil.test/invoice',
      senderEmail: 'billing@example.com',
    );
    expect(userInfo.suspicious, isTrue);

    expect(
      guard.inspect('javascript:alert(1)', senderEmail: 'billing@example.com').blocked,
      isTrue,
    );
  });
}
