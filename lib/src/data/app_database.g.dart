// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DownloadEntriesTable extends DownloadEntries
    with TableInfo<$DownloadEntriesTable, DownloadEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<String> gid = GeneratedColumn<String>(
    'gid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directoryMeta = const VerificationMeta(
    'directory',
  );
  @override
  late final GeneratedColumn<String> directory = GeneratedColumn<String>(
    'directory',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentUriMeta = const VerificationMeta(
    'contentUri',
  );
  @override
  late final GeneratedColumn<String> contentUri = GeneratedColumn<String>(
    'content_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _queuePositionMeta = const VerificationMeta(
    'queuePosition',
  );
  @override
  late final GeneratedColumn<int> queuePosition = GeneratedColumn<int>(
    'queue_position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalLengthMeta = const VerificationMeta(
    'totalLength',
  );
  @override
  late final GeneratedColumn<int> totalLength = GeneratedColumn<int>(
    'total_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedLengthMeta = const VerificationMeta(
    'completedLength',
  );
  @override
  late final GeneratedColumn<int> completedLength = GeneratedColumn<int>(
    'completed_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _downloadSpeedMeta = const VerificationMeta(
    'downloadSpeed',
  );
  @override
  late final GeneratedColumn<int> downloadSpeed = GeneratedColumn<int>(
    'download_speed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _uploadSpeedMeta = const VerificationMeta(
    'uploadSpeed',
  );
  @override
  late final GeneratedColumn<int> uploadSpeed = GeneratedColumn<int>(
    'upload_speed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _connectionsMeta = const VerificationMeta(
    'connections',
  );
  @override
  late final GeneratedColumn<int> connections = GeneratedColumn<int>(
    'connections',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _splitMeta = const VerificationMeta('split');
  @override
  late final GeneratedColumn<int> split = GeneratedColumn<int>(
    'split',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(16),
  );
  static const VerificationMeta _pieceLengthMeta = const VerificationMeta(
    'pieceLength',
  );
  @override
  late final GeneratedColumn<int> pieceLength = GeneratedColumn<int>(
    'piece_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _numPiecesMeta = const VerificationMeta(
    'numPieces',
  );
  @override
  late final GeneratedColumn<int> numPieces = GeneratedColumn<int>(
    'num_pieces',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bitfieldMeta = const VerificationMeta(
    'bitfield',
  );
  @override
  late final GeneratedColumn<String> bitfield = GeneratedColumn<String>(
    'bitfield',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aria2ErrorCodeMeta = const VerificationMeta(
    'aria2ErrorCode',
  );
  @override
  late final GeneratedColumn<int> aria2ErrorCode = GeneratedColumn<int>(
    'aria2_error_code',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _optionsJsonMeta = const VerificationMeta(
    'optionsJson',
  );
  @override
  late final GeneratedColumn<String> optionsJson = GeneratedColumn<String>(
    'options_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    gid,
    url,
    fileName,
    directory,
    contentUri,
    displayName,
    status,
    queuePosition,
    totalLength,
    completedLength,
    downloadSpeed,
    uploadSpeed,
    connections,
    split,
    pieceLength,
    numPieces,
    bitfield,
    aria2ErrorCode,
    error,
    source,
    optionsJson,
    createdAt,
    updatedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('gid')) {
      context.handle(
        _gidMeta,
        gid.isAcceptableOrUnknown(data['gid']!, _gidMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    }
    if (data.containsKey('directory')) {
      context.handle(
        _directoryMeta,
        directory.isAcceptableOrUnknown(data['directory']!, _directoryMeta),
      );
    } else if (isInserting) {
      context.missing(_directoryMeta);
    }
    if (data.containsKey('content_uri')) {
      context.handle(
        _contentUriMeta,
        contentUri.isAcceptableOrUnknown(data['content_uri']!, _contentUriMeta),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('queue_position')) {
      context.handle(
        _queuePositionMeta,
        queuePosition.isAcceptableOrUnknown(
          data['queue_position']!,
          _queuePositionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_queuePositionMeta);
    }
    if (data.containsKey('total_length')) {
      context.handle(
        _totalLengthMeta,
        totalLength.isAcceptableOrUnknown(
          data['total_length']!,
          _totalLengthMeta,
        ),
      );
    }
    if (data.containsKey('completed_length')) {
      context.handle(
        _completedLengthMeta,
        completedLength.isAcceptableOrUnknown(
          data['completed_length']!,
          _completedLengthMeta,
        ),
      );
    }
    if (data.containsKey('download_speed')) {
      context.handle(
        _downloadSpeedMeta,
        downloadSpeed.isAcceptableOrUnknown(
          data['download_speed']!,
          _downloadSpeedMeta,
        ),
      );
    }
    if (data.containsKey('upload_speed')) {
      context.handle(
        _uploadSpeedMeta,
        uploadSpeed.isAcceptableOrUnknown(
          data['upload_speed']!,
          _uploadSpeedMeta,
        ),
      );
    }
    if (data.containsKey('connections')) {
      context.handle(
        _connectionsMeta,
        connections.isAcceptableOrUnknown(
          data['connections']!,
          _connectionsMeta,
        ),
      );
    }
    if (data.containsKey('split')) {
      context.handle(
        _splitMeta,
        split.isAcceptableOrUnknown(data['split']!, _splitMeta),
      );
    }
    if (data.containsKey('piece_length')) {
      context.handle(
        _pieceLengthMeta,
        pieceLength.isAcceptableOrUnknown(
          data['piece_length']!,
          _pieceLengthMeta,
        ),
      );
    }
    if (data.containsKey('num_pieces')) {
      context.handle(
        _numPiecesMeta,
        numPieces.isAcceptableOrUnknown(data['num_pieces']!, _numPiecesMeta),
      );
    }
    if (data.containsKey('bitfield')) {
      context.handle(
        _bitfieldMeta,
        bitfield.isAcceptableOrUnknown(data['bitfield']!, _bitfieldMeta),
      );
    }
    if (data.containsKey('aria2_error_code')) {
      context.handle(
        _aria2ErrorCodeMeta,
        aria2ErrorCode.isAcceptableOrUnknown(
          data['aria2_error_code']!,
          _aria2ErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('options_json')) {
      context.handle(
        _optionsJsonMeta,
        optionsJson.isAcceptableOrUnknown(
          data['options_json']!,
          _optionsJsonMeta,
        ),
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
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      gid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gid'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      ),
      directory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}directory'],
      )!,
      contentUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_uri'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      queuePosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}queue_position'],
      )!,
      totalLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_length'],
      )!,
      completedLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_length'],
      )!,
      downloadSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download_speed'],
      )!,
      uploadSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}upload_speed'],
      )!,
      connections: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}connections'],
      )!,
      split: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}split'],
      )!,
      pieceLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}piece_length'],
      )!,
      numPieces: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}num_pieces'],
      )!,
      bitfield: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bitfield'],
      ),
      aria2ErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}aria2_error_code'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      optionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadEntriesTable createAlias(String alias) {
    return $DownloadEntriesTable(attachedDatabase, alias);
  }
}

