// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DbAccountsTable extends DbAccounts
    with TableInfo<$DbAccountsTable, DbAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerTypeMeta = const VerificationMeta(
    'providerType',
  );
  @override
  late final GeneratedColumn<String> providerType = GeneratedColumn<String>(
    'provider_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authTypeMeta = const VerificationMeta(
    'authType',
  );
  @override
  late final GeneratedColumn<String> authType = GeneratedColumn<String>(
    'auth_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imapHostMeta = const VerificationMeta(
    'imapHost',
  );
  @override
  late final GeneratedColumn<String> imapHost = GeneratedColumn<String>(
    'imap_host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imapPortMeta = const VerificationMeta(
    'imapPort',
  );
  @override
  late final GeneratedColumn<int> imapPort = GeneratedColumn<int>(
    'imap_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imapImplicitTlsMeta = const VerificationMeta(
    'imapImplicitTls',
  );
  @override
  late final GeneratedColumn<bool> imapImplicitTls = GeneratedColumn<bool>(
    'imap_implicit_tls',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("imap_implicit_tls" IN (0, 1))',
    ),
  );
  static const VerificationMeta _smtpHostMeta = const VerificationMeta(
    'smtpHost',
  );
  @override
  late final GeneratedColumn<String> smtpHost = GeneratedColumn<String>(
    'smtp_host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _smtpPortMeta = const VerificationMeta(
    'smtpPort',
  );
  @override
  late final GeneratedColumn<int> smtpPort = GeneratedColumn<int>(
    'smtp_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _smtpImplicitTlsMeta = const VerificationMeta(
    'smtpImplicitTls',
  );
  @override
  late final GeneratedColumn<bool> smtpImplicitTls = GeneratedColumn<bool>(
    'smtp_implicit_tls',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("smtp_implicit_tls" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    email,
    displayName,
    providerType,
    authType,
    colorValue,
    imapHost,
    imapPort,
    imapImplicitTls,
    smtpHost,
    smtpPort,
    smtpImplicitTls,
    isEnabled,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbAccount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('provider_type')) {
      context.handle(
        _providerTypeMeta,
        providerType.isAcceptableOrUnknown(
          data['provider_type']!,
          _providerTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerTypeMeta);
    }
    if (data.containsKey('auth_type')) {
      context.handle(
        _authTypeMeta,
        authType.isAcceptableOrUnknown(data['auth_type']!, _authTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_authTypeMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('imap_host')) {
      context.handle(
        _imapHostMeta,
        imapHost.isAcceptableOrUnknown(data['imap_host']!, _imapHostMeta),
      );
    } else if (isInserting) {
      context.missing(_imapHostMeta);
    }
    if (data.containsKey('imap_port')) {
      context.handle(
        _imapPortMeta,
        imapPort.isAcceptableOrUnknown(data['imap_port']!, _imapPortMeta),
      );
    } else if (isInserting) {
      context.missing(_imapPortMeta);
    }
    if (data.containsKey('imap_implicit_tls')) {
      context.handle(
        _imapImplicitTlsMeta,
        imapImplicitTls.isAcceptableOrUnknown(
          data['imap_implicit_tls']!,
          _imapImplicitTlsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_imapImplicitTlsMeta);
    }
    if (data.containsKey('smtp_host')) {
      context.handle(
        _smtpHostMeta,
        smtpHost.isAcceptableOrUnknown(data['smtp_host']!, _smtpHostMeta),
      );
    } else if (isInserting) {
      context.missing(_smtpHostMeta);
    }
    if (data.containsKey('smtp_port')) {
      context.handle(
        _smtpPortMeta,
        smtpPort.isAcceptableOrUnknown(data['smtp_port']!, _smtpPortMeta),
      );
    } else if (isInserting) {
      context.missing(_smtpPortMeta);
    }
    if (data.containsKey('smtp_implicit_tls')) {
      context.handle(
        _smtpImplicitTlsMeta,
        smtpImplicitTls.isAcceptableOrUnknown(
          data['smtp_implicit_tls']!,
          _smtpImplicitTlsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_smtpImplicitTlsMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbAccount(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      providerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_type'],
      )!,
      authType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_type'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      imapHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imap_host'],
      )!,
      imapPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imap_port'],
      )!,
      imapImplicitTls: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}imap_implicit_tls'],
      )!,
      smtpHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_host'],
      )!,
      smtpPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}smtp_port'],
      )!,
      smtpImplicitTls: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}smtp_implicit_tls'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DbAccountsTable createAlias(String alias) {
    return $DbAccountsTable(attachedDatabase, alias);
  }
}

class DbAccount extends DataClass implements Insertable<DbAccount> {
  final String id;
  final String email;
  final String displayName;
  final String providerType;
  final String authType;
  final int colorValue;
  final String imapHost;
  final int imapPort;
  final bool imapImplicitTls;
  final String smtpHost;
  final int smtpPort;
  final bool smtpImplicitTls;
  final bool isEnabled;
  final int createdAt;
  const DbAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.providerType,
    required this.authType,
    required this.colorValue,
    required this.imapHost,
    required this.imapPort,
    required this.imapImplicitTls,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpImplicitTls,
    required this.isEnabled,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['email'] = Variable<String>(email);
    map['display_name'] = Variable<String>(displayName);
    map['provider_type'] = Variable<String>(providerType);
    map['auth_type'] = Variable<String>(authType);
    map['color_value'] = Variable<int>(colorValue);
    map['imap_host'] = Variable<String>(imapHost);
    map['imap_port'] = Variable<int>(imapPort);
    map['imap_implicit_tls'] = Variable<bool>(imapImplicitTls);
    map['smtp_host'] = Variable<String>(smtpHost);
    map['smtp_port'] = Variable<int>(smtpPort);
    map['smtp_implicit_tls'] = Variable<bool>(smtpImplicitTls);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  DbAccountsCompanion toCompanion(bool nullToAbsent) {
    return DbAccountsCompanion(
      id: Value(id),
      email: Value(email),
      displayName: Value(displayName),
      providerType: Value(providerType),
      authType: Value(authType),
      colorValue: Value(colorValue),
      imapHost: Value(imapHost),
      imapPort: Value(imapPort),
      imapImplicitTls: Value(imapImplicitTls),
      smtpHost: Value(smtpHost),
      smtpPort: Value(smtpPort),
      smtpImplicitTls: Value(smtpImplicitTls),
      isEnabled: Value(isEnabled),
      createdAt: Value(createdAt),
    );
  }

