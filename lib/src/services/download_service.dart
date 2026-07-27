import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../aria2/aria2_client.dart';
import '../aria2/aria2_models.dart';
import '../data/app_database.dart';
import '../data/download_repository.dart';
import '../engine/download_engine.dart';
import '../facebook/facebook_models.dart';
import '../instagram/instagram_models.dart';
import '../tiktok/tiktok_models.dart';
import '../ytdlp/ytdlp_models.dart';
import 'diagnostics.dart';
import 'download_probe.dart';
import 'url_classifier.dart';

class DownloadService {
  DownloadService({
    required DownloadRepository repository,
    required DownloadEngine engine,
    DiagnosticsLog? diagnostics,
    DownloadProbe? probe,
  }) : _repository = repository,
       _engine = engine,
       _diagnostics = diagnostics,
       _probe = probe ?? DownloadProbe();

  final DownloadRepository _repository;
  final DownloadEngine _engine;
  final DiagnosticsLog? _diagnostics;
  final DownloadProbe _probe;

  Timer? _pollTimer;
  bool _started = false;
  bool _refreshing = false;
  final Set<String> _metadataProbeAttempts = {};

  DownloadEngine get engine => _engine;

  Future<void> start() async {
    if (_started && await _engine.isHealthy) {
      await _fillQueuedMetadata();
      return;
    }

    final settings = await _repository.getSettings();
    _diagnostics?.info('Starting download engine…');
    await _engine.start(
      downloadDirectory: settings.downloadDirectory,
      maxActiveDownloads: settings.maxActiveDownloads,
      defaultSplit: settings.defaultSplit,
      executableOverride: settings.aria2Path,
      ytdlpPath: settings.ytdlpPath,
      ffmpegPath: settings.ffmpegPath,
    );
    _diagnostics?.info('Download engine started.');
    _started = true;
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refreshSafely()),
    );
    await refresh();
    await _fillQueuedMetadata();
    await resumeQueued();
  }

  Future<void> addDownload(NewDownload input) async {
    await start();
    _diagnostics?.info('Adding download: ${input.url}');
    final existing = await _repository.findExistingDownload(input);
    if (existing != null) {
      _diagnostics?.warn(
        'Skipped duplicate download: ${input.url} (existing: ${existing.id})',
      );
      throw DownloadAlreadyExistsException(existing.id);
    }

    final metadata = _shouldProbe(input)
        ? await _probe.probe(input)
        : input.metadata;
    final entity = await _repository.createDownload(
      input.copyWith(metadata: metadata),
    );
    if (input.startImmediately) {
      await _startEntity(entity);
    } else {
      await resumeQueued();
    }
  }

  Future<void> pause(String id) async {
    await start();
    final entity = await _repository.findById(id);
    if (entity == null) return;
    _diagnostics?.info('Pausing download: ${entity.fileName ?? entity.url}');
    if (entity.gid != null) {
      await _engine.pause(entity.gid!);
    }
    await _repository.updateStatus(id, DownloadStatus.paused);
  }

  Future<void> resume(String id) async {
    await start();
    final entity = await _repository.findById(id);
    if (entity == null) return;
    _diagnostics?.info('Resuming download: ${entity.fileName ?? entity.url}');
    if (entity.gid != null) {
      await _engine.unpause(entity.gid!);
      await _repository.updateStatus(id, DownloadStatus.active);
    } else {
      await _repository.updateStatus(id, DownloadStatus.queued);
      await resumeQueued();
    }
  }

  Future<void> retry(String id) async {
    await start();
    final entity = await _repository.findById(id);
    if (entity == null) return;
    _diagnostics?.info('Retrying download: ${entity.fileName ?? entity.url}');
    await _repository.clearRetryState(id);
    await _repository.updateStatus(id, DownloadStatus.queued);
    await resumeQueued();
  }

  Future<void> remove(String id, {bool deleteFiles = false}) async {
    final entity = await _repository.findById(id);
    _diagnostics?.info(
      'Removing download: ${entity?.fileName ?? id} (deleteFiles=$deleteFiles)',
    );
    if (entity?.gid != null) {
      try {
        await _engine.remove(entity!.gid!);
      } catch (_) {}
    }

    Object? deleteError;
    if (deleteFiles && entity != null) {
      try {
        await _deleteDownloadedFiles(entity);
      } catch (error) {
        deleteError = error;
        _diagnostics?.error('Failed to delete files: $error');
      }
    }

    await _repository.updateStatus(id, DownloadStatus.removed);
    if (deleteError != null) {
      throw DeleteDownloadedFilesException(deleteError);
    }
  }

  Future<void> pauseAll() async {
    await start();
    final downloads = await _repository.listByStatuses({
      DownloadStatus.active,
      DownloadStatus.queued,
    });
    for (final download in downloads) {
      await pause(download.id);
    }
  }

  Future<void> resumeQueued() async {
    await start();
    final settings = await _repository.getSettings();
    final active = await _repository.listByStatuses({DownloadStatus.active});
    var slots = settings.maxActiveDownloads - active.length;
    if (slots <= 0) return;

    final queued = await _repository.listByStatuses({DownloadStatus.queued});
    for (final download in queued) {
      if (slots <= 0) return;
      await _startEntity(download);
      slots--;
    }
  }

  Future<void> reorderQueue(List<String> ids) async {
    await start();
    await _repository.reorderQueue(ids);
    final queued = await _repository.listByStatuses({DownloadStatus.queued});
    for (var i = 0; i < queued.length; i++) {
      final gid = queued[i].gid;
      if (gid != null) await _engine.changePosition(gid, i);
    }
  }

  Future<void> refresh() async {
    if (_started && !await _engine.isHealthy) {
      _started = false;
      await start();
      return;
    }
    if (!_started) return;
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _refresh();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> resetEngineSession() => _engine.resetSession();

  Future<void> _refreshSafely() async {
    try {
      await refresh();
    } catch (error) {
      _diagnostics?.error('Refresh failed: $error');
      stderr.writeln('[geonode] refresh failed: $error');
    }
  }

  Future<void> _refresh() async {
    final statuses = <Aria2Status>[
      ...await _engine.tellActive(),
      ...await _engine.tellWaiting(),
      ...await _engine.tellStopped(),
    ];
    for (final status in statuses) {
      final updated = await _repository.updateFromAria2(status);
      if (!updated) await _handleUnmatchedEngineStatus(status);
    }
    await _reconcileStaleExtractorJobs(statuses);
    await _fillQueuedMetadata();
    await resumeQueued();
  }

  /// yt-dlp jobs live only in memory; after an engine recreate their gids vanish.
  Future<void> _reconcileStaleExtractorJobs(List<Aria2Status> statuses) async {
    final knownGids = {for (final status in statuses) status.gid};
    final active = await _repository.listByStatuses({
      DownloadStatus.active,
      DownloadStatus.queued,
    });
    for (final download in active) {
      final gid = download.gid;
      if (gid == null || !gid.startsWith('ytdlp:')) continue;
      if (knownGids.contains(gid)) continue;
      _diagnostics?.warn(
        'Re-queueing download after missing yt-dlp job: ${download.url}',
      );
      await _repository.clearRetryState(download.id);
      await _repository.updateStatus(download.id, DownloadStatus.queued);
    }
  }

  Future<void> _handleUnmatchedEngineStatus(Aria2Status status) async {
    if (status.status == 'active') {
      await _repository.attachStatusToMatchingDownload(status);
    } else if (status.status == 'waiting') {
      await _removeDuplicateWaitingDownload(status);
    }
  }

  Future<void> _fillQueuedMetadata() async {
    final downloads = await _repository.listQueuedMissingMetadata();
    for (final download in downloads) {
      if (!_metadataProbeAttempts.add(download.id)) continue;
      if (isExtractorDownloadOptions(download.optionsJson)) continue;
      final metadata = await _probe.probe(
        NewDownload(
          url: download.url,
          directory: download.directory,
          fileName: download.fileName ?? '',
          split: download.split,
          startImmediately: false,
          headers: _headersFor(download),
        ),
      );
      await _repository.updateMetadata(download.id, metadata);
    }
  }

  Future<void> _removeDuplicateWaitingDownload(Aria2Status status) async {
    final existing = await _repository.findMatchingDownload(status);
    if (existing == null || existing.gid == status.gid) return;
    if (existing.status != DownloadStatus.active.name) return;
    _diagnostics?.warn(
      'Removing duplicate engine queue entry ${status.gid} '
      'for ${existing.url}',
    );
    try {
      await _engine.remove(status.gid);
      stderr.writeln(
        '[geonode] removed duplicate engine queue entry ${status.gid} for ${existing.url}',
      );
    } catch (error) {
      _diagnostics?.error('Failed to remove duplicate ${status.gid}: $error');
      stderr.writeln(
        '[geonode] failed to remove duplicate engine queue entry ${status.gid}: $error',
      );
    }
  }

  Future<void> shutdown() async {
    _diagnostics?.info('Shutting down…');
    _pollTimer?.cancel();
    _pollTimer = null;
    await _engine.shutdown();
    _started = false;
    _diagnostics?.info('Shutdown complete.');
  }

  void dispose() {
    _pollTimer?.cancel();
  }

  Future<void> _startEntity(DownloadEntity entity) async {
    try {
      _ensureExtractorOptions(entity);
      if (entity.gid != null) {
        final status = await _engine.tellStatus(entity.gid!);
        final restarted = status.status == 'error' &&
            (status.errorMessage?.contains('engine restarted') ?? false);
        if (restarted) {
          await _repository.clearRetryState(entity.id);
          entity = (await _repository.findById(entity.id)) ?? entity;
        } else {
          await _repository.updateFromAria2(status);
          return;
        }
      }

      if (entity.gid != null) {
        final status = await _engine.tellStatus(entity.gid!);
        await _repository.updateFromAria2(status);
        return;
      }

      final gid = await _engine.addUri(
        url: entity.url,
        directory: entity.directory,
        split: entity.split,
        fileName: entity.fileName,
        headers: _headersFor(entity),
        optionsJson: _optionsFor(entity),
      );
      _diagnostics?.info('Download queued: ${entity.url} → gid $gid');
      stderr.writeln('[geonode] queued ${entity.url} as engine gid $gid');
      await _repository.attachGid(entity.id, gid);
      final status = await _engine.tellStatus(gid);
      await _repository.updateFromAria2(status);
    } catch (error) {
      _diagnostics?.error('Failed to add ${entity.url}: $error');
      stderr.writeln('[geonode] failed to add ${entity.url}: $error');
      final aria2Code = error is Aria2Exception ? error.code : null;
      await _repository.updateStatus(
        entity.id,
        DownloadStatus.error,
        error: error.toString(),
        aria2ErrorCode: aria2Code,
      );
      rethrow;
    }
  }

  Future<void> _deleteDownloadedFiles(DownloadEntity entity) async {
    final contentUri = entity.contentUri;
    if (contentUri != null && contentUri.isNotEmpty) {
      // Android MediaStore cleanup is handled by the native engine remove path.
      return;
    }

    final fileName = entity.fileName ?? _fileNameFromUrl(entity.url);
    if (fileName == null || fileName.trim().isEmpty) return;

    final file = File(p.join(entity.directory, fileName));
    await _deleteIfExists(file);
    await _deleteIfExists(File('${file.path}.aria2'));
    await _deleteIfExists(File('${file.path}.part'));
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  String? _fileNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final basename = p.basename(path);
    return basename.isEmpty ? null : basename;
  }

  /// Blocks downloading TikTok/IG/FB/YouTube page URLs as raw HTTP files
  /// (which produces extension-less IDs and tiny HTML payloads).
  void _ensureExtractorOptions(DownloadEntity entity) {
    final kind = UrlClassifier.classify(entity.url);
    final needsOptions = kind == DownloadUrlKind.tiktok ||
        kind == DownloadUrlKind.instagram ||
        kind == DownloadUrlKind.facebook ||
        kind == DownloadUrlKind.youtube ||
        kind == DownloadUrlKind.youtubePlaylist;
    if (!needsOptions) return;
    if (isExtractorDownloadOptions(entity.optionsJson)) return;
    throw StateError(
      'This URL needs format selection before download. '
      'Use Add Download → Choose format.',
    );
  }

  bool _shouldProbe(NewDownload input) {
    final kind = input.options['kind']?.toString();
    if (kind == YoutubeDownloadOptions.kind ||
        kind == FacebookDownloadOptions.kind ||
        kind == InstagramDownloadOptions.kind ||
        kind == TikTokDownloadOptions.kind) {
      return false;
    }
    // Never probe extractor site pages as if they were direct files.
    final urlKind = UrlClassifier.classify(input.url);
    return urlKind == DownloadUrlKind.direct;
  }

  Map<String, Object?>? _optionsFor(DownloadEntity entity) {
    final options = entity.optionsJson;
    if (options == null || options.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(options);
      if (decoded is! Map) return null;
      return decoded.cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _headersFor(DownloadEntity entity) {
    final options = entity.optionsJson;
    if (options == null || options.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(options);
      if (decoded is! Map) return const {};
      final headers = decoded['headers'];
      if (headers is! Map) return const {};
      return headers.map((key, value) {
        return MapEntry(key.toString(), value.toString());
      });
    } catch (_) {
      return const {};
    }
  }
}

class DownloadAlreadyExistsException implements Exception {
  const DownloadAlreadyExistsException(this.downloadId);

  final String downloadId;

  @override
  String toString() {
    return 'This download is already in the list. Remove it or use Retry.';
  }
}

class DeleteDownloadedFilesException implements Exception {
  const DeleteDownloadedFilesException(this.cause);

  final Object cause;

  @override
  String toString() {
    return 'Removed from Geonode Download Manager, but could not delete downloaded files: $cause';
  }
}
