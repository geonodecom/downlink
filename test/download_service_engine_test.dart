import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/data/app_database.dart';
import 'package:downlink/src/data/download_repository.dart';
import 'package:downlink/src/services/download_probe.dart';
import 'package:downlink/src/services/download_service.dart';

import 'download_engine_test.dart';

class _FixedProbe extends DownloadProbe {
  var calls = 0;

  @override
  Future<DownloadMetadata> probe(NewDownload input) async {
    calls++;
    return const DownloadMetadata(fileName: 'probed.bin', totalLength: 100);
  }
}

void main() {
  late AppDatabase db;
  late DownloadRepository repository;
  late FakeDownloadEngine engine;
  late DownloadService service;
  late _FixedProbe probe;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DownloadRepository(db);
    engine = FakeDownloadEngine();
    probe = _FixedProbe();
    service = DownloadService(
      repository: repository,
      engine: engine,
      probe: probe,
    );
  });

  tearDown(() async {
    service.dispose();
    await db.close();
  });

  test('start and addDownload attach engine gid', () async {
    await repository.saveSettings(
      const DownlinkSettings(
        downloadDirectory: '/tmp',
        maxActiveDownloads: 1,
        defaultSplit: 4,
        aria2Path: '',
        ytdlpPath: '',
        ffmpegPath: '',
        youtubeFormatPreset: 'best_mp4',
        themeMode: 'system',
      ),
    );

    await service.addDownload(
      const NewDownload(
        url: 'https://example.com/probed.bin',
        directory: '/tmp',
        fileName: '',
        split: 4,
        startImmediately: true,
      ),
    );

    final downloads = await repository.watchDownloads().first;
    expect(downloads, hasLength(1));
    expect(downloads.single.gid, isNotNull);
    expect(downloads.single.fileName, 'probed.bin');
    expect(engine.started, isTrue);
    expect(probe.calls, 1);
  });

  test('addDownload skips probe for youtube options', () async {
    await repository.saveSettings(
      const DownlinkSettings(
        downloadDirectory: '/tmp',
        maxActiveDownloads: 1,
        defaultSplit: 4,
        aria2Path: '',
        ytdlpPath: '',
        ffmpegPath: '',
        youtubeFormatPreset: 'best_mp4',
        themeMode: 'system',
      ),
    );

    await service.addDownload(
      const NewDownload(
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        directory: '/tmp',
        fileName: 'Video.mp4',
        split: 1,
        startImmediately: true,
        metadata: DownloadMetadata(fileName: 'Video.mp4'),
        source: 'youtube',
        options: {
          'kind': 'youtube',
          'formatId': '22',
          'title': 'Video',
          'ext': 'mp4',
        },
      ),
    );

    expect(probe.calls, 0);
    final downloads = await repository.watchDownloads().first;
    expect(downloads.single.fileName, 'Video.mp4');
    expect(engine.lastOptionsJson?['kind'], 'youtube');
  });

  test('pause and resume update repository status', () async {
    await repository.saveSettings(
      const DownlinkSettings(
        downloadDirectory: '/tmp',
        maxActiveDownloads: 1,
        defaultSplit: 4,
        aria2Path: '',
        ytdlpPath: '',
        ffmpegPath: '',
        youtubeFormatPreset: 'best_mp4',
        themeMode: 'system',
      ),
    );

    await service.addDownload(
      const NewDownload(
        url: 'https://example.com/file.bin',
        directory: '/tmp',
        fileName: 'file.bin',
        split: 4,
        startImmediately: true,
      ),
    );
    final id = (await repository.watchDownloads().first).single.id;

    await service.pause(id);
    expect(
      (await repository.findById(id))!.status,
      DownloadStatus.paused.name,
    );

    await service.resume(id);
    expect(
      (await repository.findById(id))!.status,
      DownloadStatus.active.name,
    );
  });

  test('resetEngineSession clears fake engine state', () async {
    await repository.saveSettings(
      const DownlinkSettings(
        downloadDirectory: '/tmp',
        maxActiveDownloads: 1,
        defaultSplit: 4,
        aria2Path: '',
        ytdlpPath: '',
        ffmpegPath: '',
        youtubeFormatPreset: 'best_mp4',
        themeMode: 'system',
      ),
    );
    await service.start();
    await service.resetEngineSession();
    expect(engine.resetCount, 1);
  });
}
