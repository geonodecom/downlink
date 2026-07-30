import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A lightweight in-memory diagnostics log for Downlink service and aria2 events.
///
/// Keeps the last [_maxEvents] entries. Used by the in-app diagnostics panel.
class DiagnosticsLog {
  DiagnosticsLog({int maxEvents = 200}) : _maxEvents = maxEvents;

  final int _maxEvents;
  final _entries = <DiagnosticEntry>[];
  final _controller = StreamController<List<DiagnosticEntry>>.broadcast();

  Stream<List<DiagnosticEntry>> watch() async* {
    yield List.unmodifiable(_entries);
    yield* _controller.stream;
  }

  List<DiagnosticEntry> get entries => List.unmodifiable(_entries);

  void emit(DiagnosticEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEvents) {
      _entries.removeAt(0);
    }
    _controller.add(List.unmodifiable(_entries));
  }

  void info(String message) {
    emit(DiagnosticEntry(level: DownlinkLogLevel.info, message: message));
  }

  void warn(String message) {
    emit(DiagnosticEntry(level: DownlinkLogLevel.warn, message: message));
  }

  void error(String message) {
    emit(DiagnosticEntry(level: DownlinkLogLevel.error, message: message));
  }

  void debug(String message) {
    emit(DiagnosticEntry(level: DownlinkLogLevel.debug, message: message));
  }

  void clear() {
    _entries.clear();
    _controller.add(List.unmodifiable(_entries));
  }

  void dispose() {
    _controller.close();
  }
}

enum DownlinkLogLevel { debug, info, warn, error }

class DiagnosticEntry {
  DiagnosticEntry({required this.level, required this.message})
    : timestamp = DateTime.now();

  final DownlinkLogLevel level;
  final String message;
  final DateTime timestamp;
}

final diagnosticsLogProvider = Provider<DiagnosticsLog>((ref) {
  final log = DiagnosticsLog();
  ref.onDispose(log.dispose);
  return log;
});
