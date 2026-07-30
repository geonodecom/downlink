import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/aria2/aria2_models.dart';
import 'package:downlink/src/engine/download_engine.dart';

class FakeDownloadEngine implements DownloadEngine {
  final Map<String, Aria2Status> statuses = {};
  var started = false;
  var resetCount = 0;
  Map<String, Object?>? lastOptionsJson;

  @override
  Future<bool> get isHealthy async => started;

  @override
  Future<void> start({
    required String downloadDirectory,
    required int maxActiveDownloads,
    required int defaultSplit,
    String executableOverride = '',
    String ytdlpPath = '',
    String ffmpegPath = '',
  }) async {
    started = true;
  }

  @override
  Future<void> shutdown() async {
    started = false;
  }

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
    lastOptionsJson = optionsJson;
    final gid = optionsJson?['kind'] == 'youtube'
        ? 'ytdlp:fake-${statuses.length + 1}'
        : 'gid-${statuses.length + 1}';
    statuses[gid] = Aria2Status(
      gid: gid,
      status: 'active',
      totalLength: 100,
      completedLength: 10,
      downloadSpeed: 5,
      connections: split,
      pieceLength: 10,
      numPieces: 10,
      bitfield: 'f000',
      errorCode: null,
      errorMessage: null,
      files: [
        Aria2File(
          path: '$directory/${fileName ?? 'file.bin'}',
          length: 100,
          completedLength: 10,
          uris: [url],
        ),
      ],
    );
    return gid;
  }

  @override
  Future<void> pause(String gid) async {
    final current = statuses[gid];
    if (current == null) return;
    statuses[gid] = Aria2Status(
      gid: current.gid,
      status: 'paused',
      totalLength: current.totalLength,
      completedLength: current.completedLength,
      downloadSpeed: 0,
      connections: 0,
      pieceLength: current.pieceLength,
      numPieces: current.numPieces,
      bitfield: current.bitfield,
      errorCode: current.errorCode,
      errorMessage: current.errorMessage,
      files: current.files,
    );
  }

  @override
  Future<void> unpause(String gid) async {
    final current = statuses[gid];
    if (current == null) return;
    statuses[gid] = Aria2Status(
      gid: current.gid,
      status: 'active',
      totalLength: current.totalLength,
      completedLength: current.completedLength,
      downloadSpeed: current.downloadSpeed,
      connections: current.connections,
      pieceLength: current.pieceLength,
      numPieces: current.numPieces,
      bitfield: current.bitfield,
      errorCode: current.errorCode,
      errorMessage: current.errorMessage,
      files: current.files,
    );
  }

  @override
  Future<void> remove(String gid) async {
    statuses.remove(gid);
  }

  @override
  Future<void> changePosition(String gid, int position) async {}

  @override
  Future<Aria2Status> tellStatus(String gid) async => statuses[gid]!;

  @override
  Future<List<Aria2Status>> tellActive() async {
    return statuses.values.where((s) => s.status == 'active').toList();
  }

  @override
  Future<List<Aria2Status>> tellWaiting({int offset = 0, int limit = 100}) async {
    return statuses.values
        .where((s) => s.status == 'waiting')
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<List<Aria2Status>> tellStopped({int offset = 0, int limit = 100}) async {
    return statuses.values
        .where(
          (s) =>
              s.status == 'complete' ||
              s.status == 'error' ||
              s.status == 'paused',
        )
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<void> resetSession() async {
    resetCount++;
    statuses.clear();
  }
}

void main() {
  test('fake engine queues and pauses downloads', () async {
    final engine = FakeDownloadEngine();
    await engine.start(
      downloadDirectory: '/tmp',
      maxActiveDownloads: 1,
      defaultSplit: 4,
    );
    expect(await engine.isHealthy, isTrue);

    final gid = await engine.addUri(
      url: 'https://example.com/a.bin',
      directory: '/tmp',
      split: 4,
      fileName: 'a.bin',
    );
    expect(gid, isNotEmpty);
    expect((await engine.tellActive()).single.gid, gid);

    await engine.pause(gid);
    expect((await engine.tellStopped()).single.status, 'paused');

    await engine.resetSession();
    expect(engine.resetCount, 1);
    expect(await engine.tellActive(), isEmpty);
  });
}
