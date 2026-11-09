import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/features/auth/domain/entities/mail_account.dart';
import 'package:local_mail_client/features/mail/data/datasources/mail_local_datasource.dart';
import 'package:local_mail_client/features/mail/data/repositories/mail_local_repository.dart';
import 'package:local_mail_client/features/mail/domain/entities/mail_folder.dart';

class MailFixture {
  MailFixture._({
    required this.database,
    required this.localRepository,
    required this.account,
    required this.folder,
    required this.emailLocalId,
  });

  final AppDatabase database;
  final MailLocalRepository localRepository;
  final MailAccount account;
  final MailFolder folder;
  final int emailLocalId;

  static Future<MailFixture> create({
    String subject = 'Quarterly report',
    bool bodyDownloaded = true,
    int flagsBitmask = 0,
  }) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.utc(2026, 1, 1);
    final account = MailAccount(
      id: 'acc-1',
      email: 'alice@example.com',
      displayName: 'Alice',
      providerType: MailProviderType.gmail,
      authType: MailAuthType.passwordOrAuthCode,
      colorValue: 0xFFEA4335,
      imapHost: 'imap.example.com',
      imapPort: 993,
      imapImplicitTls: true,
      smtpHost: 'smtp.example.com',
      smtpPort: 465,
      smtpImplicitTls: true,
      createdAt: now,
    );
    await database.into(database.dbAccounts).insert(
          DbAccountsCompanion.insert(
            id: account.id,
            email: account.email,
            displayName: account.displayName,
            providerType: account.providerType.storageKey,
            authType: account.authType.storageKey,
            colorValue: account.colorValue,
            imapHost: account.imapHost,
            imapPort: account.imapPort,
            imapImplicitTls: account.imapImplicitTls,
            smtpHost: account.smtpHost,
            smtpPort: account.smtpPort,
            smtpImplicitTls: account.smtpImplicitTls,
            createdAt: account.createdAt.millisecondsSinceEpoch,
          ),
        );
    await database.into(database.dbFolders).insert(
          DbFoldersCompanion.insert(
            id: 'folder-1',
            accountId: account.id,
            remoteName: 'INBOX',
            displayName: 'INBOX',
            role: FolderRole.inbox.storageKey,
          ),
        );
    final emailLocalId = await database.into(database.dbEmails).insert(
          DbEmailsCompanion.insert(
            accountId: account.id,
            folderId: 'folder-1',
            uid: 1,
            subject: subject,
            fromName: 'Sender',
            fromAddress: 'sender@example.com',
            toRecipientsJson:
                '[{"name":"Bob","email":"bob@example.com"}]',
            ccJson: '[{"name":"Carol","email":"carol@example.com"}]',
            snippet: 'A short snippet',
            plainBody: const Value('Plain body text'),
            htmlBody: const Value('<p>HTML body</p>'),
            sentAt: DateTime.utc(2026, 1, 1, 10).millisecondsSinceEpoch,
            flagsBitmask: Value(flagsBitmask),
            bodyDownloaded: Value(bodyDownloaded),
          ),
        );
    final folder = MailFolder(
      id: 'folder-1',
      accountId: account.id,
      remoteName: 'INBOX',
      displayName: 'INBOX',
      role: FolderRole.inbox,
    );
    return MailFixture._(
      database: database,
      localRepository: MailLocalRepository(
        dataSource: MailLocalDataSource(database: database),
      ),
      account: account,
      folder: folder,
      emailLocalId: emailLocalId,
    );
  }

  Future<void> dispose() => database.close();
}
