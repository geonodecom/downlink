import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/ytdlp/ytdlp_progress.dart';

void main() {
  test('parses custom yt-dlp progress template', () {
    final progress = parseYtdlpProgressLine(
      'progress:524288:1048576:131072:4',
    );

    expect(progress, isNotNull);
    expect(progress!.downloadedBytes, 524288);
    expect(progress.totalBytes, 1048576);
    expect(progress.speedBytesPerSecond, 131072);
    expect(progress.etaSeconds, 4);
    expect(progress.percent, 50);
  });

  test('parses legacy yt-dlp progress line', () {
    final progress = parseLegacyYtdlpProgressLine(
      '[download]  25.0% of   10.00MiB at    1.00MiB/s ETA 00:07',
    );

    expect(progress, isNotNull);
    expect(progress!.percent, 25);
    expect(progress.totalBytes, greaterThan(0));
  });
}
