// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_setup_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AccountSetup)
final accountSetupProvider = AccountSetupProvider._();

final class AccountSetupProvider
    extends $NotifierProvider<AccountSetup, AccountSetupState> {
  AccountSetupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountSetupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountSetupHash();

  @$internal
  @override
  AccountSetup create() => AccountSetup();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountSetupState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountSetupState>(value),
    );
  }
}

String _$accountSetupHash() => r'b79048ab18fcfe4d84aa1df92c2f1bed78fc1527';

abstract class _$AccountSetup extends $Notifier<AccountSetupState> {
  AccountSetupState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AccountSetupState, AccountSetupState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AccountSetupState, AccountSetupState>,
              AccountSetupState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
