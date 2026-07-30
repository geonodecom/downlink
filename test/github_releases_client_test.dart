import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/app_update/github_releases_client.dart';

void main() {
  final sampleJson = {
    'tag_name': 'v0.2.0',
    'body': 'Bug fixes',
    'assets': [
      {
        'name': 'downlink-0.2.0.apk',
        'browser_download_url': 'https://example.com/app.apk',
        'size': 12345,
      },
      {
        'name': 'downlink-0.2.0-windows-x64-portable.zip',
        'browser_download_url': 'https://example.com/app.zip',
        'size': 99999,
      },
    ],
  };

  test('parseLatestReleaseJson selects apk on Android flag', () {
    final offer = parseLatestReleaseJson(sampleJson, android: true);
    expect(offer, isNotNull);
    expect(offer!.version, '0.2.0');
    expect(offer.fileName, 'downlink-0.2.0.apk');
    expect(offer.downloadUrl, 'https://example.com/app.apk');
    expect(offer.expectedSize, 12345);
    expect(offer.releaseNotes, 'Bug fixes');
  });

  test('parseLatestReleaseJson selects portable zip on Windows flag', () {
    final offer = parseLatestReleaseJson(sampleJson, android: false);
    expect(offer, isNotNull);
    expect(offer!.fileName, 'downlink-0.2.0-windows-x64-portable.zip');
    expect(offer.expectedSize, 99999);
  });

  test('returns null when assets missing', () {
    expect(
      parseLatestReleaseJson({'tag_name': 'v1.0.0', 'assets': []}, android: true),
      isNull,
    );
  });
}
