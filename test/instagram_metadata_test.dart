import 'package:flutter_test/flutter_test.dart';
import 'package:geonode_download_manager/src/facebook/facebook_models.dart';
import 'package:geonode_download_manager/src/instagram/instagram_metadata_client.dart';
import 'package:geonode_download_manager/src/instagram/instagram_models.dart';
import 'package:geonode_download_manager/src/ytdlp/ytdlp_client.dart';

void main() {
  group('InstagramDownloadOptions', () {
    test('round-trips JSON including directUrl', () {
      const options = InstagramDownloadOptions(
        formatId: 'v720',
        title: 'Sample Reel',
        ext: 'mp4',
        directUrl: 'https://scontent.cdninstagram.com/v/t50/clip.mp4',
      );

      final json = options.toJson();
      expect(json['kind'], 'instagram');
      expect(json['directUrl'], contains('cdninstagram'));

      final restored = InstagramDownloadOptions.fromJson(json);
      expect(restored.formatId, 'v720');
      expect(restored.title, 'Sample Reel');
      expect(restored.ext, 'mp4');
      expect(restored.directUrl, options.directUrl);
      expect(restored.sanitizedFileName, 'Sample Reel.mp4');
    });

    test('omits empty directUrl from JSON', () {
      const options = InstagramDownloadOptions(
        formatId: 'video_url',
        title: 'Desktop',
        ext: 'mp4',
      );
      expect(options.toJson().containsKey('directUrl'), isFalse);
    });

    test('detects instagram options from encoded JSON', () {
      const encoded =
          '{"kind":"instagram","formatId":"v720","title":"A","ext":"mp4",'
          '"directUrl":"https://example.com/a.mp4"}';
      expect(isInstagramDownloadOptions(encoded), isTrue);
      expect(isExtractorDownloadOptions(encoded), isTrue);
      expect(
        instagramOptionsFromJson(encoded)?.directUrl,
        'https://example.com/a.mp4',
      );
    });
  });

  group('InstagramMetadataClient.parsePageHtml', () {
    late InstagramMetadataClient client;

    setUp(() {
      client = InstagramMetadataClient();
    });

    tearDown(() {
      client.close();
    });

    test('extracts progressive CDN URLs from fixture HTML', () {
      const fixture = '''
<!DOCTYPE html>
<html>
<head>
  <meta property="og:title" content="Public Demo Reel" />
  <meta property="og:video" content="https://scontent.cdninstagram.com/v/t50/og.mp4" />
</head>
<body>
<script>
window.__additionalDataLoaded = {
  "pk": "9988776655",
  "video_duration": 12.5,
  "video_url": "https://scontent.cdninstagram.com/v/t50/main.mp4?_nc=1",
  "video_versions": [
    {"type": 101, "width": 720, "height": 1280, "url": "https://scontent.cdninstagram.com/v/t50/v1280.mp4"},
    {"type": 102, "width": 360, "height": 640, "url": "https://scontent.cdninstagram.com/v/t50/v640.mp4"}
  ]
};
</script>
</body>
</html>
''';

      final result = client.parsePageHtml(
        fixture,
        pageUrl: 'https://www.instagram.com/reel/ABC123xyz_/',
      );

      expect(result.info.title, 'Public Demo Reel');
      expect(result.info.id, '9988776655');
      expect(result.info.duration, 13);
      expect(result.progressiveUrls.isNotEmpty, isTrue);
      expect(result.urlForFormat('video_url'), contains('main.mp4'));
      expect(result.urlForFormat('v1280'), contains('v1280.mp4'));
      expect(result.info.formats.any((f) => f.formatId == 'v1280'), isTrue);
    });

    test('extracts GraphQL video_versions without width/height', () {
      const fixture = '''
{"data":{"xig_polaris_media":{"pk":"3945415418143709977","code":"DbA7mtJzhsZ",
"if_not_gated_logged_out":{"pk":"3945415418143709977","code":"DbA7mtJzhsZ",
"user":{"username":"demo_user"},
"video_duration":9.1,
"video_versions":[
  {"type":101,"url":"https://instagram.fdac142-1.fna.fbcdn.net/o1/v/t2/f2/m86/a.mp4"},
  {"type":102,"url":"https://instagram.fdac142-1.fna.fbcdn.net/o1/v/t2/f2/m86/b.mp4"},
  {"type":103,"url":"https://instagram.fdac142-1.fna.fbcdn.net/o1/v/t2/f2/m86/c.mp4"}
]}}}}
''';
      final result = client.parsePageHtml(
        fixture,
        pageUrl: 'https://www.instagram.com/reel/DbA7mtJzhsZ/',
      );
      expect(result.progressiveUrls.length, greaterThanOrEqualTo(1));
      expect(result.urlForFormat('type_101'), contains('a.mp4'));
      expect(result.info.id, anyOf('3945415418143709977', 'DbA7mtJzhsZ'));
    });

    test('throws when no progressive URL is present', () {
      expect(
        () => client.parsePageHtml(
          '<html><body>no video</body></html>',
          pageUrl: 'https://www.instagram.com/p/ABC/',
        ),
        throwsA(isA<YtdlpException>()),
      );
    });

    test('does not treat ordinary Log in chrome as useful video HTML', () {
      // Pages always mention login; useful detection must require media markers.
      const html = '''
<html><body>
<a href="/accounts/login">Log in</a>
<script>window.__cfg = {"login":true}</script>
</body></html>
''';
      expect(
        InstagramMetadataClient.pageUrlCandidates(
          'https://www.instagram.com/reel/DbPeKUKle5x/',
        ),
        contains('https://www.instagram.com/reel/DbPeKUKle5x/embed/'),
      );
      expect(
        () => client.parsePageHtml(
          html,
          pageUrl: 'https://www.instagram.com/reel/DbPeKUKle5x/',
        ),
        throwsA(
          isA<YtdlpException>().having(
            (e) => e.message,
            'message',
            contains('Settings → Instagram'),
          ),
        ),
      );
    });
  });
}
