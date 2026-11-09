import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/mail_account.dart';
import '../../domain/entities/mail_folder.dart';
import '../../domain/entities/unified_email.dart';
import 'mail_providers.dart';

part 'unified_inbox_provider.g.dart';

const Object _unset = Object();

@immutable
class UnifiedInboxViewState {
  const UnifiedInboxViewState({
    this.accountId,
    this.folder,
    this.unreadOnly = false,
    this.isSyncing = false,
    this.errorMessage,
    this.lastSyncedAt,
    this.pageLimit = 200,
  });

  /// Null means the aggregated inbox across all enabled accounts.
  final String? accountId;

  /// Null means the aggregated inbox; otherwise a specific folder.
  final MailFolder? folder;

  final bool unreadOnly;
  final bool isSyncing;
  final String? errorMessage;
  final DateTime? lastSyncedAt;

  /// Number of newest rows requested for the first/next window.
  final int pageLimit;

  bool get isUnified => folder == null;

  String get title => folder?.displayName ?? '聚合收件箱';

  UnifiedInboxViewState copyWith({
    Object? accountId = _unset,
    Object? folder = _unset,
    bool? unreadOnly,
    bool? isSyncing,
    Object? errorMessage = _unset,
    Object? lastSyncedAt = _unset,
    int? pageLimit,
  }) {
    return UnifiedInboxViewState(
      accountId: identical(accountId, _unset)
          ? this.accountId
          : accountId as String?,
      folder: identical(folder, _unset) ? this.folder : folder as MailFolder?,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      lastSyncedAt: identical(lastSyncedAt, _unset)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      pageLimit: pageLimit ?? this.pageLimit,
    );
  }
}

@riverpod
class UnifiedInboxView extends _$UnifiedInboxView {
  DateTime? _lastLoadMoreAt;

  @override
  UnifiedInboxViewState build() => const UnifiedInboxViewState();

  void selectAccount(String? accountId) {
    state = state.copyWith(accountId: accountId, errorMessage: null);
  }

  Future<void> openFolder(MailFolder? folder) async {
    state = state.copyWith(
      folder: folder,
      errorMessage: null,
      lastSyncedAt: null,
    );
    if (folder != null && folder.role != FolderRole.inbox) {
      await syncCurrent();
    }
  }

  void toggleUnreadOnly() {
    state = state.copyWith(unreadOnly: !state.unreadOnly);
  }

  /// Expands the window by 200 rows. Coalesces rapid scroll notifications so a
  /// single gesture cannot accidentally request the entire mailbox.
  void loadMore() {
    final now = DateTime.now();
    if (_lastLoadMoreAt != null &&
        now.difference(_lastLoadMoreAt!) < const Duration(milliseconds: 300)) {
      return;
    }
    _lastLoadMoreAt = now;
    state = state.copyWith(pageLimit: state.pageLimit + 200);
  }

  Future<void> syncCurrent() async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      final auth = ref.read(authRepositoryProvider);
      final folder = state.folder;
      if (folder != null) {
        final account = await auth.getAccount(folder.accountId);
        if (account == null || !account.isEnabled) {
          throw StateError('账户不存在或已停用');
        }
        await ref.read(pollFolderUseCaseProvider).call(
              account: account,
              folder: folder,
            );
      } else {
        final accounts = (await auth.getAccounts())
            .where((account) => account.isEnabled)
            .toList(growable: false);
        for (final account in accounts) {
          await _syncAccount(account);
        }
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        isSyncing: false,
        lastSyncedAt: DateTime.now(),
        errorMessage: null,
      );
    } on AppFailure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isSyncing: false,
        errorMessage: failure.userMessage,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isSyncing: false,
        errorMessage: '同步失败：$error',
      );
    }
  }

  Future<void> _syncAccount(MailAccount account) {
    // Manual refresh shares the same per-account lock and self-generated
    // EXISTS suppression as IDLE events and cold-start bootstrap.
    return ref.read(inboxSyncCoordinatorProvider).syncNow(account.id);
  }

  Future<void> toggleRead(UnifiedEmail email) {
    return _updateFlags(email, isRead: !email.isRead);
  }

  Future<void> toggleStar(UnifiedEmail email) {
    return _updateFlags(email, isFlagged: !email.isFlagged);
  }

  Future<void> _updateFlags(
    UnifiedEmail email, {
    bool? isRead,
    bool? isFlagged,
  }) async {
    final localId = email.localId;
    if (localId == null) return;
    state = state.copyWith(errorMessage: null);
    try {
      final account = await ref
          .read(authRepositoryProvider)
          .getAccount(email.accountId);
      if (account == null) throw StateError('账户不存在');
      await ref.read(updateEmailFlagsUseCaseProvider).call(
            account: account,
            emailLocalId: localId,
            isRead: isRead,
            isFlagged: isFlagged,
          );
    } on AppFailure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(errorMessage: failure.userMessage);
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(errorMessage: '更新邮件状态失败：$error');
    }
  }
}

@riverpod
Stream<List<UnifiedEmail>> inboxEmails(Ref ref) {
  final view = ref.watch(unifiedInboxViewProvider);
  final repository = ref.watch(mailLocalRepositoryProvider);
  final folder = view.folder;
  if (folder != null) {
    return repository.watchFolderEmails(
      folder.id,
      limit: view.pageLimit,
      unreadOnly: view.unreadOnly,
    );
  }
  return repository.watchUnifiedInbox(
    limit: view.pageLimit,
    accountId: view.accountId,
    unreadOnly: view.unreadOnly,
  );
}