  factory DbAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbAccount(
      id: serializer.fromJson<String>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      displayName: serializer.fromJson<String>(json['displayName']),
      providerType: serializer.fromJson<String>(json['providerType']),
      authType: serializer.fromJson<String>(json['authType']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      imapHost: serializer.fromJson<String>(json['imapHost']),
      imapPort: serializer.fromJson<int>(json['imapPort']),
      imapImplicitTls: serializer.fromJson<bool>(json['imapImplicitTls']),
      smtpHost: serializer.fromJson<String>(json['smtpHost']),
      smtpPort: serializer.fromJson<int>(json['smtpPort']),
      smtpImplicitTls: serializer.fromJson<bool>(json['smtpImplicitTls']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String>(email),
      'displayName': serializer.toJson<String>(displayName),
      'providerType': serializer.toJson<String>(providerType),
      'authType': serializer.toJson<String>(authType),
      'colorValue': serializer.toJson<int>(colorValue),
      'imapHost': serializer.toJson<String>(imapHost),
      'imapPort': serializer.toJson<int>(imapPort),
      'imapImplicitTls': serializer.toJson<bool>(imapImplicitTls),
      'smtpHost': serializer.toJson<String>(smtpHost),
      'smtpPort': serializer.toJson<int>(smtpPort),
      'smtpImplicitTls': serializer.toJson<bool>(smtpImplicitTls),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  DbAccount copyWith({
    String? id,
    String? email,
    String? displayName,
    String? providerType,
    String? authType,
    int? colorValue,
    String? imapHost,
    int? imapPort,
    bool? imapImplicitTls,
    String? smtpHost,
    int? smtpPort,
    bool? smtpImplicitTls,
    bool? isEnabled,
    int? createdAt,
  }) => DbAccount(
    id: id ?? this.id,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    providerType: providerType ?? this.providerType,
    authType: authType ?? this.authType,
    colorValue: colorValue ?? this.colorValue,
    imapHost: imapHost ?? this.imapHost,
    imapPort: imapPort ?? this.imapPort,
    imapImplicitTls: imapImplicitTls ?? this.imapImplicitTls,
    smtpHost: smtpHost ?? this.smtpHost,
    smtpPort: smtpPort ?? this.smtpPort,
    smtpImplicitTls: smtpImplicitTls ?? this.smtpImplicitTls,
    isEnabled: isEnabled ?? this.isEnabled,
    createdAt: createdAt ?? this.createdAt,
  );
  DbAccount copyWithCompanion(DbAccountsCompanion data) {
    return DbAccount(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      providerType: data.providerType.present
          ? data.providerType.value
          : this.providerType,
      authType: data.authType.present ? data.authType.value : this.authType,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      imapHost: data.imapHost.present ? data.imapHost.value : this.imapHost,
      imapPort: data.imapPort.present ? data.imapPort.value : this.imapPort,
      imapImplicitTls: data.imapImplicitTls.present
          ? data.imapImplicitTls.value
          : this.imapImplicitTls,
      smtpHost: data.smtpHost.present ? data.smtpHost.value : this.smtpHost,
      smtpPort: data.smtpPort.present ? data.smtpPort.value : this.smtpPort,
      smtpImplicitTls: data.smtpImplicitTls.present
          ? data.smtpImplicitTls.value
          : this.smtpImplicitTls,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbAccount(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('providerType: $providerType, ')
          ..write('authType: $authType, ')
          ..write('colorValue: $colorValue, ')
          ..write('imapHost: $imapHost, ')
          ..write('imapPort: $imapPort, ')
          ..write('imapImplicitTls: $imapImplicitTls, ')
          ..write('smtpHost: $smtpHost, ')
          ..write('smtpPort: $smtpPort, ')
          ..write('smtpImplicitTls: $smtpImplicitTls, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    email,
    displayName,
    providerType,
    authType,
    colorValue,
    imapHost,
    imapPort,
    imapImplicitTls,
    smtpHost,
    smtpPort,
    smtpImplicitTls,
    isEnabled,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbAccount &&
          other.id == this.id &&
          other.email == this.email &&
          other.displayName == this.displayName &&
          other.providerType == this.providerType &&
          other.authType == this.authType &&
          other.colorValue == this.colorValue &&
          other.imapHost == this.imapHost &&
          other.imapPort == this.imapPort &&
          other.imapImplicitTls == this.imapImplicitTls &&
          other.smtpHost == this.smtpHost &&
          other.smtpPort == this.smtpPort &&
          other.smtpImplicitTls == this.smtpImplicitTls &&
          other.isEnabled == this.isEnabled &&
          other.createdAt == this.createdAt);
}

class DbAccountsCompanion extends UpdateCompanion<DbAccount> {
  final Value<String> id;
  final Value<String> email;
  final Value<String> displayName;
  final Value<String> providerType;
  final Value<String> authType;
  final Value<int> colorValue;
  final Value<String> imapHost;
  final Value<int> imapPort;
  final Value<bool> imapImplicitTls;
  final Value<String> smtpHost;
  final Value<int> smtpPort;
  final Value<bool> smtpImplicitTls;
  final Value<bool> isEnabled;
  final Value<int> createdAt;
  final Value<int> rowid;
  const DbAccountsCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.providerType = const Value.absent(),
    this.authType = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.imapHost = const Value.absent(),
    this.imapPort = const Value.absent(),
    this.imapImplicitTls = const Value.absent(),
    this.smtpHost = const Value.absent(),
    this.smtpPort = const Value.absent(),
    this.smtpImplicitTls = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DbAccountsCompanion.insert({
    required String id,
    required String email,
    required String displayName,
    required String providerType,
    required String authType,
    required int colorValue,
    required String imapHost,
    required int imapPort,
    required bool imapImplicitTls,
    required String smtpHost,
    required int smtpPort,
    required bool smtpImplicitTls,
    this.isEnabled = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       email = Value(email),
       displayName = Value(displayName),
       providerType = Value(providerType),
       authType = Value(authType),
       colorValue = Value(colorValue),
       imapHost = Value(imapHost),
       imapPort = Value(imapPort),
       imapImplicitTls = Value(imapImplicitTls),
       smtpHost = Value(smtpHost),
       smtpPort = Value(smtpPort),
       smtpImplicitTls = Value(smtpImplicitTls),
       createdAt = Value(createdAt);
  static Insertable<DbAccount> custom({
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? displayName,
    Expression<String>? providerType,
    Expression<String>? authType,
    Expression<int>? colorValue,
    Expression<String>? imapHost,
    Expression<int>? imapPort,
    Expression<bool>? imapImplicitTls,
    Expression<String>? smtpHost,
    Expression<int>? smtpPort,
    Expression<bool>? smtpImplicitTls,
    Expression<bool>? isEnabled,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (displayName != null) 'display_name': displayName,
      if (providerType != null) 'provider_type': providerType,
      if (authType != null) 'auth_type': authType,
      if (colorValue != null) 'color_value': colorValue,
      if (imapHost != null) 'imap_host': imapHost,
      if (imapPort != null) 'imap_port': imapPort,
      if (imapImplicitTls != null) 'imap_implicit_tls': imapImplicitTls,
      if (smtpHost != null) 'smtp_host': smtpHost,
      if (smtpPort != null) 'smtp_port': smtpPort,
      if (smtpImplicitTls != null) 'smtp_implicit_tls': smtpImplicitTls,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DbAccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? email,
    Value<String>? displayName,
    Value<String>? providerType,
    Value<String>? authType,
    Value<int>? colorValue,
    Value<String>? imapHost,
    Value<int>? imapPort,
    Value<bool>? imapImplicitTls,
    Value<String>? smtpHost,
    Value<int>? smtpPort,
    Value<bool>? smtpImplicitTls,
    Value<bool>? isEnabled,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return DbAccountsCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      providerType: providerType ?? this.providerType,
      authType: authType ?? this.authType,
      colorValue: colorValue ?? this.colorValue,
      imapHost: imapHost ?? this.imapHost,
      imapPort: imapPort ?? this.imapPort,
      imapImplicitTls: imapImplicitTls ?? this.imapImplicitTls,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      smtpImplicitTls: smtpImplicitTls ?? this.smtpImplicitTls,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (providerType.present) {
      map['provider_type'] = Variable<String>(providerType.value);
    }
    if (authType.present) {
      map['auth_type'] = Variable<String>(authType.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (imapHost.present) {
      map['imap_host'] = Variable<String>(imapHost.value);
    }
    if (imapPort.present) {
      map['imap_port'] = Variable<int>(imapPort.value);
    }
    if (imapImplicitTls.present) {
      map['imap_implicit_tls'] = Variable<bool>(imapImplicitTls.value);
    }
    if (smtpHost.present) {
      map['smtp_host'] = Variable<String>(smtpHost.value);
    }
    if (smtpPort.present) {
      map['smtp_port'] = Variable<int>(smtpPort.value);
    }
    if (smtpImplicitTls.present) {
      map['smtp_implicit_tls'] = Variable<bool>(smtpImplicitTls.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbAccountsCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('providerType: $providerType, ')
          ..write('authType: $authType, ')
          ..write('colorValue: $colorValue, ')
          ..write('imapHost: $imapHost, ')
          ..write('imapPort: $imapPort, ')
          ..write('imapImplicitTls: $imapImplicitTls, ')
          ..write('smtpHost: $smtpHost, ')
          ..write('smtpPort: $smtpPort, ')
          ..write('smtpImplicitTls: $smtpImplicitTls, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DbFoldersTable extends DbFolders
    with TableInfo<$DbFoldersTable, DbFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES db_accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _remoteNameMeta = const VerificationMeta(
    'remoteName',
  );
  @override
  late final GeneratedColumn<String> remoteName = GeneratedColumn<String>(
    'remote_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uidValidityMeta = const VerificationMeta(
    'uidValidity',
  );
  @override
  late final GeneratedColumn<int> uidValidity = GeneratedColumn<int>(
    'uid_validity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _highestModSeqMeta = const VerificationMeta(
    'highestModSeq',
  );
  @override
  late final GeneratedColumn<int> highestModSeq = GeneratedColumn<int>(
    'highest_mod_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncAt = GeneratedColumn<int>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    remoteName,
    displayName,
    role,
    uidValidity,
    highestModSeq,
    unreadCount,
    lastSyncAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('remote_name')) {
      context.handle(
        _remoteNameMeta,
        remoteName.isAcceptableOrUnknown(data['remote_name']!, _remoteNameMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteNameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('uid_validity')) {
      context.handle(
        _uidValidityMeta,
        uidValidity.isAcceptableOrUnknown(
          data['uid_validity']!,
          _uidValidityMeta,
        ),
      );
    }
    if (data.containsKey('highest_mod_seq')) {
      context.handle(
        _highestModSeqMeta,
        highestModSeq.isAcceptableOrUnknown(
          data['highest_mod_seq']!,
          _highestModSeqMeta,
        ),
      );
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      remoteName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      uidValidity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uid_validity'],
      ),
      highestModSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}highest_mod_seq'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_sync_at'],
      ),
    );
  }

  @override
  $DbFoldersTable createAlias(String alias) {
    return $DbFoldersTable(attachedDatabase, alias);
  }
}

class DbFolder extends DataClass implements Insertable<DbFolder> {
  final String id;
  final String accountId;
  final String remoteName;
  final String displayName;
  final String role;
  final int? uidValidity;
  final int? highestModSeq;
  final int unreadCount;
  final int? lastSyncAt;
  const DbFolder({
    required this.id,
    required this.accountId,
    required this.remoteName,
    required this.displayName,
    required this.role,
    this.uidValidity,
    this.highestModSeq,
    required this.unreadCount,
    this.lastSyncAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['remote_name'] = Variable<String>(remoteName);
    map['display_name'] = Variable<String>(displayName);
    map['role'] = Variable<String>(role);
    if (!nullToAbsent || uidValidity != null) {
      map['uid_validity'] = Variable<int>(uidValidity);
    }
    if (!nullToAbsent || highestModSeq != null) {
      map['highest_mod_seq'] = Variable<int>(highestModSeq);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<int>(lastSyncAt);
    }
    return map;
  }

  DbFoldersCompanion toCompanion(bool nullToAbsent) {
    return DbFoldersCompanion(
      id: Value(id),
      accountId: Value(accountId),
      remoteName: Value(remoteName),
      displayName: Value(displayName),
      role: Value(role),
      uidValidity: uidValidity == null && nullToAbsent
          ? const Value.absent()
          : Value(uidValidity),
      highestModSeq: highestModSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(highestModSeq),
      unreadCount: Value(unreadCount),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
    );
  }

  factory DbFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbFolder(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      remoteName: serializer.fromJson<String>(json['remoteName']),
      displayName: serializer.fromJson<String>(json['displayName']),
      role: serializer.fromJson<String>(json['role']),
      uidValidity: serializer.fromJson<int?>(json['uidValidity']),
      highestModSeq: serializer.fromJson<int?>(json['highestModSeq']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      lastSyncAt: serializer.fromJson<int?>(json['lastSyncAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'remoteName': serializer.toJson<String>(remoteName),
      'displayName': serializer.toJson<String>(displayName),
      'role': serializer.toJson<String>(role),
      'uidValidity': serializer.toJson<int?>(uidValidity),
      'highestModSeq': serializer.toJson<int?>(highestModSeq),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'lastSyncAt': serializer.toJson<int?>(lastSyncAt),
    };
  }

  DbFolder copyWith({
    String? id,
    String? accountId,
    String? remoteName,
    String? displayName,
    String? role,
    Value<int?> uidValidity = const Value.absent(),
    Value<int?> highestModSeq = const Value.absent(),
    int? unreadCount,
    Value<int?> lastSyncAt = const Value.absent(),
  }) => DbFolder(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    remoteName: remoteName ?? this.remoteName,
    displayName: displayName ?? this.displayName,
    role: role ?? this.role,
    uidValidity: uidValidity.present ? uidValidity.value : this.uidValidity,
    highestModSeq: highestModSeq.present
        ? highestModSeq.value
        : this.highestModSeq,
    unreadCount: unreadCount ?? this.unreadCount,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
  );
  DbFolder copyWithCompanion(DbFoldersCompanion data) {
    return DbFolder(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      remoteName: data.remoteName.present
          ? data.remoteName.value
          : this.remoteName,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      role: data.role.present ? data.role.value : this.role,
      uidValidity: data.uidValidity.present
          ? data.uidValidity.value
          : this.uidValidity,
      highestModSeq: data.highestModSeq.present
          ? data.highestModSeq.value
          : this.highestModSeq,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbFolder(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('remoteName: $remoteName, ')
          ..write('displayName: $displayName, ')
          ..write('role: $role, ')
          ..write('uidValidity: $uidValidity, ')
          ..write('highestModSeq: $highestModSeq, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    remoteName,
    displayName,
    role,
    uidValidity,
    highestModSeq,
    unreadCount,
    lastSyncAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbFolder &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.remoteName == this.remoteName &&
          other.displayName == this.displayName &&
          other.role == this.role &&
          other.uidValidity == this.uidValidity &&
          other.highestModSeq == this.highestModSeq &&
          other.unreadCount == this.unreadCount &&
          other.lastSyncAt == this.lastSyncAt);
}

class DbFoldersCompanion extends UpdateCompanion<DbFolder> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> remoteName;
  final Value<String> displayName;
  final Value<String> role;
  final Value<int?> uidValidity;
  final Value<int?> highestModSeq;
  final Value<int> unreadCount;
  final Value<int?> lastSyncAt;
  final Value<int> rowid;
  const DbFoldersCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.remoteName = const Value.absent(),
    this.displayName = const Value.absent(),
    this.role = const Value.absent(),
    this.uidValidity = const Value.absent(),
    this.highestModSeq = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DbFoldersCompanion.insert({
    required String id,
    required String accountId,
    required String remoteName,
    required String displayName,
    required String role,
    this.uidValidity = const Value.absent(),
    this.highestModSeq = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       remoteName = Value(remoteName),
       displayName = Value(displayName),
       role = Value(role);
  static Insertable<DbFolder> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? remoteName,
    Expression<String>? displayName,
    Expression<String>? role,
    Expression<int>? uidValidity,
    Expression<int>? highestModSeq,
    Expression<int>? unreadCount,
    Expression<int>? lastSyncAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (remoteName != null) 'remote_name': remoteName,
      if (displayName != null) 'display_name': displayName,
      if (role != null) 'role': role,
      if (uidValidity != null) 'uid_validity': uidValidity,
      if (highestModSeq != null) 'highest_mod_seq': highestModSeq,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DbFoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? remoteName,
    Value<String>? displayName,
    Value<String>? role,
    Value<int?>? uidValidity,
    Value<int?>? highestModSeq,
    Value<int>? unreadCount,
    Value<int?>? lastSyncAt,
    Value<int>? rowid,
  }) {
    return DbFoldersCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      remoteName: remoteName ?? this.remoteName,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      uidValidity: uidValidity ?? this.uidValidity,
      highestModSeq: highestModSeq ?? this.highestModSeq,
      unreadCount: unreadCount ?? this.unreadCount,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (remoteName.present) {
      map['remote_name'] = Variable<String>(remoteName.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (uidValidity.present) {
      map['uid_validity'] = Variable<int>(uidValidity.value);
    }
    if (highestModSeq.present) {
      map['highest_mod_seq'] = Variable<int>(highestModSeq.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<int>(lastSyncAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbFoldersCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('remoteName: $remoteName, ')
          ..write('displayName: $displayName, ')
          ..write('role: $role, ')
          ..write('uidValidity: $uidValidity, ')
          ..write('highestModSeq: $highestModSeq, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DbEmailsTable extends DbEmails with TableInfo<$DbEmailsTable, DbEmail> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbEmailsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<int> localId = GeneratedColumn<int>(
    'local_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES db_accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES db_folders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<int> uid = GeneratedColumn<int>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromNameMeta = const VerificationMeta(
    'fromName',
  );
  @override
  late final GeneratedColumn<String> fromName = GeneratedColumn<String>(
    'from_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromAddressMeta = const VerificationMeta(
    'fromAddress',
  );
  @override
  late final GeneratedColumn<String> fromAddress = GeneratedColumn<String>(
    'from_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toRecipientsJsonMeta = const VerificationMeta(
    'toRecipientsJson',
  );
  @override
  late final GeneratedColumn<String> toRecipientsJson = GeneratedColumn<String>(
    'to_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ccJsonMeta = const VerificationMeta('ccJson');
  @override
  late final GeneratedColumn<String> ccJson = GeneratedColumn<String>(
    'cc_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snippetMeta = const VerificationMeta(
    'snippet',
  );
  @override
  late final GeneratedColumn<String> snippet = GeneratedColumn<String>(
    'snippet',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plainBodyMeta = const VerificationMeta(
    'plainBody',
  );
  @override
  late final GeneratedColumn<String> plainBody = GeneratedColumn<String>(
    'plain_body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _htmlBodyMeta = const VerificationMeta(
    'htmlBody',
  );
  @override
  late final GeneratedColumn<String> htmlBody = GeneratedColumn<String>(
    'html_body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<int> sentAt = GeneratedColumn<int>(
    'sent_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _flagsBitmaskMeta = const VerificationMeta(
    'flagsBitmask',
  );
  @override
  late final GeneratedColumn<int> flagsBitmask = GeneratedColumn<int>(
    'flags_bitmask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hasAttachmentsMeta = const VerificationMeta(
    'hasAttachments',
  );
  @override
  late final GeneratedColumn<bool> hasAttachments = GeneratedColumn<bool>(
    'has_attachments',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_attachments" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _bodyDownloadedMeta = const VerificationMeta(
    'bodyDownloaded',
  );
  @override
  late final GeneratedColumn<bool> bodyDownloaded = GeneratedColumn<bool>(
    'body_downloaded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("body_downloaded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    accountId,
    folderId,
    uid,
    messageId,
    subject,
    fromName,
    fromAddress,
    toRecipientsJson,
    ccJson,
    snippet,
    plainBody,
    htmlBody,
    sentAt,
    flagsBitmask,
    hasAttachments,
    bodyDownloaded,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_emails';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbEmail> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('from_name')) {
      context.handle(
        _fromNameMeta,
        fromName.isAcceptableOrUnknown(data['from_name']!, _fromNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fromNameMeta);
    }
    if (data.containsKey('from_address')) {
      context.handle(
        _fromAddressMeta,
        fromAddress.isAcceptableOrUnknown(
          data['from_address']!,
          _fromAddressMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromAddressMeta);
    }
    if (data.containsKey('to_json')) {
      context.handle(
        _toRecipientsJsonMeta,
        toRecipientsJson.isAcceptableOrUnknown(
          data['to_json']!,
          _toRecipientsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_toRecipientsJsonMeta);
    }
    if (data.containsKey('cc_json')) {
      context.handle(
        _ccJsonMeta,
        ccJson.isAcceptableOrUnknown(data['cc_json']!, _ccJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_ccJsonMeta);
    }
    if (data.containsKey('snippet')) {
      context.handle(
        _snippetMeta,
        snippet.isAcceptableOrUnknown(data['snippet']!, _snippetMeta),
      );
    } else if (isInserting) {
      context.missing(_snippetMeta);
    }
    if (data.containsKey('plain_body')) {
      context.handle(
        _plainBodyMeta,
        plainBody.isAcceptableOrUnknown(data['plain_body']!, _plainBodyMeta),
      );
    }
    if (data.containsKey('html_body')) {
      context.handle(
        _htmlBodyMeta,
        htmlBody.isAcceptableOrUnknown(data['html_body']!, _htmlBodyMeta),
      );
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    } else if (isInserting) {
      context.missing(_sentAtMeta);
    }
    if (data.containsKey('flags_bitmask')) {
      context.handle(
        _flagsBitmaskMeta,
        flagsBitmask.isAcceptableOrUnknown(
          data['flags_bitmask']!,
          _flagsBitmaskMeta,
        ),
      );
    }
    if (data.containsKey('has_attachments')) {
      context.handle(
        _hasAttachmentsMeta,
        hasAttachments.isAcceptableOrUnknown(
          data['has_attachments']!,
          _hasAttachmentsMeta,
        ),
      );
    }
    if (data.containsKey('body_downloaded')) {
      context.handle(
        _bodyDownloadedMeta,
        bodyDownloaded.isAcceptableOrUnknown(
          data['body_downloaded']!,
          _bodyDownloadedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {folderId, uid},
  ];
  @override
  DbEmail map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbEmail(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uid'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      ),
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      fromName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_name'],
      )!,
      fromAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_address'],
      )!,
      toRecipientsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_json'],
      )!,
      ccJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cc_json'],
      )!,
      snippet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snippet'],
      )!,
      plainBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plain_body'],
      ),
      htmlBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}html_body'],
      ),
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sent_at'],
      )!,
      flagsBitmask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}flags_bitmask'],
      )!,
      hasAttachments: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_attachments'],
      )!,
      bodyDownloaded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}body_downloaded'],
      )!,
    );
  }

  @override
  $DbEmailsTable createAlias(String alias) {
    return $DbEmailsTable(attachedDatabase, alias);
  }
}

class DbEmail extends DataClass implements Insertable<DbEmail> {
  final int localId;
  final String accountId;
  final String folderId;
  final int uid;
  final String? messageId;
  final String subject;
  final String fromName;
  final String fromAddress;
  final String toRecipientsJson;
  final String ccJson;
  final String snippet;
  final String? plainBody;
  final String? htmlBody;
  final int sentAt;
  final int flagsBitmask;
  final bool hasAttachments;
  final bool bodyDownloaded;
  const DbEmail({
    required this.localId,
    required this.accountId,
    required this.folderId,
    required this.uid,
    this.messageId,
    required this.subject,
    required this.fromName,
    required this.fromAddress,
    required this.toRecipientsJson,
    required this.ccJson,
    required this.snippet,
    this.plainBody,
    this.htmlBody,
    required this.sentAt,
    required this.flagsBitmask,
    required this.hasAttachments,
    required this.bodyDownloaded,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<int>(localId);
    map['account_id'] = Variable<String>(accountId);
    map['folder_id'] = Variable<String>(folderId);
    map['uid'] = Variable<int>(uid);
    if (!nullToAbsent || messageId != null) {
      map['message_id'] = Variable<String>(messageId);
    }
    map['subject'] = Variable<String>(subject);
    map['from_name'] = Variable<String>(fromName);
    map['from_address'] = Variable<String>(fromAddress);
    map['to_json'] = Variable<String>(toRecipientsJson);
    map['cc_json'] = Variable<String>(ccJson);
    map['snippet'] = Variable<String>(snippet);
    if (!nullToAbsent || plainBody != null) {
      map['plain_body'] = Variable<String>(plainBody);
    }
    if (!nullToAbsent || htmlBody != null) {
      map['html_body'] = Variable<String>(htmlBody);
    }
    map['sent_at'] = Variable<int>(sentAt);
    map['flags_bitmask'] = Variable<int>(flagsBitmask);
    map['has_attachments'] = Variable<bool>(hasAttachments);
    map['body_downloaded'] = Variable<bool>(bodyDownloaded);
    return map;
  }

  DbEmailsCompanion toCompanion(bool nullToAbsent) {
    return DbEmailsCompanion(
      localId: Value(localId),
      accountId: Value(accountId),
      folderId: Value(folderId),
      uid: Value(uid),
      messageId: messageId == null && nullToAbsent
          ? const Value.absent()
          : Value(messageId),
      subject: Value(subject),
      fromName: Value(fromName),
      fromAddress: Value(fromAddress),
      toRecipientsJson: Value(toRecipientsJson),
      ccJson: Value(ccJson),
      snippet: Value(snippet),
      plainBody: plainBody == null && nullToAbsent
          ? const Value.absent()
          : Value(plainBody),
      htmlBody: htmlBody == null && nullToAbsent
          ? const Value.absent()
          : Value(htmlBody),
      sentAt: Value(sentAt),
      flagsBitmask: Value(flagsBitmask),
      hasAttachments: Value(hasAttachments),
      bodyDownloaded: Value(bodyDownloaded),
    );
  }

  factory DbEmail.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbEmail(
      localId: serializer.fromJson<int>(json['localId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      folderId: serializer.fromJson<String>(json['folderId']),
      uid: serializer.fromJson<int>(json['uid']),
      messageId: serializer.fromJson<String?>(json['messageId']),
      subject: serializer.fromJson<String>(json['subject']),
      fromName: serializer.fromJson<String>(json['fromName']),
      fromAddress: serializer.fromJson<String>(json['fromAddress']),
      toRecipientsJson: serializer.fromJson<String>(json['toRecipientsJson']),
      ccJson: serializer.fromJson<String>(json['ccJson']),
      snippet: serializer.fromJson<String>(json['snippet']),
      plainBody: serializer.fromJson<String?>(json['plainBody']),
      htmlBody: serializer.fromJson<String?>(json['htmlBody']),
      sentAt: serializer.fromJson<int>(json['sentAt']),
      flagsBitmask: serializer.fromJson<int>(json['flagsBitmask']),
      hasAttachments: serializer.fromJson<bool>(json['hasAttachments']),
      bodyDownloaded: serializer.fromJson<bool>(json['bodyDownloaded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<int>(localId),
      'accountId': serializer.toJson<String>(accountId),
      'folderId': serializer.toJson<String>(folderId),
      'uid': serializer.toJson<int>(uid),
      'messageId': serializer.toJson<String?>(messageId),
      'subject': serializer.toJson<String>(subject),
      'fromName': serializer.toJson<String>(fromName),
      'fromAddress': serializer.toJson<String>(fromAddress),
      'toRecipientsJson': serializer.toJson<String>(toRecipientsJson),
      'ccJson': serializer.toJson<String>(ccJson),
      'snippet': serializer.toJson<String>(snippet),
      'plainBody': serializer.toJson<String?>(plainBody),
      'htmlBody': serializer.toJson<String?>(htmlBody),
      'sentAt': serializer.toJson<int>(sentAt),
      'flagsBitmask': serializer.toJson<int>(flagsBitmask),
      'hasAttachments': serializer.toJson<bool>(hasAttachments),
      'bodyDownloaded': serializer.toJson<bool>(bodyDownloaded),
    };
  }

  DbEmail copyWith({
    int? localId,
    String? accountId,
    String? folderId,
    int? uid,
    Value<String?> messageId = const Value.absent(),
    String? subject,
    String? fromName,
    String? fromAddress,
    String? toRecipientsJson,
    String? ccJson,
    String? snippet,
    Value<String?> plainBody = const Value.absent(),
    Value<String?> htmlBody = const Value.absent(),
    int? sentAt,
    int? flagsBitmask,
    bool? hasAttachments,
    bool? bodyDownloaded,
  }) => DbEmail(
    localId: localId ?? this.localId,
    accountId: accountId ?? this.accountId,
    folderId: folderId ?? this.folderId,
    uid: uid ?? this.uid,
    messageId: messageId.present ? messageId.value : this.messageId,
    subject: subject ?? this.subject,
    fromName: fromName ?? this.fromName,
    fromAddress: fromAddress ?? this.fromAddress,
    toRecipientsJson: toRecipientsJson ?? this.toRecipientsJson,
    ccJson: ccJson ?? this.ccJson,
    snippet: snippet ?? this.snippet,
    plainBody: plainBody.present ? plainBody.value : this.plainBody,
    htmlBody: htmlBody.present ? htmlBody.value : this.htmlBody,
    sentAt: sentAt ?? this.sentAt,
    flagsBitmask: flagsBitmask ?? this.flagsBitmask,
    hasAttachments: hasAttachments ?? this.hasAttachments,
    bodyDownloaded: bodyDownloaded ?? this.bodyDownloaded,
  );
  DbEmail copyWithCompanion(DbEmailsCompanion data) {
    return DbEmail(
      localId: data.localId.present ? data.localId.value : this.localId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      uid: data.uid.present ? data.uid.value : this.uid,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      subject: data.subject.present ? data.subject.value : this.subject,
      fromName: data.fromName.present ? data.fromName.value : this.fromName,
      fromAddress: data.fromAddress.present
          ? data.fromAddress.value
          : this.fromAddress,
      toRecipientsJson: data.toRecipientsJson.present
          ? data.toRecipientsJson.value
          : this.toRecipientsJson,
      ccJson: data.ccJson.present ? data.ccJson.value : this.ccJson,
      snippet: data.snippet.present ? data.snippet.value : this.snippet,
      plainBody: data.plainBody.present ? data.plainBody.value : this.plainBody,
      htmlBody: data.htmlBody.present ? data.htmlBody.value : this.htmlBody,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      flagsBitmask: data.flagsBitmask.present
          ? data.flagsBitmask.value
          : this.flagsBitmask,
      hasAttachments: data.hasAttachments.present
          ? data.hasAttachments.value
          : this.hasAttachments,
      bodyDownloaded: data.bodyDownloaded.present
          ? data.bodyDownloaded.value
          : this.bodyDownloaded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbEmail(')
          ..write('localId: $localId, ')
          ..write('accountId: $accountId, ')
          ..write('folderId: $folderId, ')
          ..write('uid: $uid, ')
          ..write('messageId: $messageId, ')
          ..write('subject: $subject, ')
          ..write('fromName: $fromName, ')
          ..write('fromAddress: $fromAddress, ')
          ..write('toRecipientsJson: $toRecipientsJson, ')
          ..write('ccJson: $ccJson, ')
          ..write('snippet: $snippet, ')
          ..write('plainBody: $plainBody, ')
          ..write('htmlBody: $htmlBody, ')
          ..write('sentAt: $sentAt, ')
          ..write('flagsBitmask: $flagsBitmask, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('bodyDownloaded: $bodyDownloaded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    accountId,
    folderId,
    uid,
    messageId,
    subject,
    fromName,
    fromAddress,
    toRecipientsJson,
    ccJson,
    snippet,
    plainBody,
    htmlBody,
    sentAt,
    flagsBitmask,
    hasAttachments,
    bodyDownloaded,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbEmail &&
          other.localId == this.localId &&
          other.accountId == this.accountId &&
          other.folderId == this.folderId &&
          other.uid == this.uid &&
          other.messageId == this.messageId &&
          other.subject == this.subject &&
          other.fromName == this.fromName &&
          other.fromAddress == this.fromAddress &&
          other.toRecipientsJson == this.toRecipientsJson &&
          other.ccJson == this.ccJson &&
          other.snippet == this.snippet &&
          other.plainBody == this.plainBody &&
          other.htmlBody == this.htmlBody &&
          other.sentAt == this.sentAt &&
          other.flagsBitmask == this.flagsBitmask &&
          other.hasAttachments == this.hasAttachments &&
          other.bodyDownloaded == this.bodyDownloaded);
}

class DbEmailsCompanion extends UpdateCompanion<DbEmail> {
  final Value<int> localId;
  final Value<String> accountId;
  final Value<String> folderId;
  final Value<int> uid;
  final Value<String?> messageId;
  final Value<String> subject;
  final Value<String> fromName;
  final Value<String> fromAddress;
  final Value<String> toRecipientsJson;
  final Value<String> ccJson;
  final Value<String> snippet;
  final Value<String?> plainBody;
  final Value<String?> htmlBody;
  final Value<int> sentAt;
  final Value<int> flagsBitmask;
  final Value<bool> hasAttachments;
  final Value<bool> bodyDownloaded;
  const DbEmailsCompanion({
    this.localId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.folderId = const Value.absent(),
    this.uid = const Value.absent(),
    this.messageId = const Value.absent(),
    this.subject = const Value.absent(),
    this.fromName = const Value.absent(),
    this.fromAddress = const Value.absent(),
    this.toRecipientsJson = const Value.absent(),
    this.ccJson = const Value.absent(),
    this.snippet = const Value.absent(),
    this.plainBody = const Value.absent(),
    this.htmlBody = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.flagsBitmask = const Value.absent(),
    this.hasAttachments = const Value.absent(),
    this.bodyDownloaded = const Value.absent(),
  });
  DbEmailsCompanion.insert({
    this.localId = const Value.absent(),
    required String accountId,
    required String folderId,
    required int uid,
    this.messageId = const Value.absent(),
    required String subject,
    required String fromName,
    required String fromAddress,
    required String toRecipientsJson,
    required String ccJson,
    required String snippet,
    this.plainBody = const Value.absent(),
    this.htmlBody = const Value.absent(),
    required int sentAt,
    this.flagsBitmask = const Value.absent(),
    this.hasAttachments = const Value.absent(),
    this.bodyDownloaded = const Value.absent(),
  }) : accountId = Value(accountId),
       folderId = Value(folderId),
       uid = Value(uid),
       subject = Value(subject),
       fromName = Value(fromName),
       fromAddress = Value(fromAddress),
       toRecipientsJson = Value(toRecipientsJson),
       ccJson = Value(ccJson),
       snippet = Value(snippet),
       sentAt = Value(sentAt);
  static Insertable<DbEmail> custom({
    Expression<int>? localId,
    Expression<String>? accountId,
    Expression<String>? folderId,
    Expression<int>? uid,
    Expression<String>? messageId,
    Expression<String>? subject,
    Expression<String>? fromName,
    Expression<String>? fromAddress,
    Expression<String>? toRecipientsJson,
    Expression<String>? ccJson,
    Expression<String>? snippet,
    Expression<String>? plainBody,
    Expression<String>? htmlBody,
    Expression<int>? sentAt,
    Expression<int>? flagsBitmask,
    Expression<bool>? hasAttachments,
    Expression<bool>? bodyDownloaded,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (accountId != null) 'account_id': accountId,
      if (folderId != null) 'folder_id': folderId,
      if (uid != null) 'uid': uid,
      if (messageId != null) 'message_id': messageId,
      if (subject != null) 'subject': subject,
      if (fromName != null) 'from_name': fromName,
      if (fromAddress != null) 'from_address': fromAddress,
      if (toRecipientsJson != null) 'to_json': toRecipientsJson,
      if (ccJson != null) 'cc_json': ccJson,
      if (snippet != null) 'snippet': snippet,
      if (plainBody != null) 'plain_body': plainBody,
      if (htmlBody != null) 'html_body': htmlBody,
      if (sentAt != null) 'sent_at': sentAt,
      if (flagsBitmask != null) 'flags_bitmask': flagsBitmask,
      if (hasAttachments != null) 'has_attachments': hasAttachments,
      if (bodyDownloaded != null) 'body_downloaded': bodyDownloaded,
    });
  }

  DbEmailsCompanion copyWith({
    Value<int>? localId,
    Value<String>? accountId,
    Value<String>? folderId,
    Value<int>? uid,
    Value<String?>? messageId,
    Value<String>? subject,
    Value<String>? fromName,
    Value<String>? fromAddress,
    Value<String>? toRecipientsJson,
    Value<String>? ccJson,
    Value<String>? snippet,
    Value<String?>? plainBody,
    Value<String?>? htmlBody,
    Value<int>? sentAt,
    Value<int>? flagsBitmask,
    Value<bool>? hasAttachments,
    Value<bool>? bodyDownloaded,
  }) {
    return DbEmailsCompanion(
      localId: localId ?? this.localId,
      accountId: accountId ?? this.accountId,
      folderId: folderId ?? this.folderId,
      uid: uid ?? this.uid,
      messageId: messageId ?? this.messageId,
      subject: subject ?? this.subject,
      fromName: fromName ?? this.fromName,
      fromAddress: fromAddress ?? this.fromAddress,
      toRecipientsJson: toRecipientsJson ?? this.toRecipientsJson,
      ccJson: ccJson ?? this.ccJson,
      snippet: snippet ?? this.snippet,
      plainBody: plainBody ?? this.plainBody,
      htmlBody: htmlBody ?? this.htmlBody,
      sentAt: sentAt ?? this.sentAt,
      flagsBitmask: flagsBitmask ?? this.flagsBitmask,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      bodyDownloaded: bodyDownloaded ?? this.bodyDownloaded,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<int>(localId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (uid.present) {
      map['uid'] = Variable<int>(uid.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (fromName.present) {
      map['from_name'] = Variable<String>(fromName.value);
    }
    if (fromAddress.present) {
      map['from_address'] = Variable<String>(fromAddress.value);
    }
    if (toRecipientsJson.present) {
      map['to_json'] = Variable<String>(toRecipientsJson.value);
    }
    if (ccJson.present) {
      map['cc_json'] = Variable<String>(ccJson.value);
    }
    if (snippet.present) {
      map['snippet'] = Variable<String>(snippet.value);
    }
    if (plainBody.present) {
      map['plain_body'] = Variable<String>(plainBody.value);
    }
    if (htmlBody.present) {
      map['html_body'] = Variable<String>(htmlBody.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<int>(sentAt.value);
    }
    if (flagsBitmask.present) {
      map['flags_bitmask'] = Variable<int>(flagsBitmask.value);
    }
    if (hasAttachments.present) {
      map['has_attachments'] = Variable<bool>(hasAttachments.value);
    }
    if (bodyDownloaded.present) {
      map['body_downloaded'] = Variable<bool>(bodyDownloaded.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbEmailsCompanion(')
          ..write('localId: $localId, ')
          ..write('accountId: $accountId, ')
          ..write('folderId: $folderId, ')
          ..write('uid: $uid, ')
          ..write('messageId: $messageId, ')
          ..write('subject: $subject, ')
          ..write('fromName: $fromName, ')
          ..write('fromAddress: $fromAddress, ')
          ..write('toRecipientsJson: $toRecipientsJson, ')
          ..write('ccJson: $ccJson, ')
          ..write('snippet: $snippet, ')
          ..write('plainBody: $plainBody, ')
          ..write('htmlBody: $htmlBody, ')
          ..write('sentAt: $sentAt, ')
          ..write('flagsBitmask: $flagsBitmask, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('bodyDownloaded: $bodyDownloaded')
          ..write(')'))
        .toString();
  }
}

class $DbAttachmentsTable extends DbAttachments
    with TableInfo<$DbAttachmentsTable, DbAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailLocalIdMeta = const VerificationMeta(
    'emailLocalId',
  );
  @override
  late final GeneratedColumn<int> emailLocalId = GeneratedColumn<int>(
    'email_local_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES db_emails (local_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _partIdMeta = const VerificationMeta('partId');
  @override
  late final GeneratedColumn<String> partId = GeneratedColumn<String>(
    'part_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentIdMeta = const VerificationMeta(
    'contentId',
  );
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
    'content_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filenameMeta = const VerificationMeta(
    'filename',
  );
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
    'filename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localCachePathMeta = const VerificationMeta(
    'localCachePath',
  );
  @override
  late final GeneratedColumn<String> localCachePath = GeneratedColumn<String>(
    'local_cache_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isInlineMeta = const VerificationMeta(
    'isInline',
  );
  @override
  late final GeneratedColumn<bool> isInline = GeneratedColumn<bool>(
    'is_inline',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_inline" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    emailLocalId,
    partId,
    contentId,
    filename,
    mimeType,
    sizeBytes,
    localCachePath,
    isInline,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbAttachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email_local_id')) {
      context.handle(
        _emailLocalIdMeta,
        emailLocalId.isAcceptableOrUnknown(
          data['email_local_id']!,
          _emailLocalIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_emailLocalIdMeta);
    }
    if (data.containsKey('part_id')) {
      context.handle(
        _partIdMeta,
        partId.isAcceptableOrUnknown(data['part_id']!, _partIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partIdMeta);
    }
    if (data.containsKey('content_id')) {
      context.handle(
        _contentIdMeta,
        contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta),
      );
    }
    if (data.containsKey('filename')) {
      context.handle(
        _filenameMeta,
        filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta),
      );
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('local_cache_path')) {
      context.handle(
        _localCachePathMeta,
        localCachePath.isAcceptableOrUnknown(
          data['local_cache_path']!,
          _localCachePathMeta,
        ),
      );
    }
    if (data.containsKey('is_inline')) {
      context.handle(
        _isInlineMeta,
        isInline.isAcceptableOrUnknown(data['is_inline']!, _isInlineMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbAttachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      emailLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}email_local_id'],
      )!,
      partId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_id'],
      )!,
      contentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_id'],
      ),
      filename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      localCachePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_cache_path'],
      ),
      isInline: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_inline'],
      )!,
    );
  }

  @override
  $DbAttachmentsTable createAlias(String alias) {
    return $DbAttachmentsTable(attachedDatabase, alias);
  }
}

class DbAttachment extends DataClass implements Insertable<DbAttachment> {
  final String id;
  final int emailLocalId;
  final String partId;
  final String? contentId;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final String? localCachePath;
  final bool isInline;
  const DbAttachment({
    required this.id,
    required this.emailLocalId,
    required this.partId,
    this.contentId,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    this.localCachePath,
    required this.isInline,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['email_local_id'] = Variable<int>(emailLocalId);
    map['part_id'] = Variable<String>(partId);
    if (!nullToAbsent || contentId != null) {
      map['content_id'] = Variable<String>(contentId);
    }
    map['filename'] = Variable<String>(filename);
    map['mime_type'] = Variable<String>(mimeType);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || localCachePath != null) {
      map['local_cache_path'] = Variable<String>(localCachePath);
    }
    map['is_inline'] = Variable<bool>(isInline);
    return map;
  }

  DbAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return DbAttachmentsCompanion(
      id: Value(id),
      emailLocalId: Value(emailLocalId),
      partId: Value(partId),
      contentId: contentId == null && nullToAbsent
          ? const Value.absent()
          : Value(contentId),
      filename: Value(filename),
      mimeType: Value(mimeType),
      sizeBytes: Value(sizeBytes),
      localCachePath: localCachePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localCachePath),
      isInline: Value(isInline),
    );
  }

  factory DbAttachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbAttachment(
      id: serializer.fromJson<String>(json['id']),
      emailLocalId: serializer.fromJson<int>(json['emailLocalId']),
      partId: serializer.fromJson<String>(json['partId']),
      contentId: serializer.fromJson<String?>(json['contentId']),
      filename: serializer.fromJson<String>(json['filename']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      localCachePath: serializer.fromJson<String?>(json['localCachePath']),
      isInline: serializer.fromJson<bool>(json['isInline']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'emailLocalId': serializer.toJson<int>(emailLocalId),
      'partId': serializer.toJson<String>(partId),
      'contentId': serializer.toJson<String?>(contentId),
      'filename': serializer.toJson<String>(filename),
      'mimeType': serializer.toJson<String>(mimeType),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'localCachePath': serializer.toJson<String?>(localCachePath),
      'isInline': serializer.toJson<bool>(isInline),
    };
  }

  DbAttachment copyWith({
    String? id,
    int? emailLocalId,
    String? partId,
    Value<String?> contentId = const Value.absent(),
    String? filename,
    String? mimeType,
    int? sizeBytes,
    Value<String?> localCachePath = const Value.absent(),
    bool? isInline,
  }) => DbAttachment(
    id: id ?? this.id,
    emailLocalId: emailLocalId ?? this.emailLocalId,
    partId: partId ?? this.partId,
    contentId: contentId.present ? contentId.value : this.contentId,
    filename: filename ?? this.filename,
    mimeType: mimeType ?? this.mimeType,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    localCachePath: localCachePath.present
        ? localCachePath.value
        : this.localCachePath,
    isInline: isInline ?? this.isInline,
  );
  DbAttachment copyWithCompanion(DbAttachmentsCompanion data) {
    return DbAttachment(
      id: data.id.present ? data.id.value : this.id,
      emailLocalId: data.emailLocalId.present
          ? data.emailLocalId.value
          : this.emailLocalId,
      partId: data.partId.present ? data.partId.value : this.partId,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      filename: data.filename.present ? data.filename.value : this.filename,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      localCachePath: data.localCachePath.present
          ? data.localCachePath.value
          : this.localCachePath,
      isInline: data.isInline.present ? data.isInline.value : this.isInline,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbAttachment(')
          ..write('id: $id, ')
          ..write('emailLocalId: $emailLocalId, ')
          ..write('partId: $partId, ')
          ..write('contentId: $contentId, ')
          ..write('filename: $filename, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('localCachePath: $localCachePath, ')
          ..write('isInline: $isInline')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    emailLocalId,
    partId,
    contentId,
    filename,
    mimeType,
    sizeBytes,
    localCachePath,
    isInline,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbAttachment &&
          other.id == this.id &&
          other.emailLocalId == this.emailLocalId &&
          other.partId == this.partId &&
          other.contentId == this.contentId &&
          other.filename == this.filename &&
          other.mimeType == this.mimeType &&
          other.sizeBytes == this.sizeBytes &&
          other.localCachePath == this.localCachePath &&
          other.isInline == this.isInline);
}

class DbAttachmentsCompanion extends UpdateCompanion<DbAttachment> {
  final Value<String> id;
  final Value<int> emailLocalId;
  final Value<String> partId;
  final Value<String?> contentId;
  final Value<String> filename;
  final Value<String> mimeType;
  final Value<int> sizeBytes;
  final Value<String?> localCachePath;
  final Value<bool> isInline;
  final Value<int> rowid;
  const DbAttachmentsCompanion({
    this.id = const Value.absent(),
    this.emailLocalId = const Value.absent(),
    this.partId = const Value.absent(),
    this.contentId = const Value.absent(),
    this.filename = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.localCachePath = const Value.absent(),
    this.isInline = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DbAttachmentsCompanion.insert({
    required String id,
    required int emailLocalId,
    required String partId,
    this.contentId = const Value.absent(),
    required String filename,
    required String mimeType,
    required int sizeBytes,
    this.localCachePath = const Value.absent(),
    this.isInline = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       emailLocalId = Value(emailLocalId),
       partId = Value(partId),
       filename = Value(filename),
       mimeType = Value(mimeType),
       sizeBytes = Value(sizeBytes);
  static Insertable<DbAttachment> custom({
    Expression<String>? id,
    Expression<int>? emailLocalId,
    Expression<String>? partId,
    Expression<String>? contentId,
    Expression<String>? filename,
    Expression<String>? mimeType,
    Expression<int>? sizeBytes,
    Expression<String>? localCachePath,
    Expression<bool>? isInline,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (emailLocalId != null) 'email_local_id': emailLocalId,
      if (partId != null) 'part_id': partId,
      if (contentId != null) 'content_id': contentId,
      if (filename != null) 'filename': filename,
      if (mimeType != null) 'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (localCachePath != null) 'local_cache_path': localCachePath,
      if (isInline != null) 'is_inline': isInline,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DbAttachmentsCompanion copyWith({
    Value<String>? id,
    Value<int>? emailLocalId,
    Value<String>? partId,
    Value<String?>? contentId,
    Value<String>? filename,
    Value<String>? mimeType,
    Value<int>? sizeBytes,
    Value<String?>? localCachePath,
    Value<bool>? isInline,
    Value<int>? rowid,
  }) {
    return DbAttachmentsCompanion(
      id: id ?? this.id,
      emailLocalId: emailLocalId ?? this.emailLocalId,
      partId: partId ?? this.partId,
      contentId: contentId ?? this.contentId,
      filename: filename ?? this.filename,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      localCachePath: localCachePath ?? this.localCachePath,
      isInline: isInline ?? this.isInline,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (emailLocalId.present) {
      map['email_local_id'] = Variable<int>(emailLocalId.value);
    }
    if (partId.present) {
      map['part_id'] = Variable<String>(partId.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (localCachePath.present) {
      map['local_cache_path'] = Variable<String>(localCachePath.value);
    }
    if (isInline.present) {
      map['is_inline'] = Variable<bool>(isInline.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbAttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('emailLocalId: $emailLocalId, ')
          ..write('partId: $partId, ')
          ..write('contentId: $contentId, ')
          ..write('filename: $filename, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('localCachePath: $localCachePath, ')
          ..write('isInline: $isInline, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DbTrustedSendersTable extends DbTrustedSenders
    with TableInfo<$DbTrustedSendersTable, DbTrustedSender> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbTrustedSendersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _senderEmailMeta = const VerificationMeta(
    'senderEmail',
  );
  @override
  late final GeneratedColumn<String> senderEmail = GeneratedColumn<String>(
    'sender_email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [senderEmail, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_trusted_senders';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbTrustedSender> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sender_email')) {
      context.handle(
        _senderEmailMeta,
        senderEmail.isAcceptableOrUnknown(
          data['sender_email']!,
          _senderEmailMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_senderEmailMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {senderEmail};
  @override
  DbTrustedSender map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbTrustedSender(
      senderEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_email'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DbTrustedSendersTable createAlias(String alias) {
    return $DbTrustedSendersTable(attachedDatabase, alias);
  }
}

class DbTrustedSender extends DataClass implements Insertable<DbTrustedSender> {
  final String senderEmail;
  final int createdAt;
  const DbTrustedSender({required this.senderEmail, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sender_email'] = Variable<String>(senderEmail);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  DbTrustedSendersCompanion toCompanion(bool nullToAbsent) {
    return DbTrustedSendersCompanion(
      senderEmail: Value(senderEmail),
      createdAt: Value(createdAt),
    );
  }

  factory DbTrustedSender.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbTrustedSender(
      senderEmail: serializer.fromJson<String>(json['senderEmail']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'senderEmail': serializer.toJson<String>(senderEmail),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  DbTrustedSender copyWith({String? senderEmail, int? createdAt}) =>
      DbTrustedSender(
        senderEmail: senderEmail ?? this.senderEmail,
        createdAt: createdAt ?? this.createdAt,
      );
  DbTrustedSender copyWithCompanion(DbTrustedSendersCompanion data) {
    return DbTrustedSender(
      senderEmail: data.senderEmail.present
          ? data.senderEmail.value
          : this.senderEmail,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbTrustedSender(')
          ..write('senderEmail: $senderEmail, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(senderEmail, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbTrustedSender &&
          other.senderEmail == this.senderEmail &&
          other.createdAt == this.createdAt);
}

class DbTrustedSendersCompanion extends UpdateCompanion<DbTrustedSender> {
  final Value<String> senderEmail;
  final Value<int> createdAt;
  final Value<int> rowid;
  const DbTrustedSendersCompanion({
    this.senderEmail = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DbTrustedSendersCompanion.insert({
    required String senderEmail,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : senderEmail = Value(senderEmail),
       createdAt = Value(createdAt);
  static Insertable<DbTrustedSender> custom({
    Expression<String>? senderEmail,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (senderEmail != null) 'sender_email': senderEmail,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DbTrustedSendersCompanion copyWith({
    Value<String>? senderEmail,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return DbTrustedSendersCompanion(
      senderEmail: senderEmail ?? this.senderEmail,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (senderEmail.present) {
      map['sender_email'] = Variable<String>(senderEmail.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbTrustedSendersCompanion(')
          ..write('senderEmail: $senderEmail, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DbOutboxMessagesTable extends DbOutboxMessages
    with TableInfo<$DbOutboxMessagesTable, DbOutboxMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbOutboxMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES db_accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originEmailLocalIdMeta =
      const VerificationMeta('originEmailLocalId');
  @override
  late final GeneratedColumn<int> originEmailLocalId = GeneratedColumn<int>(
    'origin_email_local_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inReplyToMeta = const VerificationMeta(
    'inReplyTo',
  );
  @override
  late final GeneratedColumn<String> inReplyTo = GeneratedColumn<String>(
    'in_reply_to',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referencesHeaderMeta = const VerificationMeta(
    'referencesHeader',
  );
  @override
  late final GeneratedColumn<String> referencesHeader = GeneratedColumn<String>(
    'references_header',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toRecipientsJsonMeta = const VerificationMeta(
    'toRecipientsJson',
  );
  @override
  late final GeneratedColumn<String> toRecipientsJson = GeneratedColumn<String>(
    'to_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ccJsonMeta = const VerificationMeta('ccJson');
  @override
  late final GeneratedColumn<String> ccJson = GeneratedColumn<String>(
    'cc_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bccJsonMeta = const VerificationMeta(
    'bccJson',
  );
  @override
  late final GeneratedColumn<String> bccJson = GeneratedColumn<String>(
    'bcc_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outgoingMessageIdMeta = const VerificationMeta(
    'outgoingMessageId',
  );
  @override
  late final GeneratedColumn<String> outgoingMessageId =
      GeneratedColumn<String>(
        'outgoing_message_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _plainBodyMeta = const VerificationMeta(
    'plainBody',
  );
  @override
  late final GeneratedColumn<String> plainBody = GeneratedColumn<String>(
    'plain_body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _htmlBodyMeta = const VerificationMeta(
    'htmlBody',
  );
  @override
  late final GeneratedColumn<String> htmlBody = GeneratedColumn<String>(
    'html_body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentsJsonMeta = const VerificationMeta(
    'attachmentsJson',
  );
  @override
  late final GeneratedColumn<String> attachmentsJson = GeneratedColumn<String>(
    'attachments_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _retryableMeta = const VerificationMeta(
    'retryable',
  );
  @override
  late final GeneratedColumn<bool> retryable = GeneratedColumn<bool>(
    'retryable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("retryable" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<int> nextRetryAt = GeneratedColumn<int>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<int> sentAt = GeneratedColumn<int>(
    'sent_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    mode,
    originEmailLocalId,
    inReplyTo,
    referencesHeader,
    toRecipientsJson,
    ccJson,
    bccJson,
    subject,
    outgoingMessageId,
    plainBody,
    htmlBody,
    attachmentsJson,
    status,
    retryCount,
    retryable,
    nextRetryAt,
    lastError,
    createdAt,
    updatedAt,
    sentAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_outbox_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbOutboxMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('origin_email_local_id')) {
      context.handle(
        _originEmailLocalIdMeta,
        originEmailLocalId.isAcceptableOrUnknown(
          data['origin_email_local_id']!,
          _originEmailLocalIdMeta,
        ),
      );
    }
    if (data.containsKey('in_reply_to')) {
      context.handle(
        _inReplyToMeta,
        inReplyTo.isAcceptableOrUnknown(data['in_reply_to']!, _inReplyToMeta),
      );
    }
    if (data.containsKey('references_header')) {
      context.handle(
        _referencesHeaderMeta,
        referencesHeader.isAcceptableOrUnknown(
          data['references_header']!,
          _referencesHeaderMeta,
        ),
      );
    }
    if (data.containsKey('to_json')) {
      context.handle(
        _toRecipientsJsonMeta,
        toRecipientsJson.isAcceptableOrUnknown(
          data['to_json']!,
          _toRecipientsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_toRecipientsJsonMeta);
    }
    if (data.containsKey('cc_json')) {
      context.handle(
        _ccJsonMeta,
        ccJson.isAcceptableOrUnknown(data['cc_json']!, _ccJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_ccJsonMeta);
    }
    if (data.containsKey('bcc_json')) {
      context.handle(
        _bccJsonMeta,
        bccJson.isAcceptableOrUnknown(data['bcc_json']!, _bccJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_bccJsonMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('outgoing_message_id')) {
      context.handle(
        _outgoingMessageIdMeta,
        outgoingMessageId.isAcceptableOrUnknown(
          data['outgoing_message_id']!,
          _outgoingMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('plain_body')) {
      context.handle(
        _plainBodyMeta,
        plainBody.isAcceptableOrUnknown(data['plain_body']!, _plainBodyMeta),
      );
    } else if (isInserting) {
      context.missing(_plainBodyMeta);
    }
    if (data.containsKey('html_body')) {
      context.handle(
        _htmlBodyMeta,
        htmlBody.isAcceptableOrUnknown(data['html_body']!, _htmlBodyMeta),
      );
    }
    if (data.containsKey('attachments_json')) {
      context.handle(
        _attachmentsJsonMeta,
        attachmentsJson.isAcceptableOrUnknown(
          data['attachments_json']!,
          _attachmentsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attachmentsJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('retryable')) {
      context.handle(
        _retryableMeta,
        retryable.isAcceptableOrUnknown(data['retryable']!, _retryableMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbOutboxMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbOutboxMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      originEmailLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}origin_email_local_id'],
      ),
      inReplyTo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}in_reply_to'],
      ),
      referencesHeader: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}references_header'],
      ),
      toRecipientsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_json'],
      )!,
      ccJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cc_json'],
      )!,
      bccJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bcc_json'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      outgoingMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outgoing_message_id'],
      ),
      plainBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plain_body'],
      )!,
      htmlBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}html_body'],
      ),
      attachmentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      retryable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}retryable'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_retry_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sent_at'],
      ),
    );
  }

  @override
  $DbOutboxMessagesTable createAlias(String alias) {
    return $DbOutboxMessagesTable(attachedDatabase, alias);
  }
}

class DbOutboxMessage extends DataClass implements Insertable<DbOutboxMessage> {
  final String id;
  final String accountId;
  final String mode;
  final int? originEmailLocalId;
  final String? inReplyTo;
  final String? referencesHeader;
  final String toRecipientsJson;
  final String ccJson;
  final String bccJson;
  final String subject;
  final String? outgoingMessageId;
  final String plainBody;
  final String? htmlBody;
  final String attachmentsJson;
  final String status;
  final int retryCount;
  final bool retryable;
  final int? nextRetryAt;
  final String? lastError;
  final int createdAt;
  final int updatedAt;
  final int? sentAt;
  const DbOutboxMessage({
    required this.id,
    required this.accountId,
    required this.mode,
    this.originEmailLocalId,
    this.inReplyTo,
    this.referencesHeader,
    required this.toRecipientsJson,
    required this.ccJson,
    required this.bccJson,
    required this.subject,
    this.outgoingMessageId,
    required this.plainBody,
    this.htmlBody,
    required this.attachmentsJson,
    required this.status,
    required this.retryCount,
    required this.retryable,
    this.nextRetryAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
    this.sentAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || originEmailLocalId != null) {
      map['origin_email_local_id'] = Variable<int>(originEmailLocalId);
    }
    if (!nullToAbsent || inReplyTo != null) {
      map['in_reply_to'] = Variable<String>(inReplyTo);
    }
    if (!nullToAbsent || referencesHeader != null) {
      map['references_header'] = Variable<String>(referencesHeader);
    }
    map['to_json'] = Variable<String>(toRecipientsJson);
    map['cc_json'] = Variable<String>(ccJson);
    map['bcc_json'] = Variable<String>(bccJson);
    map['subject'] = Variable<String>(subject);
    if (!nullToAbsent || outgoingMessageId != null) {
      map['outgoing_message_id'] = Variable<String>(outgoingMessageId);
    }
    map['plain_body'] = Variable<String>(plainBody);
    if (!nullToAbsent || htmlBody != null) {
      map['html_body'] = Variable<String>(htmlBody);
    }
    map['attachments_json'] = Variable<String>(attachmentsJson);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    map['retryable'] = Variable<bool>(retryable);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<int>(nextRetryAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<int>(sentAt);
    }
    return map;
  }

  DbOutboxMessagesCompanion toCompanion(bool nullToAbsent) {
    return DbOutboxMessagesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      mode: Value(mode),
      originEmailLocalId: originEmailLocalId == null && nullToAbsent
          ? const Value.absent()
          : Value(originEmailLocalId),
      inReplyTo: inReplyTo == null && nullToAbsent
          ? const Value.absent()
          : Value(inReplyTo),
      referencesHeader: referencesHeader == null && nullToAbsent
          ? const Value.absent()
          : Value(referencesHeader),
      toRecipientsJson: Value(toRecipientsJson),
      ccJson: Value(ccJson),
      bccJson: Value(bccJson),
      subject: Value(subject),
      outgoingMessageId: outgoingMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(outgoingMessageId),
      plainBody: Value(plainBody),
      htmlBody: htmlBody == null && nullToAbsent
          ? const Value.absent()
          : Value(htmlBody),
      attachmentsJson: Value(attachmentsJson),
      status: Value(status),
      retryCount: Value(retryCount),
      retryable: Value(retryable),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      sentAt: sentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sentAt),
    );
  }

  factory DbOutboxMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbOutboxMessage(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      mode: serializer.fromJson<String>(json['mode']),
      originEmailLocalId: serializer.fromJson<int?>(json['originEmailLocalId']),
      inReplyTo: serializer.fromJson<String?>(json['inReplyTo']),
      referencesHeader: serializer.fromJson<String?>(json['referencesHeader']),
      toRecipientsJson: serializer.fromJson<String>(json['toRecipientsJson']),
      ccJson: serializer.fromJson<String>(json['ccJson']),
      bccJson: serializer.fromJson<String>(json['bccJson']),
      subject: serializer.fromJson<String>(json['subject']),
      outgoingMessageId: serializer.fromJson<String?>(
        json['outgoingMessageId'],
      ),
      plainBody: serializer.fromJson<String>(json['plainBody']),
      htmlBody: serializer.fromJson<String?>(json['htmlBody']),
      attachmentsJson: serializer.fromJson<String>(json['attachmentsJson']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      retryable: serializer.fromJson<bool>(json['retryable']),
      nextRetryAt: serializer.fromJson<int?>(json['nextRetryAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      sentAt: serializer.fromJson<int?>(json['sentAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'mode': serializer.toJson<String>(mode),
      'originEmailLocalId': serializer.toJson<int?>(originEmailLocalId),
      'inReplyTo': serializer.toJson<String?>(inReplyTo),
      'referencesHeader': serializer.toJson<String?>(referencesHeader),
      'toRecipientsJson': serializer.toJson<String>(toRecipientsJson),
      'ccJson': serializer.toJson<String>(ccJson),
      'bccJson': serializer.toJson<String>(bccJson),
      'subject': serializer.toJson<String>(subject),
      'outgoingMessageId': serializer.toJson<String?>(outgoingMessageId),
      'plainBody': serializer.toJson<String>(plainBody),
      'htmlBody': serializer.toJson<String?>(htmlBody),
      'attachmentsJson': serializer.toJson<String>(attachmentsJson),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'retryable': serializer.toJson<bool>(retryable),
      'nextRetryAt': serializer.toJson<int?>(nextRetryAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'sentAt': serializer.toJson<int?>(sentAt),
    };
  }

  DbOutboxMessage copyWith({
    String? id,
    String? accountId,
    String? mode,
    Value<int?> originEmailLocalId = const Value.absent(),
    Value<String?> inReplyTo = const Value.absent(),
    Value<String?> referencesHeader = const Value.absent(),
    String? toRecipientsJson,
    String? ccJson,
    String? bccJson,
    String? subject,
    Value<String?> outgoingMessageId = const Value.absent(),
    String? plainBody,
    Value<String?> htmlBody = const Value.absent(),
    String? attachmentsJson,
    String? status,
    int? retryCount,
    bool? retryable,
    Value<int?> nextRetryAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> sentAt = const Value.absent(),
  }) => DbOutboxMessage(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    mode: mode ?? this.mode,
    originEmailLocalId: originEmailLocalId.present
        ? originEmailLocalId.value
        : this.originEmailLocalId,
    inReplyTo: inReplyTo.present ? inReplyTo.value : this.inReplyTo,
    referencesHeader: referencesHeader.present
        ? referencesHeader.value
        : this.referencesHeader,
    toRecipientsJson: toRecipientsJson ?? this.toRecipientsJson,
    ccJson: ccJson ?? this.ccJson,
    bccJson: bccJson ?? this.bccJson,
    subject: subject ?? this.subject,
    outgoingMessageId: outgoingMessageId.present
        ? outgoingMessageId.value
        : this.outgoingMessageId,
    plainBody: plainBody ?? this.plainBody,
    htmlBody: htmlBody.present ? htmlBody.value : this.htmlBody,
    attachmentsJson: attachmentsJson ?? this.attachmentsJson,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    retryable: retryable ?? this.retryable,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    sentAt: sentAt.present ? sentAt.value : this.sentAt,
  );
  DbOutboxMessage copyWithCompanion(DbOutboxMessagesCompanion data) {
    return DbOutboxMessage(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      mode: data.mode.present ? data.mode.value : this.mode,
      originEmailLocalId: data.originEmailLocalId.present
          ? data.originEmailLocalId.value
          : this.originEmailLocalId,
      inReplyTo: data.inReplyTo.present ? data.inReplyTo.value : this.inReplyTo,
      referencesHeader: data.referencesHeader.present
          ? data.referencesHeader.value
          : this.referencesHeader,
      toRecipientsJson: data.toRecipientsJson.present
          ? data.toRecipientsJson.value
          : this.toRecipientsJson,
      ccJson: data.ccJson.present ? data.ccJson.value : this.ccJson,
      bccJson: data.bccJson.present ? data.bccJson.value : this.bccJson,
      subject: data.subject.present ? data.subject.value : this.subject,
      outgoingMessageId: data.outgoingMessageId.present
          ? data.outgoingMessageId.value
          : this.outgoingMessageId,
      plainBody: data.plainBody.present ? data.plainBody.value : this.plainBody,
      htmlBody: data.htmlBody.present ? data.htmlBody.value : this.htmlBody,
      attachmentsJson: data.attachmentsJson.present
          ? data.attachmentsJson.value
          : this.attachmentsJson,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      retryable: data.retryable.present ? data.retryable.value : this.retryable,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbOutboxMessage(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('mode: $mode, ')
          ..write('originEmailLocalId: $originEmailLocalId, ')
          ..write('inReplyTo: $inReplyTo, ')
          ..write('referencesHeader: $referencesHeader, ')
          ..write('toRecipientsJson: $toRecipientsJson, ')
          ..write('ccJson: $ccJson, ')
          ..write('bccJson: $bccJson, ')
          ..write('subject: $subject, ')
          ..write('outgoingMessageId: $outgoingMessageId, ')
          ..write('plainBody: $plainBody, ')
          ..write('htmlBody: $htmlBody, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('retryable: $retryable, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sentAt: $sentAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    accountId,
    mode,
    originEmailLocalId,
    inReplyTo,
    referencesHeader,
    toRecipientsJson,
    ccJson,
    bccJson,
    subject,
    outgoingMessageId,
    plainBody,
    htmlBody,
    attachmentsJson,
    status,
    retryCount,
    retryable,
    nextRetryAt,
    lastError,
    createdAt,
    updatedAt,
    sentAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbOutboxMessage &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.mode == this.mode &&
          other.originEmailLocalId == this.originEmailLocalId &&
          other.inReplyTo == this.inReplyTo &&
          other.referencesHeader == this.referencesHeader &&
          other.toRecipientsJson == this.toRecipientsJson &&
          other.ccJson == this.ccJson &&
          other.bccJson == this.bccJson &&
          other.subject == this.subject &&
          other.outgoingMessageId == this.outgoingMessageId &&
          other.plainBody == this.plainBody &&
          other.htmlBody == this.htmlBody &&
          other.attachmentsJson == this.attachmentsJson &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.retryable == this.retryable &&
          other.nextRetryAt == this.nextRetryAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.sentAt == this.sentAt);
}

class DbOutboxMessagesCompanion extends UpdateCompanion<DbOutboxMessage> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> mode;
  final Value<int?> originEmailLocalId;
  final Value<String?> inReplyTo;
  final Value<String?> referencesHeader;
  final Value<String> toRecipientsJson;
  final Value<String> ccJson;
  final Value<String> bccJson;
  final Value<String> subject;
  final Value<String?> outgoingMessageId;
  final Value<String> plainBody;
  final Value<String?> htmlBody;
  final Value<String> attachmentsJson;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<bool> retryable;
  final Value<int?> nextRetryAt;
  final Value<String?> lastError;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> sentAt;
  final Value<int> rowid;
  const DbOutboxMessagesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.mode = const Value.absent(),
    this.originEmailLocalId = const Value.absent(),
    this.inReplyTo = const Value.absent(),
    this.referencesHeader = const Value.absent(),
    this.toRecipientsJson = const Value.absent(),
    this.ccJson = const Value.absent(),
    this.bccJson = const Value.absent(),
    this.subject = const Value.absent(),
    this.outgoingMessageId = const Value.absent(),
    this.plainBody = const Value.absent(),
    this.htmlBody = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.retryable = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DbOutboxMessagesCompanion.insert({
    required String id,
    required String accountId,
    required String mode,
    this.originEmailLocalId = const Value.absent(),
    this.inReplyTo = const Value.absent(),
    this.referencesHeader = const Value.absent(),
    required String toRecipientsJson,
    required String ccJson,
    required String bccJson,
    required String subject,
    this.outgoingMessageId = const Value.absent(),
    required String plainBody,
    this.htmlBody = const Value.absent(),
    required String attachmentsJson,
    required String status,
    this.retryCount = const Value.absent(),
    this.retryable = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       mode = Value(mode),
       toRecipientsJson = Value(toRecipientsJson),
       ccJson = Value(ccJson),
       bccJson = Value(bccJson),
       subject = Value(subject),
       plainBody = Value(plainBody),
       attachmentsJson = Value(attachmentsJson),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DbOutboxMessage> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? mode,
    Expression<int>? originEmailLocalId,
    Expression<String>? inReplyTo,
    Expression<String>? referencesHeader,
    Expression<String>? toRecipientsJson,
    Expression<String>? ccJson,
    Expression<String>? bccJson,
    Expression<String>? subject,
    Expression<String>? outgoingMessageId,
    Expression<String>? plainBody,
    Expression<String>? htmlBody,
    Expression<String>? attachmentsJson,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<bool>? retryable,
    Expression<int>? nextRetryAt,
    Expression<String>? lastError,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? sentAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (mode != null) 'mode': mode,
      if (originEmailLocalId != null)
        'origin_email_local_id': originEmailLocalId,
      if (inReplyTo != null) 'in_reply_to': inReplyTo,
      if (referencesHeader != null) 'references_header': referencesHeader,
      if (toRecipientsJson != null) 'to_json': toRecipientsJson,
      if (ccJson != null) 'cc_json': ccJson,
      if (bccJson != null) 'bcc_json': bccJson,
      if (subject != null) 'subject': subject,
      if (outgoingMessageId != null) 'outgoing_message_id': outgoingMessageId,
      if (plainBody != null) 'plain_body': plainBody,
      if (htmlBody != null) 'html_body': htmlBody,
      if (attachmentsJson != null) 'attachments_json': attachmentsJson,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (retryable != null) 'retryable': retryable,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (sentAt != null) 'sent_at': sentAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DbOutboxMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? mode,
    Value<int?>? originEmailLocalId,
    Value<String?>? inReplyTo,
    Value<String?>? referencesHeader,
    Value<String>? toRecipientsJson,
    Value<String>? ccJson,
    Value<String>? bccJson,
    Value<String>? subject,
    Value<String?>? outgoingMessageId,
    Value<String>? plainBody,
    Value<String?>? htmlBody,
    Value<String>? attachmentsJson,
    Value<String>? status,
    Value<int>? retryCount,
    Value<bool>? retryable,
    Value<int?>? nextRetryAt,
    Value<String?>? lastError,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? sentAt,
    Value<int>? rowid,
  }) {
    return DbOutboxMessagesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      mode: mode ?? this.mode,
      originEmailLocalId: originEmailLocalId ?? this.originEmailLocalId,
      inReplyTo: inReplyTo ?? this.inReplyTo,
      referencesHeader: referencesHeader ?? this.referencesHeader,
      toRecipientsJson: toRecipientsJson ?? this.toRecipientsJson,
      ccJson: ccJson ?? this.ccJson,
      bccJson: bccJson ?? this.bccJson,
      subject: subject ?? this.subject,
      outgoingMessageId: outgoingMessageId ?? this.outgoingMessageId,
      plainBody: plainBody ?? this.plainBody,
      htmlBody: htmlBody ?? this.htmlBody,
      attachmentsJson: attachmentsJson ?? this.attachmentsJson,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      retryable: retryable ?? this.retryable,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sentAt: sentAt ?? this.sentAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (originEmailLocalId.present) {
      map['origin_email_local_id'] = Variable<int>(originEmailLocalId.value);
    }
    if (inReplyTo.present) {
      map['in_reply_to'] = Variable<String>(inReplyTo.value);
    }
    if (referencesHeader.present) {
      map['references_header'] = Variable<String>(referencesHeader.value);
    }
    if (toRecipientsJson.present) {
      map['to_json'] = Variable<String>(toRecipientsJson.value);
    }
    if (ccJson.present) {
      map['cc_json'] = Variable<String>(ccJson.value);
    }
    if (bccJson.present) {
      map['bcc_json'] = Variable<String>(bccJson.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (outgoingMessageId.present) {
      map['outgoing_message_id'] = Variable<String>(outgoingMessageId.value);
    }
    if (plainBody.present) {
      map['plain_body'] = Variable<String>(plainBody.value);
    }
    if (htmlBody.present) {
      map['html_body'] = Variable<String>(htmlBody.value);
    }
    if (attachmentsJson.present) {
      map['attachments_json'] = Variable<String>(attachmentsJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (retryable.present) {
      map['retryable'] = Variable<bool>(retryable.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<int>(nextRetryAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<int>(sentAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbOutboxMessagesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('mode: $mode, ')
          ..write('originEmailLocalId: $originEmailLocalId, ')
          ..write('inReplyTo: $inReplyTo, ')
          ..write('referencesHeader: $referencesHeader, ')
          ..write('toRecipientsJson: $toRecipientsJson, ')
          ..write('ccJson: $ccJson, ')
          ..write('bccJson: $bccJson, ')
          ..write('subject: $subject, ')
          ..write('outgoingMessageId: $outgoingMessageId, ')
          ..write('plainBody: $plainBody, ')
          ..write('htmlBody: $htmlBody, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('retryable: $retryable, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sentAt: $sentAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DbAccountsTable dbAccounts = $DbAccountsTable(this);
  late final $DbFoldersTable dbFolders = $DbFoldersTable(this);
  late final $DbEmailsTable dbEmails = $DbEmailsTable(this);
  late final $DbAttachmentsTable dbAttachments = $DbAttachmentsTable(this);
  late final $DbTrustedSendersTable dbTrustedSenders = $DbTrustedSendersTable(
    this,
  );
  late final $DbOutboxMessagesTable dbOutboxMessages = $DbOutboxMessagesTable(
    this,
  );
  late final Index idxFoldersRoleAccount = Index(
    'idx_folders_role_account',
    'CREATE INDEX idx_folders_role_account ON db_folders (role, account_id)',
  );
  late final Index idxEmailsFolderSent = Index(
    'idx_emails_folder_sent',
    'CREATE INDEX idx_emails_folder_sent ON db_emails (folder_id, sent_at)',
  );
  late final Index idxEmailsSentAt = Index(
    'idx_emails_sent_at',
    'CREATE INDEX idx_emails_sent_at ON db_emails (sent_at)',
  );
  late final Index idxEmailsAccountSent = Index(
    'idx_emails_account_sent',
    'CREATE INDEX idx_emails_account_sent ON db_emails (account_id, sent_at)',
  );
  late final Index idxEmailsFolderSentUid = Index(
    'idx_emails_folder_sent_uid',
    'CREATE INDEX idx_emails_folder_sent_uid ON db_emails (folder_id, sent_at, uid)',
  );
  late final Index idxAttachmentsEmail = Index(
    'idx_attachments_email',
    'CREATE INDEX idx_attachments_email ON db_attachments (email_local_id)',
  );
  late final Index idxOutboxAccount = Index(
    'idx_outbox_account',
    'CREATE INDEX idx_outbox_account ON db_outbox_messages (account_id)',
  );
  late final Index idxOutboxStatus = Index(
    'idx_outbox_status',
    'CREATE INDEX idx_outbox_status ON db_outbox_messages (status)',
  );
  late final Index idxOutboxUpdated = Index(
    'idx_outbox_updated',
    'CREATE INDEX idx_outbox_updated ON db_outbox_messages (updated_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dbAccounts,
    dbFolders,
    dbEmails,
    dbAttachments,
    dbTrustedSenders,
    dbOutboxMessages,
    idxFoldersRoleAccount,
    idxEmailsFolderSent,
    idxEmailsSentAt,
    idxEmailsAccountSent,
    idxEmailsFolderSentUid,
    idxAttachmentsEmail,
    idxOutboxAccount,
    idxOutboxStatus,
    idxOutboxUpdated,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'db_accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('db_folders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'db_accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('db_emails', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'db_folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('db_emails', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'db_emails',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('db_attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'db_accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('db_outbox_messages', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DbAccountsTableCreateCompanionBuilder = DbAccountsCompanion Function({
  required String id,
  required String email,
  required String displayName,
  required String providerType,
  required String authType,
  required int colorValue,
  required String imapHost,
  required int imapPort,
  required bool imapImplicitTls,
  required String smtpHost,
  required int smtpPort,
  required bool smtpImplicitTls,
  Value<bool> isEnabled,
  required int createdAt,
  Value<int> rowid,
});
typedef $$DbAccountsTableUpdateCompanionBuilder = DbAccountsCompanion Function({
  Value<String> id,
  Value<String> email,
  Value<String> displayName,
  Value<String> providerType,
  Value<String> authType,
  Value<int> colorValue,
  Value<String> imapHost,
  Value<int> imapPort,
  Value<bool> imapImplicitTls,
  Value<String> smtpHost,
  Value<int> smtpPort,
  Value<bool> smtpImplicitTls,
  Value<bool> isEnabled,
  Value<int> createdAt,
  Value<int> rowid,
});

final class $$DbAccountsTableReferences
    extends BaseReferences<_$AppDatabase, $DbAccountsTable, DbAccount> {
  $$DbAccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DbFoldersTable, List<DbFolder>>
  _dbFoldersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dbFolders,
    aliasName: 'db_accounts__id__db_folders__account_id',
  );

  $$DbFoldersTableProcessedTableManager get dbFoldersRefs {
    final manager = $$DbFoldersTableTableManager(
      $_db,
      $_db.dbFolders,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dbFoldersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DbEmailsTable, List<DbEmail>> _dbEmailsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.dbEmails,
    aliasName: 'db_accounts__id__db_emails__account_id',
  );

  $$DbEmailsTableProcessedTableManager get dbEmailsRefs {
    final manager = $$DbEmailsTableTableManager(
      $_db,
      $_db.dbEmails,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dbEmailsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DbOutboxMessagesTable, List<DbOutboxMessage>>
  _dbOutboxMessagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dbOutboxMessages,
    aliasName: 'db_accounts__id__db_outbox_messages__account_id',
  );

  $$DbOutboxMessagesTableProcessedTableManager get dbOutboxMessagesRefs {
    final manager = $$DbOutboxMessagesTableTableManager(
      $_db,
      $_db.dbOutboxMessages,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _dbOutboxMessagesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DbAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $DbAccountsTable> {
  $$DbAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authType => $composableBuilder(
    column: $table.authType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imapHost => $composableBuilder(
    column: $table.imapHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imapPort => $composableBuilder(
    column: $table.imapPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get imapImplicitTls => $composableBuilder(
    column: $table.imapImplicitTls,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smtpHost => $composableBuilder(
    column: $table.smtpHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get smtpPort => $composableBuilder(
    column: $table.smtpPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get smtpImplicitTls => $composableBuilder(
    column: $table.smtpImplicitTls,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> dbFoldersRefs(
    Expression<bool> Function($$DbFoldersTableFilterComposer f) f,
  ) {
    final $$DbFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dbFolders,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbFoldersTableFilterComposer(
            $db: $db,
            $table: $db.dbFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dbEmailsRefs(
    Expression<bool> Function($$DbEmailsTableFilterComposer f) f,
  ) {
    final $$DbEmailsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dbEmails,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbEmailsTableFilterComposer(
            $db: $db,
            $table: $db.dbEmails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dbOutboxMessagesRefs(
    Expression<bool> Function($$DbOutboxMessagesTableFilterComposer f) f,
  ) {
    final $$DbOutboxMessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dbOutboxMessages,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbOutboxMessagesTableFilterComposer(
            $db: $db,
            $table: $db.dbOutboxMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DbAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $DbAccountsTable> {
  $$DbAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authType => $composableBuilder(
    column: $table.authType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imapHost => $composableBuilder(
    column: $table.imapHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imapPort => $composableBuilder(
    column: $table.imapPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get imapImplicitTls => $composableBuilder(
    column: $table.imapImplicitTls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpHost => $composableBuilder(
    column: $table.smtpHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get smtpPort => $composableBuilder(
    column: $table.smtpPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get smtpImplicitTls => $composableBuilder(
    column: $table.smtpImplicitTls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbAccountsTable> {
  $$DbAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authType =>
      $composableBuilder(column: $table.authType, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imapHost =>
      $composableBuilder(column: $table.imapHost, builder: (column) => column);

  GeneratedColumn<int> get imapPort =>
      $composableBuilder(column: $table.imapPort, builder: (column) => column);

  GeneratedColumn<bool> get imapImplicitTls => $composableBuilder(
    column: $table.imapImplicitTls,
    builder: (column) => column,
  );

  GeneratedColumn<String> get smtpHost =>
      $composableBuilder(column: $table.smtpHost, builder: (column) => column);

  GeneratedColumn<int> get smtpPort =>
      $composableBuilder(column: $table.smtpPort, builder: (column) => column);

  GeneratedColumn<bool> get smtpImplicitTls => $composableBuilder(
    column: $table.smtpImplicitTls,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> dbFoldersRefs<T extends Object>(
    Expression<T> Function($$DbFoldersTableAnnotationComposer a) f,
  ) {
    final $$DbFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dbFolders,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.dbFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dbEmailsRefs<T extends Object>(
    Expression<T> Function($$DbEmailsTableAnnotationComposer a) f,
  ) {
    final $$DbEmailsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dbEmails,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbEmailsTableAnnotationComposer(
            $db: $db,
            $table: $db.dbEmails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dbOutboxMessagesRefs<T extends Object>(
    Expression<T> Function($$DbOutboxMessagesTableAnnotationComposer a) f,
  ) {
    final $$DbOutboxMessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dbOutboxMessages,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbOutboxMessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.dbOutboxMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DbAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbAccountsTable,
          DbAccount,
          $$DbAccountsTableFilterComposer,
          $$DbAccountsTableOrderingComposer,
          $$DbAccountsTableAnnotationComposer,
          $$DbAccountsTableCreateCompanionBuilder,
          $$DbAccountsTableUpdateCompanionBuilder,
          (DbAccount, $$DbAccountsTableReferences),
          DbAccount,
          PrefetchHooks Function({
            bool dbFoldersRefs,
            bool dbEmailsRefs,
            bool dbOutboxMessagesRefs,
          })
        > {
  $$DbAccountsTableTableManager(_$AppDatabase db, $DbAccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> providerType = const Value.absent(),
                Value<String> authType = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String> imapHost = const Value.absent(),
                Value<int> imapPort = const Value.absent(),
                Value<bool> imapImplicitTls = const Value.absent(),
                Value<String> smtpHost = const Value.absent(),
                Value<int> smtpPort = const Value.absent(),
                Value<bool> smtpImplicitTls = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbAccountsCompanion(
                id: id,
                email: email,
                displayName: displayName,
                providerType: providerType,
                authType: authType,
                colorValue: colorValue,
                imapHost: imapHost,
                imapPort: imapPort,
                imapImplicitTls: imapImplicitTls,
                smtpHost: smtpHost,
                smtpPort: smtpPort,
                smtpImplicitTls: smtpImplicitTls,
                isEnabled: isEnabled,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String email,
                required String displayName,
                required String providerType,
                required String authType,
                required int colorValue,
                required String imapHost,
                required int imapPort,
                required bool imapImplicitTls,
                required String smtpHost,
                required int smtpPort,
                required bool smtpImplicitTls,
                Value<bool> isEnabled = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => DbAccountsCompanion.insert(
                id: id,
                email: email,
                displayName: displayName,
                providerType: providerType,
                authType: authType,
                colorValue: colorValue,
                imapHost: imapHost,
                imapPort: imapPort,
                imapImplicitTls: imapImplicitTls,
                smtpHost: smtpHost,
                smtpPort: smtpPort,
                smtpImplicitTls: smtpImplicitTls,
                isEnabled: isEnabled,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DbAccountsTable, DbAccount>(table),
                  $$DbAccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                dbFoldersRefs = false,
                dbEmailsRefs = false,
                dbOutboxMessagesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (dbFoldersRefs) db.dbFolders,
                    if (dbEmailsRefs) db.dbEmails,
                    if (dbOutboxMessagesRefs) db.dbOutboxMessages,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (dbFoldersRefs)
                        await $_getPrefetchedDataByColumns<
                          DbAccount,
                          $DbAccountsTable,
                          DbFolder,
                          $DbFoldersTable
                        >(
                          currentTable: table,
                          referencedTable: $$DbAccountsTableReferences
                              ._dbFoldersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DbAccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).dbFoldersRefs,
                          currentColumn: 'id',
                          referencedColumn: 'account_id',
                          typedResults: items,
                        ),
                      if (dbEmailsRefs)
                        await $_getPrefetchedDataByColumns<
                          DbAccount,
                          $DbAccountsTable,
                          DbEmail,
                          $DbEmailsTable
                        >(
                          currentTable: table,
                          referencedTable: $$DbAccountsTableReferences
                              ._dbEmailsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DbAccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).dbEmailsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'account_id',
                          typedResults: items,
                        ),
                      if (dbOutboxMessagesRefs)
                        await $_getPrefetchedDataByColumns<
                          DbAccount,
                          $DbAccountsTable,
                          DbOutboxMessage,
                          $DbOutboxMessagesTable
                        >(
                          currentTable: table,
                          referencedTable: $$DbAccountsTableReferences
                              ._dbOutboxMessagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DbAccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).dbOutboxMessagesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'account_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DbAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbAccountsTable,
      DbAccount,
      $$DbAccountsTableFilterComposer,
      $$DbAccountsTableOrderingComposer,
      $$DbAccountsTableAnnotationComposer,
      $$DbAccountsTableCreateCompanionBuilder,
      $$DbAccountsTableUpdateCompanionBuilder,
      (DbAccount, $$DbAccountsTableReferences),
      DbAccount,
      PrefetchHooks Function({
        bool dbFoldersRefs,
        bool dbEmailsRefs,
        bool dbOutboxMessagesRefs,
      })
    >;
typedef $$DbFoldersTableCreateCompanionBuilder = DbFoldersCompanion Function({
  required String id,
  required String accountId,
  required String remoteName,
  required String displayName,
  required String role,
  Value<int?> uidValidity,
  Value<int?> highestModSeq,
  Value<int> unreadCount,
  Value<int?> lastSyncAt,
  Value<int> rowid,
});
typedef $$DbFoldersTableUpdateCompanionBuilder = DbFoldersCompanion Function({
  Value<String> id,
  Value<String> accountId,
  Value<String> remoteName,
  Value<String> displayName,
  Value<String> role,
  Value<int?> uidValidity,
  Value<int?> highestModSeq,
  Value<int> unreadCount,
  Value<int?> lastSyncAt,
  Value<int> rowid,
});

final class $$DbFoldersTableReferences
    extends BaseReferences<_$AppDatabase, $DbFoldersTable, DbFolder> {
  $$DbFoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DbAccountsTable _accountIdTable(_$AppDatabase db) =>
      db.dbAccounts.createAlias('db_folders__account_id__db_accounts__id');

  $$DbAccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$DbAccountsTableTableManager(
      $_db,
      $_db.dbAccounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DbEmailsTable, List<DbEmail>> _dbEmailsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.dbEmails,
    aliasName: 'db_folders__id__db_emails__folder_id',
  );

  $$DbEmailsTableProcessedTableManager get dbEmailsRefs {
    final manager = $$DbEmailsTableTableManager(
      $_db,
      $_db.dbEmails,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dbEmailsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DbFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $DbFoldersTable> {
  $$DbFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteName => $composableBuilder(
    column: $table.remoteName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get highestModSeq => $composableBuilder(
    column: $table.highestModSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DbAccountsTableFilterComposer get accountId {
    final $$DbAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.dbAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbAccountsTableFilterComposer(
            $db: $db,
            $table: $db.dbAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> dbEmailsRefs(
    Expression<bool> Function($$DbEmailsTableFilterComposer f) f,
  ) {
    final $$DbEmailsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dbEmails,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbEmailsTableFilterComposer(
            $db: $db,
            $table: $db.dbEmails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DbFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $DbFoldersTable> {
  $$DbFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteName => $composableBuilder(
    column: $table.remoteName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get highestModSeq => $composableBuilder(
    column: $table.highestModSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DbAccountsTableOrderingComposer get accountId {
    final $$DbAccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.dbAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbAccountsTableOrderingComposer(
            $db: $db,
            $table: $db.dbAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DbFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbFoldersTable> {
  $$DbFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteName => $composableBuilder(
    column: $table.remoteName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get highestModSeq => $composableBuilder(
    column: $table.highestModSeq,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  $$DbAccountsTableAnnotationComposer get accountId {
    final $$DbAccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.dbAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbAccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.dbAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> dbEmailsRefs<T extends Object>(
    Expression<T> Function($$DbEmailsTableAnnotationComposer a) f,
  ) {
    final $$DbEmailsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dbEmails,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbEmailsTableAnnotationComposer(
            $db: $db,
            $table: $db.dbEmails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DbFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbFoldersTable,
          DbFolder,
          $$DbFoldersTableFilterComposer,
          $$DbFoldersTableOrderingComposer,
          $$DbFoldersTableAnnotationComposer,
          $$DbFoldersTableCreateCompanionBuilder,
          $$DbFoldersTableUpdateCompanionBuilder,
          (DbFolder, $$DbFoldersTableReferences),
          DbFolder,
          PrefetchHooks Function({bool accountId, bool dbEmailsRefs})
        > {
  $$DbFoldersTableTableManager(_$AppDatabase db, $DbFoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> remoteName = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<int?> uidValidity = const Value.absent(),
                Value<int?> highestModSeq = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<int?> lastSyncAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbFoldersCompanion(
                id: id,
                accountId: accountId,
                remoteName: remoteName,
                displayName: displayName,
                role: role,
                uidValidity: uidValidity,
                highestModSeq: highestModSeq,
                unreadCount: unreadCount,
                lastSyncAt: lastSyncAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String remoteName,
                required String displayName,
                required String role,
                Value<int?> uidValidity = const Value.absent(),
                Value<int?> highestModSeq = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<int?> lastSyncAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbFoldersCompanion.insert(
                id: id,
                accountId: accountId,
                remoteName: remoteName,
                displayName: displayName,
                role: role,
                uidValidity: uidValidity,
                highestModSeq: highestModSeq,
                unreadCount: unreadCount,
                lastSyncAt: lastSyncAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DbFoldersTable, DbFolder>(table),
                  $$DbFoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false, dbEmailsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (dbEmailsRefs) db.dbEmails],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$DbFoldersTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$DbFoldersTableReferences
                            ._accountIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (dbEmailsRefs)
                    await $_getPrefetchedDataByColumns<
                      DbFolder,
                      $DbFoldersTable,
                      DbEmail,
                      $DbEmailsTable
                    >(
                      currentTable: table,
                      referencedTable: $$DbFoldersTableReferences
                          ._dbEmailsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DbFoldersTableReferences(
                            db,
                            table,
                            p0,
                          ).dbEmailsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'folder_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DbFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbFoldersTable,
      DbFolder,
      $$DbFoldersTableFilterComposer,
      $$DbFoldersTableOrderingComposer,
      $$DbFoldersTableAnnotationComposer,
      $$DbFoldersTableCreateCompanionBuilder,
      $$DbFoldersTableUpdateCompanionBuilder,
      (DbFolder, $$DbFoldersTableReferences),
      DbFolder,
      PrefetchHooks Function({bool accountId, bool dbEmailsRefs})
    >;
typedef $$DbEmailsTableCreateCompanionBuilder = DbEmailsCompanion Function({
  Value<int> localId,
  required String accountId,
  required String folderId,
  required int uid,
  Value<String?> messageId,
  required String subject,
  required String fromName,
  required String fromAddress,
  required String toRecipientsJson,
  required String ccJson,
  required String snippet,
  Value<String?> plainBody,
  Value<String?> htmlBody,
  required int sentAt,
  Value<int> flagsBitmask,
  Value<bool> hasAttachments,
  Value<bool> bodyDownloaded,
});
typedef $$DbEmailsTableUpdateCompanionBuilder = DbEmailsCompanion Function({
  Value<int> localId,
  Value<String> accountId,
  Value<String> folderId,
  Value<int> uid,
  Value<String?> messageId,
  Value<String> subject,
  Value<String> fromName,
  Value<String> fromAddress,
  Value<String> toRecipientsJson,
  Value<String> ccJson,
  Value<String> snippet,
  Value<String?> plainBody,
  Value<String?> htmlBody,
  Value<int> sentAt,
  Value<int> flagsBitmask,
  Value<bool> hasAttachments,
  Value<bool> bodyDownloaded,
});

final class $$DbEmailsTableReferences
    extends BaseReferences<_$AppDatabase, $DbEmailsTable, DbEmail> {
  $$DbEmailsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DbAccountsTable _accountIdTable(_$AppDatabase db) =>
      db.dbAccounts.createAlias('db_emails__account_id__db_accounts__id');

  $$DbAccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$DbAccountsTableTableManager(
      $_db,
      $_db.dbAccounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DbFoldersTable _folderIdTable(_$AppDatabase db) =>
      db.dbFolders.createAlias('db_emails__folder_id__db_folders__id');

  $$DbFoldersTableProcessedTableManager get folderId {
    final $_column = $_itemColumn<String>('folder_id')!;

    final manager = $$DbFoldersTableTableManager(
      $_db,
      $_db.dbFolders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DbAttachmentsTable, List<DbAttachment>>
  _dbAttachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dbAttachments,
    aliasName: 'db_emails__local_id__db_attachments__email_local_id',
  );

  $$DbAttachmentsTableProcessedTableManager get dbAttachmentsRefs {
    final manager = $$DbAttachmentsTableTableManager($_db, $_db.dbAttachments)
        .filter(
          (f) =>
              f.emailLocalId.localId.sqlEquals($_itemColumn<int>('local_id')!),
        );

    final cache = $_typedResult.readTableOrNull(_dbAttachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DbEmailsTableFilterComposer
    extends Composer<_$AppDatabase, $DbEmailsTable> {
  $$DbEmailsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromName => $composableBuilder(
    column: $table.fromName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromAddress => $composableBuilder(
    column: $table.fromAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toRecipientsJson => $composableBuilder(
    column: $table.toRecipientsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ccJson => $composableBuilder(
    column: $table.ccJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snippet => $composableBuilder(
    column: $table.snippet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plainBody => $composableBuilder(
    column: $table.plainBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get htmlBody => $composableBuilder(
    column: $table.htmlBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get flagsBitmask => $composableBuilder(
    column: $table.flagsBitmask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get bodyDownloaded => $composableBuilder(
    column: $table.bodyDownloaded,
    builder: (column) => ColumnFilters(column),
  );

  $$DbAccountsTableFilterComposer get accountId {
    final $$DbAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.dbAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbAccountsTableFilterComposer(
            $db: $db,
            $table: $db.dbAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DbFoldersTableFilterComposer get folderId {
    final $$DbFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.dbFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbFoldersTableFilterComposer(
            $db: $db,
            $table: $db.dbFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> dbAttachmentsRefs(
    Expression<bool> Function($$DbAttachmentsTableFilterComposer f) f,
  ) {
    final $$DbAttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.localId,
      referencedTable: $db.dbAttachments,
      getReferencedColumn: (t) => t.emailLocalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbAttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.dbAttachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DbEmailsTableOrderingComposer
    extends Composer<_$AppDatabase, $DbEmailsTable> {
  $$DbEmailsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromName => $composableBuilder(
    column: $table.fromName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromAddress => $composableBuilder(
    column: $table.fromAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toRecipientsJson => $composableBuilder(
    column: $table.toRecipientsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ccJson => $composableBuilder(
    column: $table.ccJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snippet => $composableBuilder(
    column: $table.snippet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plainBody => $composableBuilder(
    column: $table.plainBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get htmlBody => $composableBuilder(
    column: $table.htmlBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get flagsBitmask => $composableBuilder(
    column: $table.flagsBitmask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get bodyDownloaded => $composableBuilder(
    column: $table.bodyDownloaded,
    builder: (column) => ColumnOrderings(column),
  );

  $$DbAccountsTableOrderingComposer get accountId {
    final $$DbAccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.dbAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbAccountsTableOrderingComposer(
            $db: $db,
            $table: $db.dbAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DbFoldersTableOrderingComposer get folderId {
    final $$DbFoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.dbFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbFoldersTableOrderingComposer(
            $db: $db,
            $table: $db.dbFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DbEmailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbEmailsTable> {
  $$DbEmailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<int> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get fromName =>
      $composableBuilder(column: $table.fromName, builder: (column) => column);

  GeneratedColumn<String> get fromAddress => $composableBuilder(
    column: $table.fromAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toRecipientsJson => $composableBuilder(
    column: $table.toRecipientsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ccJson =>
      $composableBuilder(column: $table.ccJson, builder: (column) => column);

  GeneratedColumn<String> get snippet =>
      $composableBuilder(column: $table.snippet, builder: (column) => column);

  GeneratedColumn<String> get plainBody =>
      $composableBuilder(column: $table.plainBody, builder: (column) => column);

  GeneratedColumn<String> get htmlBody =>
      $composableBuilder(column: $table.htmlBody, builder: (column) => column);

  GeneratedColumn<int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<int> get flagsBitmask => $composableBuilder(
    column: $table.flagsBitmask,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get bodyDownloaded => $composableBuilder(
    column: $table.bodyDownloaded,
    builder: (column) => column,
  );

  $$DbAccountsTableAnnotationComposer get accountId {
    final $$DbAccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.dbAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbAccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.dbAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DbFoldersTableAnnotationComposer get folderId {
    final $$DbFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.dbFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.dbFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> dbAttachmentsRefs<T extends Object>(
    Expression<T> Function($$DbAttachmentsTableAnnotationComposer a) f,
  ) {
    final $$DbAttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.localId,
      referencedTable: $db.dbAttachments,
      getReferencedColumn: (t) => t.emailLocalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbAttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.dbAttachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DbEmailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbEmailsTable,
          DbEmail,
          $$DbEmailsTableFilterComposer,
          $$DbEmailsTableOrderingComposer,
          $$DbEmailsTableAnnotationComposer,
          $$DbEmailsTableCreateCompanionBuilder,
          $$DbEmailsTableUpdateCompanionBuilder,
          (DbEmail, $$DbEmailsTableReferences),
          DbEmail,
          PrefetchHooks Function({
            bool accountId,
            bool folderId,
            bool dbAttachmentsRefs,
          })
        > {
  $$DbEmailsTableTableManager(_$AppDatabase db, $DbEmailsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbEmailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbEmailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbEmailsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> localId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> folderId = const Value.absent(),
                Value<int> uid = const Value.absent(),
                Value<String?> messageId = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> fromName = const Value.absent(),
                Value<String> fromAddress = const Value.absent(),
                Value<String> toRecipientsJson = const Value.absent(),
                Value<String> ccJson = const Value.absent(),
                Value<String> snippet = const Value.absent(),
                Value<String?> plainBody = const Value.absent(),
                Value<String?> htmlBody = const Value.absent(),
                Value<int> sentAt = const Value.absent(),
                Value<int> flagsBitmask = const Value.absent(),
                Value<bool> hasAttachments = const Value.absent(),
                Value<bool> bodyDownloaded = const Value.absent(),
              }) => DbEmailsCompanion(
                localId: localId,
                accountId: accountId,
                folderId: folderId,
                uid: uid,
                messageId: messageId,
                subject: subject,
                fromName: fromName,
                fromAddress: fromAddress,
                toRecipientsJson: toRecipientsJson,
                ccJson: ccJson,
                snippet: snippet,
                plainBody: plainBody,
                htmlBody: htmlBody,
                sentAt: sentAt,
                flagsBitmask: flagsBitmask,
                hasAttachments: hasAttachments,
                bodyDownloaded: bodyDownloaded,
              ),
          createCompanionCallback:
              ({
                Value<int> localId = const Value.absent(),
                required String accountId,
                required String folderId,
                required int uid,
                Value<String?> messageId = const Value.absent(),
                required String subject,
                required String fromName,
                required String fromAddress,
                required String toRecipientsJson,
                required String ccJson,
                required String snippet,
                Value<String?> plainBody = const Value.absent(),
                Value<String?> htmlBody = const Value.absent(),
                required int sentAt,
                Value<int> flagsBitmask = const Value.absent(),
                Value<bool> hasAttachments = const Value.absent(),
                Value<bool> bodyDownloaded = const Value.absent(),
              }) => DbEmailsCompanion.insert(
                localId: localId,
                accountId: accountId,
                folderId: folderId,
                uid: uid,
                messageId: messageId,
                subject: subject,
                fromName: fromName,
                fromAddress: fromAddress,
                toRecipientsJson: toRecipientsJson,
                ccJson: ccJson,
                snippet: snippet,
                plainBody: plainBody,
                htmlBody: htmlBody,
                sentAt: sentAt,
                flagsBitmask: flagsBitmask,
                hasAttachments: hasAttachments,
                bodyDownloaded: bodyDownloaded,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DbEmailsTable, DbEmail>(table),
                  $$DbEmailsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                folderId = false,
                dbAttachmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (dbAttachmentsRefs) db.dbAttachments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.accountId,
                            referencedTable: $$DbEmailsTableReferences
                                ._accountIdTable(db),
                            referencedColumn: $$DbEmailsTableReferences
                                ._accountIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (folderId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.folderId,
                            referencedTable: $$DbEmailsTableReferences
                                ._folderIdTable(db),
                            referencedColumn: $$DbEmailsTableReferences
                                ._folderIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (dbAttachmentsRefs)
                        await $_getPrefetchedDataByColumns<
                          DbEmail,
                          $DbEmailsTable,
                          DbAttachment,
                          $DbAttachmentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$DbEmailsTableReferences
                              ._dbAttachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DbEmailsTableReferences(
                                db,
                                table,
                                p0,
                              ).dbAttachmentsRefs,
                          currentColumn: 'local_id',
                          referencedColumn: 'email_local_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DbEmailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbEmailsTable,
      DbEmail,
      $$DbEmailsTableFilterComposer,
      $$DbEmailsTableOrderingComposer,
      $$DbEmailsTableAnnotationComposer,
      $$DbEmailsTableCreateCompanionBuilder,
      $$DbEmailsTableUpdateCompanionBuilder,
      (DbEmail, $$DbEmailsTableReferences),
      DbEmail,
      PrefetchHooks Function({
        bool accountId,
        bool folderId,
        bool dbAttachmentsRefs,
      })
    >;
typedef $$DbAttachmentsTableCreateCompanionBuilder =
    DbAttachmentsCompanion Function({
      required String id,
      required int emailLocalId,
      required String partId,
      Value<String?> contentId,
      required String filename,
      required String mimeType,
      required int sizeBytes,
      Value<String?> localCachePath,
      Value<bool> isInline,
      Value<int> rowid,
    });
typedef $$DbAttachmentsTableUpdateCompanionBuilder =
    DbAttachmentsCompanion Function({
      Value<String> id,
      Value<int> emailLocalId,
      Value<String> partId,
      Value<String?> contentId,
      Value<String> filename,
      Value<String> mimeType,
      Value<int> sizeBytes,
      Value<String?> localCachePath,
      Value<bool> isInline,
      Value<int> rowid,
    });

final class $$DbAttachmentsTableReferences
    extends BaseReferences<_$AppDatabase, $DbAttachmentsTable, DbAttachment> {
  $$DbAttachmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DbEmailsTable _emailLocalIdTable(_$AppDatabase db) => db.dbEmails
      .createAlias('db_attachments__email_local_id__db_emails__local_id');

  $$DbEmailsTableProcessedTableManager get emailLocalId {
    final $_column = $_itemColumn<int>('email_local_id')!;

    final manager = $$DbEmailsTableTableManager(
      $_db,
      $_db.dbEmails,
    ).filter((f) => f.localId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_emailLocalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DbAttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $DbAttachmentsTable> {
  $$DbAttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localCachePath => $composableBuilder(
    column: $table.localCachePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInline => $composableBuilder(
    column: $table.isInline,
    builder: (column) => ColumnFilters(column),
  );

  $$DbEmailsTableFilterComposer get emailLocalId {
    final $$DbEmailsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.emailLocalId,
      referencedTable: $db.dbEmails,
      getReferencedColumn: (t) => t.localId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbEmailsTableFilterComposer(
            $db: $db,
            $table: $db.dbEmails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DbAttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DbAttachmentsTable> {
  $$DbAttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localCachePath => $composableBuilder(
    column: $table.localCachePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInline => $composableBuilder(
    column: $table.isInline,
    builder: (column) => ColumnOrderings(column),
  );

  $$DbEmailsTableOrderingComposer get emailLocalId {
    final $$DbEmailsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.emailLocalId,
      referencedTable: $db.dbEmails,
      getReferencedColumn: (t) => t.localId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbEmailsTableOrderingComposer(
            $db: $db,
            $table: $db.dbEmails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DbAttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbAttachmentsTable> {
  $$DbAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get partId =>
      $composableBuilder(column: $table.partId, builder: (column) => column);

  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get localCachePath => $composableBuilder(
    column: $table.localCachePath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isInline =>
      $composableBuilder(column: $table.isInline, builder: (column) => column);

  $$DbEmailsTableAnnotationComposer get emailLocalId {
    final $$DbEmailsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.emailLocalId,
      referencedTable: $db.dbEmails,
      getReferencedColumn: (t) => t.localId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbEmailsTableAnnotationComposer(
            $db: $db,
            $table: $db.dbEmails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DbAttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbAttachmentsTable,
          DbAttachment,
          $$DbAttachmentsTableFilterComposer,
          $$DbAttachmentsTableOrderingComposer,
          $$DbAttachmentsTableAnnotationComposer,
          $$DbAttachmentsTableCreateCompanionBuilder,
          $$DbAttachmentsTableUpdateCompanionBuilder,
          (DbAttachment, $$DbAttachmentsTableReferences),
          DbAttachment,
          PrefetchHooks Function({bool emailLocalId})
        > {
  $$DbAttachmentsTableTableManager(_$AppDatabase db, $DbAttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbAttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbAttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbAttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> emailLocalId = const Value.absent(),
                Value<String> partId = const Value.absent(),
                Value<String?> contentId = const Value.absent(),
                Value<String> filename = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String?> localCachePath = const Value.absent(),
                Value<bool> isInline = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbAttachmentsCompanion(
                id: id,
                emailLocalId: emailLocalId,
                partId: partId,
                contentId: contentId,
                filename: filename,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                localCachePath: localCachePath,
                isInline: isInline,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int emailLocalId,
                required String partId,
                Value<String?> contentId = const Value.absent(),
                required String filename,
                required String mimeType,
                required int sizeBytes,
                Value<String?> localCachePath = const Value.absent(),
                Value<bool> isInline = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbAttachmentsCompanion.insert(
                id: id,
                emailLocalId: emailLocalId,
                partId: partId,
                contentId: contentId,
                filename: filename,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                localCachePath: localCachePath,
                isInline: isInline,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DbAttachmentsTable, DbAttachment>(table),
                  $$DbAttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({emailLocalId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (emailLocalId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.emailLocalId,
                        referencedTable: $$DbAttachmentsTableReferences
                            ._emailLocalIdTable(db),
                        referencedColumn: $$DbAttachmentsTableReferences
                            ._emailLocalIdTable(db)
                            .localId,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DbAttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbAttachmentsTable,
      DbAttachment,
      $$DbAttachmentsTableFilterComposer,
      $$DbAttachmentsTableOrderingComposer,
      $$DbAttachmentsTableAnnotationComposer,
      $$DbAttachmentsTableCreateCompanionBuilder,
      $$DbAttachmentsTableUpdateCompanionBuilder,
      (DbAttachment, $$DbAttachmentsTableReferences),
      DbAttachment,
      PrefetchHooks Function({bool emailLocalId})
    >;
typedef $$DbTrustedSendersTableCreateCompanionBuilder =
    DbTrustedSendersCompanion Function({
      required String senderEmail,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$DbTrustedSendersTableUpdateCompanionBuilder =
    DbTrustedSendersCompanion Function({
      Value<String> senderEmail,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$DbTrustedSendersTableFilterComposer
    extends Composer<_$AppDatabase, $DbTrustedSendersTable> {
  $$DbTrustedSendersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get senderEmail => $composableBuilder(
    column: $table.senderEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbTrustedSendersTableOrderingComposer
    extends Composer<_$AppDatabase, $DbTrustedSendersTable> {
  $$DbTrustedSendersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get senderEmail => $composableBuilder(
    column: $table.senderEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbTrustedSendersTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbTrustedSendersTable> {
  $$DbTrustedSendersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get senderEmail => $composableBuilder(
    column: $table.senderEmail,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DbTrustedSendersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbTrustedSendersTable,
          DbTrustedSender,
          $$DbTrustedSendersTableFilterComposer,
          $$DbTrustedSendersTableOrderingComposer,
          $$DbTrustedSendersTableAnnotationComposer,
          $$DbTrustedSendersTableCreateCompanionBuilder,
          $$DbTrustedSendersTableUpdateCompanionBuilder,
          (
            DbTrustedSender,
            BaseReferences<
              _$AppDatabase,
              $DbTrustedSendersTable,
              DbTrustedSender
            >,
          ),
          DbTrustedSender,
          PrefetchHooks Function()
        > {
  $$DbTrustedSendersTableTableManager(
    _$AppDatabase db,
    $DbTrustedSendersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbTrustedSendersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbTrustedSendersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbTrustedSendersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> senderEmail = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbTrustedSendersCompanion(
                senderEmail: senderEmail,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String senderEmail,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => DbTrustedSendersCompanion.insert(
                senderEmail: senderEmail,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DbTrustedSendersTable, DbTrustedSender>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DbTrustedSendersTable,
                    DbTrustedSender
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbTrustedSendersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbTrustedSendersTable,
      DbTrustedSender,
      $$DbTrustedSendersTableFilterComposer,
      $$DbTrustedSendersTableOrderingComposer,
      $$DbTrustedSendersTableAnnotationComposer,
      $$DbTrustedSendersTableCreateCompanionBuilder,
      $$DbTrustedSendersTableUpdateCompanionBuilder,
      (
        DbTrustedSender,
        BaseReferences<_$AppDatabase, $DbTrustedSendersTable, DbTrustedSender>,
      ),
      DbTrustedSender,
      PrefetchHooks Function()
    >;
typedef $$DbOutboxMessagesTableCreateCompanionBuilder =
    DbOutboxMessagesCompanion Function({
      required String id,
      required String accountId,
      required String mode,
      Value<int?> originEmailLocalId,
      Value<String?> inReplyTo,
      Value<String?> referencesHeader,
      required String toRecipientsJson,
      required String ccJson,
      required String bccJson,
      required String subject,
      Value<String?> outgoingMessageId,
      required String plainBody,
      Value<String?> htmlBody,
      required String attachmentsJson,
      required String status,
      Value<int> retryCount,
      Value<bool> retryable,
      Value<int?> nextRetryAt,
      Value<String?> lastError,
      required int createdAt,
      required int updatedAt,
      Value<int?> sentAt,
      Value<int> rowid,
    });
typedef $$DbOutboxMessagesTableUpdateCompanionBuilder =
    DbOutboxMessagesCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> mode,
      Value<int?> originEmailLocalId,
      Value<String?> inReplyTo,
      Value<String?> referencesHeader,
      Value<String> toRecipientsJson,
      Value<String> ccJson,
      Value<String> bccJson,
      Value<String> subject,
      Value<String?> outgoingMessageId,
      Value<String> plainBody,
      Value<String?> htmlBody,
      Value<String> attachmentsJson,
      Value<String> status,
      Value<int> retryCount,
      Value<bool> retryable,
      Value<int?> nextRetryAt,
      Value<String?> lastError,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> sentAt,
      Value<int> rowid,
    });

final class $$DbOutboxMessagesTableReferences
    extends
        BaseReferences<_$AppDatabase, $DbOutboxMessagesTable, DbOutboxMessage> {
  $$DbOutboxMessagesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DbAccountsTable _accountIdTable(_$AppDatabase db) => db.dbAccounts
      .createAlias('db_outbox_messages__account_id__db_accounts__id');

  $$DbAccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$DbAccountsTableTableManager(
      $_db,
      $_db.dbAccounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DbOutboxMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $DbOutboxMessagesTable> {
  $$DbOutboxMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originEmailLocalId => $composableBuilder(
    column: $table.originEmailLocalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inReplyTo => $composableBuilder(
    column: $table.inReplyTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referencesHeader => $composableBuilder(
    column: $table.referencesHeader,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toRecipientsJson => $composableBuilder(
    column: $table.toRecipientsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ccJson => $composableBuilder(
    column: $table.ccJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bccJson => $composableBuilder(
    column: $table.bccJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outgoingMessageId => $composableBuilder(
    column: $table.outgoingMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plainBody => $composableBuilder(
    column: $table.plainBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get htmlBody => $composableBuilder(
    column: $table.htmlBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get retryable => $composableBuilder(
    column: $table.retryable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DbAccountsTableFilterComposer get accountId {
    final $$DbAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.dbAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbAccountsTableFilterComposer(
            $db: $db,
            $table: $db.dbAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DbOutboxMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $DbOutboxMessagesTable> {
  $$DbOutboxMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originEmailLocalId => $composableBuilder(
    column: $table.originEmailLocalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inReplyTo => $composableBuilder(
    column: $table.inReplyTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referencesHeader => $composableBuilder(
    column: $table.referencesHeader,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toRecipientsJson => $composableBuilder(
    column: $table.toRecipientsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ccJson => $composableBuilder(
    column: $table.ccJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bccJson => $composableBuilder(
    column: $table.bccJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outgoingMessageId => $composableBuilder(
    column: $table.outgoingMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plainBody => $composableBuilder(
    column: $table.plainBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get htmlBody => $composableBuilder(
    column: $table.htmlBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get retryable => $composableBuilder(
    column: $table.retryable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DbAccountsTableOrderingComposer get accountId {
    final $$DbAccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.dbAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbAccountsTableOrderingComposer(
            $db: $db,
            $table: $db.dbAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DbOutboxMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbOutboxMessagesTable> {
  $$DbOutboxMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get originEmailLocalId => $composableBuilder(
    column: $table.originEmailLocalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inReplyTo =>
      $composableBuilder(column: $table.inReplyTo, builder: (column) => column);

  GeneratedColumn<String> get referencesHeader => $composableBuilder(
    column: $table.referencesHeader,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toRecipientsJson => $composableBuilder(
    column: $table.toRecipientsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ccJson =>
      $composableBuilder(column: $table.ccJson, builder: (column) => column);

  GeneratedColumn<String> get bccJson =>
      $composableBuilder(column: $table.bccJson, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get outgoingMessageId => $composableBuilder(
    column: $table.outgoingMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plainBody =>
      $composableBuilder(column: $table.plainBody, builder: (column) => column);

  GeneratedColumn<String> get htmlBody =>
      $composableBuilder(column: $table.htmlBody, builder: (column) => column);

  GeneratedColumn<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get retryable =>
      $composableBuilder(column: $table.retryable, builder: (column) => column);

  GeneratedColumn<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  $$DbAccountsTableAnnotationComposer get accountId {
    final $$DbAccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.dbAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DbAccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.dbAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DbOutboxMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbOutboxMessagesTable,
          DbOutboxMessage,
          $$DbOutboxMessagesTableFilterComposer,
          $$DbOutboxMessagesTableOrderingComposer,
          $$DbOutboxMessagesTableAnnotationComposer,
          $$DbOutboxMessagesTableCreateCompanionBuilder,
          $$DbOutboxMessagesTableUpdateCompanionBuilder,
          (DbOutboxMessage, $$DbOutboxMessagesTableReferences),
          DbOutboxMessage,
          PrefetchHooks Function({bool accountId})
        > {
  $$DbOutboxMessagesTableTableManager(
    _$AppDatabase db,
    $DbOutboxMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbOutboxMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbOutboxMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbOutboxMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int?> originEmailLocalId = const Value.absent(),
                Value<String?> inReplyTo = const Value.absent(),
                Value<String?> referencesHeader = const Value.absent(),
                Value<String> toRecipientsJson = const Value.absent(),
                Value<String> ccJson = const Value.absent(),
                Value<String> bccJson = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String?> outgoingMessageId = const Value.absent(),
                Value<String> plainBody = const Value.absent(),
                Value<String?> htmlBody = const Value.absent(),
                Value<String> attachmentsJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<bool> retryable = const Value.absent(),
                Value<int?> nextRetryAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> sentAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbOutboxMessagesCompanion(
                id: id,
                accountId: accountId,
                mode: mode,
                originEmailLocalId: originEmailLocalId,
                inReplyTo: inReplyTo,
                referencesHeader: referencesHeader,
                toRecipientsJson: toRecipientsJson,
                ccJson: ccJson,
                bccJson: bccJson,
                subject: subject,
                outgoingMessageId: outgoingMessageId,
                plainBody: plainBody,
                htmlBody: htmlBody,
                attachmentsJson: attachmentsJson,
                status: status,
                retryCount: retryCount,
                retryable: retryable,
                nextRetryAt: nextRetryAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                sentAt: sentAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String mode,
                Value<int?> originEmailLocalId = const Value.absent(),
                Value<String?> inReplyTo = const Value.absent(),
                Value<String?> referencesHeader = const Value.absent(),
                required String toRecipientsJson,
                required String ccJson,
                required String bccJson,
                required String subject,
                Value<String?> outgoingMessageId = const Value.absent(),
                required String plainBody,
                Value<String?> htmlBody = const Value.absent(),
                required String attachmentsJson,
                required String status,
                Value<int> retryCount = const Value.absent(),
                Value<bool> retryable = const Value.absent(),
                Value<int?> nextRetryAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> sentAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbOutboxMessagesCompanion.insert(
                id: id,
                accountId: accountId,
                mode: mode,
                originEmailLocalId: originEmailLocalId,
                inReplyTo: inReplyTo,
                referencesHeader: referencesHeader,
                toRecipientsJson: toRecipientsJson,
                ccJson: ccJson,
                bccJson: bccJson,
                subject: subject,
                outgoingMessageId: outgoingMessageId,
                plainBody: plainBody,
                htmlBody: htmlBody,
                attachmentsJson: attachmentsJson,
                status: status,
                retryCount: retryCount,
                retryable: retryable,
                nextRetryAt: nextRetryAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                sentAt: sentAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DbOutboxMessagesTable, DbOutboxMessage>(table),
                  $$DbOutboxMessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$DbOutboxMessagesTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$DbOutboxMessagesTableReferences
                            ._accountIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DbOutboxMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbOutboxMessagesTable,
      DbOutboxMessage,
      $$DbOutboxMessagesTableFilterComposer,
      $$DbOutboxMessagesTableOrderingComposer,
      $$DbOutboxMessagesTableAnnotationComposer,
      $$DbOutboxMessagesTableCreateCompanionBuilder,
      $$DbOutboxMessagesTableUpdateCompanionBuilder,
      (DbOutboxMessage, $$DbOutboxMessagesTableReferences),
      DbOutboxMessage,
      PrefetchHooks Function({bool accountId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DbAccountsTableTableManager get dbAccounts =>
      $$DbAccountsTableTableManager(_db, _db.dbAccounts);
  $$DbFoldersTableTableManager get dbFolders =>
      $$DbFoldersTableTableManager(_db, _db.dbFolders);
  $$DbEmailsTableTableManager get dbEmails =>
      $$DbEmailsTableTableManager(_db, _db.dbEmails);
  $$DbAttachmentsTableTableManager get dbAttachments =>
      $$DbAttachmentsTableTableManager(_db, _db.dbAttachments);
  $$DbTrustedSendersTableTableManager get dbTrustedSenders =>
      $$DbTrustedSendersTableTableManager(_db, _db.dbTrustedSenders);
  $$DbOutboxMessagesTableTableManager get dbOutboxMessages =>
      $$DbOutboxMessagesTableTableManager(_db, _db.dbOutboxMessages);
}
