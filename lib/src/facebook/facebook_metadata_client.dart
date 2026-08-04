import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/url_classifier.dart';
import '../ytdlp/ytdlp_client.dart';
import '../ytdlp/ytdlp_models.dart';

/// Progressive Facebook formats extracted from a public page (Android).
class FacebookExtractResult {
  const FacebookExtractResult({
    required this.info,
    required this.progressiveUrls,
  });

  final YtdlpVideoInfo info;

  /// Maps [YtdlpFormat.formatId] to a progressive CDN MP4 URL.
  final Map<String, String> progressiveUrls;

  String? urlForFormat(String formatId) => progressiveUrls[formatId];
}

class FacebookMetadataClient {
  FacebookMetadataClient({
    http.Client? httpClient,
    this.cookieHeader = '',
  }) : _http = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  final http.Client _http;
  final bool _ownsClient;
  final String cookieHeader;

  // Browser UAs are often rejected (HTTP 400). yt-dlp uses facebookexternalhit.
  static const _externalHitUserAgent = 'facebookexternalhit/1.1';

  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) '
      'Gecko/20100101 Firefox/121.0';

  static const _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  void close() {
    if (_ownsClient) _http.close();
  }

  Future<FacebookExtractResult> fetchInfo(String url) async {
    final pageUrl = UrlClassifier.normalizeFacebookUrl(url);
    final html = await _fetchPage(pageUrl);
    return parsePageHtml(html, pageUrl: pageUrl);
  }

  /// Parses Facebook HTML/embedded JSON for progressive MP4 CDN URLs.
  FacebookExtractResult parsePageHtml(
    String html, {
    required String pageUrl,
  }) {
    final decoded = _unescapeFacebookText(html);
    final found = <String, String>{};

    void addUrl(String formatId, String? rawUrl) {
      if (rawUrl == null || rawUrl.isEmpty) return;
      final url = _cleanMediaUrl(rawUrl);
      if (!_looksLikeProgressiveMp4(url)) return;
      // Prefer first URL for a given quality key; keep distinct CDN URLs too.
      found.putIfAbsent(formatId, () => url);
    }

    // Legacy / GraphQL playable fields (aligned with yt-dlp facebook extractor).
    for (final entry in const [
      ('playable_url_quality_hd', 'hd'),
      ('browser_native_hd_url', 'hd'),
      ('playable_url', 'sd'),
      ('browser_native_sd_url', 'sd'),
    ]) {
      for (final match in RegExp(
        '"${entry.$1}"\\s*:\\s*"([^"]+)"',
      ).allMatches(decoded)) {
        addUrl(entry.$2, match.group(1));
      }
    }

    // Newer videoDeliveryResponse progressive_urls entries.
    var progIndex = 0;
    for (final match in RegExp(
      '"progressive_url"\\s*:\\s*"([^"]+)"',
    ).allMatches(decoded)) {
      final windowEnd = (match.end + 160).clamp(0, decoded.length);
      final window = decoded.substring(match.start, windowEnd);
      final qualityMatch = RegExp(
        '"quality"\\s*:\\s*"([^"]+)"',
      ).firstMatch(window);
      final quality = qualityMatch?.group(1)?.toLowerCase() ?? '';
      final formatId = quality == 'hd' || quality == 'sd'
          ? quality
          : 'prog_$progIndex';
      addUrl(formatId, match.group(1));
      progIndex++;
    }

    // Representation base_url MP4s (progressive packaging).
    var baseIndex = 0;
    for (final match in RegExp(
      '"base_url"\\s*:\\s*"(https?[^"]+\\.mp4[^"]*)"',
      caseSensitive: false,
    ).allMatches(decoded)) {
      addUrl('base_$baseIndex', match.group(1));
      baseIndex++;
    }

    if (found.isEmpty) {
      throw YtdlpException(
        'No progressive Facebook video URL was found. '
        'Public videos work without login; private/friends-only need '
        'Facebook login in Settings.',
      );
    }

    final title = _extractTitle(decoded) ?? 'Facebook video';
    final id = _extractVideoId(pageUrl, decoded) ?? 'facebook';
    final duration = _extractDurationSeconds(decoded);

    final formats = <YtdlpFormat>[];
    final urls = <String, String>{};
    final orderedIds = found.keys.toList()
      ..sort((a, b) => _qualityRank(b).compareTo(_qualityRank(a)));

    for (final formatId in orderedIds) {
      final mediaUrl = found[formatId]!;
      // Deduplicate identical CDN URLs under one format id.
      if (urls.containsValue(mediaUrl)) continue;
      urls[formatId] = mediaUrl;
      formats.add(
        YtdlpFormat(
          formatId: formatId,
          ext: 'mp4',
          resolution: _resolutionForId(formatId),
          note: _noteForId(formatId),
          fileSize: null,
          vcodec: 'avc1',
          acodec: 'mp4a',
          format: 'progressive $formatId',
        ),
      );
    }

    if (formats.isEmpty) {
      throw YtdlpException(
        'No progressive Facebook video URL was found. '
        'Public videos work without login; private/friends-only need '
        'Facebook login in Settings.',
      );
    }

    return FacebookExtractResult(
      info: YtdlpVideoInfo(
        id: id,
        title: title,
        duration: duration,
        formats: formats,
      ),
      progressiveUrls: urls,
    );
  }

  Future<String> _fetchPage(String pageUrl) async {
    Object? lastError;
    var lastStatus = 0;

    for (final candidate in pageUrlCandidates(pageUrl)) {
      for (final userAgent in const [
        _externalHitUserAgent,
        _desktopUserAgent,
        _mobileUserAgent,
      ]) {
        try {
          final response = await _http
              .get(
                Uri.parse(candidate),
                headers: {
                  'User-Agent': userAgent,
                  'Accept':
                      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                  'Accept-Language': 'en-US,en;q=0.9',
                  if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
                },
              )
              .timeout(const Duration(seconds: 30));

          lastStatus = response.statusCode;
          if (response.statusCode >= 400) {
            continue;
          }

          final body = _decodeResponseBody(response);
          if (_htmlLooksUseful(body)) {
            return body;
          }
          if (_looksLikeLoginWall(body) && cookieHeader.isEmpty) {
            throw YtdlpException(
              'Facebook asked for login. Open Settings → Facebook and log in '
              'to download private or friends-only videos.',
            );
          }
        } catch (error) {
          if (error is YtdlpException) rethrow;
          lastError = error;
        }
      }
    }

    if (lastStatus >= 400) {
      throw YtdlpException(
        'Facebook returned HTTP $lastStatus while loading the page. '
        '${cookieHeader.isEmpty ? "Try logging in under Settings → Facebook. " : ""}'
        'Or open the link in a browser to confirm it loads.',
      );
    }
    if (lastError != null) {
      throw YtdlpException('Failed to load Facebook page: $lastError');
    }
    throw YtdlpException(
      cookieHeader.isEmpty
          ? 'No progressive Facebook video URL was found. '
              'Public videos work without login; private/friends-only videos '
              'need Facebook login in Settings.'
          : 'No progressive Facebook video URL was found for this session. '
              'The video may be unavailable, DRM-only, or your login expired.',
    );
  }

  /// Reel pages often 400 with browser UAs; prefer watch URLs like yt-dlp.
  /// Group permalinks need mobile / posts variants for logged-in HTML.
  @visibleForTesting
  static List<String> pageUrlCandidates(String pageUrl) {
    final uri = Uri.tryParse(pageUrl);
    if (uri == null) return [pageUrl];

    final candidates = <String>[pageUrl];
    final reelMatch = RegExp(
      r'/reels?/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(uri.path);
    final videoId = uri.queryParameters['v'] ??
        uri.queryParameters['vd'] ??
        reelMatch?.group(1);

    if (videoId != null && videoId.isNotEmpty) {
      candidates.addAll([
        'https://www.facebook.com/watch/?v=$videoId',
        'https://m.facebook.com/watch/?v=$videoId&_rdr',
        'https://www.facebook.com/reel/$videoId',
        'https://m.facebook.com/reel/$videoId',
      ]);
    }

    final groupPermalink = RegExp(
      r'/groups/(\d+)/permalink/(\d+)',
      caseSensitive: false,
    ).firstMatch(uri.path);
    if (groupPermalink != null) {
      final groupId = groupPermalink.group(1)!;
      final postId = groupPermalink.group(2)!;
      candidates.addAll([
        'https://www.facebook.com/groups/$groupId/permalink/$postId/',
        'https://m.facebook.com/groups/$groupId/permalink/$postId/',
        'https://www.facebook.com/groups/$groupId/posts/$postId/',
        'https://m.facebook.com/groups/$groupId/posts/$postId/',
        'https://m.facebook.com/story.php?story_fbid=$postId&id=$groupId',
        // Some group videos also resolve as watch once the post id is known.
        'https://www.facebook.com/watch/?v=$postId',
        'https://m.facebook.com/watch/?v=$postId&_rdr',
      ]);
    }

    final seen = <String>{};
    return [
      for (final url in candidates)
        if (seen.add(url)) url,
    ];
  }

  /// True for Facebook group post / permalink URLs (often fail in yt-dlp).
  static bool isGroupPostUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final path = uri.path.toLowerCase();
    return path.contains('/groups/') &&
        (path.contains('/permalink/') || path.contains('/posts/'));
  }

  /// Facebook pages are not always valid UTF-8; never throw on decode.
  static String _decodeResponseBody(http.Response response) {
    final bytes = response.bodyBytes;
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      // Latin-1 accepts every byte; enough for ASCII CDN URL extraction.
      return latin1.decode(bytes);
    }
  }

  static bool _htmlLooksUseful(String html) {
    return html.contains('playable_url') ||
        html.contains('browser_native_') ||
        html.contains('progressive_url') ||
        html.contains('og:video');
  }

  static bool _looksLikeLoginWall(String html) {
    final lower = html.toLowerCase();
    return lower.contains('log in') ||
        lower.contains('login') ||
        lower.contains('create new account') ||
        lower.contains('"login_form"');
  }

  static String _unescapeFacebookText(String value) {
    var text = value
        .replaceAll(r'\/', '/')
        .replaceAll(r'\\/', '/')
        .replaceAll(r'\\"', '"');
    text = text.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (match) {
      final code = int.parse(match.group(1)!, radix: 16);
      return String.fromCharCode(code);
    });
    text = text.replaceAllMapped(RegExp(r'\\x([0-9a-fA-F]{2})'), (match) {
      final code = int.parse(match.group(1)!, radix: 16);
      return String.fromCharCode(code);
    });
    return text;
  }

  static String _cleanMediaUrl(String raw) {
    var url = raw.trim();
    url = url.replaceAll(r'\/', '/');
    url = _unescapeFacebookText(url);
    // Strip trailing escape leftovers.
    if (url.endsWith(r'\') ) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static bool _looksLikeProgressiveMp4(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    final lower = url.toLowerCase();
    if (lower.contains('.mpd') || lower.contains('manifest')) return false;
    if (lower.contains('.m3u8')) return false;
    // Facebook CDN progressive MP4s usually include .mp4 or video extension.
    return lower.contains('.mp4') ||
        lower.contains('video') ||
        uri.host.contains('fbcdn');
  }

  static String? _extractTitle(String html) {
    final og = RegExp(
      '<meta[^>]+property=["\']og:title["\'][^>]+content=["\']([^"\']+)["\']',
      caseSensitive: false,
    ).firstMatch(html);
    if (og != null) return _decodeHtmlEntities(og.group(1)!).trim();

    final ogAlt = RegExp(
      '<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:title["\']',
      caseSensitive: false,
    ).firstMatch(html);
    if (ogAlt != null) return _decodeHtmlEntities(ogAlt.group(1)!).trim();

    final name = RegExp(
      '"name"\\s*:\\s*"([^"]{3,200})"',
    ).firstMatch(html);
    if (name != null) return _decodeHtmlEntities(name.group(1)!).trim();

    return null;
  }

  static String? _extractVideoId(String pageUrl, String html) {
    final fromUrl = Uri.tryParse(pageUrl);
    if (fromUrl != null) {
      final v = fromUrl.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
      final reel = RegExp(r'/reel/([^/?#]+)', caseSensitive: false)
          .firstMatch(fromUrl.path);
      if (reel != null) return reel.group(1);
      if (fromUrl.host == 'fb.watch' && fromUrl.pathSegments.isNotEmpty) {
        return fromUrl.pathSegments.first;
      }
    }

    final fromHtml = RegExp(
      '"video_id"\\s*:\\s*"?(\\d+)"?',
    ).firstMatch(html);
    return fromHtml?.group(1);
  }

  static int _extractDurationSeconds(String html) {
    final ms = RegExp(
      '"playable_duration_in_ms"\\s*:\\s*(\\d+)',
    ).firstMatch(html);
    if (ms != null) {
      return (int.tryParse(ms.group(1)!) ?? 0) ~/ 1000;
    }
    final sec = RegExp(
      '"length_in_second"\\s*:\\s*(\\d+(?:\\.\\d+)?)',
    ).firstMatch(html);
    if (sec != null) {
      return double.tryParse(sec.group(1)!)?.round() ?? 0;
    }
    return 0;
  }

  static int _qualityRank(String formatId) {
    return switch (formatId) {
      'hd' => 3,
      'sd' => 2,
      _ when formatId.startsWith('prog_') => 1,
      _ => 0,
    };
  }

  static String _resolutionForId(String formatId) {
    return switch (formatId) {
      'hd' => 'HD',
      'sd' => 'SD',
      _ => '',
    };
  }

  static String _noteForId(String formatId) {
    return switch (formatId) {
      'hd' => 'progressive HD',
      'sd' => 'progressive SD',
      _ => 'progressive',
    };
  }

  static String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
