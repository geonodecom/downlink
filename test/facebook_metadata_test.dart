import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/facebook/facebook_metadata_client.dart';
import 'package:downlink/src/facebook/facebook_models.dart';
import 'package:downlink/src/ytdlp/ytdlp_client.dart';

void main() {
  group('FacebookDownloadOptions', () {
    test('round-trips JSON including directUrl', () {
      const options = FacebookDownloadOptions(
        formatId: 'hd',
        title: 'Sample Clip',
        ext: 'mp4',
        directUrl: 'https://video.xx.fbcdn.net/v/t66/hd.mp4',
      );

      final json = options.toJson();
      expect(json['kind'], 'facebook');
      expect(json['directUrl'], contains('fbcdn'));

      final restored = FacebookDownloadOptions.fromJson(json);
      expect(restored.formatId, 'hd');
      expect(restored.title, 'Sample Clip');
      expect(restored.ext, 'mp4');
      expect(restored.directUrl, options.directUrl);
      expect(restored.sanitizedFileName, 'Sample Clip.mp4');
    });

    test('omits empty directUrl from JSON', () {
      const options = FacebookDownloadOptions(
        formatId: 'sd',
        title: 'Desktop',
        ext: 'mp4',
      );
      expect(options.toJson().containsKey('directUrl'), isFalse);
    });

    test('detects facebook options from encoded JSON', () {
      const options = FacebookDownloadOptions(
        formatId: 'hd',
        title: 'A',
        ext: 'mp4',
        directUrl: 'https://example.com/a.mp4',
      );
      final encoded =
          '{"kind":"facebook","formatId":"hd","title":"A","ext":"mp4",'
          '"directUrl":"https://example.com/a.mp4"}';
      expect(isFacebookDownloadOptions(encoded), isTrue);
      expect(isExtractorDownloadOptions(encoded), isTrue);
      expect(facebookOptionsFromJson(encoded)?.directUrl, options.directUrl);
    });
  });

  group('FacebookMetadataClient.parsePageHtml', () {
    late FacebookMetadataClient client;

    setUp(() {
      client = FacebookMetadataClient();
    });

    tearDown(() {
      client.close();
    });

    test('extracts progressive HD/SD CDN URLs from fixture HTML', () {
      const fixture = '''
<!DOCTYPE html>
<html>
<head>
  <meta property="og:title" content="Public Demo Video" />
</head>
<body>
<script>
window.__data = {
  "video_id": "1234567890",
  "playable_duration_in_ms": 12500,
  "browser_native_hd_url": "https://video.xx.fbcdn.net/v/t66/hd_clip.mp4?_nc=1",
  "browser_native_sd_url": "https://video.xx.fbcdn.net/v/t66/sd_clip.mp4?_nc=1",
  "playable_url": "https://video.xx.fbcdn.net/v/t66/sd_clip.mp4?_nc=1",
  "playable_url_quality_hd": "https://video.xx.fbcdn.net/v/t66/hd_clip.mp4?_nc=1"
};
</script>
</body>
</html>
''';

      final result = client.parsePageHtml(
        fixture,
        pageUrl: 'https://www.facebook.com/watch/?v=1234567890',
      );

      expect(result.info.title, 'Public Demo Video');
      expect(result.info.id, '1234567890');
      expect(result.info.duration, 12);
      expect(result.progressiveUrls.keys, containsAll(['hd', 'sd']));
      expect(result.urlForFormat('hd'), contains('hd_clip.mp4'));
      expect(result.urlForFormat('sd'), contains('sd_clip.mp4'));

      final selectable = result.info.selectableFormats();
      expect(selectable, isNotEmpty);
      expect(selectable.first.formatId, 'hd');
    });

    test('extracts unicode-escaped progressive_url entries', () {
      const fixture = r'''
<html><head><meta property="og:title" content="Escaped" /></head>
<body><script>
{"videoDeliveryResponseResult":{"progressive_urls":[
  {"progressive_url":"https\u003a\u002f\u002fvideo.xx.fbcdn.net\u002fv\u002fprog_hd.mp4","metadata":{"quality":"hd"}},
  {"progressive_url":"https\u003a\u002f\u002fvideo.xx.fbcdn.net\u002fv\u002fprog_sd.mp4","metadata":{"quality":"sd"}}
]}}
</script></body></html>
''';

      final result = client.parsePageHtml(
        fixture,
        pageUrl: 'https://fb.watch/AbCdEf12',
      );

      expect(result.info.title, 'Escaped');
      expect(result.urlForFormat('hd'), 'https://video.xx.fbcdn.net/v/prog_hd.mp4');
      expect(result.urlForFormat('sd'), 'https://video.xx.fbcdn.net/v/prog_sd.mp4');
    });

    test('throws when no progressive MP4 is present', () {
      const fixture = '''
<html><head><meta property="og:title" content="Login wall" /></head>
<body><div>Please log in to continue</div></body></html>
''';

      expect(
        () => client.parsePageHtml(
          fixture,
          pageUrl: 'https://www.facebook.com/watch/?v=1',
        ),
        throwsA(isA<YtdlpException>()),
      );
    });

    test('decodes malformed UTF-8 response bodies without throwing', () {
      // Invalid continuation byte sequence (classic "Unexpected extension byte").
      final bytes = <int>[
        ...utf8.encode('<html>'),
        0x80,
        0x81,
        ...utf8.encode('"browser_native_hd_url":"https://video.xx.fbcdn.net/v/t.mp4"'),
        ...utf8.encode('</html>'),
      ];
      final body = utf8.decode(bytes, allowMalformed: true);
      final result = client.parsePageHtml(
        body,
        pageUrl: 'https://www.facebook.com/watch/?v=99',
      );
      expect(result.urlForFormat('hd'), contains('.mp4'));
    });

    test('pageUrlCandidates expands reel links to watch URLs', () {
      final candidates = FacebookMetadataClient.pageUrlCandidates(
        'https://www.facebook.com/reel/26839013919024659',
      );
      expect(
        candidates,
        contains('https://www.facebook.com/watch/?v=26839013919024659'),
      );
      expect(
        candidates,
        contains('https://m.facebook.com/watch/?v=26839013919024659&_rdr'),
      );
    });

    test('pageUrlCandidates expands group permalinks', () {
      final candidates = FacebookMetadataClient.pageUrlCandidates(
        'https://www.facebook.com/groups/1055951273631507/permalink/1064647862761848/',
      );
      expect(
        candidates,
        contains(
          'https://m.facebook.com/groups/1055951273631507/permalink/1064647862761848/',
        ),
      );
      expect(
        candidates,
        contains(
          'https://m.facebook.com/story.php?story_fbid=1064647862761848&id=1055951273631507',
        ),
      );
      expect(
        candidates,
        contains('https://www.facebook.com/watch/?v=1064647862761848'),
      );
      expect(
        FacebookMetadataClient.isGroupPostUrl(
          'https://www.facebook.com/groups/1/permalink/2/',
        ),
        isTrue,
      );
      expect(
        FacebookMetadataClient.isGroupPostUrl(
          'https://www.facebook.com/watch/?v=1',
        ),
        isFalse,
      );
    });
  });
}
