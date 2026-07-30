import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/facebook/facebook_models.dart';
import 'package:downlink/src/tiktok/tiktok_metadata_client.dart';
import 'package:downlink/src/tiktok/tiktok_models.dart';
import 'package:downlink/src/ytdlp/ytdlp_client.dart';

void main() {
  group('TikTokDownloadOptions', () {
    test('round-trips JSON including directUrl', () {
      const options = TikTokDownloadOptions(
        formatId: 'tiktok_play_0',
        title: 'Sample clip',
        ext: 'mp4',
        directUrl: 'https://v16-webapp-prime.tiktok.com/video/tos/example.mp4',
      );

      final json = options.toJson();
      expect(json['kind'], 'tiktok');
      expect(json['directUrl'], contains('tiktok.com'));

      final restored = TikTokDownloadOptions.fromJson(json);
      expect(restored.formatId, 'tiktok_play_0');
      expect(restored.title, 'Sample clip');
      expect(restored.ext, 'mp4');
      expect(restored.directUrl, options.directUrl);
      expect(restored.sanitizedFileName, 'Sample clip.mp4');
    });

    test('omits empty directUrl from JSON', () {
      const options = TikTokDownloadOptions(
        formatId: 'best',
        title: 'Desktop',
        ext: 'mp4',
      );
      expect(options.toJson().containsKey('directUrl'), isFalse);
    });

    test('detects tiktok options from encoded JSON', () {
      const encoded =
          '{"kind":"tiktok","formatId":"play","title":"A","ext":"mp4",'
          '"directUrl":"https://example.com/a.mp4"}';
      expect(isTikTokDownloadOptions(encoded), isTrue);
      expect(isExtractorDownloadOptions(encoded), isTrue);
      expect(
        tiktokOptionsFromJson(encoded)?.directUrl,
        'https://example.com/a.mp4',
      );
    });
  });

  group('TikTokMetadataClient.parsePageHtml', () {
    late TikTokMetadataClient client;

    setUp(() {
      client = TikTokMetadataClient();
    });

    tearDown(() {
      client.close();
    });

    test('extracts progressive URLs from universal data fixture', () {
      const fixture = '''
<!DOCTYPE html>
<html>
<head><title>TikTok</title></head>
<body>
<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">
{
  "__DEFAULT_SCOPE__": {
    "webapp.video-detail": {
      "itemInfo": {
        "itemStruct": {
          "id": "7123456789012345678",
          "desc": "Public demo clip",
          "author": {"uniqueId": "demo_user"},
          "video": {
            "duration": 15,
            "downloadAddr": "https://v16-webapp.tiktok.com/video/download/demo.mp4",
            "playAddr": "https://v16-webapp.tiktok.com/video/play/demo.mp4",
            "bitrateInfo": [
              {
                "GearName": "adapt_720",
                "PlayAddr": {
                  "UrlList": ["https://v16-webapp.tiktok.com/video/720/demo.mp4"]
                }
              }
            ]
          }
        }
      }
    }
  }
}
</script>
</body>
</html>
''';

      final result = client.parsePageHtml(
        fixture,
        pageUrl: 'https://www.tiktok.com/@demo_user/video/7123456789012345678',
      );

      expect(result.info.id, '7123456789012345678');
      expect(result.info.title, 'Public demo clip');
      expect(result.progressiveUrls.length, greaterThanOrEqualTo(2));
      expect(
        result.progressiveUrls.values.first,
        startsWith('https://'),
      );
    });

    test('extracts from SIGI_STATE playAddr fixture', () {
      const fixture = '''
<script id="SIGI_STATE" type="application/json">
{
  "ItemModule": {
    "7123456789012345678": {
      "id": "7123456789012345678",
      "desc": "Legacy layout",
      "video": {
        "duration": 9,
        "playAddr": "https://v16-webapp.tiktok.com/video/legacy.mp4"
      }
    }
  }
}
</script>
''';

      final result = client.parsePageHtml(
        fixture,
        pageUrl: 'https://www.tiktok.com/video/7123456789012345678',
      );

      expect(result.info.title, 'Legacy layout');
      expect(result.urlForFormat(result.info.formats.first.formatId), isNotNull);
    });

    test('throws friendly error when no video JSON present', () {
      expect(
        () => client.parsePageHtml(
          '<html><body>empty</body></html>',
          pageUrl: 'https://www.tiktok.com/@x/video/1',
        ),
        throwsA(isA<YtdlpException>()),
      );
    });
  });
}
