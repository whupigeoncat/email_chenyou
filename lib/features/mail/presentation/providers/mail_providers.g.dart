// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mail_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mailLocalDataSource)
final mailLocalDataSourceProvider = MailLocalDataSourceProvider._();

final class MailLocalDataSourceProvider
    extends
        $FunctionalProvider<
          MailLocalDataSource,
          MailLocalDataSource,
          MailLocalDataSource
        >
    with $Provider<MailLocalDataSource> {
  MailLocalDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mailLocalDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mailLocalDataSourceHash();

  @$internal
  @override
  $ProviderElement<MailLocalDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MailLocalDataSource create(Ref ref) {
    return mailLocalDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MailLocalDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MailLocalDataSource>(value),
    );
  }
}

String _$mailLocalDataSourceHash() =>
    r'ec0d2db89e1fd9a1e30fc9eb60a0752bdb3e52e6';

@ProviderFor(mailLocalRepository)
final mailLocalRepositoryProvider = MailLocalRepositoryProvider._();

final class MailLocalRepositoryProvider
    extends
        $FunctionalProvider<
          MailLocalRepository,
          MailLocalRepository,
          MailLocalRepository
        >
    with $Provider<MailLocalRepository> {
  MailLocalRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mailLocalRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mailLocalRepositoryHash();

  @$internal
  @override
  $ProviderElement<MailLocalRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MailLocalRepository create(Ref ref) {
    return mailLocalRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MailLocalRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MailLocalRepository>(value),
    );
  }
}

String _$mailLocalRepositoryHash() =>
    r'd3210b02bc8d7c38b9b984b09a166a7fe9728eba';

@ProviderFor(mailRemoteDataSource)
final mailRemoteDataSourceProvider = MailRemoteDataSourceProvider._();

final class MailRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          MailRemoteDataSource,
          MailRemoteDataSource,
          MailRemoteDataSource
        >
    with $Provider<MailRemoteDataSource> {
  MailRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mailRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mailRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<MailRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MailRemoteDataSource create(Ref ref) {
    return mailRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MailRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MailRemoteDataSource>(value),
    );
  }
}

String _$mailRemoteDataSourceHash() =>
    r'c452721dbb24dff840e22f00a9d26c881feaba0a';

@ProviderFor(mailRemoteRepository)
final mailRemoteRepositoryProvider = MailRemoteRepositoryProvider._();

final class MailRemoteRepositoryProvider
    extends
        $FunctionalProvider<
          MailRemoteRepository,
          MailRemoteRepository,
          MailRemoteRepository
        >
    with $Provider<MailRemoteRepository> {
  MailRemoteRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mailRemoteRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mailRemoteRepositoryHash();

  @$internal
  @override
  $ProviderElement<MailRemoteRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MailRemoteRepository create(Ref ref) {
    return mailRemoteRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MailRemoteRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MailRemoteRepository>(value),
    );
  }
}

String _$mailRemoteRepositoryHash() =>
    r'e4fb1dbf3c2520e7a50935d557df37bf5588ba24';

@ProviderFor(syncInboxUseCase)
final syncInboxUseCaseProvider = SyncInboxUseCaseProvider._();

final class SyncInboxUseCaseProvider
    extends
        $FunctionalProvider<
          SyncInboxUseCase,
          SyncInboxUseCase,
          SyncInboxUseCase
        >
    with $Provider<SyncInboxUseCase> {
  SyncInboxUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncInboxUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncInboxUseCaseHash();

  @$internal
  @override
  $ProviderElement<SyncInboxUseCase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncInboxUseCase create(Ref ref) {
    return syncInboxUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncInboxUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncInboxUseCase>(value),
    );
  }
}

String _$syncInboxUseCaseHash() => r'e393ab3d1dbff9e04e0c24ee0b01e699a8f39f6b';

@ProviderFor(pollFolderUseCase)
final pollFolderUseCaseProvider = PollFolderUseCaseProvider._();

final class PollFolderUseCaseProvider
    extends
        $FunctionalProvider<
          PollFolderUseCase,
          PollFolderUseCase,
          PollFolderUseCase
        >
    with $Provider<PollFolderUseCase> {
  PollFolderUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pollFolderUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pollFolderUseCaseHash();

  @$internal
  @override
  $ProviderElement<PollFolderUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PollFolderUseCase create(Ref ref) {
    return pollFolderUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PollFolderUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PollFolderUseCase>(value),
    );
  }
}

