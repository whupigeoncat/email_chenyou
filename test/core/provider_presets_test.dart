import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';

void main() {
  group('ProviderPresets.inferFromEmail', () {
    const cases = <String, MailProviderType>{
      'alice@gmail.com': MailProviderType.gmail,
      'alice@googlemail.com': MailProviderType.gmail,
      'ALICE@GMAIL.COM': MailProviderType.gmail,
      'bob@outlook.com': MailProviderType.outlook,
      'bob@hotmail.com': MailProviderType.outlook,
      'bob@live.com': MailProviderType.outlook,
      'bob@msn.com': MailProviderType.outlook,
      'carol@163.com': MailProviderType.netease163,
      'carol@126.com': MailProviderType.netease163,
      'carol@yeah.net': MailProviderType.netease163,
      'dave@qq.com': MailProviderType.qq,
      'dave@vip.qq.com': MailProviderType.qq,
      'erin@foxmail.com': MailProviderType.foxmail,
      'unknown@example.com': MailProviderType.custom,
      'not-an-email': MailProviderType.custom,
      'trailing@': MailProviderType.custom,
    };

    for (final entry in cases.entries) {
      test('${entry.key} -> ${entry.value.storageKey}', () {
        expect(ProviderPresets.inferFromEmail(entry.key).type, entry.value);
      });
    }

    test('trims trailing whitespace around the domain', () {
      expect(
        ProviderPresets.inferFromEmail('alice@gmail.com  ').type,
        MailProviderType.gmail,
      );
    });

    test('empty or malformed addresses fall back to custom', () {
      expect(ProviderPresets.inferFromEmail('').type, MailProviderType.custom);
      expect(ProviderPresets.inferFromEmail('@gmail.com').type, MailProviderType.gmail);
      expect(ProviderPresets.inferFromEmail('alice@').type, MailProviderType.custom);
    });
  });

  group('provider host / port / auth constraints', () {
    test('Gmail uses official IMAP/SMTP TLS endpoints', () {
      const preset = ProviderPresets.gmail;
      expect(preset.imapHost, 'imap.gmail.com');
      expect(preset.imapPort, 993);
      expect(preset.imapImplicitTls, isTrue);
      expect(preset.smtpHost, 'smtp.gmail.com');
      expect(preset.smtpPort, 465);
      expect(preset.smtpImplicitTls, isTrue);
      expect(preset.requiresImapIdCommand, isFalse);
      expect(preset.supportedAuthTypes, contains(MailAuthType.oauth2Pkce));
      expect(
        preset.supportedAuthTypes,
        contains(MailAuthType.passwordOrAuthCode),
      );
    });

    test('Outlook uses Office 365 endpoints and OAuth2 only', () {
      const preset = ProviderPresets.outlook;
      expect(preset.imapHost, 'outlook.office365.com');
      expect(preset.imapPort, 993);
      expect(preset.imapImplicitTls, isTrue);
      expect(preset.smtpHost, 'smtp.office365.com');
      expect(preset.smtpPort, 587);
      expect(preset.smtpImplicitTls, isFalse, reason: '587 uses STARTTLS');
      expect(preset.requiresImapIdCommand, isFalse);
      expect(preset.supportedAuthTypes, <MailAuthType>[
        MailAuthType.oauth2Pkce,
      ]);
      expect(preset.defaultAuthType, MailAuthType.oauth2Pkce);
      expect(
        preset.supportedAuthTypes,
        isNot(contains(MailAuthType.passwordOrAuthCode)),
      );
    });

    test('NetEase (163/126/yeah) requires the RFC 2971 IMAP ID command', () {
      const preset = ProviderPresets.netease163;
      expect(preset.domains, containsAll(<String>['163.com', '126.com', 'yeah.net']));
      expect(preset.imapHost, 'imap.163.com');
      expect(preset.imapPort, 993);
      expect(preset.imapImplicitTls, isTrue);
      expect(preset.smtpPort, 465);
      expect(preset.smtpImplicitTls, isTrue);
      expect(preset.requiresImapIdCommand, isTrue);
      expect(
        preset.inboxPollInterval,
        const Duration(seconds: 60),
      );
      expect(preset.supportedAuthTypes, <MailAuthType>[
        MailAuthType.passwordOrAuthCode,
      ]);
    });

    test('163/126/yeah resolve their provider-specific IMAP/SMTP hosts', () {
      expect(
        ProviderPresets.resolveImapHostForEmail(
          MailProviderType.netease163,
          'carol@163.com',
        ),
        'imap.163.com',
      );
      expect(
        ProviderPresets.resolveImapHostForEmail(
          MailProviderType.netease163,
          'carol@126.com',
        ),
        'imap.126.com',
      );
      expect(
        ProviderPresets.resolveImapHostForEmail(
          MailProviderType.netease163,
          'carol@yeah.net',
        ),
        'imap.yeah.net',
      );
      expect(
        ProviderPresets.resolveSmtpHostForEmail(
          MailProviderType.netease163,
          'carol@126.com',
        ),
        'smtp.126.com',
      );
      expect(
        ProviderPresets.resolveSmtpHostForEmail(
          MailProviderType.netease163,
          'carol@yeah.net',
        ),
        'smtp.yeah.net',
      );
    });

    test('QQ and Foxmail share Tencent mail servers on implicit TLS', () {
      const qq = ProviderPresets.qq;
      const foxmail = ProviderPresets.foxmail;

      expect(qq.imapHost, 'imap.qq.com');
      expect(qq.imapPort, 993);
      expect(qq.smtpHost, 'smtp.qq.com');
      expect(qq.smtpPort, 465);
      expect(qq.smtpImplicitTls, isTrue);
      expect(qq.requiresImapIdCommand, isFalse);

      expect(foxmail.imapHost, 'imap.qq.com');
      expect(foxmail.imapPort, 993);
      expect(foxmail.smtpHost, 'smtp.qq.com');
      expect(foxmail.smtpPort, 465);
      expect(foxmail.smtpImplicitTls, isTrue);
      expect(foxmail.requiresImapIdCommand, isFalse);
    });

    test('only NetEase declares requiresImapIdCommand', () {
      for (final preset in ProviderPresets.all) {
        expect(
          preset.requiresImapIdCommand,
          preset.type == MailProviderType.netease163,
          reason: preset.type.storageKey,
        );
      }
    });

    test('custom preset has no preconfigured domains', () {
      expect(ProviderPresets.custom.domains, isEmpty);
      expect(ProviderPresets.custom.imapHost, isEmpty);
      expect(ProviderPresets.custom.smtpHost, isEmpty);
      expect(
        ProviderPresets.byType(MailProviderType.custom).type,
        MailProviderType.custom,
      );
    });
  });
}
