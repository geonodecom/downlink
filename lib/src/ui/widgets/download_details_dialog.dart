import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../aria2/aria2_models.dart';
import '../../data/app_database.dart';
import '../../platform/open_path.dart';
import '../../providers.dart';
import '../downloads_page.dart' show showDeleteDownloadDialog;
import '../../utils/download_display.dart';
import '../../utils/error_display.dart';
import '../../utils/formatters.dart';
import '../../torrent/torrent_models.dart';

Future<void> showDownloadDetailsDialog(
  BuildContext context,
  DownloadEntity download,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => DownloadDetailsDialog(initialDownload: download),
  );
}

class DownloadDetailsDialog extends ConsumerWidget {
  const DownloadDetailsDialog({required this.initialDownload, super.key});

  final DownloadEntity initialDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveDownload = ref.watch(downloadProvider(initialDownload.id));
    return liveDownload.when(
      data: (download) => _DownloadDetailsContent(
        download: download ?? initialDownload,
        missing: download == null,
      ),
      loading: () => _DownloadDetailsContent(download: initialDownload),
      error: (_, _) => _DownloadDetailsContent(download: initialDownload),
    );
  }
}

class _DownloadDetailsContent extends ConsumerWidget {
  const _DownloadDetailsContent({required this.download, this.missing = false});

