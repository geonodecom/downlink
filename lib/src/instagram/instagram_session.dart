import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../facebook/facebook_session.dart';
import '../services/url_classifier.dart';
import 'instagram_cookies.dart';

/// Persists Instagram session cookies (encrypted via platform secure storage).
class InstagramSession {
  InstagramSession({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'instagram_session_cookies_v1';

  final FlutterSecureStorage _storage;
  List<InstagramCookie>? _cache;

  Future<List<InstagramCookie>> loadCookies() async {
    if (_cache != null) return _cache!;
    final raw = await _storage.read(key: _storageKey);
    _cache = decodeInstagramCookiesJson(raw ?? '');
    return _cache!;
  }

  Future<void> saveCookies(List<InstagramCookie> cookies) async {
    _cache = List<InstagramCookie>.from(cookies);
    await _storage.write(
      key: _storageKey,
      value: encodeInstagramCookiesJson(cookies),
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
    return instagramSessionLooksLoggedIn(await loadCookies());
  }

  Future<String> cookieHeader() async {
    return instagramCookieHeader(await loadCookies());
  }

  /// Writes a Netscape cookie file for yt-dlp and returns its path.
  /// Returns null when there is no usable session.
  Future<String?> writeNetscapeCookieFile() async {
    final cookies = await loadCookies();
    if (!instagramSessionLooksLoggedIn(cookies)) return null;
    final file = await _netscapeFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(instagramNetscapeCookieFileContents(cookies));
    return file.path;
  }

  Future<File> _netscapeFile() async {
    final support = await getApplicationSupportDirectory();
    return File(p.join(support.path, 'instagram', 'cookies.txt'));
  }
}

/// Instagram-specific yt-dlp cookie settings (separate from Facebook).
class InstagramCookieArgs {
  const InstagramCookieArgs({this.cookiesPath = '', this.fromBrowser = ''});

  final String cookiesPath;
  final String fromBrowser;

  bool get hasOverride =>
      cookiesPath.trim().isNotEmpty || fromBrowser.trim().isNotEmpty;
}

Future<List<String>> resolveYtdlpInstagramCookieArgs({
  required InstagramCookieArgs settings,
  InstagramSession? session,
  String url = '',
}) async {
  if (url.isNotEmpty && !UrlClassifier.isInstagram(url)) {
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

  final igSession = session ?? InstagramSession();
  final exported = await igSession.writeNetscapeCookieFile();
  if (exported != null && exported.isNotEmpty) {
    return ['--cookies', exported];
  }
  return const [];
}

/// Resolves yt-dlp cookie CLI args for Facebook or Instagram URLs only.
Future<List<String>> resolveYtdlpSiteCookieArgs({
  required String url,
  FacebookCookieArgs facebook = const FacebookCookieArgs(),
  InstagramCookieArgs instagram = const InstagramCookieArgs(),
  FacebookSession? facebookSession,
  InstagramSession? instagramSession,
}) async {
  if (UrlClassifier.isFacebook(url)) {
    return resolveYtdlpFacebookCookieArgs(
      settings: facebook,
      session: facebookSession,
      url: url,
    );
  }
  if (UrlClassifier.isInstagram(url)) {
    return resolveYtdlpInstagramCookieArgs(
      settings: instagram,
      session: instagramSession,
      url: url,
    );
  }
  return const [];
}