class DownloadEntity extends DataClass implements Insertable<DownloadEntity> {
  final String id;
  final String? gid;
  final String url;
  final String? fileName;
  final String directory;
  final String? contentUri;
  final String? displayName;
  final String status;
  final int queuePosition;
  final int totalLength;
  final int completedLength;
  final int downloadSpeed;
  final int uploadSpeed;
  final int connections;
  final int split;
  final int pieceLength;
  final int numPieces;
  final String? bitfield;
  final int? aria2ErrorCode;
  final String? error;
  final String source;
  final String? optionsJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  const DownloadEntity({
    required this.id,
    this.gid,
    required this.url,
    this.fileName,
    required this.directory,
    this.contentUri,
    this.displayName,
    required this.status,
    required this.queuePosition,
    required this.totalLength,
    required this.completedLength,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.connections,
    required this.split,
    required this.pieceLength,
    required this.numPieces,
    this.bitfield,
    this.aria2ErrorCode,
    this.error,
    required this.source,
    this.optionsJson,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || gid != null) {
      map['gid'] = Variable<String>(gid);
    }
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || fileName != null) {
      map['file_name'] = Variable<String>(fileName);
    }
    map['directory'] = Variable<String>(directory);
    if (!nullToAbsent || contentUri != null) {
      map['content_uri'] = Variable<String>(contentUri);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['status'] = Variable<String>(status);
    map['queue_position'] = Variable<int>(queuePosition);
    map['total_length'] = Variable<int>(totalLength);
    map['completed_length'] = Variable<int>(completedLength);
    map['download_speed'] = Variable<int>(downloadSpeed);
    map['upload_speed'] = Variable<int>(uploadSpeed);
    map['connections'] = Variable<int>(connections);
    map['split'] = Variable<int>(split);
    map['piece_length'] = Variable<int>(pieceLength);
    map['num_pieces'] = Variable<int>(numPieces);
    if (!nullToAbsent || bitfield != null) {
      map['bitfield'] = Variable<String>(bitfield);
    }
    if (!nullToAbsent || aria2ErrorCode != null) {
      map['aria2_error_code'] = Variable<int>(aria2ErrorCode);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || optionsJson != null) {
      map['options_json'] = Variable<String>(optionsJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadEntriesCompanion toCompanion(bool nullToAbsent) {
    return DownloadEntriesCompanion(
      id: Value(id),
      gid: gid == null && nullToAbsent ? const Value.absent() : Value(gid),
      url: Value(url),
      fileName: fileName == null && nullToAbsent
          ? const Value.absent()
          : Value(fileName),
      directory: Value(directory),
      contentUri: contentUri == null && nullToAbsent
          ? const Value.absent()
          : Value(contentUri),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      status: Value(status),
      queuePosition: Value(queuePosition),
      totalLength: Value(totalLength),
      completedLength: Value(completedLength),
      downloadSpeed: Value(downloadSpeed),
      uploadSpeed: Value(uploadSpeed),
      connections: Value(connections),
      split: Value(split),
      pieceLength: Value(pieceLength),
      numPieces: Value(numPieces),
      bitfield: bitfield == null && nullToAbsent
          ? const Value.absent()
          : Value(bitfield),
      aria2ErrorCode: aria2ErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(aria2ErrorCode),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      source: Value(source),
      optionsJson: optionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(optionsJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DownloadEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadEntity(
      id: serializer.fromJson<String>(json['id']),
      gid: serializer.fromJson<String?>(json['gid']),
      url: serializer.fromJson<String>(json['url']),
      fileName: serializer.fromJson<String?>(json['fileName']),
      directory: serializer.fromJson<String>(json['directory']),
      contentUri: serializer.fromJson<String?>(json['contentUri']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      status: serializer.fromJson<String>(json['status']),
      queuePosition: serializer.fromJson<int>(json['queuePosition']),
      totalLength: serializer.fromJson<int>(json['totalLength']),
      completedLength: serializer.fromJson<int>(json['completedLength']),
      downloadSpeed: serializer.fromJson<int>(json['downloadSpeed']),
      uploadSpeed: serializer.fromJson<int>(json['uploadSpeed']),
      connections: serializer.fromJson<int>(json['connections']),
      split: serializer.fromJson<int>(json['split']),
      pieceLength: serializer.fromJson<int>(json['pieceLength']),
      numPieces: serializer.fromJson<int>(json['numPieces']),
      bitfield: serializer.fromJson<String?>(json['bitfield']),
      aria2ErrorCode: serializer.fromJson<int?>(json['aria2ErrorCode']),
      error: serializer.fromJson<String?>(json['error']),
      source: serializer.fromJson<String>(json['source']),
      optionsJson: serializer.fromJson<String?>(json['optionsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'gid': serializer.toJson<String?>(gid),
      'url': serializer.toJson<String>(url),
      'fileName': serializer.toJson<String?>(fileName),
      'directory': serializer.toJson<String>(directory),
      'contentUri': serializer.toJson<String?>(contentUri),
      'displayName': serializer.toJson<String?>(displayName),
      'status': serializer.toJson<String>(status),
      'queuePosition': serializer.toJson<int>(queuePosition),
      'totalLength': serializer.toJson<int>(totalLength),
      'completedLength': serializer.toJson<int>(completedLength),
      'downloadSpeed': serializer.toJson<int>(downloadSpeed),
      'uploadSpeed': serializer.toJson<int>(uploadSpeed),
      'connections': serializer.toJson<int>(connections),
      'split': serializer.toJson<int>(split),
      'pieceLength': serializer.toJson<int>(pieceLength),
      'numPieces': serializer.toJson<int>(numPieces),
      'bitfield': serializer.toJson<String?>(bitfield),
      'aria2ErrorCode': serializer.toJson<int?>(aria2ErrorCode),
      'error': serializer.toJson<String?>(error),
      'source': serializer.toJson<String>(source),
      'optionsJson': serializer.toJson<String?>(optionsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  DownloadEntity copyWith({
    String? id,
    Value<String?> gid = const Value.absent(),
    String? url,
    Value<String?> fileName = const Value.absent(),
    String? directory,
    Value<String?> contentUri = const Value.absent(),
    Value<String?> displayName = const Value.absent(),
    String? status,
    int? queuePosition,
    int? totalLength,
    int? completedLength,
    int? downloadSpeed,
    int? uploadSpeed,
    int? connections,
    int? split,
    int? pieceLength,
    int? numPieces,
    Value<String?> bitfield = const Value.absent(),
    Value<int?> aria2ErrorCode = const Value.absent(),
    Value<String?> error = const Value.absent(),
    String? source,
    Value<String?> optionsJson = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => DownloadEntity(
    id: id ?? this.id,
    gid: gid.present ? gid.value : this.gid,
    url: url ?? this.url,
    fileName: fileName.present ? fileName.value : this.fileName,
    directory: directory ?? this.directory,
    contentUri: contentUri.present ? contentUri.value : this.contentUri,
    displayName: displayName.present ? displayName.value : this.displayName,
    status: status ?? this.status,
    queuePosition: queuePosition ?? this.queuePosition,
    totalLength: totalLength ?? this.totalLength,
    completedLength: completedLength ?? this.completedLength,
    downloadSpeed: downloadSpeed ?? this.downloadSpeed,
    uploadSpeed: uploadSpeed ?? this.uploadSpeed,
    connections: connections ?? this.connections,
    split: split ?? this.split,
    pieceLength: pieceLength ?? this.pieceLength,
    numPieces: numPieces ?? this.numPieces,
    bitfield: bitfield.present ? bitfield.value : this.bitfield,
    aria2ErrorCode: aria2ErrorCode.present
        ? aria2ErrorCode.value
        : this.aria2ErrorCode,
    error: error.present ? error.value : this.error,
    source: source ?? this.source,
    optionsJson: optionsJson.present ? optionsJson.value : this.optionsJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DownloadEntity copyWithCompanion(DownloadEntriesCompanion data) {
    return DownloadEntity(
      id: data.id.present ? data.id.value : this.id,
      gid: data.gid.present ? data.gid.value : this.gid,
      url: data.url.present ? data.url.value : this.url,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      directory: data.directory.present ? data.directory.value : this.directory,
      contentUri: data.contentUri.present
          ? data.contentUri.value
          : this.contentUri,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      status: data.status.present ? data.status.value : this.status,
      queuePosition: data.queuePosition.present
          ? data.queuePosition.value
          : this.queuePosition,
      totalLength: data.totalLength.present
          ? data.totalLength.value
          : this.totalLength,
      completedLength: data.completedLength.present
          ? data.completedLength.value
          : this.completedLength,
      downloadSpeed: data.downloadSpeed.present
          ? data.downloadSpeed.value
          : this.downloadSpeed,
      uploadSpeed: data.uploadSpeed.present
          ? data.uploadSpeed.value
          : this.uploadSpeed,
      connections: data.connections.present
          ? data.connections.value
          : this.connections,
      split: data.split.present ? data.split.value : this.split,
      pieceLength: data.pieceLength.present
          ? data.pieceLength.value
          : this.pieceLength,
      numPieces: data.numPieces.present ? data.numPieces.value : this.numPieces,
      bitfield: data.bitfield.present ? data.bitfield.value : this.bitfield,
      aria2ErrorCode: data.aria2ErrorCode.present
          ? data.aria2ErrorCode.value
          : this.aria2ErrorCode,
      error: data.error.present ? data.error.value : this.error,
      source: data.source.present ? data.source.value : this.source,
      optionsJson: data.optionsJson.present
          ? data.optionsJson.value
          : this.optionsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadEntity(')
          ..write('id: $id, ')
          ..write('gid: $gid, ')
          ..write('url: $url, ')
          ..write('fileName: $fileName, ')
          ..write('directory: $directory, ')
          ..write('contentUri: $contentUri, ')
          ..write('displayName: $displayName, ')
          ..write('status: $status, ')
          ..write('queuePosition: $queuePosition, ')
          ..write('totalLength: $totalLength, ')
          ..write('completedLength: $completedLength, ')
          ..write('downloadSpeed: $downloadSpeed, ')
          ..write('uploadSpeed: $uploadSpeed, ')
          ..write('connections: $connections, ')
          ..write('split: $split, ')
          ..write('pieceLength: $pieceLength, ')
          ..write('numPieces: $numPieces, ')
          ..write('bitfield: $bitfield, ')
          ..write('aria2ErrorCode: $aria2ErrorCode, ')
          ..write('error: $error, ')
          ..write('source: $source, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    gid,
    url,
    fileName,
    directory,
    contentUri,
    displayName,
    status,
    queuePosition,
    totalLength,
    completedLength,
    downloadSpeed,
    uploadSpeed,
    connections,
    split,
    pieceLength,
    numPieces,
    bitfield,
    aria2ErrorCode,
    error,
    source,
    optionsJson,
    createdAt,
    updatedAt,
    completedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadEntity &&
          other.id == this.id &&
          other.gid == this.gid &&
          other.url == this.url &&
          other.fileName == this.fileName &&
          other.directory == this.directory &&
          other.contentUri == this.contentUri &&
          other.displayName == this.displayName &&
          other.status == this.status &&
          other.queuePosition == this.queuePosition &&
          other.totalLength == this.totalLength &&
          other.completedLength == this.completedLength &&
          other.downloadSpeed == this.downloadSpeed &&
          other.uploadSpeed == this.uploadSpeed &&
          other.connections == this.connections &&
          other.split == this.split &&
          other.pieceLength == this.pieceLength &&
          other.numPieces == this.numPieces &&
          other.bitfield == this.bitfield &&
          other.aria2ErrorCode == this.aria2ErrorCode &&
          other.error == this.error &&
          other.source == this.source &&
          other.optionsJson == this.optionsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class DownloadEntriesCompanion extends UpdateCompanion<DownloadEntity> {
  final Value<String> id;
  final Value<String?> gid;
  final Value<String> url;
  final Value<String?> fileName;
  final Value<String> directory;
  final Value<String?> contentUri;
  final Value<String?> displayName;
  final Value<String> status;
  final Value<int> queuePosition;
  final Value<int> totalLength;
  final Value<int> completedLength;
  final Value<int> downloadSpeed;
  final Value<int> uploadSpeed;
  final Value<int> connections;
  final Value<int> split;
  final Value<int> pieceLength;
  final Value<int> numPieces;
  final Value<String?> bitfield;
  final Value<int?> aria2ErrorCode;
  final Value<String?> error;
  final Value<String> source;
  final Value<String?> optionsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const DownloadEntriesCompanion({
    this.id = const Value.absent(),
    this.gid = const Value.absent(),
    this.url = const Value.absent(),
    this.fileName = const Value.absent(),
    this.directory = const Value.absent(),
    this.contentUri = const Value.absent(),
    this.displayName = const Value.absent(),
    this.status = const Value.absent(),
    this.queuePosition = const Value.absent(),
    this.totalLength = const Value.absent(),
    this.completedLength = const Value.absent(),
    this.downloadSpeed = const Value.absent(),
    this.uploadSpeed = const Value.absent(),
    this.connections = const Value.absent(),
    this.split = const Value.absent(),
    this.pieceLength = const Value.absent(),
    this.numPieces = const Value.absent(),
    this.bitfield = const Value.absent(),
    this.aria2ErrorCode = const Value.absent(),
    this.error = const Value.absent(),
    this.source = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadEntriesCompanion.insert({
    required String id,
    this.gid = const Value.absent(),
    required String url,
    this.fileName = const Value.absent(),
    required String directory,
    this.contentUri = const Value.absent(),
    this.displayName = const Value.absent(),
    required String status,
    required int queuePosition,
    this.totalLength = const Value.absent(),
    this.completedLength = const Value.absent(),
    this.downloadSpeed = const Value.absent(),
    this.uploadSpeed = const Value.absent(),
    this.connections = const Value.absent(),
    this.split = const Value.absent(),
    this.pieceLength = const Value.absent(),
    this.numPieces = const Value.absent(),
    this.bitfield = const Value.absent(),
    this.aria2ErrorCode = const Value.absent(),
    this.error = const Value.absent(),
    this.source = const Value.absent(),
    this.optionsJson = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       url = Value(url),
       directory = Value(directory),
       status = Value(status),
       queuePosition = Value(queuePosition),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DownloadEntity> custom({
    Expression<String>? id,
    Expression<String>? gid,
    Expression<String>? url,
    Expression<String>? fileName,
    Expression<String>? directory,
    Expression<String>? contentUri,
    Expression<String>? displayName,
    Expression<String>? status,
    Expression<int>? queuePosition,
    Expression<int>? totalLength,
    Expression<int>? completedLength,
    Expression<int>? downloadSpeed,
    Expression<int>? uploadSpeed,
    Expression<int>? connections,
    Expression<int>? split,
    Expression<int>? pieceLength,
    Expression<int>? numPieces,
    Expression<String>? bitfield,
    Expression<int>? aria2ErrorCode,
    Expression<String>? error,
    Expression<String>? source,
    Expression<String>? optionsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (gid != null) 'gid': gid,
      if (url != null) 'url': url,
      if (fileName != null) 'file_name': fileName,
      if (directory != null) 'directory': directory,
      if (contentUri != null) 'content_uri': contentUri,
      if (displayName != null) 'display_name': displayName,
      if (status != null) 'status': status,
      if (queuePosition != null) 'queue_position': queuePosition,
      if (totalLength != null) 'total_length': totalLength,
      if (completedLength != null) 'completed_length': completedLength,
      if (downloadSpeed != null) 'download_speed': downloadSpeed,
      if (uploadSpeed != null) 'upload_speed': uploadSpeed,
      if (connections != null) 'connections': connections,
      if (split != null) 'split': split,
      if (pieceLength != null) 'piece_length': pieceLength,
      if (numPieces != null) 'num_pieces': numPieces,
      if (bitfield != null) 'bitfield': bitfield,
      if (aria2ErrorCode != null) 'aria2_error_code': aria2ErrorCode,
      if (error != null) 'error': error,
      if (source != null) 'source': source,
      if (optionsJson != null) 'options_json': optionsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadEntriesCompanion copyWith({
    Value<String>? id,
    Value<String?>? gid,
    Value<String>? url,
    Value<String?>? fileName,
    Value<String>? directory,
    Value<String?>? contentUri,
    Value<String?>? displayName,
    Value<String>? status,
    Value<int>? queuePosition,
    Value<int>? totalLength,
    Value<int>? completedLength,
    Value<int>? downloadSpeed,
    Value<int>? uploadSpeed,
    Value<int>? connections,
    Value<int>? split,
    Value<int>? pieceLength,
    Value<int>? numPieces,
    Value<String?>? bitfield,
    Value<int?>? aria2ErrorCode,
    Value<String?>? error,
    Value<String>? source,
    Value<String?>? optionsJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return DownloadEntriesCompanion(
      id: id ?? this.id,
      gid: gid ?? this.gid,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      directory: directory ?? this.directory,
      contentUri: contentUri ?? this.contentUri,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      queuePosition: queuePosition ?? this.queuePosition,
      totalLength: totalLength ?? this.totalLength,
      completedLength: completedLength ?? this.completedLength,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      connections: connections ?? this.connections,
      split: split ?? this.split,
      pieceLength: pieceLength ?? this.pieceLength,
      numPieces: numPieces ?? this.numPieces,
      bitfield: bitfield ?? this.bitfield,
      aria2ErrorCode: aria2ErrorCode ?? this.aria2ErrorCode,
      error: error ?? this.error,
      source: source ?? this.source,
      optionsJson: optionsJson ?? this.optionsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (gid.present) {
      map['gid'] = Variable<String>(gid.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (directory.present) {
      map['directory'] = Variable<String>(directory.value);
    }
    if (contentUri.present) {
      map['content_uri'] = Variable<String>(contentUri.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (queuePosition.present) {
      map['queue_position'] = Variable<int>(queuePosition.value);
    }
    if (totalLength.present) {
      map['total_length'] = Variable<int>(totalLength.value);
    }
    if (completedLength.present) {
      map['completed_length'] = Variable<int>(completedLength.value);
    }
    if (downloadSpeed.present) {
      map['download_speed'] = Variable<int>(downloadSpeed.value);
    }
    if (uploadSpeed.present) {
      map['upload_speed'] = Variable<int>(uploadSpeed.value);
    }
    if (connections.present) {
      map['connections'] = Variable<int>(connections.value);
    }
    if (split.present) {
      map['split'] = Variable<int>(split.value);
    }
    if (pieceLength.present) {
      map['piece_length'] = Variable<int>(pieceLength.value);
    }
    if (numPieces.present) {
      map['num_pieces'] = Variable<int>(numPieces.value);
    }
    if (bitfield.present) {
      map['bitfield'] = Variable<String>(bitfield.value);
    }
    if (aria2ErrorCode.present) {
      map['aria2_error_code'] = Variable<int>(aria2ErrorCode.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (optionsJson.present) {
      map['options_json'] = Variable<String>(optionsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadEntriesCompanion(')
          ..write('id: $id, ')
          ..write('gid: $gid, ')
          ..write('url: $url, ')
          ..write('fileName: $fileName, ')
          ..write('directory: $directory, ')
          ..write('contentUri: $contentUri, ')
          ..write('displayName: $displayName, ')
          ..write('status: $status, ')
          ..write('queuePosition: $queuePosition, ')
          ..write('totalLength: $totalLength, ')
          ..write('completedLength: $completedLength, ')
          ..write('downloadSpeed: $downloadSpeed, ')
          ..write('uploadSpeed: $uploadSpeed, ')
          ..write('connections: $connections, ')
          ..write('split: $split, ')
          ..write('pieceLength: $pieceLength, ')
          ..write('numPieces: $numPieces, ')
          ..write('bitfield: $bitfield, ')
          ..write('aria2ErrorCode: $aria2ErrorCode, ')
          ..write('error: $error, ')
          ..write('source: $source, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, SettingEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingEntity(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class SettingEntity extends DataClass implements Insertable<SettingEntity> {
  final String key;
  final String value;
  const SettingEntity({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingEntity(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingEntity copyWith({String? key, String? value}) =>
      SettingEntity(key: key ?? this.key, value: value ?? this.value);
  SettingEntity copyWithCompanion(AppSettingsCompanion data) {
    return SettingEntity(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingEntity(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingEntity &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<SettingEntity> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingEntity> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DownloadEntriesTable downloadEntries = $DownloadEntriesTable(
    this,
  );
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    downloadEntries,
    appSettings,
  ];
}

typedef $$DownloadEntriesTableCreateCompanionBuilder =
    DownloadEntriesCompanion Function({
      required String id,
      Value<String?> gid,
      required String url,
      Value<String?> fileName,
      required String directory,
      Value<String?> contentUri,
      Value<String?> displayName,
      required String status,
      required int queuePosition,
      Value<int> totalLength,
      Value<int> completedLength,
      Value<int> downloadSpeed,
      Value<int> uploadSpeed,
      Value<int> connections,
      Value<int> split,
      Value<int> pieceLength,
      Value<int> numPieces,
      Value<String?> bitfield,
      Value<int?> aria2ErrorCode,
      Value<String?> error,
      Value<String> source,
      Value<String?> optionsJson,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$DownloadEntriesTableUpdateCompanionBuilder =
    DownloadEntriesCompanion Function({
      Value<String> id,
      Value<String?> gid,
      Value<String> url,
      Value<String?> fileName,
      Value<String> directory,
      Value<String?> contentUri,
      Value<String?> displayName,
      Value<String> status,
      Value<int> queuePosition,
      Value<int> totalLength,
      Value<int> completedLength,
      Value<int> downloadSpeed,
      Value<int> uploadSpeed,
      Value<int> connections,
      Value<int> split,
      Value<int> pieceLength,
      Value<int> numPieces,
      Value<String?> bitfield,
      Value<int?> aria2ErrorCode,
      Value<String?> error,
      Value<String> source,
      Value<String?> optionsJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

class $$DownloadEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadEntriesTable> {
  $$DownloadEntriesTableFilterComposer({
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

  ColumnFilters<String> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directory => $composableBuilder(
    column: $table.directory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get queuePosition => $composableBuilder(
    column: $table.queuePosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalLength => $composableBuilder(
    column: $table.totalLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedLength => $composableBuilder(
    column: $table.completedLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadSpeed => $composableBuilder(
    column: $table.downloadSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uploadSpeed => $composableBuilder(
    column: $table.uploadSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get connections => $composableBuilder(
    column: $table.connections,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get split => $composableBuilder(
    column: $table.split,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pieceLength => $composableBuilder(
    column: $table.pieceLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numPieces => $composableBuilder(
    column: $table.numPieces,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bitfield => $composableBuilder(
    column: $table.bitfield,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get aria2ErrorCode => $composableBuilder(
    column: $table.aria2ErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadEntriesTable> {
  $$DownloadEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get gid => $composableBuilder(
    column: $table.gid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directory => $composableBuilder(
    column: $table.directory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get queuePosition => $composableBuilder(
    column: $table.queuePosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalLength => $composableBuilder(
    column: $table.totalLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedLength => $composableBuilder(
    column: $table.completedLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadSpeed => $composableBuilder(
    column: $table.downloadSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uploadSpeed => $composableBuilder(
    column: $table.uploadSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get connections => $composableBuilder(
    column: $table.connections,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get split => $composableBuilder(
    column: $table.split,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pieceLength => $composableBuilder(
    column: $table.pieceLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numPieces => $composableBuilder(
    column: $table.numPieces,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bitfield => $composableBuilder(
    column: $table.bitfield,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get aria2ErrorCode => $composableBuilder(
    column: $table.aria2ErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadEntriesTable> {
  $$DownloadEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get gid =>
      $composableBuilder(column: $table.gid, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get directory =>
      $composableBuilder(column: $table.directory, builder: (column) => column);

  GeneratedColumn<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get queuePosition => $composableBuilder(
    column: $table.queuePosition,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalLength => $composableBuilder(
    column: $table.totalLength,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedLength => $composableBuilder(
    column: $table.completedLength,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadSpeed => $composableBuilder(
    column: $table.downloadSpeed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get uploadSpeed => $composableBuilder(
    column: $table.uploadSpeed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get connections => $composableBuilder(
    column: $table.connections,
    builder: (column) => column,
  );

  GeneratedColumn<int> get split =>
      $composableBuilder(column: $table.split, builder: (column) => column);

  GeneratedColumn<int> get pieceLength => $composableBuilder(
    column: $table.pieceLength,
    builder: (column) => column,
  );

  GeneratedColumn<int> get numPieces =>
      $composableBuilder(column: $table.numPieces, builder: (column) => column);

  GeneratedColumn<String> get bitfield =>
      $composableBuilder(column: $table.bitfield, builder: (column) => column);

  GeneratedColumn<int> get aria2ErrorCode => $composableBuilder(
    column: $table.aria2ErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$DownloadEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadEntriesTable,
          DownloadEntity,
          $$DownloadEntriesTableFilterComposer,
          $$DownloadEntriesTableOrderingComposer,
          $$DownloadEntriesTableAnnotationComposer,
          $$DownloadEntriesTableCreateCompanionBuilder,
          $$DownloadEntriesTableUpdateCompanionBuilder,
          (
            DownloadEntity,
            BaseReferences<
              _$AppDatabase,
              $DownloadEntriesTable,
              DownloadEntity
            >,
          ),
          DownloadEntity,
          PrefetchHooks Function()
        > {
  $$DownloadEntriesTableTableManager(
    _$AppDatabase db,
    $DownloadEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> gid = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                Value<String> directory = const Value.absent(),
                Value<String?> contentUri = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> queuePosition = const Value.absent(),
                Value<int> totalLength = const Value.absent(),
                Value<int> completedLength = const Value.absent(),
                Value<int> downloadSpeed = const Value.absent(),
                Value<int> uploadSpeed = const Value.absent(),
                Value<int> connections = const Value.absent(),
                Value<int> split = const Value.absent(),
                Value<int> pieceLength = const Value.absent(),
                Value<int> numPieces = const Value.absent(),
                Value<String?> bitfield = const Value.absent(),
                Value<int?> aria2ErrorCode = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> optionsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadEntriesCompanion(
                id: id,
                gid: gid,
                url: url,
                fileName: fileName,
                directory: directory,
                contentUri: contentUri,
                displayName: displayName,
                status: status,
                queuePosition: queuePosition,
                totalLength: totalLength,
                completedLength: completedLength,
                downloadSpeed: downloadSpeed,
                uploadSpeed: uploadSpeed,
                connections: connections,
                split: split,
                pieceLength: pieceLength,
                numPieces: numPieces,
                bitfield: bitfield,
                aria2ErrorCode: aria2ErrorCode,
                error: error,
                source: source,
                optionsJson: optionsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> gid = const Value.absent(),
                required String url,
                Value<String?> fileName = const Value.absent(),
                required String directory,
                Value<String?> contentUri = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                required String status,
                required int queuePosition,
                Value<int> totalLength = const Value.absent(),
                Value<int> completedLength = const Value.absent(),
                Value<int> downloadSpeed = const Value.absent(),
                Value<int> uploadSpeed = const Value.absent(),
                Value<int> connections = const Value.absent(),
                Value<int> split = const Value.absent(),
                Value<int> pieceLength = const Value.absent(),
                Value<int> numPieces = const Value.absent(),
                Value<String?> bitfield = const Value.absent(),
                Value<int?> aria2ErrorCode = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> optionsJson = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadEntriesCompanion.insert(
                id: id,
                gid: gid,
                url: url,
                fileName: fileName,
                directory: directory,
                contentUri: contentUri,
                displayName: displayName,
                status: status,
                queuePosition: queuePosition,
                totalLength: totalLength,
                completedLength: completedLength,
                downloadSpeed: downloadSpeed,
                uploadSpeed: uploadSpeed,
                connections: connections,
                split: split,
                pieceLength: pieceLength,
                numPieces: numPieces,
                bitfield: bitfield,
                aria2ErrorCode: aria2ErrorCode,
                error: error,
                source: source,
                optionsJson: optionsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadEntriesTable,
      DownloadEntity,
      $$DownloadEntriesTableFilterComposer,
      $$DownloadEntriesTableOrderingComposer,
      $$DownloadEntriesTableAnnotationComposer,
      $$DownloadEntriesTableCreateCompanionBuilder,
      $$DownloadEntriesTableUpdateCompanionBuilder,
      (
        DownloadEntity,
        BaseReferences<_$AppDatabase, $DownloadEntriesTable, DownloadEntity>,
      ),
      DownloadEntity,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          SettingEntity,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            SettingEntity,
            BaseReferences<_$AppDatabase, $AppSettingsTable, SettingEntity>,
          ),
          SettingEntity,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      SettingEntity,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        SettingEntity,
        BaseReferences<_$AppDatabase, $AppSettingsTable, SettingEntity>,
      ),
      SettingEntity,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DownloadEntriesTableTableManager get downloadEntries =>
      $$DownloadEntriesTableTableManager(_db, _db.downloadEntries);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
