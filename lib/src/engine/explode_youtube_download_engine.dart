import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../aria2/aria2_models.dart';
import '../ytdlp/android_ffmpeg.dart';
import '../ytdlp/youtube_format_id.dart';
import '../ytdlp/ytdlp_models.dart';
import 'download_engine.dart';

class _ExplodeJob {
  _ExplodeJob({
    required this.gid,
    required this.url,
    required this.directory,
    required this.fileName,
    required this.options,
    required this.outputPath,
  });

  final String gid;
  final String url;
  final String directory;
  final String fileName;
  final YoutubeDownloadOptions options;
  final String outputPath;
  var status = 'waiting';
  var downloadedBytes = 0;
  var totalBytes = 0;
  var speed = 0;
  String? errorMessage;
  String? contentUri;
  var cancelRequested = false;
  Process? ffmpegProcess;
  DateTime? _speedSampleAt;
  int _speedSampleBytes = 0;
}

/// Android YouTube downloads via youtube_explode_dart (no yt-dlp process).
class ExplodeYoutubeDownloadEngine implements DownloadEngine {
  ExplodeYoutubeDownloadEngine({
    Future<String?> Function(String sourcePath, String displayName)? publishFile,
    Future<String> Function()? resolveFfmpeg,
  }) : _publishFile = publishFile ?? _defaultPublishFile,
       _resolveFfmpeg = resolveFfmpeg ?? resolveAndroidFfmpegPath;

  final Future<String?> Function(String sourcePath, String displayName)
  _publishFile;
  final Future<String> Function() _resolveFfmpeg;
  final Map<String, _ExplodeJob> _jobs = {};
  var _started = false;
  String _downloadDirectory = '';

  static final _clients = [
    YoutubeApiClient.androidVr,
    YoutubeApiClient.ios,
    YoutubeApiClient.safari,
  ];

