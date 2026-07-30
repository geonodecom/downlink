import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/services/url_classifier.dart';

void main() {
  group('UrlClassifier', () {
    test('detects youtube watch URLs', () {
      expect(
        UrlClassifier.classify(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        DownloadUrlKind.youtube,
      );
    });

    test('watch with list is single video not playlist', () {
      expect(
        UrlClassifier.classify(
          'https://www.youtube.com/watch?v=UdsO4SM4wKI&list=RDUdsO4SM4wKI&start_radio=1',
        ),
        DownloadUrlKind.youtube,
      );
    });

    test('detects youtu.be URLs', () {
      expect(
        UrlClassifier.classify('https://youtu.be/dQw4w9WgXcQ'),
        DownloadUrlKind.youtube,
      );
    });

    test('detects youtube shorts', () {
      expect(
        UrlClassifier.classify('https://www.youtube.com/shorts/abc123xyz01'),
        DownloadUrlKind.youtube,
      );
    });

    test('detects live embed clip and v paths', () {
      expect(
        UrlClassifier.classify('https://www.youtube.com/live/dQw4w9WgXcQ'),
        DownloadUrlKind.youtube,
      );
      expect(
        UrlClassifier.classify('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        DownloadUrlKind.youtube,
      );
      expect(
        UrlClassifier.classify('https://www.youtube.com/clip/UgkxABCDEFGHI'),
        DownloadUrlKind.youtube,
      );
      expect(
        UrlClassifier.classify('https://www.youtube.com/v/dQw4w9WgXcQ'),
        DownloadUrlKind.youtube,
      );
    });

    test('detects music and nocookie hosts', () {
      expect(
        UrlClassifier.classify(
          'https://music.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        DownloadUrlKind.youtube,
      );
      expect(
        UrlClassifier.classify(
          'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
        ),
        DownloadUrlKind.youtube,
      );
    });

    test('normalizes bare youtube hosts', () {
      expect(
        UrlClassifier.normalizeInputUrl(
          'youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        'https://youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(
        UrlClassifier.classify('youtube.com/watch?v=dQw4w9WgXcQ'),
        DownloadUrlKind.youtube,
      );
    });

    test('detects playlist-only URLs', () {
      expect(
        UrlClassifier.classify(
          'https://www.youtube.com/playlist?list=PL123',
        ),
        DownloadUrlKind.youtubePlaylist,
      );
    });

    test('watch with list but no video id is not a playlist', () {
      expect(
        UrlClassifier.classify(
          'https://www.youtube.com/watch?list=RDUdsO4SM4wKI&index=9',
        ),
        DownloadUrlKind.direct,
      );
    });

    test('normalizeYoutubeUrl strips list params to canonical watch url', () {
      expect(
        UrlClassifier.normalizeYoutubeUrl(
          'https://www.youtube.com/watch?v=YyepU5ztLf4&list=RDUdsO4SM4wKI&index=9',
        ),
        'https://www.youtube.com/watch?v=YyepU5ztLf4',
      );
    });

    test('normalizeInputUrl strips zero-width characters', () {
      expect(
        UrlClassifier.normalizeInputUrl(
          '\uFEFFhttps://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
    });

    test('normalizeYoutubeUrl returns canonical watch url', () {
      expect(
        UrlClassifier.normalizeYoutubeUrl(
          'https://youtu.be/dQw4w9WgXcQ?si=abc',
        ),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
    });

    test('leaves direct URLs unchanged', () {
      expect(
        UrlClassifier.classify('https://example.com/file.bin'),
        DownloadUrlKind.direct,
      );
    });

    test('detects facebook hosts and paths', () {
      expect(
        UrlClassifier.classify(
          'https://www.facebook.com/watch/?v=1234567890',
        ),
        DownloadUrlKind.facebook,
      );
      expect(
        UrlClassifier.classify('https://fb.watch/abcXYZ12'),
        DownloadUrlKind.facebook,
      );
      expect(
        UrlClassifier.classify(
          'https://www.facebook.com/reel/123456789012345',
        ),
        DownloadUrlKind.facebook,
      );
      expect(
        UrlClassifier.classify('facebook.com/watch/?v=99'),
        DownloadUrlKind.facebook,
      );
    });

    test('normalizeFacebookUrl canonicalizes watch and reel links', () {
      expect(
        UrlClassifier.normalizeFacebookUrl(
          'https://m.facebook.com/watch/?v=1234567890&ref=share',
        ),
        'https://www.facebook.com/watch/?v=1234567890',
      );
      expect(
        UrlClassifier.normalizeFacebookUrl(
          'https://www.facebook.com/reel/9876543210/?s=single',
        ),
        'https://www.facebook.com/reel/9876543210',
      );
      expect(
        UrlClassifier.normalizeFacebookUrl('https://fb.watch/AbCdEfG'),
        'https://fb.watch/AbCdEfG',
      );
    });

    test('detects instagram hosts and paths', () {
      expect(
        UrlClassifier.classify(
          'https://www.instagram.com/reel/ABC123xyz_/',
        ),
        DownloadUrlKind.instagram,
      );
      expect(
        UrlClassifier.classify(
          'https://www.instagram.com/p/ABC123xyz_/',
        ),
        DownloadUrlKind.instagram,
      );
      expect(
        UrlClassifier.classify('https://instagr.am/p/ABC123xyz_/'),
        DownloadUrlKind.instagram,
      );
      expect(
        UrlClassifier.classify('instagram.com/reel/ABC123xyz_/'),
        DownloadUrlKind.instagram,
      );
    });

    test('normalizeInstagramUrl canonicalizes post and reel links', () {
      expect(
        UrlClassifier.normalizeInstagramUrl(
          'https://m.instagram.com/reel/ABC123xyz_/?igsh=foo',
        ),
        'https://www.instagram.com/reel/ABC123xyz_/',
      );
      expect(
        UrlClassifier.normalizeInstagramUrl(
          'https://www.instagram.com/p/XYZ99abcde/',
        ),
        'https://www.instagram.com/p/XYZ99abcde/',
      );
      expect(
        UrlClassifier.normalizeInstagramUrl(
          'https://www.instagram.com/tv/TVCode12345/',
        ),
        'https://www.instagram.com/tv/TVCode12345/',
      );
      expect(
        UrlClassifier.extractInstagramShortcode(
          'https://www.instagram.com/reel/ABC123xyz_/',
        ),
        'ABC123xyz_',
      );
    });

    test('detects tiktok hosts and video paths', () {
      expect(
        UrlClassifier.classify(
          'https://www.tiktok.com/@user/video/7123456789012345678',
        ),
        DownloadUrlKind.tiktok,
      );
      expect(
        UrlClassifier.classify('https://vm.tiktok.com/7123456789012345678/'),
        DownloadUrlKind.tiktok,
      );
      expect(
        UrlClassifier.classify('https://vm.tiktok.com/ZMeShortCode/'),
        DownloadUrlKind.tiktok,
      );
      expect(
        UrlClassifier.classify('https://www.tiktok.com/'),
        DownloadUrlKind.direct,
      );
    });

    test('normalizeTiktokUrl and extractTiktokVideoId', () {
      expect(
        UrlClassifier.normalizeTiktokUrl(
          'https://m.tiktok.com/@demo/video/7123456789012345678?lang=en',
        ),
        'https://www.tiktok.com/@demo/video/7123456789012345678',
      );
      expect(
        UrlClassifier.extractTiktokVideoId(
          'https://www.tiktok.com/@demo/video/7123456789012345678',
        ),
        '7123456789012345678',
      );
      expect(
        UrlClassifier.isTiktok(
          'https://vm.tiktok.com/7123456789012345678/',
        ),
        isTrue,
      );
    });

    test('detects magnet links', () {
      expect(
        UrlClassifier.classify(
          'magnet:?xt=urn:btih:0123456789ABCDEF0123456789ABCDEF01234567&dn=Example',
        ),
        DownloadUrlKind.magnet,
      );
      expect(
        UrlClassifier.magnetDisplayName(
          'magnet:?xt=urn:btih:0123456789ABCDEF0123456789ABCDEF01234567&dn=My+File',
        ),
        'My File',
      );
    });

    test('detects torrent files and URLs', () {
      expect(
        UrlClassifier.classify(r'C:\Downloads\demo.torrent'),
        DownloadUrlKind.torrent,
      );
      expect(
        UrlClassifier.classify('https://example.com/files/demo.torrent'),
        DownloadUrlKind.torrent,
      );
    });
  });
}