String _$pollFolderUseCaseHash() => r'00a4113ecb15e8ecdd6226a928c5b24ea3fd5887';

@ProviderFor(fetchMessageBodyUseCase)
final fetchMessageBodyUseCaseProvider = FetchMessageBodyUseCaseProvider._();

final class FetchMessageBodyUseCaseProvider
    extends
        $FunctionalProvider<
          FetchMessageBodyUseCase,
          FetchMessageBodyUseCase,
          FetchMessageBodyUseCase
        >
    with $Provider<FetchMessageBodyUseCase> {
  FetchMessageBodyUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fetchMessageBodyUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fetchMessageBodyUseCaseHash();

  @$internal
  @override
  $ProviderElement<FetchMessageBodyUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FetchMessageBodyUseCase create(Ref ref) {
    return fetchMessageBodyUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FetchMessageBodyUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FetchMessageBodyUseCase>(value),
    );
  }
}

String _$fetchMessageBodyUseCaseHash() =>
    r'9cc65f8066d52566658a4d3d1d6364f19e01388a';

@ProviderFor(downloadAttachmentUseCase)
final downloadAttachmentUseCaseProvider = DownloadAttachmentUseCaseProvider._();

final class DownloadAttachmentUseCaseProvider
    extends
        $FunctionalProvider<
          DownloadAttachmentUseCase,
          DownloadAttachmentUseCase,
          DownloadAttachmentUseCase
        >
    with $Provider<DownloadAttachmentUseCase> {
  DownloadAttachmentUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadAttachmentUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadAttachmentUseCaseHash();

  @$internal
  @override
  $ProviderElement<DownloadAttachmentUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadAttachmentUseCase create(Ref ref) {
    return downloadAttachmentUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadAttachmentUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadAttachmentUseCase>(value),
    );
  }
}

String _$downloadAttachmentUseCaseHash() =>
    r'77ba9cc25b3d6dc8a622ac833136ba076e19458b';

@ProviderFor(updateEmailFlagsUseCase)
final updateEmailFlagsUseCaseProvider = UpdateEmailFlagsUseCaseProvider._();

final class UpdateEmailFlagsUseCaseProvider
    extends
        $FunctionalProvider<
          UpdateEmailFlagsUseCase,
          UpdateEmailFlagsUseCase,
          UpdateEmailFlagsUseCase
        >
    with $Provider<UpdateEmailFlagsUseCase> {
  UpdateEmailFlagsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateEmailFlagsUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateEmailFlagsUseCaseHash();

  @$internal
  @override
  $ProviderElement<UpdateEmailFlagsUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UpdateEmailFlagsUseCase create(Ref ref) {
    return updateEmailFlagsUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateEmailFlagsUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateEmailFlagsUseCase>(value),
    );
  }
}

String _$updateEmailFlagsUseCaseHash() =>
    r'c8a1242c62f98bdc00e7603ae942e72eb8177232';

@ProviderFor(searchEmailsUseCase)
final searchEmailsUseCaseProvider = SearchEmailsUseCaseProvider._();

final class SearchEmailsUseCaseProvider
    extends
        $FunctionalProvider<
          SearchEmailsUseCase,
          SearchEmailsUseCase,
          SearchEmailsUseCase
        >
    with $Provider<SearchEmailsUseCase> {
  SearchEmailsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchEmailsUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchEmailsUseCaseHash();

  @$internal
  @override
  $ProviderElement<SearchEmailsUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SearchEmailsUseCase create(Ref ref) {
    return searchEmailsUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchEmailsUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchEmailsUseCase>(value),
    );
  }
}

String _$searchEmailsUseCaseHash() =>
    r'4ff7818bd532880f2bc1abc3ce86bc9617591ea8';

@ProviderFor(unifiedInbox)
final unifiedInboxProvider = UnifiedInboxProvider._();

final class UnifiedInboxProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<UnifiedEmail>>,
          List<UnifiedEmail>,
          Stream<List<UnifiedEmail>>
        >
    with
        $FutureModifier<List<UnifiedEmail>>,
        $StreamProvider<List<UnifiedEmail>> {
  UnifiedInboxProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unifiedInboxProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unifiedInboxHash();

  @$internal
  @override
  $StreamProviderElement<List<UnifiedEmail>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<UnifiedEmail>> create(Ref ref) {
    return unifiedInbox(ref);
  }
}

