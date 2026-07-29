import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_update/app_update_controller.dart';
import '../../app_update/app_update_models.dart';
import '../../providers.dart';

Future<void> showUpdateAvailableDialog(BuildContext context) async {
  if (!Platform.isAndroid && !Platform.isWindows) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const UpdateAvailableDialog(),
  );
}

class UpdateAvailableDialog extends ConsumerStatefulWidget {
  const UpdateAvailableDialog({super.key});

  @override
  ConsumerState<UpdateAvailableDialog> createState() =>
      _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends ConsumerState<UpdateAvailableDialog> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appUpdateControllerProvider);
    final offer = state.offer;
    if (offer == null) {
      return AlertDialog(
        title: const Text('Update'),
        content: const Text('No update information is available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    final isDownloading = state.phase == AppUpdateUiPhase.downloading;
    final progress = state.progress;

    return AlertDialog(
      title: Text('Update available (v${offer.version})'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (offer.releaseNotes.isNotEmpty) ...[
              Text(
                offer.releaseNotes,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
            ],
            if (isDownloading) ...[
              if (progress?.fraction != null)
                LinearProgressIndicator(value: progress!.fraction)
              else
                const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(_progressLabel(progress)),
            ],
            if (state.phase == AppUpdateUiPhase.error && state.message != null)
              Text(
                state.message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        if (!isDownloading) ...[
          TextButton(
            onPressed: () async {
              await ref.read(appUpdateControllerProvider.notifier).skipOffer();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Skip this version'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(appUpdateControllerProvider.notifier).downloadAndApply();
            },
            child: Text(_primaryActionLabel()),
          ),
        ],
      ],
    );
  }

  String _primaryActionLabel() {
    if (Platform.isWindows) return 'Update and restart';
    if (Platform.isAndroid) return 'Download and install';
    return 'Update';
  }

  String _progressLabel(AppUpdateProgress? progress) {
    if (progress == null) return 'Downloading…';
    final received = progress.received;
    final total = progress.total;
    if (total != null && total > 0) {
      final pct = (received / total * 100).clamp(0, 100).toStringAsFixed(0);
      return 'Downloading… $pct%';
    }
    return 'Downloading… ${_formatBytes(received)}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
