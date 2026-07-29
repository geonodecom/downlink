import 'package:flutter_test/flutter_test.dart';
import 'package:geonode_download_manager/src/torrent/torrent_models.dart';

void main() {
  group('TorrentDownloadOptions', () {
    test('encodes and decodes magnet options', () {
      const options = TorrentDownloadOptions(
        kind: TorrentDownloadOptions.kindMagnet,
        seedMode: TorrentSeedMode.ratio,
        seedRatio: 1.5,
        seedTimeMinutes: 30,
      );
      final json = options.toJson();
      final parsed = TorrentDownloadOptions.fromJson(json);
      expect(parsed.kind, TorrentDownloadOptions.kindMagnet);
      expect(parsed.seedMode, TorrentSeedMode.ratio);
      expect(parsed.seedRatio, 1.5);
      expect(parsed.seedTimeMinutes, 30);
    });

    test('maps stop seed mode to aria2 options', () {
      const options = TorrentDownloadOptions(
        kind: TorrentDownloadOptions.kindMagnet,
        seedMode: TorrentSeedMode.stop,
      );
      expect(options.toAria2SeedOptions(), {
        'seed-time': '0',
        'seed-ratio': '0.0',
      });
    });

    test('maps ratio seed mode to aria2 options', () {
      const options = TorrentDownloadOptions(
        kind: TorrentDownloadOptions.kindTorrent,
        torrentPath: r'C:\a.torrent',
        seedMode: TorrentSeedMode.ratio,
        seedRatio: 2.0,
      );
      expect(options.toAria2SeedOptions(), {'seed-ratio': '2.0'});
    });

    test('maps time seed mode to aria2 options', () {
      const options = TorrentDownloadOptions(
        kind: TorrentDownloadOptions.kindMagnet,
        seedMode: TorrentSeedMode.time,
        seedTimeMinutes: 120,
      );
      expect(options.toAria2SeedOptions(), {
        'seed-time': '120',
        'seed-ratio': '0.0',
      });
    });

    test('torrentOptionsFromJson rejects other kinds', () {
      expect(
        torrentOptionsFromJson('{"kind":"tiktok","formatId":"1"}'),
        isNull,
      );
    });
  });
}
