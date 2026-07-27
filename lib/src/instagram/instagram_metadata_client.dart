import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/url_classifier.dart';
import '../ytdlp/ytdlp_client.dart';
import '../ytdlp/ytdlp_models.dart';

/// Progressive Instagram formats extracted from a public page (Android).
class InstagramExtractResult {
  const InstagramExtractResult({
    required this.info,
    required this.progressiveUrls,
  });

  final YtdlpVideoInfo info;

  /// Maps [YtdlpFormat.formatId] to a progressive CDN MP4 URL.
  final Map<String, String> progressiveUrls;

  String? urlForFormat(String formatId) => progressiveUrls[formatId];
}

class InstagramMetadataClient {
  InstagramMetadataClient({
    http.Client? httpClient,
    this.cookieHeader = '',
  }) : _http = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  final http.Client _http;
  final bool _ownsClient;
  final String cookieHeader;

  static const _igAppId = '936619743392459';

  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) '
      'Gecko/20100101 Firefox/121.0';

  static const _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static const _instagramAppUserAgent =
      'Instagram 192.0.0.37.107 Android (33/13; 420dpi; 1080x2400; '
      'Google/google; Pixel 7; panther; panther; en_US; 314665256)';

  /// Same alphabet yt-dlp uses for Instagram shortcode → media pk.
  static const _shortcodeAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

  void close() {
    if (_ownsClient) _http.close();
  }

  Future<InstagramExtractResult> fetchInfo(String url) async {
    final pageUrl = UrlClassifier.normalizeInstagramUrl(url);
    final shortcode = UrlClassifier.extractInstagramShortcode(pageUrl);
    if (shortcode == null || shortcode.isEmpty) {
      throw YtdlpException(
        'Not a supported Instagram post/reel URL. '
        'Use a link like https://www.instagram.com/reel/... or /p/...',
      );
    }

    // Authenticated media API (same path yt-dlp uses when cookies exist).
    if (cookieHeader.trim().isNotEmpty) {
      try {
        final fromApi = await _fetchFromMediaInfoApi(shortcode, pageUrl);
        if (fromApi != null) return fromApi;
      } on YtdlpException {
        rethrow;
      } catch (_) {
        // Fall through to logged-out GraphQL / HTML.
      }
    }

    // yt-dlp logged-out path: session + ruling + GraphQL (works without login
    // for public posts/reels). Prefer this over raw HTML scraping.
    try {
      final fromGraphql = await _fetchLoggedOutGraphql(shortcode, pageUrl);
      if (fromGraphql != null) return fromGraphql;
    } catch (_) {}

    final html = await _fetchPage(pageUrl);
    return parsePageHtml(html, pageUrl: pageUrl);
  }

  /// Parses Instagram HTML/embedded JSON for progressive MP4 CDN URLs.
  InstagramExtractResult parsePageHtml(
    String html, {
    required String pageUrl,
  }) {
    final decoded = _unescapeInstagramText(html);
    final found = <String, _Candidate>{};
    _collectVideoCandidates(decoded, found);

    if (found.isEmpty) {
      throw YtdlpException(_noVideoMessage());
    }

    return _resultFromCandidates(
      found,
      pageUrl: pageUrl,
      html: decoded,
    );
  }

  Future<InstagramExtractResult?> _fetchFromMediaInfoApi(
    String shortcode,
    String pageUrl,
  ) async {
    final pk = shortcodeToMediaPk(shortcode);
    if (pk == null) return null;

    Object? lastError;
    for (final endpoint in [
      'https://i.instagram.com/api/v1/media/$pk/info/',
      'https://www.instagram.com/api/v1/media/$pk/info/',
    ]) {
      for (final userAgent in [_instagramAppUserAgent, _mobileUserAgent]) {
        try {
          final response = await _http
              .get(
                Uri.parse(endpoint),
                headers: {
                  'User-Agent': userAgent,
                  'Accept': '*/*',
                  'Accept-Language': 'en-US,en;q=0.9',
                  'X-IG-App-ID': _igAppId,
                  'X-ASBD-ID': '359341',
                  'X-IG-WWW-Claim': '0',
                  'Origin': 'https://www.instagram.com',
                  'Referer': pageUrl,
                  'Cookie': cookieHeader,
                },
              )
              .timeout(const Duration(seconds: 30));

          if (response.statusCode >= 400) {
            final body = _decodeResponseBody(response);
            if (_jsonSaysLoginRequired(body)) {
              throw YtdlpException(
                'Instagram session expired or is invalid. '
                'Open Settings → Instagram, log out, then log in again.',
              );
            }
            lastError = 'HTTP ${response.statusCode}';
            continue;
          }

          final body = _decodeResponseBody(response);
          final parsed = _parseMediaInfoJson(body, pageUrl: pageUrl);
          if (parsed != null) return parsed;
        } catch (error) {
          if (error is YtdlpException) rethrow;
          lastError = error;
        }
      }
    }

    if (lastError != null) {
      // Keep going to HTML fallbacks; caller ignores null.
    }
    return null;
  }

  /// yt-dlp logged-out extraction: homepage LSD → ruling → GraphQL doc.
  Future<InstagramExtractResult?> _fetchLoggedOutGraphql(
    String shortcode,
    String pageUrl,
  ) async {
    final pk = shortcodeToMediaPk(shortcode);
    if (pk == null) return null;

    final jar = _CookieJar()..addFromHeader(cookieHeader);
    final chromeUa =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36';

    final home = await _http
        .get(
          Uri.parse('https://www.instagram.com/'),
          headers: {
            'User-Agent': chromeUa,
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Sec-Fetch-Mode': 'navigate',
            if (jar.header.isNotEmpty) 'Cookie': jar.header,
          },
        )
        .timeout(const Duration(seconds: 30));
    jar.addFromResponse(home);

    final homeBody = _decodeResponseBody(home);
    final lsd = _extractLsdToken(homeBody);
    if (lsd == null || lsd.isEmpty) return null;

    final apiHeaders = <String, String>{
      'User-Agent': chromeUa,
      'X-IG-App-ID': _igAppId,
      'X-ASBD-ID': '359341',
      'X-IG-WWW-Claim': '0',
      'Origin': 'https://www.instagram.com',
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': pageUrl,
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-origin',
      if (jar.header.isNotEmpty) 'Cookie': jar.header,
    };

    final ruling = await _http
        .get(
          Uri.parse(
            'https://i.instagram.com/api/v1/web/get_ruling_for_content/'
            '?content_type=MEDIA&target_id=$pk',
          ),
          headers: apiHeaders,
        )
        .timeout(const Duration(seconds: 30));
    jar.addFromResponse(ruling);
    final rulingBody = _decodeResponseBody(ruling);
    final rulingOk = ruling.statusCode < 400 &&
        (rulingBody.contains('"status":"ok"') ||
            rulingBody.contains('"status": "ok"'));

    final csrf = jar['csrftoken'];
    final gqlHeaders = <String, String>{
      ...apiHeaders,
      if (jar.header.isNotEmpty) 'Cookie': jar.header,
      'Content-Type': 'application/x-www-form-urlencoded',
      'X-FB-Friendly-Name': 'PolarisLoggedOutDesktopWWWPostRootContentQuery',
      'X-Requested-With': 'XMLHttpRequest',
      'X-FB-LSD': lsd,
      if (csrf != null && rulingOk) 'X-CSRFToken': csrf,
    };

    final bodyMap = {
      'lsd': lsd,
      'fb_api_caller_class': 'RelayModern',
      'fb_api_req_friendly_name':
          'PolarisLoggedOutDesktopWWWPostRootContentQuery',
      'server_timestamps': 'true',
      'variables': jsonEncode({'media_id': '$pk'}),
      'doc_id': '27130156389949648',
    };
    final encoded = bodyMap.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');

    final gql = await _http
        .post(
          Uri.parse('https://www.instagram.com/api/graphql'),
          headers: gqlHeaders,
          body: encoded,
        )
        .timeout(const Duration(seconds: 30));

    if (gql.statusCode >= 400) return null;
    final body = _decodeResponseBody(gql);
    if (body.trimLeft().startsWith('<!')) return null;

    final fromJson = _parsePolarisGraphqlJson(body, pageUrl: pageUrl);
    if (fromJson != null) return fromJson;

    final found = <String, _Candidate>{};
    _collectVideoCandidates(_unescapeInstagramText(body), found);
    if (found.isEmpty) return null;
    return _resultFromCandidates(found, pageUrl: pageUrl, html: body);
  }

  InstagramExtractResult? _parsePolarisGraphqlJson(
    String body, {
    required String pageUrl,
  }) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final media = _digMap(decoded, const [
        'data',
        'xig_polaris_media',
        'if_not_gated_logged_out',
      ]);
      if (media == null) return null;

      final found = <String, _Candidate>{};
      _addVideoFieldsFromMap(media, found);
      if (found.isEmpty) {
        _collectVideoCandidates(_unescapeInstagramText(body), found);
      }
      if (found.isEmpty) return null;

      final user = media['user'];
      String? title;
      if (user is Map) {
        final username = user['username']?.toString();
        if (username != null && username.isNotEmpty) {
          title = 'Video by $username';
        }
      }
      final caption = media['caption'];
      if (caption is Map) {
        final text = caption['text']?.toString();
        if (text != null && text.trim().isNotEmpty) {
          title = text.trim();
        }
      }

      return _resultFromCandidates(
        found,
        pageUrl: pageUrl,
        html: body,
        titleOverride: title,
        idOverride: media['pk']?.toString() ?? media['code']?.toString(),
        durationOverride: _asDouble(media['video_duration']).round(),
      );
    } catch (_) {
      return null;
    }
  }

  void _addVideoFieldsFromMap(
    Map<String, Object?> map,
    Map<String, _Candidate> found,
  ) {
    final videoUrl = map['video_url']?.toString();
    if (videoUrl != null) {
      _addCandidate(found, 'video_url', videoUrl);
    }
    final versions = map['video_versions'];
    if (versions is List) {
      var index = 0;
      for (final entry in versions) {
        if (entry is! Map) continue;
        final url = entry['url']?.toString();
        final height = _asInt(entry['height']);
        final width = _asInt(entry['width']);
        final type = entry['type'];
        final id = height > 0
            ? 'v$height'
            : (type != null ? 'type_$type' : 'v_$index');
        _addCandidate(found, id, url, height: height, width: width);
        index++;
      }
    }
  }

  static Map<String, Object?>? _digMap(Object? root, List<String> path) {
    Object? current = root;
    for (final key in path) {
      if (current is! Map) return null;
      current = current[key];
    }
    if (current is! Map) return null;
    return current.cast<String, Object?>();
  }

  static String? _extractLsdToken(String html) {
    final eqmc = RegExp(
      r'<script\b[^>]*\bid="__eqmc"[^>]*>(\{.*?\})</script>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (eqmc != null) {
      try {
        final json = jsonDecode(eqmc.group(1)!);
        if (json is Map) {
          final token = json['l']?.toString();
          if (token != null && token.isNotEmpty) return token;
        }
      } catch (_) {}
    }
    return RegExp(r'\["LSD",\[\],\{"token":"([^"]+)"')
        .firstMatch(html)
        ?.group(1);
  }

  InstagramExtractResult? _parseMediaInfoJson(
    String body, {
    required String pageUrl,
  }) {
    if (body.trimLeft().startsWith('<!')) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final items = decoded['items'];
      if (items is! List || items.isEmpty) {
        // Some responses nest under data.
        final found = <String, _Candidate>{};
        _collectVideoCandidates(_unescapeInstagramText(body), found);
        if (found.isEmpty) return null;
        return _resultFromCandidates(found, pageUrl: pageUrl, html: body);
      }

      final item = items.first;
      if (item is! Map) return null;
      final map = item.cast<String, Object?>();
      final found = <String, _Candidate>{};

      final videoUrl = map['video_url']?.toString();
      if (videoUrl != null) {
        _addCandidate(found, 'video_url', videoUrl);
      }

      final versions = map['video_versions'];
      if (versions is List) {
        for (final entry in versions) {
          if (entry is! Map) continue;
          final url = entry['url']?.toString();
          final height = _asInt(entry['height']);
          final width = _asInt(entry['width']);
          final id = height > 0 ? 'v$height' : 'v_${found.length}';
          _addCandidate(found, id, url, height: height, width: width);
        }
      }

      if (found.isEmpty) {
        _collectVideoCandidates(_unescapeInstagramText(body), found);
      }
      if (found.isEmpty) return null;

      final caption = _captionFromMediaItem(map);
      final duration = _asDouble(map['video_duration']).round();
      final id = map['pk']?.toString() ??
          map['id']?.toString() ??
          UrlClassifier.extractInstagramShortcode(pageUrl) ??
          'instagram';

      return _resultFromCandidates(
        found,
        pageUrl: pageUrl,
        html: body,
        titleOverride: caption,
        idOverride: id,
        durationOverride: duration,
      );
    } catch (_) {
      return null;
    }
  }

  void _collectVideoCandidates(String decoded, Map<String, _Candidate> found) {
    // yt-dlp Instagram extractor: video_url field.
    for (final match in RegExp(
      '"video_url"\\s*:\\s*"([^"]+)"',
    ).allMatches(decoded)) {
      _addCandidate(found, 'video_url', match.group(1));
    }

    // video_versions with width/height (legacy / media info API).
    var versionIndex = 0;
    for (final match in RegExp(
      '\\{\\s*"type"\\s*:\\s*\\d+\\s*,\\s*"width"\\s*:\\s*(\\d+)\\s*,'
      '\\s*"height"\\s*:\\s*(\\d+)\\s*,\\s*"url"\\s*:\\s*"([^"]+)"',
    ).allMatches(decoded)) {
      final width = int.tryParse(match.group(1)!) ?? 0;
      final height = int.tryParse(match.group(2)!) ?? 0;
      final id = height > 0 ? 'v$height' : 'v_$versionIndex';
      _addCandidate(
        found,
        id,
        match.group(3),
        height: height,
        width: width,
      );
      versionIndex++;
    }

    // Logged-out GraphQL shape: {"type":101,"url":"https://...mp4..."}.
    for (final match in RegExp(
      '\\{\\s*"type"\\s*:\\s*(\\d+)\\s*,\\s*"url"\\s*:\\s*"(https?[^"]+)"',
    ).allMatches(decoded)) {
      final type = match.group(1)!;
      _addCandidate(found, 'type_$type', match.group(2));
      versionIndex++;
    }

    // Alternate video_versions shape: url first.
    for (final match in RegExp(
      '"url"\\s*:\\s*"(https?[^"]+\\.mp4[^"]*)"[^}]{0,200}'
      '"height"\\s*:\\s*(\\d+)',
      caseSensitive: false,
    ).allMatches(decoded)) {
      final height = int.tryParse(match.group(2)!) ?? 0;
      final id = height > 0 ? 'v$height' : 'url_$versionIndex';
      _addCandidate(found, id, match.group(1), height: height);
      versionIndex++;
    }

    // og:video meta tags.
    for (final pattern in [
      RegExp(
        '<meta[^>]+property=["\']og:video(?::(?:secure_url|url))?["\'][^>]+'
        'content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content=["\']([^"\']+)["\'][^>]+'
        'property=["\']og:video(?::(?:secure_url|url))?["\']',
        caseSensitive: false,
      ),
    ]) {
      for (final match in pattern.allMatches(decoded)) {
        _addCandidate(found, 'og_video', match.group(1));
      }
    }

    // JSON-LD contentUrl.
    for (final match in RegExp(
      '"contentUrl"\\s*:\\s*"(https?[^"]+)"',
    ).allMatches(decoded)) {
      _addCandidate(found, 'contentUrl', match.group(1));
    }

    // CDN MP4 URLs embedded in Relay / data-sjs payloads.
    var cdnIndex = 0;
    for (final match in RegExp(
      'https?:\\\\?/\\\\?/[^"\'\\s]+(?:cdninstagram\\.com|fbcdn\\.net)[^"\'\\s]*\\.mp4[^"\'\\s]*',
      caseSensitive: false,
    ).allMatches(decoded)) {
      final raw = match.group(0)!.replaceAll(r'\/', '/');
      _addCandidate(found, 'cdn_$cdnIndex', raw);
      cdnIndex++;
    }
  }

  void _addCandidate(
    Map<String, _Candidate> found,
    String formatId,
    String? rawUrl, {
    int height = 0,
    int width = 0,
  }) {
    if (rawUrl == null || rawUrl.isEmpty) return;
    final url = _cleanMediaUrl(rawUrl);
    if (!_looksLikeProgressiveMp4(url)) return;
    final existing = found[formatId];
    if (existing == null || height > existing.height) {
      found[formatId] = _Candidate(url: url, height: height, width: width);
    }
  }

  InstagramExtractResult _resultFromCandidates(
    Map<String, _Candidate> found, {
    required String pageUrl,
    required String html,
    String? titleOverride,
    String? idOverride,
    int? durationOverride,
  }) {
    final shortcode =
        UrlClassifier.extractInstagramShortcode(pageUrl) ?? 'instagram';
    final title = titleOverride ?? _extractTitle(html) ?? 'Instagram video';
    final id = idOverride ?? _extractMediaId(html) ?? shortcode;
    final duration = durationOverride ?? _extractDurationSeconds(html);

    final formats = <YtdlpFormat>[];
    final urls = <String, String>{};
    final ordered = found.entries.toList()
      ..sort((a, b) => b.value.height.compareTo(a.value.height));

    for (final entry in ordered) {
      final mediaUrl = entry.value.url;
      if (urls.containsValue(mediaUrl)) continue;
      urls[entry.key] = mediaUrl;
      final height = entry.value.height;
      final width = entry.value.width;
      formats.add(
        YtdlpFormat(
          formatId: entry.key,
          ext: 'mp4',
          resolution: height > 0
              ? (width > 0 ? '${width}x$height' : '${height}p')
              : '',
          note: height > 0 ? 'progressive ${height}p' : 'progressive',
          fileSize: null,
          vcodec: 'avc1',
          acodec: 'mp4a',
          format: 'progressive ${entry.key}',
        ),
      );
    }

    if (formats.isEmpty) {
      throw YtdlpException(_noVideoMessage());
    }

    return InstagramExtractResult(
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
    var sawHardLoginWall = false;

    for (final candidate in pageUrlCandidates(pageUrl)) {
      for (final userAgent in const [_desktopUserAgent, _mobileUserAgent]) {
        try {
          final response = await _http
              .get(
                Uri.parse(candidate),
                headers: {
                  'User-Agent': userAgent,
                  'Accept':
                      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                  'Accept-Language': 'en-US,en;q=0.9',
                  'Referer': 'https://www.instagram.com/',
                  'X-IG-App-ID': _igAppId,
                  if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
                },
              )
              .timeout(const Duration(seconds: 30));

          lastStatus = response.statusCode;
          final finalUrl = response.request?.url.toString() ?? candidate;
          if (_isLoginRedirect(finalUrl)) {
            sawHardLoginWall = true;
            continue;
          }
          if (response.statusCode >= 400) {
            continue;
          }

          final body = _decodeResponseBody(response);
          if (_htmlLooksUseful(body)) {
            return body;
          }
          if (_isHardLoginWall(body)) {
            sawHardLoginWall = true;
          }
        } catch (error) {
          if (error is YtdlpException) rethrow;
          lastError = error;
        }
      }
    }

    if (sawHardLoginWall && cookieHeader.isEmpty) {
      throw YtdlpException(
        'Instagram requires a logged-in session to extract this video on Android. '
        'Open Settings → Instagram and log in, then try again. '
        '(Desktop may already work if cookies.txt / browser import is set.)',
      );
    }

    if (lastStatus >= 400) {
      throw YtdlpException(
        'Instagram returned HTTP $lastStatus while loading the page. '
        '${cookieHeader.isEmpty ? "Try logging in under Settings → Instagram. " : ""}'
        'Or open the link in a browser to confirm it loads.',
      );
    }
    if (lastError != null) {
      throw YtdlpException('Failed to load Instagram page: $lastError');
    }
    throw YtdlpException(_noVideoMessage());
  }

  String _noVideoMessage() {
    if (cookieHeader.isEmpty) {
      return 'No progressive Instagram video URL was found. '
          'Open the link in a browser to confirm it loads. '
          'If it is private, open Settings → Instagram and log in '
          '(desktop: cookies.txt / browser import).';
    }
    return 'No progressive Instagram video URL was found for this session. '
        'The media may be unavailable, a photo-only post, or your login expired. '
        'Try logging out and back in under Settings → Instagram.';
  }

  static List<String> pageUrlCandidates(String pageUrl) {
    final uri = Uri.tryParse(pageUrl);
    if (uri == null) return [pageUrl];

    final candidates = <String>[pageUrl];
    final shortcode = UrlClassifier.extractInstagramShortcode(pageUrl);
    if (shortcode != null && shortcode.isNotEmpty) {
      candidates.addAll([
        'https://www.instagram.com/p/$shortcode/',
        'https://www.instagram.com/reel/$shortcode/',
        'https://www.instagram.com/tv/$shortcode/',
        'https://www.instagram.com/reel/$shortcode/embed/',
        'https://www.instagram.com/p/$shortcode/embed/captioned/',
      ]);
    }

    final seen = <String>{};
    return [
      for (final url in candidates)
        if (seen.add(url)) url,
    ];
  }

  /// Converts an Instagram shortcode to the numeric media pk used by the API.
  static int? shortcodeToMediaPk(String shortcode) {
    var code = shortcode.trim();
    if (code.isEmpty) return null;
    if (code.length > 28) {
      code = code.substring(0, code.length - 28);
    }
    var id = 0;
    for (final unit in code.codeUnits) {
      final idx = _shortcodeAlphabet.indexOf(String.fromCharCode(unit));
      if (idx < 0) return null;
      id = id * 64 + idx;
    }
    return id;
  }

  static String _decodeResponseBody(http.Response response) {
    final bytes = response.bodyBytes;
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static bool _htmlLooksUseful(String html) {
    return html.contains('video_url') ||
        html.contains('video_versions') ||
        html.contains('og:video') ||
        html.contains('contentUrl') ||
        html.contains('xdt_shortcode_media') ||
        html.contains('if_not_gated_logged_out') ||
        RegExp(
          r'(cdninstagram\.com|fbcdn\.net)[^\s"]*\.mp4',
          caseSensitive: false,
        ).hasMatch(html);
  }

  /// True only for a dedicated login gate — not ordinary pages with a Log in link.
  static bool _isHardLoginWall(String html) {
    final lower = html.toLowerCase();
    if (lower.contains('"login_form"') || lower.contains('id="loginForm"')) {
      return true;
    }
    if (lower.contains('/accounts/login') &&
        !lower.contains('video_url') &&
        !lower.contains('video_versions') &&
        !lower.contains('og:video')) {
      // Thin login interstitial without media payload.
      return lower.contains('password') && lower.contains('username');
    }
    return false;
  }

  static bool _isLoginRedirect(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return path.startsWith('/accounts/login');
  }

  static bool _jsonSaysLoginRequired(String body) {
    final lower = body.toLowerCase();
    return lower.contains('login_required') ||
        lower.contains('"checkpoint_required"');
  }

  static String _unescapeInstagramText(String value) {
    var text = value
        .replaceAll(r'\/', '/')
        .replaceAll(r'\\/', '/')
        .replaceAll(r'\\"', '"');
    text = text.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (match) {
      final code = int.parse(match.group(1)!, radix: 16);
      return String.fromCharCode(code);
    });
    return text;
  }

  static String _cleanMediaUrl(String raw) {
    var url = raw.trim();
    url = url.replaceAll(r'\/', '/');
    url = _unescapeInstagramText(url);
    if (url.endsWith(r'\')) {
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
    // Ignore static asset host, not media CDN.
    if (uri.host.startsWith('static.')) return false;
    return lower.contains('.mp4') ||
        uri.host.contains('cdninstagram') ||
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

    final caption = RegExp(
      '"caption"\\s*:\\s*\\{\\s*"text"\\s*:\\s*"([^"]{3,200})"',
    ).firstMatch(html);
    if (caption != null) return _decodeHtmlEntities(caption.group(1)!).trim();

    return null;
  }

  static String? _captionFromMediaItem(Map<String, Object?> item) {
    final caption = item['caption'];
    if (caption is Map) {
      final text = caption['text']?.toString();
      if (text != null && text.trim().isNotEmpty) return text.trim();
    }
    final user = item['user'];
    if (user is Map) {
      final username = user['username']?.toString();
      if (username != null && username.isNotEmpty) {
        return 'Video by $username';
      }
    }
    return null;
  }

  static String? _extractMediaId(String html) {
    final pk = RegExp('"pk"\\s*:\\s*"?(\\d+)"?').firstMatch(html);
    if (pk != null) return pk.group(1);
    final id = RegExp('"id"\\s*:\\s*"(\\d+)"').firstMatch(html);
    return id?.group(1);
  }

  static int _extractDurationSeconds(String html) {
    final sec = RegExp(
      '"video_duration"\\s*:\\s*(\\d+(?:\\.\\d+)?)',
    ).firstMatch(html);
    if (sec != null) {
      return double.tryParse(sec.group(1)!)?.round() ?? 0;
    }
    return 0;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
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

class _Candidate {
  const _Candidate({
    required this.url,
    this.height = 0,
    this.width = 0,
  });

  final String url;
  final int height;
  final int width;
}

/// Minimal cookie jar for Instagram session bootstrap (package:http is stateless).
class _CookieJar {
  final Map<String, String> _cookies = {};

  String? operator [](String name) => _cookies[name];

  String get header =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  void addFromHeader(String raw) {
    if (raw.trim().isEmpty) return;
    for (final part in raw.split(';')) {
      final piece = part.trim();
      final eq = piece.indexOf('=');
      if (eq <= 0) continue;
      final name = piece.substring(0, eq).trim();
      final value = piece.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      // Skip cookie attributes if someone passed a full Set-Cookie line.
      if ({'path', 'domain', 'expires', 'max-age', 'samesite', 'secure', 'httponly'}
          .contains(name.toLowerCase())) {
        continue;
      }
      _cookies[name] = value;
    }
  }

  void addFromResponse(http.Response response) {
    final joined = response.headers['set-cookie'];
    if (joined == null || joined.isEmpty) return;
    // Comma can separate cookies or appear inside Expires=...; split carefully.
    for (final raw in joined.split(RegExp(r',(?=\s*[^;=]+=)'))) {
      _addSetCookie(raw);
    }
  }

  void _addSetCookie(String raw) {
    final first = raw.split(';').first.trim();
    final eq = first.indexOf('=');
    if (eq <= 0) return;
    final name = first.substring(0, eq).trim();
    final value = first.substring(eq + 1).trim();
    if (name.isNotEmpty) _cookies[name] = value;
  }
}
