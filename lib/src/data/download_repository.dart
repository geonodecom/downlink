import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../ytdlp/ytdlp_models.dart';
import '../aria2/aria2_models.dart';
import '../platform/open_path.dart';
import 'app_database.dart';

class NewDownload {
  const NewDownload({
    required this.url,
    required this.directory,
    required this.fileName,
    required this.split,
    required this.startImmediately,
    this.metadata = const DownloadMetadata(),
    this.headers = const {},
    this.source = 'manual',
    this.options = const {},
  });

  final String url;
  final String directory;
  final String fileName;
  final int split;
  final bool startImmediately;
  final DownloadMetadata metadata;
  final Map<String, String> headers;
  final String source;
  final Map<String, Object?> options;

  NewDownload copyWith({DownloadMetadata? metadata}) {
    return NewDownload(
      url: url,
      directory: directory,
      fileName: fileName,
      split: split,
      startImmediately: startImmediately,
      metadata: metadata ?? this.metadata,
      headers: headers,
      source: source,
      options: options,
    );
  }
}

class DownloadMetadata {
  const DownloadMetadata({this.fileName, this.totalLength = 0});

  final String? fileName;
  final int totalLength;
}

class DownloadRepository {
  DownloadRepository(this._db);

  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  Stream<List<DownloadEntity>> watchDownloads() {
    return (_db.select(_db.downloadEntries)
          ..where((row) => row.status.isIn(_visibleStatuses()))
          ..orderBy([
            (row) => OrderingTerm.asc(row.queuePosition),
            (row) => OrderingTerm.desc(row.createdAt),
          ]))
        .watch();
  }

  Stream<DownloadEntity?> watchDownload(String id) {
    return (_db.select(_db.downloadEntries)
          ..where((row) => row.id.equals(id))
          ..limit(1))
        .watchSingleOrNull();
  }

  Stream<List<DownloadEntity>> watchQueue() {
    return (_db.select(_db.downloadEntries)
          ..where((row) => row.status.equals(DownloadStatus.queued.name))
          ..orderBy([(row) => OrderingTerm.asc(row.queuePosition)]))
        .watch();
  }

  Stream<List<DownloadEntity>> watchActive() {
    return (_db.select(_db.downloadEntries)
          ..where((row) => row.status.equals(DownloadStatus.active.name))
          ..orderBy([(row) => OrderingTerm.asc(row.queuePosition)]))
        .watch();
  }

  Stream<List<DownloadEntity>> watchHistory() {
    return (_db.select(_db.downloadEntries)
          ..where(
            (row) =>
                row.status.equals(DownloadStatus.completed.name) |
                row.status.equals(DownloadStatus.error.name),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
        .watch();
  }

  Future<List<DownloadEntity>> listActiveAndQueued() {
    return (_db.select(_db.downloadEntries)
          ..where(
            (row) =>
                row.status.equals(DownloadStatus.active.name) |
                row.status.equals(DownloadStatus.queued.name),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.queuePosition)]))
        .get();
  }

  Future<List<DownloadEntity>> listByStatuses(Set<DownloadStatus> statuses) {
    return (_db.select(_db.downloadEntries)
          ..where((row) => row.status.isIn(statuses.map((s) => s.name)))
          ..orderBy([(row) => OrderingTerm.asc(row.queuePosition)]))
        .get();
  }

