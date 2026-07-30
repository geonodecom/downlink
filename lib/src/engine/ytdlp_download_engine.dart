import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../aria2/aria2_models.dart';
import '../facebook/facebook_models.dart';
import '../facebook/facebook_session.dart';
import '../instagram/instagram_models.dart';
import '../instagram/instagram_session.dart';
import '../tiktok/tiktok_models.dart';
import '../tiktok/tiktok_session.dart';
import '../ytdlp/ytdlp_executable.dart';
import '../ytdlp/ytdlp_models.dart';
import '../ytdlp/ytdlp_progress.dart';
import 'download_engine.dart';

class _YtdlpJob {
  _YtdlpJob({
    required this.gid,
    required this.url,
    required this.directory,
    required this.fileName,
    required this.options,
    required this.outputPath,
    required this.outputTemplate,
  });

  final String gid;
  final String url;
  final String directory;
  String fileName;
  final YoutubeDownloadOptions options;
  String outputPath;
  final String outputTemplate;
  Process? process;
  var status = 'waiting';
  var downloadedBytes = 0;
  var totalBytes = 0;
  var speed = 0;
  String? errorMessage;
  String? contentUri;
}

/// [DownloadEngine] that runs yt-dlp subprocesses for YouTube downloads.
class YtdlpDownloadEngine implements DownloadEngine {
  YtdlpDownloadEngine({
    YtdlpExecutableResolver? resolver,
    Future<String?> Function(String sourcePath, String displayName)? publishFile,
    this.facebookCookieArgs = const FacebookCookieArgs(),
    Future<FacebookCookieArgs> Function()? facebookCookieArgsProvider,
    FacebookSession? facebookSession,
    this.instagramCookieArgs = const InstagramCookieArgs(),
    Future<InstagramCookieArgs> Function()? instagramCookieArgsProvider,
    InstagramSession? instagramSession,
    this.tiktokCookieArgs = const TikTokCookieArgs(),
    Future<TikTokCookieArgs> Function()? tiktokCookieArgsProvider,
    TikTokSession? tiktokSession,
  }) : _resolver = resolver ?? YtdlpExecutableResolver(),
       _publishFile = publishFile ?? _defaultPublishFile,
       _facebookCookieArgsProvider = facebookCookieArgsProvider,
       _facebookSession = facebookSession ?? FacebookSession(),
       _instagramCookieArgsProvider = instagramCookieArgsProvider,
       _instagramSession = instagramSession ?? InstagramSession(),
       _tiktokCookieArgsProvider = tiktokCookieArgsProvider,
       _tiktokSession = tiktokSession ?? TikTokSession();

  final YtdlpExecutableResolver _resolver;
  final Future<String?> Function(String sourcePath, String displayName)
  _publishFile;
  final FacebookCookieArgs facebookCookieArgs;
  final Future<FacebookCookieArgs> Function()? _facebookCookieArgsProvider;
  final FacebookSession _facebookSession;
  final InstagramCookieArgs instagramCookieArgs;
  final Future<InstagramCookieArgs> Function()? _instagramCookieArgsProvider;
  final InstagramSession _instagramSession;
  final TikTokCookieArgs tiktokCookieArgs;
  final Future<TikTokCookieArgs> Function()? _tiktokCookieArgsProvider;
  final TikTokSession _tiktokSession;
  final Map<String, _YtdlpJob> _jobs = {};
  var _started = false;
  String _downloadDirectory = '';
  String _ytdlpOverride = '';
  String _ffmpegOverride = '';

