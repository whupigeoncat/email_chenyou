// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EmailDetail)
final emailDetailProvider = EmailDetailProvider._();

final class EmailDetailProvider
    extends $NotifierProvider<EmailDetail, EmailDetailState> {
  EmailDetailProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailDetailProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailDetailHash();

  @$internal
  @override
  EmailDetail create() => EmailDetail();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmailDetailState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmailDetailState>(value),
    );
  }
}

String _$emailDetailHash() => r'4e695e3db867ff969fa63dbba9296f6b4885f281';

abstract class _$EmailDetail extends $Notifier<EmailDetailState> {
  EmailDetailState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<EmailDetailState, EmailDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EmailDetailState, EmailDetailState>,
              EmailDetailState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(emailById)
final emailByIdProvider = EmailByIdFamily._();

final class EmailByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<UnifiedEmail?>,
          UnifiedEmail?,
          Stream<UnifiedEmail?>
        >
    with $FutureModifier<UnifiedEmail?>, $StreamProvider<UnifiedEmail?> {
  EmailByIdProvider._({
    required EmailByIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'emailByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$emailByIdHash();

  @override
  String toString() {
    return r'emailByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<UnifiedEmail?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<UnifiedEmail?> create(Ref ref) {
    final argument = this.argument as int;
    return emailById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EmailByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$emailByIdHash() => r'1481b9a20995638179d81ed8e696c8dced64d2d4';

final class EmailByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<UnifiedEmail?>, int> {
  EmailByIdFamily._()
    : super(
        retry: null,
        name: r'emailByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EmailByIdProvider call(int localId) =>
      EmailByIdProvider._(argument: localId, from: this);

  @override
  String toString() => r'emailByIdProvider';
}
