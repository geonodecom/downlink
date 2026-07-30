import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../aria2/aria2_models.dart';
import '../aria2/aria2_process_manager.dart';
import '../services/diagnostics.dart';
import '../torrent/torrent_models.dart';
import 'download_engine.dart';

/// Desktop [DownloadEngine] backed by a local aria2 process.
class Aria2DownloadEngine implements DownloadEngine {
  Aria2DownloadEngine({DiagnosticsLog? diagnostics})
    : _processManager = Aria2ProcessManager(diagnostics: diagnostics);

  Aria2DownloadEngine.forTesting(this._processManager);

  final Aria2ProcessManager _processManager;

  Aria2ProcessManager get processManager => _processManager;

  @override
  Future<bool> get isHealthy => _processManager.isHealthy;

  @override
  Future<void> start({
    required String downloadDirectory,
    required int maxActiveDownloads,
    required int defaultSplit,
    String executableOverride = '',
    String ytdlpPath = '',
    String ffmpegPath = '',
  }) async {
    await _processManager.start(
      downloadDirectory: downloadDirectory,
      maxActiveDownloads: maxActiveDownloads,
      defaultSplit: defaultSplit,
      executableOverride: executableOverride,
    );
  }

  @override
  Future<void> shutdown() => _processManager.shutdown();

  @override
  Future<String> addUri({
    required String url,
    required String directory,
    required int split,
    String? fileName,
    Map<String, String> headers = const {},
    int? position,
    Map<String, Object?>? optionsJson,
  }) async {
    final torrent = torrentOptionsFromMap(optionsJson);
    final seedOptions = torrent?.toAria2SeedOptions() ?? const <String, String>{};

    if (torrent != null && torrent.isTorrentFile) {
      final path = torrent.torrentPath.trim().isNotEmpty
          ? torrent.torrentPath.trim()
          : url;
      final file = File(path);
      if (!await file.exists()) {
        throw StateError('Torrent file not found: $path');
      }
      final bytes = await file.readAsBytes();
      return _processManager.client().addTorrent(
        torrentBytes: bytes,
        directory: directory,
        position: position,
        extraOptions: seedOptions,
      );
    }

    if (torrent != null && torrent.isMagnet) {
      return _processManager.client().addUri(
        url: url,
        directory: directory,
        split: 1,
        fileName: null,
        headers: const {},
        position: position,
        extraOptions: seedOptions,
      );
    }

    return _processManager.client().addUri(
      url: url,
      directory: directory,
      split: split,
      fileName: fileName,
      headers: headers,
      position: position,
    );
  }

  @override
  Future<void> pause(String gid) => _processManager.client().pause(gid);

  @override
  Future<void> unpause(String gid) => _processManager.client().unpause(gid);

  @override
  Future<void> remove(String gid) => _processManager.client().remove(gid);

  @override
  Future<void> changePosition(String gid, int position) {
    return _processManager.client().changePosition(gid, position);
  }

  @override
  Future<Aria2Status> tellStatus(String gid) {
    return _processManager.client().tellStatus(gid);
  }

  @override
  Future<List<Aria2Status>> tellActive() {
    return _processManager.client().tellActive();
  }

  @override
  Future<List<Aria2Status>> tellWaiting({int offset = 0, int limit = 100}) {
    return _processManager.client().tellWaiting(offset: offset, limit: limit);
  }

  @override
  Future<List<Aria2Status>> tellStopped({int offset = 0, int limit = 100}) {
    return _processManager.client().tellStopped(offset: offset, limit: limit);
  }

  @override
  Future<void> resetSession() async {
    final appDir = await getApplicationSupportDirectory();
    final sessionFile = File(p.join(appDir.path, 'aria2', 'session.txt'));
    if (await sessionFile.exists()) {
      await sessionFile.delete();
    }
  }
}
