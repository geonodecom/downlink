import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/engine/composite_download_engine.dart';
import 'package:downlink/src/ytdlp/ytdlp_models.dart';

import 'download_engine_test.dart';

class FakeYoutubeEngine extends FakeDownloadEngine {
  @override
  Future<String> addUri({
    required String url,
    required String directory,
    required int split,
    String? fileName,
    Map<String, String> headers = const {},
    int? position,
    Map<String, Object?>? optionsJson,
  }) async {
    return 'ytdlp:fake-${statuses.length + 1}';
  }
}

void main() {
  test('composite engine routes youtube downloads to yt-dlp gid prefix', () async {
    final base = FakeDownloadEngine();
    final youtube = FakeYoutubeEngine();
    final composite = CompositeDownloadEngine(
      baseEngine: base,
      youtubeEngine: youtube,
    );
    await composite.start(
      downloadDirectory: '/tmp',
      maxActiveDownloads: 1,
      defaultSplit: 4,
    );

    final directGid = await composite.addUri(
      url: 'https://example.com/file.bin',
      directory: '/tmp',
      split: 4,
      fileName: 'file.bin',
    );
    expect(directGid.startsWith('gid-'), isTrue);

    final youtubeGid = await composite.addUri(
      url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      directory: '/tmp',
      split: 1,
      fileName: 'video.mp4',
      optionsJson: const YoutubeDownloadOptions(
        formatId: '22',
        title: 'Video',
        ext: 'mp4',
      ).toJson(),
    );
    expect(youtubeGid.startsWith('ytdlp:'), isTrue);
  });
}