  static Future<String?> _defaultPublishFile(
    String sourcePath,
    String displayName,
  ) async {
    if (!Platform.isAndroid) return null;
    const channel = MethodChannel('com.geonode.downlink/engine');
    try {
      final uri = await channel.invokeMethod<String>('publishFile', {
        'sourcePath': sourcePath,
        'displayName': displayName,
      });
      return uri;
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
    _ytdlpOverride = ytdlpPath;
    _ffmpegOverride = ffmpegPath;
    _started = true;
  }

  @override
  Future<void> shutdown() async {
    for (final job in _jobs.values.toList()) {
      await _stopJob(job, markRemoved: true);
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
    final options = _extractorOptions(optionsJson);
    if (options == null) {
      throw StateError('yt-dlp engine requires youtube or facebook options.');
    }

    final gid = 'ytdlp:${const Uuid().v4()}';
    final targetDirectory = directory.isNotEmpty ? directory : _downloadDirectory;
    final resolvedName = _ensureMediaFileName(
      fileName?.trim().isNotEmpty == true
          ? fileName!.trim()
          : options.sanitizedFileName,
      fallbackExt: options.ext,
    );
    final outputPath = await _uniqueOutputPath(
      p.join(targetDirectory, resolvedName),
    );
    final uniqueName = p.basename(outputPath);
    // Use %(ext)s so yt-dlp always writes a real media extension (TikTok/etc).
    final stem = p.basenameWithoutExtension(uniqueName);
    final outputTemplate = p.join(targetDirectory, '$stem.%(ext)s');

    final job = _YtdlpJob(
      gid: gid,
      url: url,
      directory: targetDirectory,
      fileName: uniqueName,
      options: options,
      outputPath: outputPath,
      outputTemplate: outputTemplate,
    );
    _jobs[gid] = job;
    unawaited(_runJob(job));
    return gid;
  }

  @override
  Future<void> pause(String gid) async {
    final job = _jobs[gid];
    if (job == null) return;
    await _stopJob(job);
    job.status = 'paused';
  }

  @override
  Future<void> unpause(String gid) async {
    final job = _jobs[gid];
    if (job == null) return;
    if (job.status == 'complete' || job.status == 'error') return;
    job.status = 'waiting';
    unawaited(_runJob(job));
  }

  @override
  Future<void> remove(String gid) async {
    final job = _jobs.remove(gid);
    if (job == null) return;
    await _stopJob(job, markRemoved: true);
  }

  @override
  Future<void> changePosition(String gid, int position) async {}

  @override
  Future<Aria2Status> tellStatus(String gid) async {
    final job = _jobs[gid];
    if (job == null) {
      // Engine may have been recreated (e.g. settings save). Surface a clear
      // recoverable error instead of crashing the poll loop.
      return Aria2Status(
        gid: gid,
        status: 'error',
        totalLength: 0,
        completedLength: 0,
        downloadSpeed: 0,
        connections: 0,
        pieceLength: 0,
        numPieces: 0,
        bitfield: null,
        errorCode: null,
        errorMessage:
            'Download engine restarted. Tap Retry to continue this download.',
        files: const [],
      );
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
      await _stopJob(job, markRemoved: true);
    }
    _jobs.clear();
  }

  Future<void> _runJob(_YtdlpJob job) async {
    if (job.status == 'active') return;

    try {
      final binaries = await _resolver.resolve(
        ytdlpOverride: _ytdlpOverride,
        ffmpegOverride: _ffmpegOverride,
      );
      final outputDir = Directory(job.directory);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      job.status = 'active';
      job.errorMessage = null;

      final facebookArgsProvider = _facebookCookieArgsProvider;
      final facebookSettings = facebookArgsProvider != null
          ? await facebookArgsProvider()
          : facebookCookieArgs;
      final instagramArgsProvider = _instagramCookieArgsProvider;
      final instagramSettings = instagramArgsProvider != null
          ? await instagramArgsProvider()
          : instagramCookieArgs;
      final tiktokArgsProvider = _tiktokCookieArgsProvider;
      final tiktokSettings = tiktokArgsProvider != null
          ? await tiktokArgsProvider()
          : tiktokCookieArgs;
      final args = [
        '--no-playlist',
        '--continue',
        '--newline',
        '--progress',
        '--progress-template',
        'progress:%(progress.downloaded_bytes)s:%(progress.total_bytes)s:%(progress.speed)s:%(progress.eta)s',
        '--ffmpeg-location',
        p.dirname(binaries.ffmpegPath),
        '--format',
        job.options.formatId,
        '--merge-output-format',
        'mp4',
        '-o',
        job.outputTemplate,
        ...await resolveYtdlpSiteCookieArgs(
          url: job.url,
          facebook: facebookSettings,
          facebookSession: _facebookSession,
          instagram: instagramSettings,
          instagramSession: _instagramSession,
          tiktok: tiktokSettings,
          tiktokSession: _tiktokSession,
        ),
        job.url,
      ];

      job.process = await Process.start(
        binaries.ytdlpPath,
        args,
        environment: const {
          'PYTHONIOENCODING': 'utf-8',
          'PYTHONUTF8': '1',
        },
        includeParentEnvironment: true,
      );

      final stderrBuffer = StringBuffer();
      const decoder = Utf8Decoder(allowMalformed: true);
      final stdoutDone = job.process!.stdout
          .transform(decoder)
          .transform(const LineSplitter())
          .map((line) {
            _applyProgressLine(job, line);
          })
          .drain();
      final stderrDone = job.process!.stderr
          .transform(decoder)
          .transform(const LineSplitter())
          .map((line) {
            stderrBuffer.writeln(line);
            _applyProgressLine(job, line);
          })
          .drain();

      await Future.wait([stdoutDone, stderrDone]);

      final exitCode = await job.process!.exitCode;
      job.process = null;

      if (exitCode == 0) {
        await _finalizeJob(job);
        job.status = 'complete';
        return;
      }

      if (job.status == 'paused' || job.status == 'removed') {
        return;
      }

      job.status = 'error';
      job.errorMessage = stderrBuffer.toString().trim().isEmpty
          ? 'yt-dlp failed with exit code $exitCode.'
          : stderrBuffer.toString().trim();
    } catch (error) {
      if (job.status == 'paused' || job.status == 'removed') return;
      job.status = 'error';
      job.errorMessage = error.toString();
    }
  }

  Future<String> _uniqueOutputPath(String path) async {
    if (!await File(path).exists()) return path;
    final dir = p.dirname(path);
    final ext = p.extension(path);
    final base = p.basenameWithoutExtension(path);
    for (var i = 1; i < 1000; i++) {
      final candidate = p.join(dir, '$base ($i)$ext');
      if (!await File(candidate).exists()) return candidate;
    }
    return p.join(dir, '$base-${const Uuid().v4()}$ext');
  }

  String _ensureMediaFileName(String name, {required String fallbackExt}) {
    final cleaned = name.trim();
    final safeExt = fallbackExt.trim().isEmpty ? 'mp4' : fallbackExt.trim();
    final withoutDot = safeExt.startsWith('.') ? safeExt.substring(1) : safeExt;
    if (cleaned.isEmpty) return 'video.$withoutDot';
    final existing = p.extension(cleaned);
    if (existing.isNotEmpty && existing != '.') return cleaned;
    final stem = cleaned.endsWith('.')
        ? cleaned.substring(0, cleaned.length - 1)
        : cleaned;
    return '$stem.$withoutDot';
  }

  Future<void> _finalizeJob(_YtdlpJob job) async {
    final resolved = await _resolveOutputFile(job);
    if (resolved == null) return;

    job.outputPath = resolved.path;
    job.fileName = p.basename(resolved.path);
    job.totalBytes = await resolved.length();
    job.downloadedBytes = job.totalBytes;

    final published = await _publishFile(job.outputPath, job.fileName);
    if (published != null && published.isNotEmpty) {
      job.contentUri = published;
      try {
        await resolved.delete();
      } catch (_) {}
    }
  }

  Future<File?> _resolveOutputFile(_YtdlpJob job) async {
    final expected = File(job.outputPath);
    if (await expected.exists()) return expected;

    final stem = p.basenameWithoutExtension(job.outputPath);
    final dir = Directory(job.directory);
    if (!await dir.exists()) return null;

    File? best;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.endsWith('.part') || name.endsWith('.ytdl')) continue;
      if (p.basenameWithoutExtension(name) != stem) continue;
      best ??= entity;
      if (p.extension(name).toLowerCase() == '.mp4') {
        return entity;
      }
    }
    return best;
  }

