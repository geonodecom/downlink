import 'dart:io';

import '../aria2/aria2_models.dart';
import '../facebook/facebook_models.dart';
import '../facebook/facebook_session.dart';
import '../instagram/instagram_models.dart';
import '../instagram/instagram_session.dart';
import '../tiktok/tiktok_models.dart';
import '../tiktok/tiktok_session.dart';
import '../ytdlp/ytdlp_models.dart';
import 'download_engine.dart';
import 'ytdlp_download_engine.dart';

/// Routes downloads to yt-dlp or the platform HTTP engine based on options.
class CompositeDownloadEngine implements DownloadEngine {
  CompositeDownloadEngine({
    required DownloadEngine baseEngine,
    DownloadEngine? youtubeEngine,
    Future<String> Function()? facebookCookieHeader,
    Future<String> Function()? instagramCookieHeader,
    Future<String> Function()? tiktokCookieHeader,
  }) : _baseEngine = baseEngine,
       _youtubeEngine = youtubeEngine ?? YtdlpDownloadEngine(),
       _facebookCookieHeader =
           facebookCookieHeader ?? _defaultFacebookCookieHeader,
       _instagramCookieHeader =
           instagramCookieHeader ?? _defaultInstagramCookieHeader,
       _tiktokCookieHeader =
           tiktokCookieHeader ?? _defaultTiktokCookieHeader;

  final DownloadEngine _baseEngine;
  final DownloadEngine _youtubeEngine;
  final Future<String> Function() _facebookCookieHeader;
  final Future<String> Function() _instagramCookieHeader;
  final Future<String> Function() _tiktokCookieHeader;

  DownloadEngine get youtubeEngine => _youtubeEngine;

  static const _facebookReferer = 'https://www.facebook.com/';
  static const _instagramReferer = 'https://www.instagram.com/';
  static const _tiktokReferer = 'https://www.tiktok.com/';
  static const _facebookUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
  static const _instagramUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
  // Match TikTokMetadataClient / yt-dlp desktop UA — CDN rejects generic UAs.
  static const _tiktokUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
  static const _tiktokOrigin = 'https://www.tiktok.com';

  static Future<String> _defaultFacebookCookieHeader() {
    return FacebookSession().cookieHeader();
  }

  static Future<String> _defaultInstagramCookieHeader() {
    return InstagramSession().cookieHeader();
  }

  static Future<String> _defaultTiktokCookieHeader() {
    return TikTokSession().cookieHeader();
  }

  DownloadEngine _engineForOptions(Map<String, Object?>? optionsJson) {
    final kind = optionsJson?['kind']?.toString();
    if (kind == YoutubeDownloadOptions.kind) {
      return _youtubeEngine;
    }
    if ((kind == FacebookDownloadOptions.kind ||
            kind == InstagramDownloadOptions.kind ||
            kind == TikTokDownloadOptions.kind) &&
        !Platform.isAndroid) {
      return _youtubeEngine;
    }
    return _baseEngine;
  }

  DownloadEngine _engineForGid(String gid) {
    if (gid.startsWith('ytdlp:')) return _youtubeEngine;
    return _baseEngine;
  }

  @override
  Future<bool> get isHealthy async {
    return (await _baseEngine.isHealthy) && (await _youtubeEngine.isHealthy);
  }

  @override
  Future<void> start({
    required String downloadDirectory,
    required int maxActiveDownloads,
    required int defaultSplit,
    String executableOverride = '',
    String ytdlpPath = '',
    String ffmpegPath = '',
  }) async {
    await Future.wait([
      _baseEngine.start(
        downloadDirectory: downloadDirectory,
        maxActiveDownloads: maxActiveDownloads,
        defaultSplit: defaultSplit,
        executableOverride: executableOverride,
        ytdlpPath: ytdlpPath,
        ffmpegPath: ffmpegPath,
      ),
      _youtubeEngine.start(
        downloadDirectory: downloadDirectory,
        maxActiveDownloads: maxActiveDownloads,
        defaultSplit: defaultSplit,
        executableOverride: executableOverride,
        ytdlpPath: ytdlpPath,
        ffmpegPath: ffmpegPath,
      ),
    ]);
  }

