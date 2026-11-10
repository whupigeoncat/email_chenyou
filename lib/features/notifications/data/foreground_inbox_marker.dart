import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'inbox_notification_state_store.dart';

/// Advances the background notification watermark for mail the user has
/// already seen in the foreground.
///
/// The marker is intentionally idempotent and only reads the local INBOX cache;
/// it never opens a connection or changes mail rows.
class ForegroundInboxMarker {
  ForegroundInboxMarker({required this.database, required this.stateStore});

  final AppDatabase database;
  final InboxNotificationStateStore stateStore;

  Future<void> markSynced(String accountId) async {
    final folder =
        await (database.select(database.dbFolders)
              ..where(
                (table) =>
                    table.accountId.equals(accountId) &
                    table.role.equals('inbox'),
              )
              ..limit(1))
            .getSingleOrNull();
    if (folder == null) return;

    final row = await database
        .customSelect(
          'SELECT MAX(uid) AS max_uid FROM db_emails WHERE folder_id = ?',
          variables: [Variable.withString(folder.id)],
        )
        .getSingle();
    final maxUid = (row.data['max_uid'] as int?) ?? 0;
    await stateStore.markForegroundSynced(
      accountId: accountId,
      uidValidity: folder.uidValidity,
      lastUid: maxUid,
    );
  }

  Future<void> reset(String accountId) => stateStore.reset(accountId);
}
