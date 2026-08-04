import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/url_classifier.dart';
import 'facebook_cookies.dart';

/// Persists Facebook session cookies (encrypted via platform secure storage).
class FacebookSession {
  FacebookSession({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'facebook_session_cookies_v1';

  final FlutterSecureStorage _storage;
  List<FacebookCookie>? _cache;

  Future<List<FacebookCookie>> loadCookies() async {
    if (_cache != null) return _cache!;
    final raw = await _storage.read(key: _storageKey);
    _cache = decodeFacebookCookiesJson(raw ?? '');
    return _cache!;
  }

  Future<void> saveCookies(List<FacebookCookie> cookies) async {
    _cache = List<FacebookCookie>.from(cookies);
    await _storage.write(
      key: _storageKey,
      value: encodeFacebookCookiesJson(cookies),
    );
  }

  Future<void> clear() async {
    _cache = const [];
    await _storage.delete(key: _storageKey);
    try {
      final file = await _netscapeFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<bool> get isLoggedIn async {
    return facebookSessionLooksLoggedIn(await loadCookies());
  }

  Future<String> cookieHeader() async {
    return facebookCookieHeader(await loadCookies());
  }

  /// Writes a Netscape cookie file for yt-dlp and returns its path.
  /// Returns null when there is no usable session.
  Future<String?> writeNetscapeCookieFile() async {
    final cookies = await loadCookies();
    if (!facebookSessionLooksLoggedIn(cookies)) return null;
    final file = await _netscapeFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(netscapeCookieFileContents(cookies));
    return file.path;
  }

  Future<File> _netscapeFile() async {
    final support = await getApplicationSupportDirectory();
    return File(p.join(support.path, 'facebook', 'cookies.txt'));
  }
}

/// Resolves yt-dlp cookie CLI args from settings + optional WebView session.
///
/// Order: explicit cookies.txt path → cookies-from-browser → WebView session file.
class FacebookCookieArgs {
  const FacebookCookieArgs({this.cookiesPath = '', this.fromBrowser = ''});

  final String cookiesPath;
  final String fromBrowser;

  bool get hasOverride =>
      cookiesPath.trim().isNotEmpty || fromBrowser.trim().isNotEmpty;
}

Future<List<String>> resolveYtdlpFacebookCookieArgs({
  required FacebookCookieArgs settings,
  FacebookSession? session,
  String url = '',
}) async {
  // Never attach Facebook cookies to non-Facebook extractions downloads.
  if (url.isNotEmpty && !UrlClassifier.isFacebook(url)) {
    return const [];
  }

  final path = settings.cookiesPath.trim();
  if (path.isNotEmpty) {
    if (await File(path).exists()) {
      return ['--cookies', path];
    }
  }

  final browser = settings.fromBrowser.trim().toLowerCase();
  if (browser.isNotEmpty &&
      (browser == 'chrome' || browser == 'edge' || browser == 'firefox')) {
    return ['--cookies-from-browser', browser];
  }

  final fbSession = session ?? FacebookSession();
  final exported = await fbSession.writeNetscapeCookieFile();
  if (exported != null && exported.isNotEmpty) {
    return ['--cookies', exported];
  }
  return const [];
}

/// Cookie header for HTML page scrape (Android WebView session or cookies.txt).
///
/// Browser-import settings are yt-dlp-only and cannot be read here — export
/// cookies.txt when group / private posts need the HTML fallback path.
Future<String> resolveFacebookCookieHeader({
  required FacebookCookieArgs settings,
  FacebookSession? session,
}) async {
  final path = settings.cookiesPath.trim();
  if (path.isNotEmpty) {
    final file = File(path);
    if (await file.exists()) {
      try {
        final cookies = parseNetscapeCookieFile(await file.readAsString());
        final header = facebookCookieHeader(cookies);
        if (header.isNotEmpty) return header;
      } catch (_) {}
    }
  }

  final fbSession = session ?? FacebookSession();
  return fbSession.cookieHeader();
}
