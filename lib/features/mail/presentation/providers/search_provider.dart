import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/unified_email.dart';
import 'mail_providers.dart';

part 'search_provider.g.dart';

@immutable
class SearchEmailsState {
  const SearchEmailsState({
    this.query = '',
    this.accountId,
    this.unreadOnly = false,
    this.isSearching = false,
    this.results = const [],
    this.errorMessage,
  });

  final String query;
  final String? accountId;
  final bool unreadOnly;
  final bool isSearching;
  final List<UnifiedEmail> results;
  final String? errorMessage;

  SearchEmailsState copyWith({
    String? query,
    String? accountId,
    bool? unreadOnly,
    bool? isSearching,
    List<UnifiedEmail>? results,
    String? errorMessage,
    bool clearError = false,
    bool clearAccount = false,
  }) {
    return SearchEmailsState(
      query: query ?? this.query,
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      unreadOnly: unreadOnly ?? this.unreadOnly,
      isSearching: isSearching ?? this.isSearching,
      results: results ?? this.results,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

@riverpod
class SearchEmails extends _$SearchEmails {
  Timer? _debounce;

  @override
  SearchEmailsState build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _debounce = null;
    });
    return const SearchEmailsState();
  }

  void updateQuery(String value) {
    state = state.copyWith(query: value, clearError: true);
    _schedule();
  }

  void setAccountId(String? accountId) {
    state = state.copyWith(
      accountId: accountId,
      clearAccount: accountId == null,
      clearError: true,
    );
    _schedule(immediate: true);
  }

  void setUnreadOnly(bool value) {
    state = state.copyWith(unreadOnly: value, clearError: true);
    _schedule(immediate: true);
  }

  Future<void> searchNow() => _search();

  void _schedule({bool immediate = false}) {
    _debounce?.cancel();
    final query = state.query.trim();
    if (query.isEmpty) {
      state = state.copyWith(
        results: const [],
        isSearching: false,
        clearError: true,
      );
      return;
    }
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 300),
      () => unawaited(_search()),
    );
  }

  Future<void> _search() async {
    final query = state.query.trim();
    if (query.isEmpty || !ref.mounted) return;
    state = state.copyWith(isSearching: true, clearError: true);
    try {
      final results = await ref.read(searchEmailsUseCaseProvider).call(
            query: query,
            accountId: state.accountId,
            unreadOnly: state.unreadOnly,
          );
      if (!ref.mounted || state.query.trim() != query) return;
      state = state.copyWith(
        results: results,
        isSearching: false,
        clearError: true,
      );
    } on AppFailure catch (failure) {
      if (!ref.mounted || state.query.trim() != query) return;
      state = state.copyWith(
        isSearching: false,
        errorMessage: failure.userMessage,
      );
    } catch (error) {
      if (!ref.mounted || state.query.trim() != query) return;
      state = state.copyWith(
        isSearching: false,
        errorMessage: '搜索失败：$error',
      );
    }
  }
}
