import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/ytdlp/youtube_format_id.dart';
import 'package:downlink/src/ytdlp/ytdlp_models.dart';

void main() {
  test('parseMergeFormatId accepts video+audio tags', () {
    final parsed = parseMergeFormatId('137+140');
    expect(parsed, isNotNull);
    expect(parsed!.videoTag, 137);
    expect(parsed.audioTag, 140);
  });

  test('parseMergeFormatId rejects single tags', () {
    expect(parseMergeFormatId('22'), isNull);
    expect(parseMergeFormatId('137+'), isNull);
    expect(parseMergeFormatId('a+b'), isNull);
  });

  test('selectableFormats builds high-res merge rows from videoOnly', () {
    final info = YtdlpVideoInfo(
      id: 'abc',
      title: 'Sample',
      duration: 120,
      formats: const [
        YtdlpFormat(
          formatId: '22',
          ext: 'mp4',
          resolution: '640x360',
          note: '360p',
          fileSize: 19 * 1024 * 1024,
          vcodec: 'avc1',
          acodec: 'mp4a',
          format: '360p',
        ),
        YtdlpFormat(
          formatId: '137',
          ext: 'mp4',
          resolution: '1920x1080',
          note: '1080p',
          fileSize: 80 * 1024 * 1024,
          vcodec: 'avc1',
          acodec: 'none',
          format: '1080p',
        ),
        YtdlpFormat(
          formatId: '401',
          ext: 'mp4',
          resolution: '3840x2160',
          note: '2160p',
          fileSize: 300 * 1024 * 1024,
          vcodec: 'av01',
          acodec: 'none',
          format: '2160p',
        ),
        YtdlpFormat(
          formatId: '140',
          ext: 'm4a',
          resolution: '',
          note: 'medium',
          fileSize: 3 * 1024 * 1024,
          vcodec: 'none',
          acodec: 'mp4a',
          format: 'medium',
        ),
      ],
    );

    final selectable = info.selectableFormats();
    expect(selectable.any((f) => f.formatId == '22'), isTrue);
    expect(selectable.any((f) => f.formatId == '137+140'), isTrue);
    expect(selectable.any((f) => f.formatId == '401+140'), isTrue);
    expect(
      selectable.any((f) => f.formatId.contains('+') && f.resolution.contains('1080')),
      isTrue,
    );
  });
}