String _$unifiedInboxHash() => r'0777b17dfaea33d690d376f16cc7f4d00550c1db';

@ProviderFor(accountFolders)
final accountFoldersProvider = AccountFoldersFamily._();

final class AccountFoldersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MailFolder>>,
          List<MailFolder>,
          Stream<List<MailFolder>>
        >
    with $FutureModifier<List<MailFolder>>, $StreamProvider<List<MailFolder>> {
  AccountFoldersProvider._({
    required AccountFoldersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountFoldersProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountFoldersHash();

  @override
  String toString() {
    return r'accountFoldersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<MailFolder>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MailFolder>> create(Ref ref) {
    final argument = this.argument as String;
    return accountFolders(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountFoldersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountFoldersHash() => r'fad0689d838a578a16c45de47df7c397ad58fa4a';

final class AccountFoldersFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<MailFolder>>, String> {
  AccountFoldersFamily._()
    : super(
        retry: null,
        name: r'accountFoldersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  AccountFoldersProvider call(String accountId) =>
      AccountFoldersProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountFoldersProvider';
}

@ProviderFor(trustedSendersRepository)
final trustedSendersRepositoryProvider = TrustedSendersRepositoryProvider._();

final class TrustedSendersRepositoryProvider
    extends
        $FunctionalProvider<
          TrustedSendersRepository,
          TrustedSendersRepository,
          TrustedSendersRepository
        >
    with $Provider<TrustedSendersRepository> {
  TrustedSendersRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trustedSendersRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trustedSendersRepositoryHash();

  @$internal
  @override
  $ProviderElement<TrustedSendersRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TrustedSendersRepository create(Ref ref) {
    return trustedSendersRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrustedSendersRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrustedSendersRepository>(value),
    );
  }
}

String _$trustedSendersRepositoryHash() =>
    r'71a78aaf61c39ba228fa7c589ccab2b1cd571c27';

@ProviderFor(trustedSenders)
final trustedSendersProvider = TrustedSendersProvider._();

final class TrustedSendersProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<TrustedSender>>,
          Set<TrustedSender>,
          Stream<Set<TrustedSender>>
        >
    with
        $FutureModifier<Set<TrustedSender>>,
        $StreamProvider<Set<TrustedSender>> {
  TrustedSendersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trustedSendersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trustedSendersHash();

  @$internal
  @override
  $StreamProviderElement<Set<TrustedSender>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Set<TrustedSender>> create(Ref ref) {
    return trustedSenders(ref);
  }
}

String _$trustedSendersHash() => r'9bb336006c656624f75471eea6db56c059eaf29b';

@ProviderFor(attachmentPicker)
final attachmentPickerProvider = AttachmentPickerProvider._();

final class AttachmentPickerProvider
    extends
        $FunctionalProvider<
          AttachmentPicker,
          AttachmentPicker,
          AttachmentPicker
        >
    with $Provider<AttachmentPicker> {
  AttachmentPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attachmentPickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attachmentPickerHash();

  @$internal
  @override
  $ProviderElement<AttachmentPicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AttachmentPicker create(Ref ref) {
    return attachmentPicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttachmentPicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttachmentPicker>(value),
    );
  }
}

String _$attachmentPickerHash() => r'6254e6838958558d30ea46dcedb49edcf6d81838';

@ProviderFor(attachmentStore)
final attachmentStoreProvider = AttachmentStoreProvider._();

final class AttachmentStoreProvider
    extends
        $FunctionalProvider<AttachmentStore, AttachmentStore, AttachmentStore>
    with $Provider<AttachmentStore> {
  AttachmentStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attachmentStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attachmentStoreHash();

  @$internal
  @override
  $ProviderElement<AttachmentStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AttachmentStore create(Ref ref) {
    return attachmentStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttachmentStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttachmentStore>(value),
    );
  }
}

String _$attachmentStoreHash() => r'ed54760ac5cc469416dc9bce141b0698d47c2982';

@ProviderFor(composeDraftFactory)
final composeDraftFactoryProvider = ComposeDraftFactoryProvider._();

final class ComposeDraftFactoryProvider
    extends
        $FunctionalProvider<
          ComposeDraftFactory,
          ComposeDraftFactory,
          ComposeDraftFactory
        >
    with $Provider<ComposeDraftFactory> {
  ComposeDraftFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'composeDraftFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$composeDraftFactoryHash();

  @$internal
  @override
  $ProviderElement<ComposeDraftFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ComposeDraftFactory create(Ref ref) {
    return composeDraftFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ComposeDraftFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ComposeDraftFactory>(value),
    );
  }
}

String _$composeDraftFactoryHash() =>
    r'63f7b548a8845da4837ad9101f12a09c8136187e';

@ProviderFor(outboxLocalDataSource)
final outboxLocalDataSourceProvider = OutboxLocalDataSourceProvider._();

final class OutboxLocalDataSourceProvider
    extends
        $FunctionalProvider<
          OutboxLocalDataSource,
          OutboxLocalDataSource,
          OutboxLocalDataSource
        >
    with $Provider<OutboxLocalDataSource> {
  OutboxLocalDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outboxLocalDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outboxLocalDataSourceHash();

  @$internal
  @override
  $ProviderElement<OutboxLocalDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OutboxLocalDataSource create(Ref ref) {
    return outboxLocalDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OutboxLocalDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OutboxLocalDataSource>(value),
    );
  }
}

String _$outboxLocalDataSourceHash() =>
    r'de774fbabd51afee453becc5bb651cf8bf5f6880';

@ProviderFor(outboxRepository)
final outboxRepositoryProvider = OutboxRepositoryProvider._();

final class OutboxRepositoryProvider
    extends
        $FunctionalProvider<
          OutboxRepository,
          OutboxRepository,
          OutboxRepository
        >
    with $Provider<OutboxRepository> {
  OutboxRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outboxRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outboxRepositoryHash();

  @$internal
  @override
  $ProviderElement<OutboxRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OutboxRepository create(Ref ref) {
    return outboxRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OutboxRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OutboxRepository>(value),
    );
  }
}

