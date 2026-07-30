import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/facebook/facebook_cookies.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:downlink/src/facebook/facebook_metadata_client.dart';

void main() {
  group('facebook cookies helpers', () {
    test('builds Cookie header and detects login', () {
      const cookies = [
        FacebookCookie(
          name: 'c_user',
          value: '123',
          domain: '.facebook.com',
        ),
        FacebookCookie(
          name: 'xs',
          value: 'abc',
          domain: '.facebook.com',
        ),
      ];
      expect(facebookCookieHeader(cookies), 'c_user=123; xs=abc');
      expect(facebookSessionLooksLoggedIn(cookies), isTrue);
      expect(
        facebookSessionLooksLoggedIn([
          const FacebookCookie(
            name: 'datr',
            value: 'x',
            domain: '.facebook.com',
          ),
        ]),
        isFalse,
      );
    });

    test('writes netscape cookie file contents', () {
      const cookies = [
        FacebookCookie(
          name: 'c_user',
          value: '99',
          domain: 'facebook.com',
          path: '/',
          expiresEpoch: 2000000000,
          isSecure: true,
        ),
      ];
      final text = netscapeCookieFileContents(cookies);
      expect(text, contains('# Netscape HTTP Cookie File'));
      expect(text, contains('.facebook.com'));
      expect(text, contains('c_user'));
      expect(text, contains('99'));
      expect(text, contains('TRUE'));
    });

    test('json round-trip', () {
      const cookies = [
        FacebookCookie(
          name: 'xs',
          value: 'token',
          domain: '.facebook.com',
          isHttpOnly: true,
        ),
      ];
      final encoded = encodeFacebookCookiesJson(cookies);
      final decoded = decodeFacebookCookiesJson(encoded);
      expect(decoded, hasLength(1));
      expect(decoded.first.name, 'xs');
      expect(decoded.first.value, 'token');
      expect(decoded.first.isHttpOnly, isTrue);
    });
  });

  group('FacebookMetadataClient cookies', () {
    test('sends Cookie header when provided', () async {
      http.Request? seen;
      final mock = MockClient((request) async {
        seen = request;
        return http.Response(
          '<html><meta property="og:title" content="T" />'
          '<script>"browser_native_hd_url":"https://video.xx.fbcdn.net/v/a.mp4"</script>'
          '</html>',
          200,
        );
      });

      final client = FacebookMetadataClient(
        httpClient: mock,
        cookieHeader: 'c_user=1; xs=2',
      );
      final result = await client.fetchInfo(
        'https://www.facebook.com/watch/?v=1',
      );
      expect(result.urlForFormat('hd'), contains('.mp4'));
      expect(seen?.headers['cookie'], 'c_user=1; xs=2');
      client.close();
    });
  });
}
