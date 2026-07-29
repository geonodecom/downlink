import 'package:path/path.dart' as p;

import '../data/app_database.dart';
import '../torrent/torrent_models.dart';
import 'formatters.dart';

String downloadTitle(DownloadEntity download) {
  final fileName = download.fileName?.trim();
  if (fileName != null && fileName.isNotEmpty) return fileName;
  if (download.url.toLowerCase().startsWith('magnet:?')) {
    return 'Magnet download';
  }
  return sourceHost(download.url) ?? download.url;
}

String? sourceHost(String url) {
  if (url.toLowerCase().startsWith('magnet:?')) return 'magnet';
  final uri = Uri.tryParse(url);
  final host = uri?.host.trim();
  return host == null || host.isEmpty ? null : host;
}

String? outputPath(DownloadEntity download) {
  final contentUri = download.contentUri?.trim();
  if (contentUri != null && contentUri.isNotEmpty) return contentUri;
  final fileName = download.fileName?.trim();
  if (fileName == null || fileName.isEmpty) return null;
  return p.join(download.directory, fileName);
}

String statusLabel(String status) {
  return switch (status) {
    'active' => 'Active',
    'queued' => 'Queued',
    'paused' => 'Paused',
    'completed' => 'Completed',
    'error' => 'Error',
    'removed' => 'Removed',
    _ => status,
  };
}

bool isSeedingDownload(DownloadEntity download) {
  if (download.status != DownloadStatus.active.name) return false;
  if (!isTorrentDownloadOptions(download.optionsJson)) return false;
  if (download.totalLength <= 0) return false;
  return download.completedLength >= download.totalLength;
}

String downloadStatusLabel(DownloadEntity download) {
  if (isSeedingDownload(download)) return 'Seeding';
  return statusLabel(download.status);
}

String progressSummary(DownloadEntity download) {
  if (download.totalLength <= 0) {
    if (download.completedLength > 0) {
      return '${formatBytes(download.completedLength, zeroLabel: '0 B')} downloaded · Size unknown';
    }
    return 'Size unknown';
  }
  return '${formatBytes(download.completedLength, zeroLabel: '0 B')} / ${formatBytes(download.totalLength)}';
}

List<String> activitySummary(DownloadEntity download) {
  final status = DownloadStatus.values.byName(download.status);
  if (status != DownloadStatus.active) return const [];

  if (isSeedingDownload(download)) {
    final peers = download.connections;
    final up = download.uploadSpeed > 0
        ? '↑ ${formatSpeed(download.uploadSpeed)}'
        : '↑ 0 B/s';
    if (peers <= 0 && download.uploadSpeed <= 0) {
      return [up, 'waiting for peers'];
    }
    return [
      up,
      peers == 1 ? '1 peer' : '$peers peers',
    ];
  }

  final speed = formatSpeed(download.downloadSpeed);
  final eta = formatEta(
    download.totalLength - download.completedLength,
    download.downloadSpeed,
  );
  final up = download.uploadSpeed > 0 ? formatSpeed(download.uploadSpeed) : '';
  return [
    if (speed.isNotEmpty) speed,
    if (up.isNotEmpty) '↑ $up',
    if (eta.isNotEmpty) eta,
    if (download.connections > 0) '${download.connections} connections',
  ];
}

double? progressIndicatorValue(DownloadEntity download) {
  if (download.totalLength > 0) {
    return progressValue(download.completedLength, download.totalLength);
  }
  final status = DownloadStatus.values.byName(download.status);
  return status == DownloadStatus.active ? null : 0;
}
