import '../entities/account_setup_draft.dart';
import '../entities/mail_account.dart';

/// Account metadata + credential lifecycle contract.
///
/// Metadata lives in `DbAccounts`; secrets live only in `SecureStorageService`.
/// Implementations must never expose a path that writes a secret to SQLite.
abstract interface class AuthRepository {
  /// Live stream of persisted accounts, ordered by creation time.
  Stream<List<MailAccount>> watchAccounts();

  Future<List<MailAccount>> getAccounts();

  Future<MailAccount?> getAccount(String accountId);

  /// Saves credentials first, then inserts metadata. If the DB write fails the
  /// freshly written credentials are rolled back before the error is surfaced.
  Future<MailAccount> addAccount({
    required MailAccountDraft draft,
    required PendingAccountCredential credential,
  });

  Future<MailAccount> updateAccount(MailAccount account);

  Future<void> setAccountEnabled(String accountId, bool isEnabled);

  Future<void> replaceCredential(
    String accountId,
    PendingAccountCredential credential,
  );

  /// Removes metadata, secure-storage credentials and the connection-pool slot.
  Future<void> deleteAccount(String accountId);

  /// Loads persisted accounts and seeds `ConnectionPool.syncAccounts()`.
  Future<void> initialize();
}
