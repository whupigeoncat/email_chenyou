// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SearchEmails)
final searchEmailsProvider = SearchEmailsProvider._();

final class SearchEmailsProvider
    extends $NotifierProvider<SearchEmails, SearchEmailsState> {
  SearchEmailsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchEmailsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchEmailsHash();

  @$internal
  @override
  SearchEmails create() => SearchEmails();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchEmailsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchEmailsState>(value),
    );
  }
}

String _$searchEmailsHash() => r'd387946cdadc19c156ae70d6ddfc09864957be11';

abstract class _$SearchEmails extends $Notifier<SearchEmailsState> {
  SearchEmailsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SearchEmailsState, SearchEmailsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SearchEmailsState, SearchEmailsState>,
              SearchEmailsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
