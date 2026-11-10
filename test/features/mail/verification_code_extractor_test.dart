import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/features/mail/domain/services/verification_code_extractor.dart';

void main() {
  const extractor = VerificationCodeExtractor();

  group('positive formats', () {
    test('Chinese numeric code', () {
      expect(
        extractor.extract(subject: '登录提醒', plainBody: '您的验证码是 123456，5 分钟内有效。'),
        '123456',
      );
    });

    test('English numeric code', () {
      expect(
        extractor.extract(
          subject: 'Sign-in',
          plainBody: 'Your verification code is 654321.',
        ),
        '654321',
      );
    });

    test('strong-context mixed alphanumeric code', () {
      expect(
        extractor.extract(
          subject: 'Sign-in',
          plainBody: 'Use code A1B2C3 to sign in.',
        ),
        'A1B2C3',
      );
    });

    test('Google G- format keeps the numeric body', () {
      expect(
        extractor.extract(
          subject: 'Google verification',
          plainBody: 'G-123456 is your Google verification code.',
        ),
        '123456',
      );
      expect(
        extractor.extract(
          subject: 'Sign-in',
          plainBody: 'Use code G-123456 to sign in.',
        ),
        '123456',
      );
    });

    test('strong-context grouped numeric codes are normalized', () {
      expect(
        extractor.extract(subject: '登录', plainBody: '验证码：123 456'),
        '123456',
      );
      expect(
        extractor.extract(
          subject: 'Sign-in',
          plainBody: 'Your security code is 1234-5678.',
        ),
        '12345678',
      );
    });

    test('Chinese OTP wording variants', () {
      for (final wording in <String>[
        '校验码',
        '动态码',
        '动态密码',
        '确认码',
        '认证码',
        '一次性密码',
      ]) {
        expect(
          extractor.extract(subject: '通知', plainBody: '$wording：123456'),
          '123456',
          reason: wording,
        );
      }
    });
  });

  group('HTML fallback', () {
    test('visible DOM text across split blocks', () {
      expect(
        extractor.extract(
          subject: '登录',
          htmlBody:
              '<html><head><style>.x{content:"123456"}</style></head>'
              '<body><p>验证码：</p><p>123456</p>'
              '<span style="display:none">654321</span>'
              '<script>var code="777777";</script></body></html>',
        ),
        '123456',
      );
    });

    test('hidden-only code is not extracted', () {
      expect(
        extractor.extract(
          subject: '登录',
          htmlBody:
              '<p>验证码：</p>'
              '<span style="display:none">123456</span>'
              '<p>请查收</p>',
        ),
        isNull,
      );
    });

    test('plain text is preferred over HTML', () {
      expect(
        extractor.extract(
          subject: '登录',
          plainBody: '验证码：123456',
          htmlBody: '<p>验证码：654321</p>',
        ),
        '123456',
      );
    });

    test('HTML is used when plain text has no code', () {
      expect(
        extractor.extract(
          subject: '登录',
          plainBody: '请查看 HTML 版本',
          htmlBody: '<p>验证码：123456</p>',
        ),
        '123456',
      );
    });
  });

  group('negative and conservative cases', () {
    test('dates are not codes even near verification wording', () {
      expect(
        extractor.extract(subject: '验证码通知', plainBody: '验证码邮件\n日期：2025-01-01'),
        isNull,
      );
      expect(
        extractor.extract(subject: '验证码', plainBody: '验证码：2025-0101'),
        isNull,
      );
    });

    test('order numbers are not codes', () {
      expect(
        extractor.extract(subject: '验证码通知', plainBody: '订单号：123456 已发货'),
        isNull,
      );
      expect(
        extractor.extract(
          subject: 'Sign-in',
          plainBody: 'Your order code is 123456.',
        ),
        isNull,
      );
    });

    test('phone numbers are not codes', () {
      expect(
        extractor.extract(subject: '验证码通知', plainBody: '客服电话 13800138000'),
        isNull,
      );
      expect(
        extractor.extract(subject: '验证码通知', plainBody: '验证码：400-123-4567'),
        isNull,
      );
    });

    test('URLs and tracking parameters are not codes', () {
      expect(
        extractor.extract(
          subject: '验证码通知',
          plainBody: '请点击 https://example.com/verify?code=123456 完成验证',
        ),
        isNull,
      );
      expect(
        extractor.extract(
          subject: '验证码通知',
          plainBody: '打开 https://track.example/p?code=654321&token=9999',
        ),
        isNull,
      );
    });

    test('quoted old messages are not codes', () {
      expect(
        extractor.extract(
          subject: 'Re: 登录',
          plainBody: '验证码：123456\n\n> 旧邮件验证码：654321',
        ),
        '123456',
      );
      expect(
        extractor.extract(
          subject: 'Re: login',
          plainBody:
              'Your verification code is 123456.\n\n'
              'On Mon, Jan 1, 2026, Service <x@y.test> wrote:\n'
              'Your verification code is 654321.',
        ),
        '123456',
      );
    });

    test('HTML quoted old messages are not codes', () {
      expect(
        extractor.extract(
          subject: 'Re: login',
          htmlBody:
              '<p>Your verification code is 123456.</p>'
              '<div>On Mon, Jan 1, 2026, Service wrote:</div>'
              '<blockquote>Your verification code is 654321.</blockquote>',
        ),
        '123456',
      );
      expect(
        extractor.extract(
          subject: 'Re: login',
          htmlBody:
              '<p>Your verification code is 123456.</p>'
              '<blockquote>Your verification code is 654321.</blockquote>',
        ),
        '123456',
      );
      expect(
        extractor.extract(
          subject: 'Re: login',
          htmlBody:
              '<div class="gmail_quote">'
              'Your verification code is 654321.</div>',
        ),
        isNull,
      );
      expect(
        extractor.extract(
          subject: 'Re: login',
          htmlBody:
              '<div class="yahoo_quoted">'
              'Your verification code is 654321.</div>',
        ),
        isNull,
      );
    });

    test('different codes are ambiguous and hidden', () {
      expect(
        extractor.extract(subject: '登录', plainBody: '验证码：123456，备用验证码：654321'),
        isNull,
      );
      expect(
        extractor.extract(
          subject: '登录',
          plainBody: '验证码：123456，备用验证码：654321',
          htmlBody: '<p>验证码：777777</p>',
        ),
        isNull,
      );
    });

    test('no explicit verification wording', () {
      expect(
        extractor.extract(
          subject: 'Order shipped',
          plainBody: 'Order 123456 has shipped on 2025-01-01.',
        ),
        isNull,
      );
      expect(
        extractor.extract(
          subject: 'Sign-in',
          plainBody: 'Use code a1b2c3 to sign in.',
        ),
        isNull,
      );
    });

    test('bare code and project IDs are not verification codes', () {
      expect(
        extractor.extract(subject: 'Failure', plainBody: 'Error code 123456'),
        isNull,
      );
      expect(
        extractor.extract(
          subject: 'Release',
          plainBody: 'Source code updated in 2026',
        ),
        isNull,
      );
      expect(
        extractor.extract(
          subject: 'Project',
          plainBody: 'Project G-123456 is ready.',
        ),
        isNull,
      );
    });

    test('generic code still works with a nearby verify/sign-in action', () {
      expect(
        extractor.extract(
          subject: 'Account',
          plainBody: 'Enter code 123456 to verify your account.',
        ),
        '123456',
      );
    });
  });
}