  static Future<String?> _defaultPublishFile(
    String sourcePath,
    String displayName,
  ) async {
    if (!Platform.isAndroid) return null;
    const channel = MethodChannel('com.geonode.downlink/engine');
    try {
      return await channel.invokeMethod<String>('publishFile', {
        'sourcePath': sourcePath,
        'displayName': displayName,
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> get isHealthy async => _started;

  @override
  Future<void> start({
    required String downloadDirectory,
    required int maxActiveDownloads,
    required int defaultSplit,
    String executableOverride = '',
    String ytdlpPath = '',
    String ffmpegPath = '',
  }) async {
    _downloadDirectory = downloadDirectory;
    _started = true;
  }

  @override
  Future<void> shutdown() async {
    for (final job in _jobs.values.toList()) {
      await _cancelJob(job, markRemoved: true);
    }
    _jobs.clear();
    _started = false;
  }

  @override
  Future<String> addUri({
    required String url,
    required String directory,
    required int split,
    String? fileName,
    Map<String, String> headers = const {},
    int? position,
    Map<String, Object?>? optionsJson,
  }) async {
    final options = _youtubeOptions(optionsJson);
    if (options == null) {
      throw StateError('YouTube engine requires youtube options.');
    }

    final gid = 'ytdlp:${const Uuid().v4()}';
    final targetDirectory =
        directory.isNotEmpty ? directory : _downloadDirectory;
    final resolvedName = fileName?.trim().isNotEmpty == true
        ? fileName!.trim()
        : options.sanitizedFileName;
    final outputPath = p.join(targetDirectory, resolvedName);

    final job = _ExplodeJob(
      gid: gid,
      url: url,
      directory: targetDirectory,
      fileName: resolvedName,
      options: options,
      outputPath: outputPath,
    );
    _jobs[gid] = job;
    unawaited(_runJob(job));
    return gid;
  }

  @override
  Future<void> pause(String gid) async {
    final job = _jobs[gid];
    if (job == null) return;
    await _cancelJob(job);
    job.status = 'paused';
  }

  @override
  Future<void> unpause(String gid) async {
    final job = _jobs[gid];
    if (job == null) return;
    if (job.status == 'complete' || job.status == 'error') return;
    job.cancelRequested = false;
    job.status = 'waiting';
    unawaited(_runJob(job));
  }

  @override
  Future<void> remove(String gid) async {
    final job = _jobs.remove(gid);
    if (job == null) return;
    await _cancelJob(job, markRemoved: true);
  }

  @override
  Future<void> changePosition(String gid, int position) async {}

  @override
  Future<Aria2Status> tellStatus(String gid) async {
    final job = _jobs[gid];
    if (job == null) {
      throw StateError('Unknown YouTube job: $gid');
    }
    return _toStatus(job);
  }

  @override
  Future<List<Aria2Status>> tellActive() async {
    return _jobs.values
        .where((job) => job.status == 'active')
        .map(_toStatus)
        .toList();
  }

  @override
  Future<List<Aria2Status>> tellWaiting({int offset = 0, int limit = 100}) async {
    return _jobs.values
        .where((job) => job.status == 'waiting')
        .skip(offset)
        .take(limit)
        .map(_toStatus)
        .toList();
  }

  @override
  Future<List<Aria2Status>> tellStopped({int offset = 0, int limit = 100}) async {
    return _jobs.values
        .where(
          (job) =>
              job.status == 'complete' ||
              job.status == 'error' ||
              job.status == 'paused' ||
              job.status == 'removed',
        )
        .skip(offset)
        .take(limit)
        .map(_toStatus)
        .toList();
  }

  @override
  Future<void> resetSession() async {
    for (final job in _jobs.values.toList()) {
      await _cancelJob(job, markRemoved: true);
    }
    _jobs.clear();
  }

  Future<void> _runJob(_ExplodeJob job) async {
    if (job.status == 'active') return;

    final yt = YoutubeExplode();
    final tempFiles = <File>[];
    try {
      final outputDir = Directory(job.directory);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      job.status = 'active';
      job.errorMessage = null;
      job.cancelRequested = false;
      job.downloadedBytes = 0;
      job.speed = 0;
      job._speedSampleAt = DateTime.now();
      job._speedSampleBytes = 0;

      final video = await yt.videos.get(job.url);
      final manifest = await yt.videos.streamsClient.getManifest(
        video.id,
        ytClients: _clients,
      );

      final merge = parseMergeFormatId(job.options.formatId);
      if (merge != null) {
        await _downloadAndMerge(
          job: job,
          yt: yt,
          manifest: manifest,
          videoTag: merge.videoTag,
          audioTag: merge.audioTag,
          tempFiles: tempFiles,
        );
      } else {
        await _downloadSingle(
          job: job,
          yt: yt,
          manifest: manifest,
          tempFiles: tempFiles,
        );
      }

      if (job.cancelRequested) {
        await _deleteFiles([File(job.outputPath), ...tempFiles]);
        if (job.status != 'removed') {
          job.status = 'paused';
        }
        return;
      }

      await _finalizeJob(job);
      job.status = 'complete';
    } catch (error) {
      if (job.status == 'paused' || job.status == 'removed') return;
      job.status = 'error';
      job.errorMessage = error.toString();
      await _deleteFiles(tempFiles);
    } finally {
      yt.close();
      if (job.status == 'complete') {
        await _deleteFiles(tempFiles);
      }
    }
  }

  Future<void> _downloadSingle({
    required _ExplodeJob job,
    required YoutubeExplode yt,
    required StreamManifest manifest,
    required List<File> tempFiles,
  }) async {
    final tag = int.tryParse(job.options.formatId);
    if (tag == null) {
      throw StateError('Invalid format id: ${job.options.formatId}');
    }

    final streamInfo = _findStream(manifest, tag);
    if (streamInfo == null) {
      throw StateError(
        'Selected format ${job.options.formatId} is no longer available.',
      );
    }

    job.totalBytes = streamInfo.size.totalBytes;
    await _downloadStreamToFile(
      job: job,
      yt: yt,
      streamInfo: streamInfo,
      target: File(job.outputPath),
    );
  }

  Future<void> _downloadAndMerge({
    required _ExplodeJob job,
    required YoutubeExplode yt,
    required StreamManifest manifest,
    required int videoTag,
    required int audioTag,
    required List<File> tempFiles,
  }) async {
    final videoInfo = _findStream(manifest, videoTag);
    final audioInfo = _findStream(manifest, audioTag);
    if (videoInfo == null || audioInfo == null) {
      throw StateError(
        'Selected format ${job.options.formatId} is no longer available.',
      );
    }

    final videoExt = videoInfo.container.name;
    final audioExt = audioInfo.container.name;
    final videoTemp = File(
      p.join(job.directory, '.${job.gid.hashCode}.v.$videoExt'),
    );
    final audioTemp = File(
      p.join(job.directory, '.${job.gid.hashCode}.a.$audioExt'),
    );
    tempFiles.addAll([videoTemp, audioTemp]);

    job.totalBytes = videoInfo.size.totalBytes + audioInfo.size.totalBytes;

    await _downloadStreamToFile(
      job: job,
      yt: yt,
      streamInfo: videoInfo,
      target: videoTemp,
    );
    if (job.cancelRequested) return;

    await _downloadStreamToFile(
      job: job,
      yt: yt,
      streamInfo: audioInfo,
      target: audioTemp,
    );
    if (job.cancelRequested) return;

    await _mergeTracks(
      job: job,
      videoPath: videoTemp.path,
      audioPath: audioTemp.path,
      outputPath: job.outputPath,
    );
  }

  Future<void> _mergeTracks({
    required _ExplodeJob job,
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    // Prefer Android MediaMuxer — bundled libffmpeg.so often SIGSEGVs on
    // 16 KB page-size devices/emulators.
    try {
      await _runMediaMuxerMerge(
        videoPath: videoPath,
        audioPath: audioPath,
        outputPath: outputPath,
      );
      return;
    } catch (muxerError) {
      try {
        final ffmpegPath = await _resolveFfmpeg();
        await _runFfmpegMerge(
          job: job,
          ffmpegPath: ffmpegPath,
          videoPath: videoPath,
          audioPath: audioPath,
          outputPath: outputPath,
        );
      } catch (ffmpegError) {
        final detail = ffmpegError.toString();
        if (detail.contains('exit -11') ||
            detail.contains('SIGSEGV') ||
            detail.contains('code=-11')) {
          throw StateError(
            'Could not merge video and audio on this device. '
            'Try a muxed (single-file) format, or a lower MP4 quality. '
            '($muxerError)',
          );
        }
        throw StateError(
          'Merge failed. MediaMuxer: $muxerError; ffmpeg: $ffmpegError',
        );
      }
    }
  }

  Future<void> _runMediaMuxerMerge({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    const channel = MethodChannel('com.geonode.downlink/engine');
    await channel.invokeMethod<String>('mergeAv', {
      'videoPath': videoPath,
      'audioPath': audioPath,
      'outputPath': outputPath,
    });
    final out = File(outputPath);
    if (!await out.exists() || await out.length() == 0) {
      throw StateError('MediaMuxer produced an empty output file.');
    }
  }

  StreamInfo? _findStream(StreamManifest manifest, int tag) {
    for (final stream in manifest.streams) {
      if (stream.tag == tag) return stream;
    }
    return null;
  }

  Future<void> _downloadStreamToFile({
    required _ExplodeJob job,
    required YoutubeExplode yt,
    required StreamInfo streamInfo,
    required File target,
  }) async {
    final sink = target.openWrite();
    try {
      await for (final chunk in yt.videos.streamsClient.get(streamInfo)) {
        if (job.cancelRequested) break;
        sink.add(chunk);
        job.downloadedBytes += chunk.length;
        _updateSpeed(job);
      }
    } finally {
      await sink.close();
    }
  }

  Future<void> _runFfmpegMerge({
    required _ExplodeJob job,
    required String ffmpegPath,
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    Future<ProcessResult> run(List<String> args) async {
      final libDir = p.dirname(ffmpegPath);
      final environment = Map<String, String>.from(Platform.environment);
      final existing = environment['LD_LIBRARY_PATH'];
      environment['LD_LIBRARY_PATH'] = existing == null || existing.isEmpty
          ? libDir
          : '$libDir:$existing';

      job.ffmpegProcess = await Process.start(
        ffmpegPath,
        args,
        environment: environment,
        workingDirectory: libDir,
      );
      final stderrBuffer = StringBuffer();
      final stderrDone = job.ffmpegProcess!.stderr
          .transform(utf8.decoder)
          .listen(stderrBuffer.write)
          .asFuture<void>();
      final stdoutDone = job.ffmpegProcess!.stdout.drain<void>();
      final exitCode = await job.ffmpegProcess!.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      job.ffmpegProcess = null;
      return ProcessResult(0, exitCode, '', stderrBuffer.toString());
    }

    var result = await run([
      '-y',
      '-i',
      videoPath,
      '-i',
      audioPath,
      '-c',
      'copy',
      '-map',
      '0:v:0',
      '-map',
      '1:a:0',
      outputPath,
    ]);

    if (job.cancelRequested) return;

    if (result.exitCode != 0) {
      result = await run([
        '-y',
        '-i',
        videoPath,
        '-i',
        audioPath,
        '-c:v',
        'copy',
        '-c:a',
        'aac',
        '-map',
        '0:v:0',
        '-map',
        '1:a:0',
        outputPath,
      ]);
    }

    if (job.cancelRequested) return;

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      throw StateError(
        stderr.isEmpty
            ? 'ffmpeg failed to merge streams (exit ${result.exitCode}).'
            : stderr,
      );
    }
  }

  Future<void> _cancelJob(_ExplodeJob job, {bool markRemoved = false}) async {
    job.cancelRequested = true;
    final process = job.ffmpegProcess;
    if (process != null) {
      process.kill();
      await process.exitCode.catchError((_) => -1);
      job.ffmpegProcess = null;
    }
    if (markRemoved) {
      job.status = 'removed';
    }
  }

  void _updateSpeed(_ExplodeJob job) {
    final now = DateTime.now();
    final started = job._speedSampleAt;
    if (started == null) {
      job._speedSampleAt = now;
      job._speedSampleBytes = job.downloadedBytes;
      return;
    }
    final elapsedMs = now.difference(started).inMilliseconds;
    if (elapsedMs < 500) return;
    final delta = job.downloadedBytes - job._speedSampleBytes;
    job.speed = ((delta * 1000) / elapsedMs).round();
    job._speedSampleAt = now;
    job._speedSampleBytes = job.downloadedBytes;
  }

  Future<void> _finalizeJob(_ExplodeJob job) async {
    final file = File(job.outputPath);
    if (!await file.exists()) return;

    job.totalBytes = await file.length();
    job.downloadedBytes = job.totalBytes;
    job.speed = 0;

    final published = await _publishFile(job.outputPath, job.fileName);
    if (published != null && published.isNotEmpty) {
      job.contentUri = published;
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<void> _deleteFiles(Iterable<File> files) async {
    for (final file in files) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Aria2Status _toStatus(_ExplodeJob job) {
    final path = job.contentUri ?? job.outputPath;
    return Aria2Status(
      gid: job.gid,
      status: job.status,
      totalLength: job.totalBytes,
      completedLength: job.downloadedBytes,
      downloadSpeed: job.speed,
      connections: 1,
      pieceLength: 0,
      numPieces: 0,
      bitfield: null,
      errorCode: null,
      errorMessage: job.errorMessage,
      files: [
        Aria2File(
          path: path,
          length: job.totalBytes,
          completedLength: job.downloadedBytes,
          uris: [job.url],
        ),
      ],
    );
  }

  YoutubeDownloadOptions? _youtubeOptions(Map<String, Object?>? optionsJson) {
    if (optionsJson == null) return null;
    if (optionsJson['kind']?.toString() != YoutubeDownloadOptions.kind) {
      return null;
    }
    return YoutubeDownloadOptions.fromJson(optionsJson);
  }
}
