import 'dart:convert';
import 'dart:io';

import '../facebook/facebook_session.dart';
import '../instagram/instagram_session.dart';
import 'youtube_metadata_client.dart';
import 'ytdlp_executable.dart';
import 'ytdlp_models.dart';

class YtdlpException implements Exception {
  YtdlpException(this.message, {this.exitCode});

  final String message;
  final int? exitCode;

  @override
  String toString() => message;
}

class YtdlpClient implements YoutubeMetadataClient {
  YtdlpClient({
    YtdlpExecutableResolver? resolver,
    this.ytdlpOverride = '',
    this.ffmpegOverride = '',
    this.facebookCookieArgs = const FacebookCookieArgs(),
    FacebookSession? facebookSession,
    this.instagramCookieArgs = const InstagramCookieArgs(),
    InstagramSession? instagramSession,
  }) : _resolver = resolver ?? YtdlpExecutableResolver(),
       _facebookSession = facebookSession ?? FacebookSession(),
       _instagramSession = instagramSession ?? InstagramSession();

  final YtdlpExecutableResolver _resolver;
  final String ytdlpOverride;
  final String ffmpegOverride;
  final FacebookCookieArgs facebookCookieArgs;
  final FacebookSession _facebookSession;
  final InstagramCookieArgs instagramCookieArgs;
  final InstagramSession _instagramSession;

  static final Map<String, String> _utf8ProcessEnvironment = {
    'PYTHONIOENCODING': 'utf-8',
    'PYTHONUTF8': '1',
  };

  @override
  Future<bool> checkHealth() {
    return _resolver.areAvailable(
      ytdlpOverride: ytdlpOverride,
      ffmpegOverride: ffmpegOverride,
    );
  }

  @override
  Future<YtdlpVideoInfo> fetchInfo(String url) async {
    final binaries = await _resolver.resolve(
      ytdlpOverride: ytdlpOverride,
      ffmpegOverride: ffmpegOverride,
    );

    final result = await _runYtdlp(binaries.ytdlpPath, [
      '--no-playlist',
      '--dump-single-json',
      '--skip-download',
      '--no-warnings',
      ...await _cookieArgs(url),
      url,
    ]);

    if (result.exitCode != 0) {
      throw YtdlpException(
        _friendlyAuthMessage(_stderrMessage(result)),
        exitCode: result.exitCode,
      );
    }

    final stdout = _decodeOutput(result.stdout).trim();
    if (stdout.isEmpty) {
      throw YtdlpException('yt-dlp returned no metadata for this URL.');
    }

    final decoded = jsonDecode(stdout);
    if (decoded is! Map) {
      throw YtdlpException('yt-dlp returned unexpected metadata.');
    }

    return YtdlpVideoInfo.fromJson(decoded.cast<String, Object?>());
  }

  @override
  Future<YtdlpPlaylistInfo> fetchPlaylist(String url) async {
    final binaries = await _resolver.resolve(
      ytdlpOverride: ytdlpOverride,
      ffmpegOverride: ffmpegOverride,
    );

    final result = await _runYtdlp(binaries.ytdlpPath, [
      '--flat-playlist',
      '--dump-single-json',
      '--skip-download',
      '--no-warnings',
      ...await _cookieArgs(url),
      url,
    ]);

    if (result.exitCode != 0) {
      throw YtdlpException(
        _friendlyAuthMessage(_stderrMessage(result)),
        exitCode: result.exitCode,
      );
    }

    final stdout = _decodeOutput(result.stdout).trim();
    if (stdout.isEmpty) {
      throw YtdlpException('yt-dlp returned no playlist metadata for this URL.');
    }

    final decoded = jsonDecode(stdout);
    if (decoded is! Map) {
      throw YtdlpException('yt-dlp returned unexpected playlist metadata.');
    }

    final playlist = YtdlpPlaylistInfo.fromJson(decoded.cast<String, Object?>());
    if (playlist.entries.isEmpty) {
      throw YtdlpException('This playlist has no downloadable videos.');
    }
    return playlist;
  }

  Future<List<String>> _cookieArgs(String url) {
    return resolveYtdlpSiteCookieArgs(
      url: url,
      facebook: facebookCookieArgs,
      facebookSession: _facebookSession,
      instagram: instagramCookieArgs,
      instagramSession: _instagramSession,
    );
  }

  Future<ProcessResult> _runYtdlp(String ytdlpPath, List<String> args) {
    return Process.run(
      ytdlpPath,
      args,
      environment: _utf8ProcessEnvironment,
      includeParentEnvironment: true,
      stdoutEncoding: null,
      stderrEncoding: null,
    );
  }

  String _stderrMessage(ProcessResult result) {
    final stderr = _decodeOutput(result.stderr).trim();
    if (stderr.isNotEmpty) return stderr;
    return 'yt-dlp failed with exit code ${result.exitCode}.';
  }

  String _friendlyAuthMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('login') ||
        lower.contains('cookie') ||
        lower.contains('private') ||
        lower.contains('unavailable')) {
      return '$message\n\n'
          'If this is a private video, open Settings → Facebook or Instagram '
          'and log in (or set cookies.txt / import from browser).';
    }
    return message;
  }

  static String _decodeOutput(Object? output) {
    if (output == null) return '';
    if (output is String) return output;
    if (output is List<int>) {
      try {
        return utf8.decode(output, allowMalformed: true);
      } catch (_) {
        return latin1.decode(output);
      }
    }
    return output.toString();
  }
}
