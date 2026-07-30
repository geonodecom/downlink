import 'dart:convert';

import 'package:downlink/src/aria2/aria2_models.dart';
import 'package:downlink/src/data/app_database.dart';
import 'package:downlink/src/data/download_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DownloadRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DownloadRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'findExistingDownload matches even after aria2 resolves filename',
    () async {
      final input = NewDownload(
        url: 'https://ash-speed.hetzner.com/1GB.bin',
        directory: '/tmp',
        fileName: '',
        split: 16,
        startImmediately: true,
        metadata: const DownloadMetadata(fileName: '1GB.bin'),
      );

      final created = await repository.createDownload(input);
      await (database.update(database.downloadEntries)
            ..where((row) => row.id.equals(created.id)))
          .write(const DownloadEntriesCompanion(fileName: Value('1GB.bin')));

      final existing = await repository.findExistingDownload(input);

      expect(existing?.id, created.id);
    },
  );

  test(
    'createDownload keeps original extension when override has none',
    () async {
      final created = await repository.createDownload(
        const NewDownload(
          url: 'https://ash-speed.hetzner.com/1GB.bin?cache=false',
          directory: '/tmp',
          fileName: 'test-download',
          split: 16,
          startImmediately: true,
        ),
      );

      expect(created.fileName, 'test-download.bin');
    },
  );

  test('createDownload keeps explicit extension from override', () async {
    final created = await repository.createDownload(
      const NewDownload(
        url: 'https://example.com/file.bin',
        directory: '/tmp',
        fileName: 'renamed.iso',
        split: 16,
        startImmediately: true,
      ),
    );

    expect(created.fileName, 'renamed.iso');
  });

  test('createDownload stores probed filename and length', () async {
    final created = await repository.createDownload(
      const NewDownload(
        url: 'https://example.com/download',
        directory: '/tmp',
        fileName: '',
        split: 16,
        startImmediately: false,
        metadata: DownloadMetadata(fileName: 'linux.iso', totalLength: 4096),
      ),
    );

    expect(created.fileName, 'linux.iso');
    expect(created.totalLength, 4096);
  });

  test('createDownload stores youtube options', () async {
    final created = await repository.createDownload(
      const NewDownload(
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        directory: '/tmp/youtube',
        fileName: 'Sample Video.mp4',
        split: 1,
        startImmediately: false,
        source: 'youtube',
        options: {
          'kind': 'youtube',
          'formatId': '22',
          'title': 'Sample Video',
          'ext': 'mp4',
        },
      ),
    );
    final options = jsonDecode(created.optionsJson!) as Map<String, Object?>;

    expect(created.source, 'youtube');
    expect(options['kind'], 'youtube');
    expect(options['formatId'], '22');
    expect(isYoutubeDownload(created), isTrue);
    expect(youtubeOptionsFor(created)?.title, 'Sample Video');
  });

  test('createDownload stores browser extension headers and source', () async {
    final created = await repository.createDownload(
      const NewDownload(
        url: 'https://example.com/download',
        directory: '/tmp',
        fileName: 'download.iso',
        split: 16,
        startImmediately: false,
        headers: {'Referer': 'https://example.com/', 'User-Agent': 'Downlink test'},
        source: 'browser_extension',
      ),
    );
    final options = jsonDecode(created.optionsJson!) as Map<String, Object?>;

    expect(created.source, 'browser_extension');
    expect(options['headers'], {
      'Referer': 'https://example.com/',
      'User-Agent': 'Downlink test',
    });
  });

  test(
    'listQueuedMissingMetadata finds queued rows without filename or size',
    () async {
      final missing = await repository.createDownload(
        const NewDownload(
          url: 'https://example.com/download',
          directory: '/tmp',
          fileName: '',
          split: 16,
          startImmediately: false,
        ),
      );
      await repository.createDownload(
        const NewDownload(
          url: 'https://example.com/linux.iso',
          directory: '/tmp',
          fileName: '',
          split: 16,
          startImmediately: false,
          metadata: DownloadMetadata(fileName: 'linux.iso', totalLength: 4096),
        ),
      );

      final rows = await repository.listQueuedMissingMetadata();

      expect(rows.map((row) => row.id), [missing.id]);
    },
  );

  test('watchDownload emits updates for a single row', () async {
    final created = await repository.createDownload(
      const NewDownload(
        url: 'https://example.com/linux.iso',
        directory: '/tmp',
        fileName: '',
        split: 16,
        startImmediately: false,
      ),
    );

    final events = repository.watchDownload(created.id);
    expect(await events.first != null, isTrue);

    await repository.updateMetadata(
      created.id,
      const DownloadMetadata(fileName: 'linux.iso', totalLength: 4096),
    );
    final updated = await events.firstWhere(
      (download) => download?.totalLength == 4096,
    );

    expect(updated?.fileName, 'linux.iso');
  });

  test('updateMetadata only writes available metadata', () async {
    final created = await repository.createDownload(
      const NewDownload(
        url: 'https://example.com/linux.iso',
        directory: '/tmp',
        fileName: '',
        split: 16,
        startImmediately: false,
      ),
    );

    await repository.updateMetadata(
      created.id,
      const DownloadMetadata(fileName: 'linux.iso', totalLength: 4096),
    );
    final updated = await repository.findById(created.id);

    expect(updated?.fileName, 'linux.iso');
    expect(updated?.totalLength, 4096);
  });

  test(
    'updateFromAria2 does not erase known metadata with waiting zeroes',
    () async {
      final created = await repository.createDownload(
        const NewDownload(
          url: 'https://example.com/linux.iso',
          directory: '/tmp',
          fileName: '',
          split: 16,
          startImmediately: false,
          metadata: DownloadMetadata(fileName: 'linux.iso', totalLength: 4096),
        ),
      );
      await repository.attachGid(created.id, 'gid-1');
      await (database.update(database.downloadEntries)
            ..where((row) => row.id.equals(created.id)))
          .write(const DownloadEntriesCompanion(completedLength: Value(1024)));

      await repository.updateFromAria2(
        const Aria2Status(
          gid: 'gid-1',
          status: 'waiting',
          totalLength: 0,
          completedLength: 0,
          downloadSpeed: 0,
          connections: 0,
          pieceLength: 0,
          numPieces: 0,
          bitfield: null,
          errorCode: null,
          errorMessage: null,
          files: [],
        ),
      );
      final updated = await repository.findById(created.id);

      expect(updated?.status, DownloadStatus.queued.name);
      expect(updated?.fileName, 'linux.iso');
      expect(updated?.totalLength, 4096);
      expect(updated?.completedLength, 1024);
    },
  );

  test('updateFromAria2 keeps the stored name for temp part paths', () async {
    final created = await repository.createDownload(
      const NewDownload(
        url: 'https://www.facebook.com/reel/934986842964228',
        directory: '/tmp',
        fileName: 'facebook_934986842964228.mp4',
        split: 1,
        startImmediately: false,
      ),
    );
    await repository.attachGid(created.id, 'fd10c82d65bb49a5');

    await repository.updateFromAria2(
      const Aria2Status(
        gid: 'fd10c82d65bb49a5',
        status: 'active',
        totalLength: 4096,
        completedLength: 1024,
        downloadSpeed: 256,
        connections: 1,
        pieceLength: 0,
        numPieces: 0,
        bitfield: null,
        errorCode: null,
        errorMessage: null,
        files: [
          Aria2File(
            path: '/data/user/0/com.geonode.downlink/cache/parts/fd10c82d65bb49a5.part',
            length: 4096,
            completedLength: 1024,
            uris: ['https://www.facebook.com/reel/934986842964228'],
          ),
        ],
      ),
    );
    final updated = await repository.findById(created.id);

    expect(updated?.fileName, 'facebook_934986842964228.mp4');
  });

  test('updateFromAria2 keeps the stored name for MediaStore URIs', () async {
    final created = await repository.createDownload(
      const NewDownload(
        url: 'https://www.youtube.com/watch?v=abc',
        directory: '/tmp',
        fileName: 'Big Buck Bunny.mp4',
        split: 1,
        startImmediately: false,
      ),
    );
    await repository.attachGid(created.id, 'gid-1');

    await repository.updateFromAria2(
      const Aria2Status(
        gid: 'gid-1',
        status: 'complete',
        totalLength: 4096,
        completedLength: 4096,
        downloadSpeed: 0,
        connections: 1,
        pieceLength: 0,
        numPieces: 0,
        bitfield: null,
        errorCode: null,
        errorMessage: null,
        files: [
          Aria2File(
            path: 'content://media/external_primary/downloads/54',
            length: 4096,
            completedLength: 4096,
            uris: ['https://www.youtube.com/watch?v=abc'],
          ),
        ],
      ),
    );
    final updated = await repository.findById(created.id);

    expect(updated?.fileName, 'Big Buck Bunny.mp4');
    expect(
      updated?.contentUri,
      'content://media/external_primary/downloads/54',
    );
  });

  test('attachStatusToMatchingDownload repairs restored aria2 gids', () async {
    final created = await repository.createDownload(
      const NewDownload(
        url: 'https://example.com/linux.iso',
        directory: '/tmp',
        fileName: '',
        split: 16,
        startImmediately: false,
        metadata: DownloadMetadata(fileName: 'linux.iso', totalLength: 4096),
      ),
    );
    await repository.attachGid(created.id, 'old-gid');

    final attached = await repository.attachStatusToMatchingDownload(
      const Aria2Status(
        gid: 'restored-gid',
        status: 'active',
        totalLength: 4096,
        completedLength: 1024,
        downloadSpeed: 512,
        connections: 2,
        pieceLength: 1024,
        numPieces: 4,
        bitfield: '8',
        errorCode: null,
        errorMessage: null,
        files: [
          Aria2File(
            path: '/tmp/linux.iso',
            length: 4096,
            completedLength: 1024,
            uris: ['https://example.com/linux.iso'],
          ),
        ],
      ),
    );
    final updated = await repository.findById(created.id);

    expect(attached, isTrue);
    expect(updated?.gid, 'restored-gid');
    expect(updated?.status, DownloadStatus.active.name);
    expect(updated?.completedLength, 1024);
    expect(updated?.downloadSpeed, 512);
  });

  test(
    'findMatchingDownload matches aria2 status by source URL and directory',
    () async {
      final created = await repository.createDownload(
        const NewDownload(
          url: 'https://example.com/linux.iso',
          directory: '/tmp',
          fileName: '',
          split: 16,
          startImmediately: false,
        ),
      );

      final matched = await repository.findMatchingDownload(
        const Aria2Status(
          gid: 'aria2-gid',
          status: 'waiting',
          totalLength: 0,
          completedLength: 0,
          downloadSpeed: 0,
          connections: 0,
          pieceLength: 0,
          numPieces: 0,
          bitfield: null,
          errorCode: null,
          errorMessage: null,
          files: [
            Aria2File(
              path: '/tmp/linux.iso',
              length: 0,
              completedLength: 0,
              uris: ['https://example.com/linux.iso'],
            ),
          ],
        ),
      );

      expect(matched?.id, created.id);
    },
  );

  test('updateFromAria2 persists aria2 error code', () async {
    final created = await repository.createDownload(
      const NewDownload(
        url: 'https://example.com/linux.iso',
        directory: '/tmp',
        fileName: '',
        split: 16,
        startImmediately: false,
      ),
    );
    await repository.attachGid(created.id, 'gid-1');

    await repository.updateFromAria2(
      const Aria2Status(
        gid: 'gid-1',
        status: 'error',
        totalLength: 0,
        completedLength: 0,
        downloadSpeed: 0,
        connections: 0,
        pieceLength: 0,
        numPieces: 0,
        bitfield: null,
        errorCode: 3,
        errorMessage: 'Resource not found',
        files: [],
      ),
    );
    final updated = await repository.findById(created.id);

    expect(updated?.status, DownloadStatus.error.name);
    expect(updated?.aria2ErrorCode, 3);
    expect(updated?.error, 'Resource not found');
  });

  test('updateFromAria2 clears stale error when download recovers', () async {
    final created = await repository.createDownload(
      const NewDownload(
        url: 'https://example.com/linux.iso',
        directory: '/tmp',
        fileName: '',
        split: 16,
        startImmediately: false,
      ),
    );
    await repository.attachGid(created.id, 'gid-1');
    await repository.updateFromAria2(
      const Aria2Status(
        gid: 'gid-1',
        status: 'error',
        totalLength: 0,
        completedLength: 0,
        downloadSpeed: 0,
        connections: 0,
        pieceLength: 0,
        numPieces: 0,
        bitfield: null,
        errorCode: 3,
        errorMessage: 'Resource not found',
        files: [],
      ),
    );

    await repository.updateFromAria2(
      const Aria2Status(
        gid: 'gid-1',
        status: 'active',
        totalLength: 4096,
        completedLength: 1024,
        downloadSpeed: 256,
        connections: 4,
        pieceLength: 1024,
        numPieces: 4,
        bitfield: '8',
        errorCode: null,
        errorMessage: null,
        files: [],
      ),
    );
    final updated = await repository.findById(created.id);

    expect(updated?.status, DownloadStatus.active.name);
    expect(updated?.aria2ErrorCode, null);
    expect(updated?.error, null);
    expect(updated?.completedLength, 1024);
  });

  test('clearRetryState removes gid and error fields', () async {
    final created = await repository.createDownload(
      const NewDownload(
        url: 'https://example.com/linux.iso',
        directory: '/tmp',
        fileName: '',
        split: 16,
        startImmediately: false,
      ),
    );
    await repository.attachGid(created.id, 'gid-1');
    await repository.updateStatus(
      created.id,
      DownloadStatus.error,
      error: 'Something went wrong',
      aria2ErrorCode: 3,
    );

    await repository.clearRetryState(created.id);
    final updated = await repository.findById(created.id);

    expect(updated?.gid, null);
    expect(updated?.error, null);
    expect(updated?.aria2ErrorCode, null);
  });
}
