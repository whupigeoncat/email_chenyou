// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_inbox_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UnifiedInboxView)
final unifiedInboxViewProvider = UnifiedInboxViewProvider._();

final class UnifiedInboxViewProvider
    extends $NotifierProvider<UnifiedInboxView, UnifiedInboxViewState> {
  UnifiedInboxViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unifiedInboxViewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unifiedInboxViewHash();

  @$internal
  @override
  UnifiedInboxView create() => UnifiedInboxView();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UnifiedInboxViewState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UnifiedInboxViewState>(value),
    );
  }
}

String _$unifiedInboxViewHash() => r'7a9d325ec35facc9473a32121bdad52621bba1f2';

abstract class _$UnifiedInboxView extends $Notifier<UnifiedInboxViewState> {
  UnifiedInboxViewState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UnifiedInboxViewState, UnifiedInboxViewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UnifiedInboxViewState, UnifiedInboxViewState>,
              UnifiedInboxViewState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(inboxEmails)
final inboxEmailsProvider = InboxEmailsProvider._();

final class InboxEmailsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<UnifiedEmail>>,
          List<UnifiedEmail>,
          Stream<List<UnifiedEmail>>
        >
    with
        $FutureModifier<List<UnifiedEmail>>,
        $StreamProvider<List<UnifiedEmail>> {
  InboxEmailsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inboxEmailsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inboxEmailsHash();

  @$internal
  @override
  $StreamProviderElement<List<UnifiedEmail>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<UnifiedEmail>> create(Ref ref) {
    return inboxEmails(ref);
  }
}

String _$inboxEmailsHash() => r'dbaa15e3eeed3361602f209959ce65e2db75e227';