String _$outboxRepositoryHash() => r'e48073d98c4af3f531e3bd8609652ab0acb4fc5e';

@ProviderFor(localCacheStats)
final localCacheStatsProvider = LocalCacheStatsProvider._();

final class LocalCacheStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<LocalCacheStats>,
          LocalCacheStats,
          FutureOr<LocalCacheStats>
        >
    with $FutureModifier<LocalCacheStats>, $FutureProvider<LocalCacheStats> {
  LocalCacheStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localCacheStatsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localCacheStatsHash();

  @$internal
  @override
  $FutureProviderElement<LocalCacheStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LocalCacheStats> create(Ref ref) {
    return localCacheStats(ref);
  }
}

String _$localCacheStatsHash() => r'79eb5bdab551e688799d49ebc1f0ed6617d6812c';

@ProviderFor(outboxMessages)
final outboxMessagesProvider = OutboxMessagesProvider._();

final class OutboxMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<OutboxMessage>>,
          List<OutboxMessage>,
          Stream<List<OutboxMessage>>
        >
    with
        $FutureModifier<List<OutboxMessage>>,
        $StreamProvider<List<OutboxMessage>> {
  OutboxMessagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outboxMessagesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outboxMessagesHash();

  @$internal
  @override
  $StreamProviderElement<List<OutboxMessage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<OutboxMessage>> create(Ref ref) {
    return outboxMessages(ref);
  }
}

String _$outboxMessagesHash() => r'334fb4e5031d9eccd10d4c662f1d037130d96345';

@ProviderFor(outboxDrafts)
final outboxDraftsProvider = OutboxDraftsProvider._();

final class OutboxDraftsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<OutboxMessage>>,
          List<OutboxMessage>,
          Stream<List<OutboxMessage>>
        >
    with
        $FutureModifier<List<OutboxMessage>>,
        $StreamProvider<List<OutboxMessage>> {
  OutboxDraftsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outboxDraftsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outboxDraftsHash();

  @$internal
  @override
  $StreamProviderElement<List<OutboxMessage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<OutboxMessage>> create(Ref ref) {
    return outboxDrafts(ref);
  }
}

String _$outboxDraftsHash() => r'3db402b258cffb4fca7d973759e363ea4275fc7d';

