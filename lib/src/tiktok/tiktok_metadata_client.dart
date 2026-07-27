import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../services/url_classifier.dart';
import '../ytdlp/ytdlp_client.dart';
import '../ytdlp/ytdlp_models.dart';

class TikTokExtractResult {
  const TikTokExtractResult({
    required this.info,
    required this.progressiveUrls,
    this.cdnCookieHeader = '',
  });

  final YtdlpVideoInfo info;
  final Map<String, String> progressiveUrls;

  /// Cookies captured while loading the video page (needed for CDN on Android).
  final String cdnCookieHeader;

  String? urlForFormat(String formatId) => progressiveUrls[formatId];
}

typedef TikTokWebViewHtmlFetcher = Future<String?> Function(String pageUrl);

class TikTokMetadataClient {
  TikTokMetadataClient({
    http.Client? httpClient,
    this.cookieHeader = '',
    this.webViewHtmlFetcher,
  })  : _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  final http.Client _http;
  final bool _ownsClient;
  final String cookieHeader;
  final TikTokWebViewHtmlFetcher? webViewHtmlFetcher;
  var _pageCookieHeader = '';

  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  void close() {
    if (_ownsClient) _http.close();
  }

  Future<TikTokExtractResult> fetchInfo(String url) async {
    final pageUrl = UrlClassifier.normalizeTiktokUrl(url);
    final videoId = UrlClassifier.extractTiktokVideoId(pageUrl);
    if (videoId == null || videoId.isEmpty) {
      throw YtdlpException(
        'Not a supported TikTok video URL. '
        'Use a link like https://www.tiktok.com/@user/video/123 or vm.tiktok.com/…',
      );
    }

    var html = await _fetchPage(pageUrl);
    var parsed = _tryParsePageHtml(html, pageUrl: pageUrl);
    if (parsed != null) {
      return TikTokExtractResult(
        info: parsed.info,
        progressiveUrls: parsed.progressiveUrls,
        cdnCookieHeader: _mergedCookieHeader(),
      );
    }

    if (_looksLikeWafOrChallenge(html) &&
        Platform.isAndroid &&
        webViewHtmlFetcher != null) {
      final fromWebView = await webViewHtmlFetcher!(pageUrl);
      if (fromWebView != null && fromWebView.isNotEmpty) {
        parsed = _tryParsePageHtml(fromWebView, pageUrl: pageUrl);
        if (parsed != null) {
          return TikTokExtractResult(
            info: parsed.info,
            progressiveUrls: parsed.progressiveUrls,
            cdnCookieHeader: _mergedCookieHeader(),
          );
        }
      }
    }

    if (_htmlSaysLoginRequired(html)) {
      throw YtdlpException(
        'This TikTok video is private or requires login. '
        'Open Settings → TikTok, log in, then try again.',
      );
    }

    throw YtdlpException(_noVideoMessage());
  }

  TikTokExtractResult? _tryParsePageHtml(String html, {required String pageUrl}) {
    try {
      return parsePageHtml(html, pageUrl: pageUrl);
    } on YtdlpException {
      return null;
    }
  }

  TikTokExtractResult parsePageHtml(String html, {required String pageUrl}) {
    if (_htmlSaysLoginRequired(html)) {
      throw YtdlpException(
        'This TikTok video is private or requires login. '
        'Open Settings → TikTok, log in, then try again.',
      );
    }

    final item = _extractItemStruct(html);
    if (item == null) {
      throw YtdlpException(_noVideoMessage());
    }

    final videoId = item['id']?.toString() ??
        UrlClassifier.extractTiktokVideoId(pageUrl) ??
        'tiktok';
    final title = _titleFromItem(item, videoId);
    final urls = _progressiveUrlsFromItem(item);
    if (urls.isEmpty) {
      throw YtdlpException(_noVideoMessage());
    }

    final formats = <YtdlpFormat>[];
    final progressiveUrls = <String, String>{};
    var index = 0;
    for (final entry in urls.entries) {
      final formatId = 'tiktok_${entry.key}_$index';
      index++;
      progressiveUrls[formatId] = entry.value;
      formats.add(
        YtdlpFormat(
          formatId: formatId,
          ext: 'mp4',
          resolution: entry.key,
          note: entry.key,
          fileSize: 0,
          vcodec: 'h264',
          acodec: 'aac',
          format: entry.value,
        ),
      );
    }

    final info = YtdlpVideoInfo(
      id: videoId,
      title: title,
      duration: _durationFromItem(item).round(),
      formats: formats,
    );

    return TikTokExtractResult(info: info, progressiveUrls: progressiveUrls);
  }

