import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:downlink/src/aria2/aria2_models.dart';
import 'package:downlink/src/data/app_database.dart';
import 'package:downlink/src/utils/download_display.dart';
import 'package:downlink/src/utils/formatters.dart';

void main() {
  test('piecesFromBitfield expands aria2 bitfields', () {
    final pieces = piecesFromBitfield('a0', 8);

    expect(pieces.map((piece) => piece.complete), [
      true,
      false,
      true,
      false,
      false,
      false,
      false,
      false,
    ]);
  });

  test('Aria2Status reads source URL from file uris', () {
    final status = Aria2Status.fromJson({
      'gid': 'gid-1',
      'status': 'active',
      'files': [
        {
          'path': '/tmp/file.iso',
          'length': '100',
          'completedLength': '10',
          'uris': [
            {'uri': 'https://example.com/file.iso'},
          ],
        },
      ],
    });

    expect(status.sourceUrl, 'https://example.com/file.iso');
  });

  test('formatters keep byte and speed labels readable', () {
    expect(formatBytes(0), 'Unknown');
    expect(formatBytes(0, zeroLabel: '0 B'), '0 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatSpeed(1536), '1.5 KB/s');
  });

  test('download display helpers keep row labels clear', () {
    final queued = _download(
      status: DownloadStatus.queued,
      fileName: 'ubuntu.iso',
      totalLength: 0,
    );
    final active = _download(
      status: DownloadStatus.active,
      totalLength: 1024 * 1024,
      completedLength: 512 * 1024,
      downloadSpeed: 1024,
      connections: 2,
    );

    expect(downloadTitle(queued), 'ubuntu.iso');
    expect(statusLabel(queued.status), 'Queued');
    expect(progressSummary(queued), 'Size unknown');
    expect(progressIndicatorValue(queued), 0);
    expect(outputPath(queued), p.join('/tmp', 'ubuntu.iso'));
    expect(sourceHost(queued.url), 'example.com');

    expect(progressSummary(active), '512 KB / 1.0 MB');
    expect(activitySummary(active), ['1.0 KB/s', '8m 32s', '2 connections']);
    expect(progressIndicatorValue(active), 0.5);

    final seeding = _download(
      status: DownloadStatus.active,
      fileName: 'movie.mkv',
      totalLength: 1024,
      completedLength: 1024,
      optionsJson:
          '{"kind":"torrent","seedMode":"ratio","seedRatio":1.0,'
          '"seedTimeMinutes":60}',
    );
    expect(downloadStatusLabel(seeding), 'Seeding');
    expect(activitySummary(seeding), ['↑ 0 B/s', 'waiting for peers']);
  });
}

DownloadEntity _download({
  DownloadStatus status = DownloadStatus.queued,
  String? fileName,
  int totalLength = 0,
  int completedLength = 0,
  int downloadSpeed = 0,
  int connections = 0,
  String? optionsJson,
}) {
  final now = DateTime(2026);
  return DownloadEntity(
    id: 'id',
    gid: null,
    url: 'https://example.com/file.iso',
    fileName: fileName,
    directory: '/tmp',
    status: status.name,
    queuePosition: 1,
    totalLength: totalLength,
    completedLength: completedLength,
    downloadSpeed: downloadSpeed,
    uploadSpeed: 0,
    connections: connections,
    split: 16,
    pieceLength: 0,
    numPieces: 0,
    bitfield: null,
    error: null,
    source: 'manual',
    optionsJson: optionsJson,
    createdAt: now,
    updatedAt: now,
    completedAt: null,
  );
}