  @override
  Future<void> shutdown() async {
    await Future.wait([
      _baseEngine.shutdown(),
      _youtubeEngine.shutdown(),
    ]);
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
    final kind = optionsJson?['kind']?.toString();
    if (kind == FacebookDownloadOptions.kind && Platform.isAndroid) {
      final directUrl = optionsJson?['directUrl']?.toString() ?? '';
      if (directUrl.isEmpty) {
        throw StateError(
          'Facebook download on Android requires a progressive CDN URL.',
        );
      }
      final cookie = await _facebookCookieHeader();
      return _baseEngine.addUri(
        url: directUrl,
        directory: directory,
        split: split,
        fileName: fileName,
        headers: {
          ...headers,
          'Referer': _facebookReferer,
          'User-Agent': _facebookUserAgent,
          if (cookie.isNotEmpty) 'Cookie': cookie,
        },
        position: position,
        optionsJson: optionsJson,
      );
    }
    if (kind == InstagramDownloadOptions.kind && Platform.isAndroid) {
      final directUrl = optionsJson?['directUrl']?.toString() ?? '';
      if (directUrl.isEmpty) {
        throw StateError(
          'Instagram download on Android requires a progressive CDN URL.',
        );
      }
      final cookie = await _instagramCookieHeader();
      return _baseEngine.addUri(
        url: directUrl,
        directory: directory,
        split: split,
        fileName: fileName,
        headers: {
          ...headers,
          'Referer': _instagramReferer,
          'User-Agent': _instagramUserAgent,
          if (cookie.isNotEmpty) 'Cookie': cookie,
        },
        position: position,
        optionsJson: optionsJson,
      );
    }
    if (kind == TikTokDownloadOptions.kind && Platform.isAndroid) {
      final directUrl = optionsJson?['directUrl']?.toString() ?? '';
      if (directUrl.isEmpty) {
        throw StateError(
          'TikTok download on Android requires a progressive CDN URL.',
        );
      }
      final cookie = await _tiktokCookieHeader();
      final fromOptions = optionsJson?['cookieHeader']?.toString() ?? '';
      final mergedCookie = fromOptions.trim().isNotEmpty ? fromOptions : cookie;
      return _baseEngine.addUri(
        url: directUrl,
        directory: directory,
        // TikTok CDN signed URLs often reject multi-connection Range fetches.
        split: 1,
        fileName: fileName,
        headers: {
          ...headers,
          'Referer': _tiktokReferer,
          'Origin': _tiktokOrigin,
          'User-Agent': _tiktokUserAgent,
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          if (mergedCookie.isNotEmpty) 'Cookie': mergedCookie,
        },
        position: position,
        optionsJson: optionsJson,
      );
    }

    return _engineForOptions(optionsJson).addUri(
      url: url,
      directory: directory,
      split: split,
      fileName: fileName,
      headers: headers,
      position: position,
      optionsJson: optionsJson,
    );
  }

  @override
  Future<void> pause(String gid) => _engineForGid(gid).pause(gid);

  @override
  Future<void> unpause(String gid) => _engineForGid(gid).unpause(gid);

  @override
  Future<void> remove(String gid) => _engineForGid(gid).remove(gid);

  @override
  Future<void> changePosition(String gid, int position) {
    return _engineForGid(gid).changePosition(gid, position);
  }

  @override
  Future<Aria2Status> tellStatus(String gid) {
    return _engineForGid(gid).tellStatus(gid);
  }

  @override
  Future<List<Aria2Status>> tellActive() async {
    return [
      ...await _baseEngine.tellActive(),
      ...await _youtubeEngine.tellActive(),
    ];
  }

  @override
  Future<List<Aria2Status>> tellWaiting({
    int offset = 0,
    int limit = 100,
  }) async {
    return [
      ...await _baseEngine.tellWaiting(offset: offset, limit: limit),
      ...await _youtubeEngine.tellWaiting(offset: offset, limit: limit),
    ];
  }

  @override
  Future<List<Aria2Status>> tellStopped({
    int offset = 0,
    int limit = 100,
  }) async {
    return [
      ...await _baseEngine.tellStopped(offset: offset, limit: limit),
      ...await _youtubeEngine.tellStopped(offset: offset, limit: limit),
    ];
  }

  @override
  Future<void> resetSession() async {
    await Future.wait([
      _baseEngine.resetSession(),
      _youtubeEngine.resetSession(),
    ]);
  }
}
