import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/instagram/instagram_cookies.dart';
import 'package:downlink/src/instagram/instagram_metadata_client.dart';
import 'package:downlink/src/instagram/instagram_session.dart';
import 'package:downlink/src/services/url_classifier.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('instagram cookies helpers', () {
    test('builds Cookie header and detects login via sessionid', () {
      const cookies = [
        InstagramCookie(
          name: 'sessionid',
          value: 'abc123',
          domain: '.instagram.com',
        ),
        InstagramCookie(
          name: 'csrftoken',
          value: 'tok',
          domain: '.instagram.com',
        ),
      ];
      expect(instagramCookieHeader(cookies), 'sessionid=abc123; csrftoken=tok');
      expect(instagramSessionLooksLoggedIn(cookies), isTrue);
      expect(
        instagramSessionLooksLoggedIn([
          const InstagramCookie(
            name: 'csrftoken',
            value: 'x',
            domain: '.instagram.com',
          ),
        ]),
        isFalse,
      );
    });

    test('writes netscape cookie file contents', () {
      const cookies = [
        InstagramCookie(
          name: 'sessionid',
          value: '99',
          domain: 'instagram.com',
          path: '/',
          expiresEpoch: 2000000000,
          isSecure: true,
        ),
      ];
      final text = instagramNetscapeCookieFileContents(cookies);
      expect(text, contains('# Netscape HTTP Cookie File'));
      expect(text, contains('.instagram.com'));
      expect(text, contains('sessionid'));
      expect(text, contains('99'));
      expect(text, contains('TRUE'));
    });

    test('json round-trip', () {
      const cookies = [
        InstagramCookie(
          name: 'sessionid',
          value: 'token',
          domain: '.instagram.com',
          isHttpOnly: true,
        ),
      ];
      final encoded = encodeInstagramCookiesJson(cookies);
      final decoded = decodeInstagramCookiesJson(encoded);
      expect(decoded, hasLength(1));
      expect(decoded.first.name, 'sessionid');
      expect(decoded.first.value, 'token');
      expect(decoded.first.isHttpOnly, isTrue);
    });
  });

  group('resolveYtdlpInstagramCookieArgs', () {
    test('returns empty for non-Instagram URLs', () async {
      final args = await resolveYtdlpInstagramCookieArgs(
        settings: const InstagramCookieArgs(cookiesPath: '/tmp/cookies.txt'),
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(args, isEmpty);
      expect(UrlClassifier.isInstagram('https://www.instagram.com/p/x/'), isTrue);
    });
  });

  group('InstagramMetadataClient cookies', () {
    test('uses media info API when session cookie is provided', () async {
      final seen = <http.Request>[];
      final mock = MockClient((request) async {
        seen.add(request);
        if (request.url.path.contains('/api/v1/media/')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'pk': '123',
                  'video_duration': 8.2,
                  'caption': {'text': 'API Reel'},
                  'user': {'username': 'demo'},
                  'video_url':
                      'https://scontent.cdninstagram.com/v/t50/api_main.mp4',
                  'video_versions': [
                    {
                      'type': 101,
                      'width': 720,
                      'height': 1280,
                      'url':
                          'https://scontent.cdninstagram.com/v/t50/api_v1280.mp4',
                    },
                  ],
                },
              ],
              'status': 'ok',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('unexpected', 500);
      });

      final client = InstagramMetadataClient(
        httpClient: mock,
        cookieHeader: 'sessionid=1; csrftoken=2',
      );
      final result = await client.fetchInfo(
        'https://www.instagram.com/reel/DbPeKUKle5x/',
      );
      expect(result.info.title, 'API Reel');
      expect(result.urlForFormat('video_url'), contains('api_main.mp4'));
      expect(result.urlForFormat('v1280'), contains('api_v1280.mp4'));
      expect(seen, isNotEmpty);
      expect(seen.first.headers['cookie'], 'sessionid=1; csrftoken=2');
      expect(seen.first.url.path, contains('/api/v1/media/'));
      client.close();
    });

    test('falls back to HTML scrape when media API has no video', () async {
      http.Request? htmlRequest;
      final mock = MockClient((request) async {
        if (request.url.path.contains('/api/v1/media/')) {
          return http.Response('{"status":"ok","items":[]}', 200);
        }
        // Logged-out GraphQL bootstrap — fail so HTML path is used.
        if (request.url.host == 'www.instagram.com' &&
            request.url.path == '/') {
          return http.Response('<html></html>', 200);
        }
        if (request.url.path.contains('graphql') ||
            request.url.path.contains('get_ruling')) {
          return http.Response('{"status":"fail"}', 400);
        }
        htmlRequest = request;
        return http.Response(
          '<html><meta property="og:title" content="T" />'
          '<script>"video_url":"https://scontent.cdninstagram.com/v/a.mp4"</script>'
          '</html>',
          200,
        );
      });

      final client = InstagramMetadataClient(
        httpClient: mock,
        cookieHeader: 'sessionid=1; csrftoken=2',
      );
      final result = await client.fetchInfo(
        'https://www.instagram.com/reel/ABC123xyz_/',
      );
      expect(result.urlForFormat('video_url'), contains('.mp4'));
      expect(htmlRequest?.headers['cookie'], contains('sessionid=1'));
      client.close();
    });

    test('extracts public reel via logged-out GraphQL session', () async {
      final mock = MockClient((request) async {
        if (request.url.host == 'www.instagram.com' &&
            request.method == 'GET' &&
            request.url.path == '/') {
          return http.Response(
            '<html><script id="__eqmc">{"l":"LSDTOKEN"}</script></html>',
            200,
            headers: {
              'set-cookie': 'csrftoken=csrf1; Path=/; Domain=.instagram.com',
            },
          );
        }
        if (request.url.path.contains('get_ruling_for_content')) {
          return http.Response('{"status":"ok"}', 200);
        }
        if (request.url.path.contains('graphql')) {
          expect(request.headers['x-fb-lsd'], 'LSDTOKEN');
          expect(request.headers['x-csrftoken'], 'csrf1');
          return http.Response(
            jsonEncode({
              'data': {
                'xig_polaris_media': {
                  'pk': '3945415418143709977',
                  'code': 'DbA7mtJzhsZ',
                  'if_not_gated_logged_out': {
                    'pk': '3945415418143709977',
                    'code': 'DbA7mtJzhsZ',
                    'user': {'username': 'demo_user'},
                    'video_duration': 9.1,
                    'video_versions': [
                      {
                        'type': 101,
                        'url':
                            'https://instagram.fdac142-1.fna.fbcdn.net/o1/v/a.mp4',
                      },
                    ],
                  },
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('unexpected ${request.url}', 500);
      });

      final client = InstagramMetadataClient(httpClient: mock);
      final result = await client.fetchInfo(
        'https://www.instagram.com/reels/DbA7mtJzhsZ/',
      );
      expect(result.info.title, 'Video by demo_user');
      expect(result.urlForFormat('type_101'), contains('a.mp4'));
      client.close();
    });
  });

  group('shortcodeToMediaPk', () {
    test('decodes Instagram shortcodes like yt-dlp', () {
      expect(
        InstagramMetadataClient.shortcodeToMediaPk('DbPeKUKle5x'),
        3949508048469749361,
      );
    });
  });
}
