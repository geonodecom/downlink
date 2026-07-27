import 'package:flutter_test/flutter_test.dart';
import 'package:geonode_download_manager/src/ytdlp/ytdlp_models.dart';

void main() {
  test('parses yt-dlp metadata and builds selectable formats', () {
    final info = YtdlpVideoInfo.fromJson({
      'id': 'abc123',
      'title': 'Sample Video',
      'duration': 125,
      'formats': [
        {
          'format_id': '22',
          'ext': 'mp4',
          'width': 1280,
          'height': 720,
          'format_note': '720p',
          'filesize': 1048576,
          'vcodec': 'avc1',
          'acodec': 'mp4a',
          'format': '720p mp4',
        },
        {
          'format_id': '137',
          'ext': 'mp4',
          'width': 1920,
          'height': 1080,
          'format_note': '1080p',
          'filesize': 2097152,
          'vcodec': 'avc1',
          'acodec': 'none',
          'format': '1080p video',
        },
        {
          'format_id': '140',
          'ext': 'm4a',
          'format_note': 'medium',
          'filesize': 524288,
          'vcodec': 'none',
          'acodec': 'mp4a',
          'format': 'audio only',
        },
      ],
    });

    expect(info.title, 'Sample Video');
    expect(info.duration, 125);

    final selectable = info.selectableFormats();
    expect(selectable, isNotEmpty);
    expect(selectable.first.formatId, '22');
    expect(
      selectable.any((format) => format.formatId.contains('137+140')),
      isTrue,
    );
    expect(
      info.defaultFormatId(YoutubeFormatPreset.bestMp4),
      '22',
    );
  });

  test('sanitizes youtube filenames', () {
    const options = YoutubeDownloadOptions(
      formatId: '22',
      title: 'Video: Test / Demo?',
      ext: 'mp4',
    );
    expect(options.sanitizedFileName, 'Video_ Test _ Demo_.mp4');
  });

  test('parses flat playlist metadata', () {
    final playlist = YtdlpPlaylistInfo.fromJson({
      'id': 'PL123',
      'title': 'My Playlist',
      'entries': [
        {'id': 'aaaaaaaaaaa', 'title': 'One'},
        {
          'id': 'bbbbbbbbbbb',
          'title': 'Two',
          'url': 'https://www.youtube.com/watch?v=bbbbbbbbbbb',
        },
        null,
        {'id': '', 'title': 'Skip'},
      ],
    });

    expect(playlist.title, 'My Playlist');
    expect(playlist.entries, hasLength(2));
    expect(playlist.entries.first.url, contains('aaaaaaaaaaa'));
    expect(playlist.entries.last.title, 'Two');
  });

  test('treats Facebook progressive formats without codecs as selectable', () {
    final info = YtdlpVideoInfo.fromJson({
      'id': '400089874377628',
      'title': 'Facebook Reel',
      'duration': 12,
      'formats': [
        {
          'format_id': 'hd',
          'ext': 'mp4',
          'format_note': 'HD',
          'url': 'https://video.xx.fbcdn.net/v/t66/hd.mp4',
        },
        {
          'format_id': 'sd',
          'ext': 'mp4',
          'format_note': 'SD',
          'url': 'https://video.xx.fbcdn.net/v/t66/sd.mp4',
        },
      ],
    });

    final selectable = info.selectableFormats();
    expect(selectable, isNotEmpty);
    expect(selectable.map((f) => f.formatId), containsAll(['hd', 'sd']));
    expect(selectable.first.isCombined, isTrue);
    expect(info.defaultFormatId(YoutubeFormatPreset.bestMp4), isNotNull);
  });

  test('dedupes equivalent TikTok format twins in the picker', () {
    const info = YtdlpVideoInfo(
      id: '1',
      title: 'TikTok',
      duration: 10,
      formats: [
        YtdlpFormat(
          formatId: 'h264_720p-0',
          ext: 'mp4',
          resolution: '1280x720',
          note: '',
          fileSize: 122000000,
          vcodec: 'h264',
          acodec: 'aac',
          format: 'a',
        ),
        YtdlpFormat(
          formatId: 'h264_720p-1',
          ext: 'mp4',
          resolution: '1280x720',
          note: '',
          fileSize: 122000000,
          vcodec: 'h264',
          acodec: 'aac',
          format: 'b',
        ),
        YtdlpFormat(
          formatId: 'download',
          ext: 'mp4',
          resolution: '',
          note: 'watermarked',
          fileSize: null,
          vcodec: 'h264',
          acodec: 'aac',
          format: 'c',
        ),
      ],
    );

    final selectable = info.selectableFormats();
    expect(selectable.length, 2);
    expect(selectable.where((f) => f.resolution == '1280x720').length, 1);
  });
}
