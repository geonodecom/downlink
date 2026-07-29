import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/app_database.dart';
import '../providers.dart';
import '../services/download_service.dart';
import '../utils/download_display.dart';
import '../utils/error_display.dart';
import 'widgets/download_details_dialog.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);
    return _PageFrame(
      title: 'Downloads',
      child: downloads.when(
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                // Extra bottom space so the Add FAB never covers row actions.
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemBuilder: (context, index) => _DownloadTile(items[index]),
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemCount: items.length,
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile(this.download);

  final DownloadEntity download;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = activitySummary(download);
    final error = friendlyErrorSummary(download);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDownloadDetailsDialog(context, download),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      downloadTitle(download),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _StatusChip(download: download),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progressIndicatorValue(download)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        progressSummary(download),
                        ...activity,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _Actions(download),
                ],
              ),
              if (error != null && error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions(this.download);

  final DownloadEntity download;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(downloadServiceProvider);
    final status = DownloadStatus.values.byName(download.status);
    return Wrap(
      spacing: 4,
      children: [
        if (status == DownloadStatus.active)
          IconButton(
            tooltip: 'Pause',
            onPressed: () => service.pause(download.id),
            icon: const Icon(Symbols.pause),
          )
        else if (status == DownloadStatus.paused ||
            status == DownloadStatus.queued ||
            status == DownloadStatus.error)
          IconButton(
            tooltip: status == DownloadStatus.error ? 'Retry' : 'Resume',
            onPressed: () => status == DownloadStatus.error
                ? service.retry(download.id)
                : service.resume(download.id),
            icon: Icon(
              status == DownloadStatus.error
                  ? Symbols.refresh
                  : Symbols.play_arrow,
            ),
          ),
        IconButton(
          tooltip: 'Remove',
          onPressed: () => _confirmRemove(context, service),
          icon: const Icon(Symbols.delete),
        ),
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    DownloadService service,
  ) async {
    final deleteFiles = await showDeleteDownloadDialog(context, download);
    if (deleteFiles == null) return;

    try {
      await service.remove(download.id, deleteFiles: deleteFiles);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

Future<bool?> showDeleteDownloadDialog(
  BuildContext context,
  DownloadEntity download,
) {
  var deleteFiles = false;
  final path = outputPath(download);
  final canDeleteFile = path != null;
  final pathToShow = path ?? 'File path is not known yet.';

  return showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Remove Download'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    download.fileName ?? download.url,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pathToShow,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: deleteFiles,
                    onChanged: canDeleteFile
                        ? (value) =>
                            setState(() => deleteFiles = value ?? false)
                        : null,
                    title: const Text('Also delete downloaded files'),
                    subtitle: Text(
                      canDeleteFile
                          ? 'Removes the file and its .aria2 resume data '
                              'from disk.'
                          : 'The file path is not known yet so nothing can '
                              'be deleted.',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(deleteFiles),
                child: const Text('Remove'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.download});

  final DownloadEntity download;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final seeding = isSeedingDownload(download);
    final downloadStatus = DownloadStatus.values.byName(download.status);
    final colors = switch (downloadStatus) {
      DownloadStatus.active => (
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      ),
      DownloadStatus.completed => (
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
      ),
      DownloadStatus.error => (
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      ),
      DownloadStatus.queued || DownloadStatus.paused => (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      ),
      DownloadStatus.removed => (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      ),
    };
    return Chip(
      label: Text(downloadStatusLabel(download)),
      backgroundColor: seeding
          ? colorScheme.secondaryContainer
          : colors.background,
      labelStyle: TextStyle(
        color: seeding ? colorScheme.onSecondaryContainer : colors.foreground,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.download, size: 48),
          SizedBox(height: 12),
          Text('No downloads yet'),
          SizedBox(height: 4),
          Text('Add a URL to start downloading with aria2.'),
        ],
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        Expanded(child: child),
      ],
    );
  }
}
