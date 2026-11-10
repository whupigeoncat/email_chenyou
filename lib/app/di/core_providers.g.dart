// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'core_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'8ce6f3b7d38a977108e673f58e109eeade470010';

@ProviderFor(secureStorageService)
final secureStorageServiceProvider = SecureStorageServiceProvider._();

final class SecureStorageServiceProvider
    extends
        $FunctionalProvider<
          SecureStorageService,
          SecureStorageService,
          SecureStorageService
        >
    with $Provider<SecureStorageService> {
  SecureStorageServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureStorageServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureStorageServiceHash();

  @$internal
  @override
  $ProviderElement<SecureStorageService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SecureStorageService create(Ref ref) {
    return secureStorageService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureStorageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureStorageService>(value),
    );
  }
}

String _$secureStorageServiceHash() =>
    r'e6a02a22edfe9ccff4d341f7d1d14daf7cade897';

@ProviderFor(oauthPkceService)
final oauthPkceServiceProvider = OauthPkceServiceProvider._();

final class OauthPkceServiceProvider
    extends
        $FunctionalProvider<
          OAuthPkceService,
          OAuthPkceService,
          OAuthPkceService
        >
    with $Provider<OAuthPkceService> {
  OauthPkceServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oauthPkceServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oauthPkceServiceHash();

  @$internal
  @override
  $ProviderElement<OAuthPkceService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OAuthPkceService create(Ref ref) {
    return oauthPkceService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OAuthPkceService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OAuthPkceService>(value),
    );
  }
}

String _$oauthPkceServiceHash() => r'44d7301c37699ee0f8ced7fc67c0dfed8a170750';

@ProviderFor(accountCredentialResolver)
final accountCredentialResolverProvider = AccountCredentialResolverProvider._();

final class AccountCredentialResolverProvider
    extends
        $FunctionalProvider<
          AccountCredentialResolver,
          AccountCredentialResolver,
          AccountCredentialResolver
        >
    with $Provider<AccountCredentialResolver> {
  AccountCredentialResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountCredentialResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountCredentialResolverHash();

  @$internal
  @override
  $ProviderElement<AccountCredentialResolver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountCredentialResolver create(Ref ref) {
    return accountCredentialResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountCredentialResolver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountCredentialResolver>(value),
    );
  }
}

String _$accountCredentialResolverHash() =>
    r'b657dfda9baec5aebc071e9323b2b36fa93e850d';

@ProviderFor(imapSessionFactory)
final imapSessionFactoryProvider = ImapSessionFactoryProvider._();

final class ImapSessionFactoryProvider
    extends
        $FunctionalProvider<
          ImapSessionFactory,
          ImapSessionFactory,
          ImapSessionFactory
        >
    with $Provider<ImapSessionFactory> {
  ImapSessionFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imapSessionFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imapSessionFactoryHash();

  @$internal
  @override
  $ProviderElement<ImapSessionFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ImapSessionFactory create(Ref ref) {
    return imapSessionFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImapSessionFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImapSessionFactory>(value),
    );
  }
}

String _$imapSessionFactoryHash() =>
    r'd149e60c6ef0f480b105a079d236d3b5e480acaf';

@ProviderFor(connectionPool)
final connectionPoolProvider = ConnectionPoolProvider._();

final class ConnectionPoolProvider
    extends $FunctionalProvider<ConnectionPool, ConnectionPool, ConnectionPool>
    with $Provider<ConnectionPool> {
  ConnectionPoolProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionPoolProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionPoolHash();

  @$internal
  @override
  $ProviderElement<ConnectionPool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ConnectionPool create(Ref ref) {
    return connectionPool(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectionPool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectionPool>(value),
    );
  }
}

String _$connectionPoolHash() => r'33500771203734b18e9f234b050bacc870d473a5';

@ProviderFor(imapConnectionTester)
final imapConnectionTesterProvider = ImapConnectionTesterProvider._();

final class ImapConnectionTesterProvider
    extends
        $FunctionalProvider<
          ImapConnectionTester,
          ImapConnectionTester,
          ImapConnectionTester
        >
    with $Provider<ImapConnectionTester> {
  ImapConnectionTesterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imapConnectionTesterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imapConnectionTesterHash();

  @$internal
  @override
  $ProviderElement<ImapConnectionTester> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ImapConnectionTester create(Ref ref) {
    return imapConnectionTester(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImapConnectionTester value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImapConnectionTester>(value),
    );
  }
}

String _$imapConnectionTesterHash() =>
    r'4bde749f69ea5becf90a81fe36f2eaeaf03cb3d8';

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'1f35de59c8ccde389cb8a5da029e16bf9791a0fc';

@ProviderFor(appLifecycleManager)
final appLifecycleManagerProvider = AppLifecycleManagerProvider._();

final class AppLifecycleManagerProvider
    extends
        $FunctionalProvider<
          AppLifecycleManager,
          AppLifecycleManager,
          AppLifecycleManager
        >
    with $Provider<AppLifecycleManager> {
  AppLifecycleManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLifecycleManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLifecycleManagerHash();

  @$internal
  @override
  $ProviderElement<AppLifecycleManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppLifecycleManager create(Ref ref) {
    return appLifecycleManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLifecycleManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLifecycleManager>(value),
    );
  }
}

String _$appLifecycleManagerHash() =>
    r'b3a852aad67828a5098f69cf87c4432d9673d9a3';

@ProviderFor(connectivityMonitor)
final connectivityMonitorProvider = ConnectivityMonitorProvider._();

final class ConnectivityMonitorProvider
    extends
        $FunctionalProvider<
          ConnectivityMonitor,
          ConnectivityMonitor,
          ConnectivityMonitor
        >
    with $Provider<ConnectivityMonitor> {
  ConnectivityMonitorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityMonitorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityMonitorHash();

  @$internal
  @override
  $ProviderElement<ConnectivityMonitor> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectivityMonitor create(Ref ref) {
    return connectivityMonitor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectivityMonitor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectivityMonitor>(value),
    );
  }
}

String _$connectivityMonitorHash() =>
    r'85cc53598f39425592e165d91dbdcffa57321506';

@ProviderFor(accounts)
final accountsProvider = AccountsProvider._();

final class AccountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MailAccount>>,
          List<MailAccount>,
          Stream<List<MailAccount>>
        >
    with
        $FutureModifier<List<MailAccount>>,
        $StreamProvider<List<MailAccount>> {
  AccountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountsHash();

  @$internal
  @override
  $StreamProviderElement<List<MailAccount>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MailAccount>> create(Ref ref) {
    return accounts(ref);
  }
}

String _$accountsHash() => r'b04084fd9b7feb12b2d4a820800791436db3f75c';

@ProviderFor(accountSlotStates)
final accountSlotStatesProvider = AccountSlotStatesProvider._();

final class AccountSlotStatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, ConnectionSlotState>>,
          Map<String, ConnectionSlotState>,
          Stream<Map<String, ConnectionSlotState>>
        >
    with
        $FutureModifier<Map<String, ConnectionSlotState>>,
        $StreamProvider<Map<String, ConnectionSlotState>> {
  AccountSlotStatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountSlotStatesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountSlotStatesHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, ConnectionSlotState>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, ConnectionSlotState>> create(Ref ref) {
    return accountSlotStates(ref);
  }
}

String _$accountSlotStatesHash() => r'6fe73ec2e4f32dcb26cc22d605d66358589eecb4';