@ProviderFor(outboxCounts)
final outboxCountsProvider = OutboxCountsProvider._();

final class OutboxCountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<OutboxCounts>,
          OutboxCounts,
          Stream<OutboxCounts>
        >
    with $FutureModifier<OutboxCounts>, $StreamProvider<OutboxCounts> {
  OutboxCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outboxCountsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outboxCountsHash();

  @$internal
  @override
  $StreamProviderElement<OutboxCounts> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<OutboxCounts> create(Ref ref) {
    return outboxCounts(ref);
  }
}

String _$outboxCountsHash() => r'de7351f93e69c83b8c103668a0fc06305d6d302d';

@ProviderFor(smtpSessionFactory)
final smtpSessionFactoryProvider = SmtpSessionFactoryProvider._();

final class SmtpSessionFactoryProvider
    extends
        $FunctionalProvider<
          SmtpSessionFactory,
          SmtpSessionFactory,
          SmtpSessionFactory
        >
    with $Provider<SmtpSessionFactory> {
  SmtpSessionFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'smtpSessionFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$smtpSessionFactoryHash();

  @$internal
  @override
  $ProviderElement<SmtpSessionFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SmtpSessionFactory create(Ref ref) {
    return smtpSessionFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SmtpSessionFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SmtpSessionFactory>(value),
    );
  }
}

String _$smtpSessionFactoryHash() =>
    r'fc1419ba352c406013f20c82b53f1fcda7ef8d36';

@ProviderFor(outboxQueue)
final outboxQueueProvider = OutboxQueueProvider._();

final class OutboxQueueProvider
    extends
        $FunctionalProvider<
          OutboxQueueService,
          OutboxQueueService,
          OutboxQueueService
        >
    with $Provider<OutboxQueueService> {
  OutboxQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outboxQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outboxQueueHash();

  @$internal
  @override
  $ProviderElement<OutboxQueueService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OutboxQueueService create(Ref ref) {
    return outboxQueue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OutboxQueueService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OutboxQueueService>(value),
    );
  }
}

String _$outboxQueueHash() => r'e923dfb867fc4dcf29dba2c9a0ec3694bca54215';

@ProviderFor(saveDraftUseCase)
final saveDraftUseCaseProvider = SaveDraftUseCaseProvider._();

final class SaveDraftUseCaseProvider
    extends
        $FunctionalProvider<
          SaveDraftUseCase,
          SaveDraftUseCase,
          SaveDraftUseCase
        >
    with $Provider<SaveDraftUseCase> {
  SaveDraftUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveDraftUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveDraftUseCaseHash();

  @$internal
  @override
  $ProviderElement<SaveDraftUseCase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SaveDraftUseCase create(Ref ref) {
    return saveDraftUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveDraftUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveDraftUseCase>(value),
    );
  }
}

String _$saveDraftUseCaseHash() => r'ccda71e5696b1f5d09a15a38d587be23bc61051b';

@ProviderFor(queueAndSendEmailUseCase)
final queueAndSendEmailUseCaseProvider = QueueAndSendEmailUseCaseProvider._();

final class QueueAndSendEmailUseCaseProvider
    extends
        $FunctionalProvider<
          QueueAndSendEmailUseCase,
          QueueAndSendEmailUseCase,
          QueueAndSendEmailUseCase
        >
    with $Provider<QueueAndSendEmailUseCase> {
  QueueAndSendEmailUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'queueAndSendEmailUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$queueAndSendEmailUseCaseHash();

  @$internal
  @override
  $ProviderElement<QueueAndSendEmailUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  QueueAndSendEmailUseCase create(Ref ref) {
    return queueAndSendEmailUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QueueAndSendEmailUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QueueAndSendEmailUseCase>(value),
    );
  }
}

String _$queueAndSendEmailUseCaseHash() =>
    r'b960e7aa671d8c0643713f62d1c3b7c2d88e62f0';

@ProviderFor(retryOutboxMessageUseCase)
final retryOutboxMessageUseCaseProvider = RetryOutboxMessageUseCaseProvider._();