  Future<List<DownloadEntity>> listQueuedMissingMetadata() {
    return (_db.select(_db.downloadEntries)
          ..where(
            (row) =>
                row.status.equals(DownloadStatus.queued.name) &
                (row.fileName.isNull() | row.totalLength.equals(0)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.queuePosition)]))
        .get();
  }

  Future<DownloadEntity?> findById(String id) {
    return (_db.select(_db.downloadEntries)
          ..where((row) => row.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<DownloadEntity?> findByGid(String gid) {
    return (_db.select(_db.downloadEntries)
          ..where((row) => row.gid.equals(gid))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<DownloadEntity?> findExistingDownload(NewDownload input) {
    return (_db.select(_db.downloadEntries)
          ..where(
            (row) =>
                row.url.equals(input.url) &
                row.directory.equals(input.directory) &
                row.status.isNotIn([
                  DownloadStatus.completed.name,
                  DownloadStatus.removed.name,
                ]),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<DownloadEntity> createDownload(NewDownload input) async {
    final now = DateTime.now();
    final status = input.startImmediately
        ? DownloadStatus.active
        : DownloadStatus.queued;
    final fileName = _resolvedFileName(input);
    final entity = DownloadEntriesCompanion.insert(
      id: _uuid.v4(),
      url: input.url,
      fileName: Value(fileName),
      directory: input.directory,
      status: status.name,
      queuePosition: await nextQueuePosition(),
      totalLength: Value(input.metadata.totalLength),
      split: Value(input.split),
      source: Value(input.source),
      optionsJson: Value(_encodeOptions(input)),
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.downloadEntries).insert(entity);
    final created = await findById(entity.id.value);
    if (created == null) {
      throw StateError('Created download could not be loaded');
    }
    return created;
  }

  Future<int> nextQueuePosition() async {
    final maxPosition = _db.downloadEntries.queuePosition.max();
    final query = _db.selectOnly(_db.downloadEntries)
      ..addColumns([maxPosition])
      ..where(
        _db.downloadEntries.status.isIn([
          DownloadStatus.active.name,
          DownloadStatus.queued.name,
          DownloadStatus.paused.name,
        ]),
      );
    final row = await query.getSingle();
    return (row.read(maxPosition) ?? 0) + 1;
  }

  Future<void> attachGid(String id, String gid) {
    return (_db.update(
      _db.downloadEntries,
    )..where((row) => row.id.equals(id))).write(
      DownloadEntriesCompanion(
        gid: Value(gid),
        status: Value(DownloadStatus.active.name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateStatus(
    String id,
    DownloadStatus status, {
    String? error,
    int? aria2ErrorCode,
  }) {
    return (_db.update(
      _db.downloadEntries,
    )..where((row) => row.id.equals(id))).write(
      DownloadEntriesCompanion(
        status: Value(status.name),
        error: Value(error),
        aria2ErrorCode: Value(aria2ErrorCode),
        downloadSpeed: const Value(0),
        updatedAt: Value(DateTime.now()),
        completedAt: Value(
          status == DownloadStatus.completed ? DateTime.now() : null,
        ),
      ),
    );
  }

  Future<void> updateMetadata(String id, DownloadMetadata metadata) {
    final companion = DownloadEntriesCompanion(
      fileName: metadata.fileName == null
          ? const Value.absent()
          : Value(metadata.fileName),
      totalLength: metadata.totalLength <= 0
          ? const Value.absent()
          : Value(metadata.totalLength),
      updatedAt: Value(DateTime.now()),
    );
    return (_db.update(
      _db.downloadEntries,
    )..where((row) => row.id.equals(id))).write(companion);
  }

  Future<bool> updateFromAria2(Aria2Status status) async {
    final existing = await findByGid(status.gid);
    if (existing == null) return false;
    final mapped = status.toDownloadStatus();
    final totalLength = status.totalLength > 0
        ? status.totalLength
        : existing.totalLength;
    final completedLength = status.completedLength > 0 || status.totalLength > 0
        ? status.completedLength
        : existing.completedLength;
    final error = mapped == DownloadStatus.error ? status.errorMessage : null;
    final errorCode = mapped == DownloadStatus.error ? status.errorCode : null;
    final path = status.files.isEmpty ? null : status.files.first.path;
    final contentUri = path != null && path.startsWith('content:')
        ? path
        : existing.contentUri;
    await (_db.update(
      _db.downloadEntries,
    )..where((row) => row.id.equals(existing.id))).write(
      DownloadEntriesCompanion(
        status: Value(mapped.name),
        totalLength: Value(totalLength),
        completedLength: Value(completedLength),
        downloadSpeed: Value(status.downloadSpeed),
        connections: Value(status.connections),
        pieceLength: Value(status.pieceLength),
        numPieces: Value(status.numPieces),
        bitfield: Value(status.bitfield),
        fileName: Value(status.fileName ?? existing.fileName),
        displayName: Value(status.fileName ?? existing.displayName),
        contentUri: Value(contentUri),
        aria2ErrorCode: Value(errorCode),
        error: Value(error),
        updatedAt: Value(DateTime.now()),
        completedAt: Value(
          mapped == DownloadStatus.completed
              ? DateTime.now()
              : existing.completedAt,
        ),
      ),
    );
    return true;
  }

  Future<bool> attachStatusToMatchingDownload(Aria2Status status) async {
    final existing = await findMatchingDownload(status);
    if (existing == null) return false;

    await (_db.update(
      _db.downloadEntries,
    )..where((row) => row.id.equals(existing.id))).write(
      DownloadEntriesCompanion(
        gid: Value(status.gid),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return updateFromAria2(status);
  }

  Future<DownloadEntity?> findMatchingDownload(Aria2Status status) {
    final url = status.sourceUrl;
    if (url == null || status.files.isEmpty) return Future.value(null);

    final directory = p.dirname(status.files.first.path);
    return (_db.select(_db.downloadEntries)
          ..where(
            (row) =>
                row.url.equals(url) &
                row.directory.equals(directory) &
                row.status.isNotIn([
                  DownloadStatus.completed.name,
                  DownloadStatus.removed.name,
                ]),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> clearRetryState(String id) {
    return (_db.update(
      _db.downloadEntries,
    )..where((row) => row.id.equals(id))).write(
      DownloadEntriesCompanion(
        gid: const Value(null),
        error: const Value(null),
        aria2ErrorCode: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reorderQueue(List<String> ids) async {
    await _db.transaction(() async {
      for (var i = 0; i < ids.length; i++) {
        await (_db.update(
          _db.downloadEntries,
        )..where((row) => row.id.equals(ids[i]))).write(
          DownloadEntriesCompanion(
            queuePosition: Value(i + 1),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  Stream<GeonodeSettings> watchSettings() async* {
    await ensureSettings();
    yield* _db.select(_db.appSettings).watch().map(_settingsFromRows);
  }

  Future<GeonodeSettings> getSettings() async {
    await ensureSettings();
    final rows = await _db.select(_db.appSettings).get();
    return _settingsFromRows(rows);
  }

  Future<void> saveSettings(GeonodeSettings settings) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.appSettings, [
        AppSettingsCompanion.insert(
          key: 'download_directory',
          value: settings.downloadDirectory,
        ),
        AppSettingsCompanion.insert(
          key: 'max_active_downloads',
          value: settings.maxActiveDownloads.toString(),
        ),
        AppSettingsCompanion.insert(
          key: 'default_split',
          value: settings.defaultSplit.toString(),
        ),
        AppSettingsCompanion.insert(
          key: 'aria2_path',
          value: settings.aria2Path,
        ),
        AppSettingsCompanion.insert(
          key: 'ytdlp_path',
          value: settings.ytdlpPath,
        ),
        AppSettingsCompanion.insert(
          key: 'ffmpeg_path',
          value: settings.ffmpegPath,
        ),
        AppSettingsCompanion.insert(
          key: 'youtube_format_preset',
          value: settings.youtubeFormatPreset,
        ),
        AppSettingsCompanion.insert(
          key: 'theme_mode',
          value: settings.themeMode,
        ),
        AppSettingsCompanion.insert(
          key: 'facebook_cookies_path',
          value: settings.facebookCookiesPath,
        ),
        AppSettingsCompanion.insert(
          key: 'facebook_cookies_from_browser',
          value: settings.facebookCookiesFromBrowser,
        ),
        AppSettingsCompanion.insert(
          key: 'instagram_cookies_path',
          value: settings.instagramCookiesPath,
        ),
        AppSettingsCompanion.insert(
          key: 'instagram_cookies_from_browser',
          value: settings.instagramCookiesFromBrowser,
        ),
      ]);
    });
  }

  Future<void> ensureSettings() async {
    final count = await _db.select(_db.appSettings).get();
    if (count.isNotEmpty) return;
    final downloads = await getDownloadsDirectory();
    await saveSettings(
      GeonodeSettings(
        downloadDirectory: downloads?.path ?? defaultDownloadsFallback(),
        maxActiveDownloads: 1,
        defaultSplit: 16,
        aria2Path: '',
        ytdlpPath: '',
        ffmpegPath: '',
        youtubeFormatPreset: 'best_mp4',
        themeMode: 'system',
        facebookCookiesPath: '',
        facebookCookiesFromBrowser: '',
        instagramCookiesPath: '',
        instagramCookiesFromBrowser: '',
      ),
    );
  }

  Iterable<String> _visibleStatuses() {
    return DownloadStatus.values
        .where((status) => status != DownloadStatus.removed)
        .map((status) => status.name);
  }

  GeonodeSettings _settingsFromRows(List<SettingEntity> rows) {
    final values = {for (final row in rows) row.key: row.value};
    return GeonodeSettings(
      downloadDirectory: values['download_directory'] ?? '',
      maxActiveDownloads:
          int.tryParse(values['max_active_downloads'] ?? '') ?? 1,
      defaultSplit: int.tryParse(values['default_split'] ?? '') ?? 16,
      aria2Path: values['aria2_path'] ?? '',
      ytdlpPath: values['ytdlp_path'] ?? '',
      ffmpegPath: values['ffmpeg_path'] ?? '',
      youtubeFormatPreset: values['youtube_format_preset'] ?? 'best_mp4',
      themeMode: values['theme_mode'] ?? 'system',
      facebookCookiesPath: values['facebook_cookies_path'] ?? '',
      facebookCookiesFromBrowser:
          values['facebook_cookies_from_browser'] ?? '',
      instagramCookiesPath: values['instagram_cookies_path'] ?? '',
      instagramCookiesFromBrowser:
          values['instagram_cookies_from_browser'] ?? '',
    );
  }
}

bool isYoutubeDownload(DownloadEntity entity) {
  return isYoutubeDownloadOptions(entity.optionsJson);
}

YoutubeDownloadOptions? youtubeOptionsFor(DownloadEntity entity) {
  return youtubeOptionsFromJson(entity.optionsJson);
}

String? _encodeOptions(NewDownload input) {
  final payload = <String, Object?>{...input.options};
  if (input.headers.isNotEmpty) {
    payload['headers'] = input.headers;
  }
  if (payload.isEmpty) return null;
  return jsonEncode(payload);
}

String? _resolvedFileName(NewDownload input) {
  final override = input.fileName.trim();
  if (override.isEmpty) return _cleanFileName(input.metadata.fileName);
  if (p.extension(override).isNotEmpty) return override;

  final extension =
      _extensionFromFileName(input.metadata.fileName) ??
      _extensionFromUrl(input.url);
  if (extension.isEmpty) return override;
  return '$override$extension';
}

String? _cleanFileName(String? fileName) {
  final value = fileName?.trim();
  if (value == null || value.isEmpty) return null;
  final clean = p.basename(value);
  return clean.isEmpty || clean == '.' ? null : clean;
}

String? _extensionFromFileName(String? fileName) {
  final clean = _cleanFileName(fileName);
  if (clean == null) return null;
  final extension = p.extension(clean);
  return extension.isEmpty ? null : extension;
}

String _extensionFromUrl(String url) {
  final uri = Uri.tryParse(url);
  final sourcePath = uri?.path ?? url;
  return p.extension(p.basename(sourcePath));
}
