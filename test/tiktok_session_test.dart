import 'package:flutter_test/flutter_test.dart';
import 'package:geonode_download_manager/src/tiktok/tiktok_cookies.dart';
import 'package:geonode_download_manager/src/tiktok/tiktok_session.dart';

void main() {
  group('tiktok cookies helpers', () {
    test('builds Cookie header and detects login via sessionid', () {
      const cookies = [
        TikTokCookie(
          name: 'sessionid',
          value: 'abc123',
          domain: '.tiktok.com',
        ),
        TikTokCookie(
          name: 'tt_chain_token',
          value: 'tok',
          domain: '.tiktok.com',
        ),
      ];
      expect(tiktokCookieHeader(cookies), 'sessionid=abc123; tt_chain_token=tok');
      expect(tiktokSessionLooksLoggedIn(cookies), isTrue);
      expect(
        tiktokSessionLooksLoggedIn([
          const TikTokCookie(
            name: 'tt_chain_token',
            value: 'x',
            domain: '.tiktok.com',
          ),
        ]),
        isFalse,
      );
    });
  });

  group('resolveYtdlpTiktokCookieArgs', () {
    test('returns empty for non-TikTok URLs', () async {
      final args = await resolveYtdlpTiktokCookieArgs(
        settings: const TikTokCookieArgs(cookiesPath: '/tmp/cookies.txt'),
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(args, isEmpty);
    });
  });
}
