// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_runtime_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Starts lifecycle/network observers, seeds connection-pool slots, runs the
/// first sync for enabled accounts, and mounts the IDLE coordinator exactly
/// once per app process.

@ProviderFor(appRuntime)
final appRuntimeProvider = AppRuntimeProvider._();

/// Starts lifecycle/network observers, seeds connection-pool slots, runs the
/// first sync for enabled accounts, and mounts the IDLE coordinator exactly
/// once per app process.

final class AppRuntimeProvider
    extends $FunctionalProvider<AppRuntime, AppRuntime, AppRuntime>
    with $Provider<AppRuntime> {
  /// Starts lifecycle/network observers, seeds connection-pool slots, runs the
  /// first sync for enabled accounts, and mounts the IDLE coordinator exactly
  /// once per app process.
  AppRuntimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRuntimeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRuntimeHash();

  @$internal
  @override
  $ProviderElement<AppRuntime> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppRuntime create(Ref ref) {
    return appRuntime(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppRuntime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppRuntime>(value),
    );
  }
}

String _$appRuntimeHash() => r'15262ec98977329b1551460b91c28e23650f6d78';