final class RetryOutboxMessageUseCaseProvider
    extends
        $FunctionalProvider<
          RetryOutboxMessageUseCase,
          RetryOutboxMessageUseCase,
          RetryOutboxMessageUseCase
        >
    with $Provider<RetryOutboxMessageUseCase> {
  RetryOutboxMessageUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'retryOutboxMessageUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$retryOutboxMessageUseCaseHash();

  @$internal
  @override
  $ProviderElement<RetryOutboxMessageUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RetryOutboxMessageUseCase create(Ref ref) {
    return retryOutboxMessageUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RetryOutboxMessageUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RetryOutboxMessageUseCase>(value),
    );
  }
}

String _$retryOutboxMessageUseCaseHash() =>
    r'66b3eb2579d1d391efc6a48090c30d3227ee0f5d';

@ProviderFor(markOutboxMessageSentUseCase)
final markOutboxMessageSentUseCaseProvider =
    MarkOutboxMessageSentUseCaseProvider._();

final class MarkOutboxMessageSentUseCaseProvider
    extends
        $FunctionalProvider<
          MarkOutboxMessageSentUseCase,
          MarkOutboxMessageSentUseCase,
          MarkOutboxMessageSentUseCase
        >
    with $Provider<MarkOutboxMessageSentUseCase> {
  MarkOutboxMessageSentUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'markOutboxMessageSentUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$markOutboxMessageSentUseCaseHash();

  @$internal
  @override
  $ProviderElement<MarkOutboxMessageSentUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MarkOutboxMessageSentUseCase create(Ref ref) {
    return markOutboxMessageSentUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MarkOutboxMessageSentUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MarkOutboxMessageSentUseCase>(value),
    );
  }
}

String _$markOutboxMessageSentUseCaseHash() =>
    r'd439a686d91279db985c5812b889b74d5589f284';

@ProviderFor(deleteOutboxMessageUseCase)
final deleteOutboxMessageUseCaseProvider =
    DeleteOutboxMessageUseCaseProvider._();

final class DeleteOutboxMessageUseCaseProvider
    extends
        $FunctionalProvider<
          DeleteOutboxMessageUseCase,
          DeleteOutboxMessageUseCase,
          DeleteOutboxMessageUseCase
        >
    with $Provider<DeleteOutboxMessageUseCase> {
  DeleteOutboxMessageUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deleteOutboxMessageUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deleteOutboxMessageUseCaseHash();

  @$internal
  @override
  $ProviderElement<DeleteOutboxMessageUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeleteOutboxMessageUseCase create(Ref ref) {
    return deleteOutboxMessageUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeleteOutboxMessageUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeleteOutboxMessageUseCase>(value),
    );
  }
}

String _$deleteOutboxMessageUseCaseHash() =>
    r'292aeb3b84352a09e9141870015456c24df53ede';

@ProviderFor(inboxSyncCoordinator)
final inboxSyncCoordinatorProvider = InboxSyncCoordinatorProvider._();

final class InboxSyncCoordinatorProvider
    extends
        $FunctionalProvider<
          InboxSyncCoordinator,
          InboxSyncCoordinator,
          InboxSyncCoordinator
        >
    with $Provider<InboxSyncCoordinator> {
  InboxSyncCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inboxSyncCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inboxSyncCoordinatorHash();

  @$internal
  @override
  $ProviderElement<InboxSyncCoordinator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InboxSyncCoordinator create(Ref ref) {
    return inboxSyncCoordinator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InboxSyncCoordinator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InboxSyncCoordinator>(value),
    );
  }
}

String _$inboxSyncCoordinatorHash() =>
    r'5ecf1df41774d0c7d86a5615571589f0693ebd11';

@ProviderFor(accountSyncBootstrap)
final accountSyncBootstrapProvider = AccountSyncBootstrapProvider._();

final class AccountSyncBootstrapProvider
    extends
        $FunctionalProvider<
          AccountSyncBootstrap,
          AccountSyncBootstrap,
          AccountSyncBootstrap
        >
    with $Provider<AccountSyncBootstrap> {
  AccountSyncBootstrapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountSyncBootstrapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountSyncBootstrapHash();

  @$internal
  @override
  $ProviderElement<AccountSyncBootstrap> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountSyncBootstrap create(Ref ref) {
    return accountSyncBootstrap(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountSyncBootstrap value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountSyncBootstrap>(value),
    );
  }
}

String _$accountSyncBootstrapHash() =>
    r'a4fe59882839d068c514d8b77845e8223d3a35c7';
