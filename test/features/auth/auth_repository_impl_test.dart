import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/core/constants/provider_presets.dart';
import 'package:local_mail_client/core/database/app_database.dart';
import 'package:local_mail_client/core/error/failures.dart';
import 'package:local_mail_client/core/security/secure_storage_service.dart';
import 'package:local_mail_client/features/auth/data/auth_repository_impl.dart';
import 'package:local_mail_client/features/auth/domain/entities/account_setup_draft.dart';
import 'package:local_mail_client/features/mail/domain/services/attachment_picker.dart';

import 'support/fakes.dart';

void main() {
  late AppDatabase database;
  late InMemorySecureStorageService storage;
  late RecordingConnectionPool pool;
  late AuthRepositoryImpl repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    storage = InMemorySecureStorageService();
    pool = RecordingConnectionPool();
    repository = AuthRepositoryImpl(
      database: database,
      secureStorage: storage,
      connectionPool: pool,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('AuthRepositoryImpl add', () {
    test(
      'writes metadata to SQLite and the secret only to secure storage',
      () async {
        final account = await repository.addAccount(
          draft: buildDraft(email: 'carol@163.com'),
          credential: const PasswordAccountCredential('163-auth-code'),
        );

        final rows = await database.select(database.dbAccounts).get();
        expect(rows, hasLength(1));
        expect(rows.single.id, account.id);
        expect(rows.single.email, 'carol@163.com');
        expect(storage.passwordSecrets[account.id], '163-auth-code');
        expect(storage.oauthBundles, isEmpty);
        expect(pool.syncCalls.single, <String>[account.id]);

        // The metadata row contains no credential and no secret column.
        expect(
          rows.single.toJson().toString(),
          isNot(contains('163-auth-code')),
        );
        final columns = await database
            .customSelect('PRAGMA table_info(db_accounts)')
            .get();
        final columnNames = columns
            .map((row) => row.read<String>('name'))
            .toList();
        for (final name in columnNames) {
          expect(
            RegExp(
              'password|token|secret|credential',
              caseSensitive: false,
            ).hasMatch(name),
            isFalse,
            reason: 'DbAccounts must never contain a credential column: $name',
          );
        }
      },
    );

    test('DB insert failure rolls back the freshly written secret', () async {
      await database.customStatement('DROP TABLE db_accounts');

      await expectLater(
        repository.addAccount(
          draft: buildDraft(email: 'carol@163.com'),
          credential: const PasswordAccountCredential('rollback-secret'),
        ),
        throwsA(isA<StorageFailure>()),
      );

      expect(storage.passwordSecrets, isEmpty);
      expect(storage.oauthBundles, isEmpty);
      expect(storage.deleteCredentialCalls, 1);
      expect(pool.syncCalls, isEmpty);
    });

    test('OAuth credentials are stored only in secure storage', () async {
      final tokens = OAuthTokenBundle(
        accessToken: 'oauth-access',
        refreshToken: 'oauth-refresh',
        expiresAt: DateTime.utc(2027, 1, 1),
        clientId: 'client-id',
        tokenEndpoint: 'https://oauth2.googleapis.com/token',
        scopes: const ['https://mail.google.com/'],
      );

      final account = await repository.addAccount(
        draft: buildDraft(
          email: 'alice@gmail.com',
          authType: MailAuthType.oauth2Pkce,
        ),
        credential: OAuthAccountCredential(tokens),
      );

      expect(storage.oauthBundles[account.id]?.accessToken, 'oauth-access');
      expect(storage.passwordSecrets, isEmpty);
      final row = await database.select(database.dbAccounts).getSingle();
      expect(row.toJson().toString(), isNot(contains('oauth-access')));
      expect(row.authType, 'oauth2');
    });
  });

  group('AuthRepositoryImpl update / delete', () {
    test('enable toggle persists and refreshes pool slots', () async {
      final account = await repository.addAccount(
        draft: buildDraft(email: 'carol@163.com'),
        credential: const PasswordAccountCredential('auth-code'),
      );
      pool.syncCalls.clear();

      await repository.setAccountEnabled(account.id, false);

      final row = await database.select(database.dbAccounts).getSingle();
      expect(row.isEnabled, isFalse);
      expect(pool.syncCalls.single, <String>[account.id]);
    });

    test(
      'replaceCredential updates secure storage without touching metadata',
      () async {
        final account = await repository.addAccount(
          draft: buildDraft(email: 'carol@163.com'),
          credential: const PasswordAccountCredential('old-code'),
        );

        await repository.replaceCredential(
          account.id,
          const PasswordAccountCredential('new-code'),
        );

        expect(storage.passwordSecrets[account.id], 'new-code');
        final row = await database.select(database.dbAccounts).getSingle();
        expect(row.toJson().toString(), isNot(contains('new-code')));
      },
    );

    test(
      'delete removes metadata, secure credentials and the pool slot',
      () async {
        final account = await repository.addAccount(
          draft: buildDraft(email: 'carol@163.com'),
          credential: const PasswordAccountCredential('delete-me'),
        );
        expect(await repository.getAccounts(), hasLength(1));

        await repository.deleteAccount(account.id);

        expect(await repository.getAccounts(), isEmpty);
        expect(storage.passwordSecrets, isEmpty);
        expect(storage.oauthBundles, isEmpty);
        expect(storage.deleteCredentialCalls, 1);
        expect(pool.syncCalls.last, isEmpty);
      },
    );

    test('deleteAccount removes outbox attachment files after DB cascade',
        () async {
      final account = await repository.addAccount(
        draft: buildDraft(email: 'carol@163.com'),
        credential: const PasswordAccountCredential('delete-attachments'),
      );
      final root = await Directory.systemTemp.createTemp('auth_outbox_');
      addTearDown(() => root.delete(recursive: true));
      final file = File(
        '${root.path}/mail_outbox_attachments/${account.id}/note.txt',
      );
      await file.parent.create(recursive: true);
      await file.writeAsString('outbox data');
      final store = AttachmentStore(rootProvider: () async => root);
      final withCleanup = AuthRepositoryImpl(
        database: database,
        secureStorage: storage,
        connectionPool: pool,
        cleanupOutboxAttachments: store.cleanupPaths,
      );
      await database.into(database.dbOutboxMessages).insert(
            DbOutboxMessagesCompanion.insert(
              id: 'outbox-delete',
              accountId: account.id,
              mode: 'newMail',
              toRecipientsJson: '[]',
              ccJson: '[]',
              bccJson: '[]',
              subject: 'attachment draft',
              plainBody: 'body',
              attachmentsJson:
                  '[{"fileName":"note.txt","mimeType":"text/plain",'
                  '"localPath":"${file.path}","sizeBytes":10}]',
              status: 'draft',
              createdAt: 1,
              updatedAt: 1,
            ),
          );

      await withCleanup.deleteAccount(account.id);

      expect(await database.select(database.dbOutboxMessages).get(), isEmpty);
      expect(file.existsSync(), isFalse);
    });

    test(
      'deleteAccount keeps credentials when metadata deletion fails',
      () async {
        final account = await repository.addAccount(
          draft: buildDraft(email: 'carol@163.com'),
          credential: const PasswordAccountCredential('keep-me'),
        );
        await database.customStatement('DROP TABLE db_accounts');

        await expectLater(
          repository.deleteAccount(account.id),
          throwsA(anything),
        );

        expect(storage.passwordSecrets[account.id], 'keep-me');
      },
    );
  });
}
