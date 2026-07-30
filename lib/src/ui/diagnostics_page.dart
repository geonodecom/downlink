import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../providers.dart';
import '../services/diagnostics.dart';

class DiagnosticsPage extends ConsumerWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(diagnosticsLogProvider);
    final entriesAsync = ref.watch(_diagnosticsEntriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
          child: Row(
            children: [
              Text(
                'Diagnostics',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _confirmResetSession(context, ref),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset Session'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => log.clear(),
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: entriesAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return const Center(
                  child: Text('No events yet. Events appear as Downlink runs.'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: entries.length,
                itemBuilder: (context, index) =>
                    _EntryTile(entry: entries[entries.length - 1 - index]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
          ),
        ),
      ],
    );
  }
}

final _diagnosticsEntriesProvider = StreamProvider<List<DiagnosticEntry>>((ref) {
  return ref.watch(diagnosticsLogProvider).watch();
});

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final DiagnosticEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (entry.level) {
      DownlinkLogLevel.debug => (Icons.bug_report, colorScheme.outline),
      DownlinkLogLevel.info => (Icons.info_outline, colorScheme.primary),
      DownlinkLogLevel.warn => (Icons.warning_amber, Colors.orange),
      DownlinkLogLevel.error => (Icons.error_outline, colorScheme.error),
    };
    final time = _formatTime(entry.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              entry.message,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}

Future<void> _confirmResetSession(
  BuildContext context,
  WidgetRef ref,
) async {
  final isAndroid = Platform.isAndroid;
  final appDir = await getApplicationSupportDirectory();
  final sessionFile = File(p.join(appDir.path, 'aria2', 'session.txt'));
  final sessionExists = isAndroid ? true : await sessionFile.exists();

  if (!context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Reset Session Data'),
        content: Text(
          isAndroid
              ? 'This will clear Android engine resumable state '
                  '(partial files and queued native tasks).\n\n'
                  'This is a development tool.'
              : sessionExists
              ? 'This will delete the aria2 session file at\n'
                    '${sessionFile.path}\n\n'
                    'Active and queued downloads will be lost. '
                    'This is a development tool.\n'
              : 'No aria2 session file was found at\n'
                    '${sessionFile.path}.\n\n'
                    'This action has nothing to do.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          if (sessionExists)
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              child: Text(
                isAndroid ? 'Reset Engine State' : 'Delete Session File Only',
              ),
            ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(downloadServiceProvider).resetEngineSession();
    ref.read(diagnosticsLogProvider).info('Reset download engine session.');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Engine session reset. Restart Downlink to start fresh.',
          ),
        ),
      );
    }
  } catch (error) {
    ref
        .read(diagnosticsLogProvider)
        .error('Reset: failed to clear engine session: $error');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reset engine session: $error')),
      );
    }
  }
}