  Future<String> _fetchPage(String pageUrl) async {
    final response = await _http
        .get(
          Uri.parse(pageUrl),
          headers: {
            'User-Agent': _desktopUserAgent,
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Referer': 'https://www.tiktok.com/',
            if (cookieHeader.trim().isNotEmpty) 'Cookie': cookieHeader,
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw YtdlpException(
        'TikTok returned HTTP ${response.statusCode} for this video page.',
      );
    }
    _pageCookieHeader = _cookiesFromResponse(response);
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  String _mergedCookieHeader() {
    return _mergeCookieHeaders(cookieHeader, _pageCookieHeader);
  }

  static String _cookiesFromResponse(http.Response response) {
    final single = response.headers['set-cookie'];
    if (single == null || single.trim().isEmpty) return '';
    // package:http may join multiple Set-Cookie values; take name=value pairs.
    final pairs = <String>[];
    for (final part in single.split(',')) {
      final first = part.split(';').first.trim();
      if (first.contains('=')) pairs.add(first);
    }
    return pairs.join('; ');
  }

  static String _mergeCookieHeaders(String a, String b) {
    final map = <String, String>{};
    void add(String header) {
      for (final part in header.split(';')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final eq = trimmed.indexOf('=');
        if (eq <= 0) continue;
        map[trimmed.substring(0, eq).trim()] = trimmed.substring(eq + 1).trim();
      }
    }

    add(a);
    add(b);
    if (map.isEmpty) return '';
    return map.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  static bool _looksLikeWafOrChallenge(String html) {
    final lower = html.toLowerCase();
    if (lower.contains('captcha') && lower.contains('tiktok')) return true;
    if (lower.contains('verify to continue')) return true;
    if (lower.contains('__universal_data_for_rehydration__')) return false;
    if (lower.contains('sigi_state')) return false;
    return html.length < 4000;
  }

  static bool _htmlSaysLoginRequired(String html) {
    final lower = html.toLowerCase();
    if (lower.contains('"loginrequired"') ||
        lower.contains('"login_required"') ||
        lower.contains('loginrequired')) {
      return true;
    }
    if (lower.contains('private video') && lower.contains('log in')) {
      return true;
    }
    return false;
  }

  static String _noVideoMessage() {
    return 'Could not find a downloadable TikTok video on this page. '
        'Public videos usually work without login; private videos need '
        'Settings → TikTok. On Android, try again or use desktop yt-dlp '
        'when TikTok shows a security check.';
  }

  static Map<String, Object?>? _extractItemStruct(String html) {
    final fromUniversal = _itemFromUniversalData(html);
    if (fromUniversal != null) return fromUniversal;
    return _itemFromSigiState(html);
  }

  static Map<String, Object?>? _itemFromUniversalData(String html) {
    final match = RegExp(
      r'<script[^>]*id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return null;
    try {
      final decoded = jsonDecode(match.group(1)!.trim());
      if (decoded is! Map) return null;
      final root = decoded.cast<String, Object?>();
      final scope = root['__DEFAULT_SCOPE__'];
      if (scope is! Map) return null;
      final scopeMap = scope.cast<String, Object?>();
      final detail = scopeMap['webapp.video-detail'];
      if (detail is! Map) return null;
      final detailMap = detail.cast<String, Object?>();
      final itemInfo = detailMap['itemInfo'];
      if (itemInfo is! Map) return null;
      final itemStruct = itemInfo['itemStruct'];
      if (itemStruct is Map) {
        return itemStruct.cast<String, Object?>();
      }
    } catch (_) {}
    return null;
  }

  static Map<String, Object?>? _itemFromSigiState(String html) {
    final match = RegExp(
      r'<script[^>]*id="SIGI_STATE"[^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return null;
    try {
      final decoded = jsonDecode(match.group(1)!.trim());
      if (decoded is! Map) return null;
      final root = decoded.cast<String, Object?>();
      final itemModule = root['ItemModule'];
      if (itemModule is! Map) return null;
      for (final value in itemModule.values) {
        if (value is Map && value.containsKey('video')) {
          return value.cast<String, Object?>();
        }
      }
    } catch (_) {}
    return null;
  }

  static String _titleFromItem(Map<String, Object?> item, String videoId) {
    final desc = item['desc']?.toString().trim() ?? '';
    if (desc.isNotEmpty) return desc;
    final author = item['author'];
    if (author is Map) {
      final uniqueId = author['uniqueId']?.toString();
      if (uniqueId != null && uniqueId.isNotEmpty) {
        return 'TikTok @$uniqueId $videoId';
      }
    }
    return 'TikTok $videoId';
  }

  static double _durationFromItem(Map<String, Object?> item) {
    final video = item['video'];
    if (video is! Map) return 0;
    final duration = video['duration'];
    if (duration is num) return duration.toDouble();
    return 0;
  }

  static Map<String, String> _progressiveUrlsFromItem(
    Map<String, Object?> item,
  ) {
    final video = item['video'];
    if (video is! Map) return const {};
    final videoMap = video.cast<String, Object?>();
    final found = <String, String>{};

    void add(String label, String? url) {
      if (url == null || !url.startsWith('http')) return;
      found.putIfAbsent(label, () => url);
    }

    add('download', _urlFromPlayAddr(videoMap['downloadAddr']));
    add('play', _urlFromPlayAddr(videoMap['playAddr']));

    final bitrateInfo = videoMap['bitrateInfo'];
    if (bitrateInfo is List) {
      for (final entry in bitrateInfo) {
        if (entry is! Map) continue;
        final gearName = entry['GearName']?.toString() ?? 'bitrate';
        final playAddr = entry['PlayAddr'] ?? entry['playAddr'];
        add(gearName, _urlFromPlayAddr(playAddr));
      }
    }

    return found;
  }

  static String? _urlFromPlayAddr(Object? value) {
    if (value == null) return null;
    if (value is String) return value.replaceAll(r'\u002F', '/');
    if (value is Map) {
      final urlList = value['UrlList'] ?? value['urlList'];
      if (urlList is List && urlList.isNotEmpty) {
        return urlList.first.toString().replaceAll(r'\u002F', '/');
      }
      final url = value['url'] ?? value['Url'];
      if (url != null) return url.toString().replaceAll(r'\u002F', '/');
    }
    return null;
  }
}
