import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/url_classifier.dart';
import 'tiktok_cookies.dart';

/// Persists TikTok session cookies (encrypted via platform secure storage).
class TikTokSession {
  TikTokSession({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'tiktok_session_cookies_v1';

  final FlutterSecureStorage _storage;
  List<TikTokCookie>? _cache;

  Future<List<TikTokCookie>> loadCookies() async {
    if (_cache != null) return _cache!;
    final raw = await _storage.read(key: _storageKey);
    _cache = decodeTikTokCookiesJson(raw ?? '');
    return _cache!;
  }

  Future<void> saveCookies(List<TikTokCookie> cookies) async {
    _cache = List<TikTokCookie>.from(cookies);
    await _storage.write(
      key: _storageKey,
      value: encodeTikTokCookiesJson(cookies),
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
    return tiktokSessionLooksLoggedIn(await loadCookies());
  }

  Future<String> cookieHeader() async {
    return tiktokCookieHeader(await loadCookies());
  }

  Future<String?> writeNetscapeCookieFile() async {
    final cookies = await loadCookies();
    if (!tiktokSessionLooksLoggedIn(cookies)) return null;
    final file = await _netscapeFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(tiktokNetscapeCookieFileContents(cookies));
    return file.path;
  }

  Future<File> _netscapeFile() async {
    final support = await getApplicationSupportDirectory();
    return File(p.join(support.path, 'tiktok', 'cookies.txt'));
  }
}

class TikTokCookieArgs {
  const TikTokCookieArgs({this.cookiesPath = '', this.fromBrowser = ''});

  final String cookiesPath;
  final String fromBrowser;

  bool get hasOverride =>
      cookiesPath.trim().isNotEmpty || fromBrowser.trim().isNotEmpty;
}

Future<List<String>> resolveYtdlpTiktokCookieArgs({
  required TikTokCookieArgs settings,
  TikTokSession? session,
  String url = '',
}) async {
  if (url.isNotEmpty && !UrlClassifier.isTiktok(url)) {
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

  final tkSession = session ?? TikTokSession();
  final exported = await tkSession.writeNetscapeCookieFile();
  if (exported != null && exported.isNotEmpty) {
    return ['--cookies', exported];
  }
  return const [];
}