  final DownloadEntity download;
  final bool missing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pieces = piecesFromBitfield(download.bitfield, download.numPieces);
    final completedPieces = pieces.where((piece) => piece.complete).length;
    final path = outputPath(download);
    final host = sourceHost(download.url);
    final errorLabel = aria2ErrorLabel(download.aria2ErrorCode);
    final rawError = download.error?.trim();
    final showErrorPanel =
        errorLabel != null || (rawError != null && rawError.isNotEmpty);
    final status = DownloadStatus.values.byName(download.status);
    return AlertDialog(
      title: Text(downloadTitle(download)),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (missing) ...[
                const _MissingPanel(),
                const SizedBox(height: 16),
              ],
              if (showErrorPanel) ...[
                _ErrorPanel(
                  label: errorLabel,
                  raw: rawError,
                  code: download.aria2ErrorCode,
                ),
                const SizedBox(height: 16),
              ],
              _DetailRow(label: 'URL', value: download.url),
              _DetailRow(label: 'Host', value: host ?? ''),
              _DetailRow(
                label: download.contentUri == null || download.contentUri!.isEmpty
                    ? 'Directory'
                    : 'Location',
                value: (download.contentUri != null &&
                        download.contentUri!.isNotEmpty)
                    ? download.contentUri!
                    : download.directory,
              ),
              _DetailRow(label: 'File', value: path ?? ''),
              _DetailRow(
                label: 'Status',
                value: downloadStatusLabel(download),
              ),
              _DetailRow(label: 'GID', value: download.gid ?? ''),
              _DetailRow(label: 'Progress', value: progressSummary(download)),
              _DetailRow(
                label: 'Download speed',
                value: formatSpeed(download.downloadSpeed).isEmpty
                    ? '0 B/s'
                    : formatSpeed(download.downloadSpeed),
              ),
              if (download.uploadSpeed > 0 || isSeedingDownload(download))
                _DetailRow(
                  label: 'Upload speed',
                  value: download.uploadSpeed > 0
                      ? formatSpeed(download.uploadSpeed)
                      : '0 B/s',
                ),
              _DetailRow(
                label: isTorrentDownloadOptions(download.optionsJson)
                    ? 'Peers'
                    : 'Connections',
                value: download.connections.toString(),
              ),
              const SizedBox(height: 16),
              Text('Pieces', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (pieces.isEmpty)
                const Text(
                  'Piece map is available after the download engine starts the transfer.',
                )
              else ...[
                Text('$completedPieces / ${pieces.length} pieces complete'),
                const SizedBox(height: 8),
                _PieceMap(pieces: pieces),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Clipboard.setData(ClipboardData(text: download.url)),
          icon: const Icon(Symbols.link),
          label: const Text('Copy URL'),
        ),
        TextButton.icon(
          onPressed: path == null
              ? null
              : () => Clipboard.setData(ClipboardData(text: path)),
          icon: const Icon(Symbols.content_copy),
          label: const Text('Copy path'),
        ),
        TextButton.icon(
          onPressed: path == null
              ? null
              : () => unawaited(openPath(path)),
          icon: const Icon(Symbols.file_open),
          label: const Text('Open file'),
        ),
        if (download.contentUri == null || download.contentUri!.isEmpty)
          TextButton.icon(
            onPressed: () => unawaited(openPath(download.directory)),
            icon: const Icon(Symbols.folder_open),
            label: const Text('Open folder'),
          ),
        if (status == DownloadStatus.active)
          TextButton.icon(
            onPressed: () =>
                ref.read(downloadServiceProvider).pause(download.id),
            icon: const Icon(Symbols.pause),
            label: const Text('Pause'),
          )
        else if (status == DownloadStatus.paused)
          TextButton.icon(
            onPressed: () =>
                ref.read(downloadServiceProvider).resume(download.id),
            icon: const Icon(Symbols.play_arrow),
            label: const Text('Resume'),
          )
        else if (status == DownloadStatus.error)
          TextButton.icon(
            onPressed: () =>
                ref.read(downloadServiceProvider).retry(download.id),
            icon: const Icon(Symbols.refresh),
            label: const Text('Retry'),
          ),
        if (status != DownloadStatus.removed)
          TextButton.icon(
            onPressed: () {
              _confirmRemove(context, download, ref).then((confirmed) {
                if (confirmed && context.mounted) {
                  Navigator.of(context).pop();
                }
              });
            },
            icon: const Icon(Symbols.delete),
            label: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _MissingPanel extends StatelessWidget {
  const _MissingPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'This download is no longer in the active list.',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.label, required this.raw, required this.code});

  final String? label;
  final String? raw;
  final int? code;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayLabel = label;
    final displayRaw = raw;
    final showRaw =
        displayRaw != null &&
        displayRaw.isNotEmpty &&
        displayRaw != displayLabel;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (displayLabel != null)
            Text(
              displayLabel,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (code != null) ...[
            const SizedBox(height: 4),
            Text(
              'aria2 error code $code',
              style: TextStyle(
                color: colorScheme.onErrorContainer.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (showRaw) ...[
            const SizedBox(height: 8),
            Text(
              'raw details:',
              style: TextStyle(
                color: colorScheme.onErrorContainer.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            SelectableText(
              displayRaw,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(
            child: SelectableText(value.isEmpty ? 'Unavailable' : value),
          ),
        ],
      ),
    );
  }
}

class _PieceMap extends StatelessWidget {
  const _PieceMap({required this.pieces});

  final List<PieceInfo> pieces;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(240.0, 680.0);
        final columns = (width / _PieceMapPainter.cellExtent).floor().clamp(
          1,
          pieces.length,
        );
        final rows = (pieces.length / columns).ceil();
        final height = (rows * _PieceMapPainter.cellExtent).clamp(24.0, 180.0);
        return ClipRect(
          child: CustomPaint(
            size: Size(width, height),
            painter: _PieceMapPainter(
              pieces: pieces,
              columns: columns,
              completeColor: colorScheme.primary,
              pendingColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        );
      },
    );
  }
}

class _PieceMapPainter extends CustomPainter {
  const _PieceMapPainter({
    required this.pieces,
    required this.columns,
    required this.completeColor,
    required this.pendingColor,
  });

  static const cellSize = 4.0;
  static const cellGap = 2.0;
  static const cellExtent = cellSize + cellGap;

  final List<PieceInfo> pieces;
  final int columns;
  final Color completeColor;
  final Color pendingColor;

  @override
  void paint(Canvas canvas, Size size) {
    final completePaint = Paint()..color = completeColor;
    final pendingPaint = Paint()..color = pendingColor;
    for (final piece in pieces) {
      final row = piece.index ~/ columns;
      final top = row * cellExtent;
      if (top > size.height) return;

      final left = (piece.index % columns) * cellExtent;
      canvas.drawRect(
        Rect.fromLTWH(left, top, cellSize, cellSize),
        piece.complete ? completePaint : pendingPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_PieceMapPainter oldDelegate) {
    return oldDelegate.pieces != pieces ||
        oldDelegate.columns != columns ||
        oldDelegate.completeColor != completeColor ||
        oldDelegate.pendingColor != pendingColor;
  }
}

Future<bool> _confirmRemove(
  BuildContext context,
  DownloadEntity download,
  WidgetRef ref,
) async {
  final deleteFiles = await showDeleteDownloadDialog(context, download);
  if (deleteFiles == null) return false;

  try {
    await ref
        .read(downloadServiceProvider)
        .remove(download.id, deleteFiles: deleteFiles);
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
    return false;
  }
}