  Future<void> _stopJob(_YtdlpJob job, {bool markRemoved = false}) async {
    final process = job.process;
    if (process != null) {
      process.kill();
      await process.exitCode.catchError((_) => -1);
      job.process = null;
    }
    if (markRemoved) {
      job.status = 'removed';
    }
  }

  void _applyProgressLine(_YtdlpJob job, String line) {
    final progress =
        parseYtdlpProgressLine(line) ?? parseLegacyYtdlpProgressLine(line);
    if (progress == null) return;
    job.downloadedBytes = progress.downloadedBytes;
    job.totalBytes = progress.totalBytes;
    job.speed = progress.speedBytesPerSecond;
  }

  Aria2Status _toStatus(_YtdlpJob job) {
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

  YoutubeDownloadOptions? _extractorOptions(Map<String, Object?>? optionsJson) {
    if (optionsJson == null) return null;
    final kind = optionsJson['kind']?.toString();
    if (kind == YoutubeDownloadOptions.kind) {
      return YoutubeDownloadOptions.fromJson(optionsJson);
    }
    if (kind == FacebookDownloadOptions.kind) {
      final facebook = FacebookDownloadOptions.fromJson(optionsJson);
      return YoutubeDownloadOptions(
        formatId: facebook.formatId,
        title: facebook.title,
        ext: facebook.ext,
      );
    }
    if (kind == InstagramDownloadOptions.kind) {
      final instagram = InstagramDownloadOptions.fromJson(optionsJson);
      return YoutubeDownloadOptions(
        formatId: instagram.formatId,
        title: instagram.title,
        ext: instagram.ext,
      );
    }
    if (kind == TikTokDownloadOptions.kind) {
      final tiktok = TikTokDownloadOptions.fromJson(optionsJson);
      return YoutubeDownloadOptions(
        formatId: tiktok.formatId,
        title: tiktok.title,
        ext: tiktok.ext,
      );
    }
    return null;
  }
}
