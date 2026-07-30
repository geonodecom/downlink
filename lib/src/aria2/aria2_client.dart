import 'dart:convert';
import 'dart:io';

import 'aria2_models.dart';

class Aria2Client {
  Aria2Client(this.endpoint);

  final Aria2Endpoint endpoint;
  final HttpClient _http = HttpClient();
  int _requestId = 0;

  Future<String> addUri({
    required String url,
    required String directory,
    required int split,
    String? fileName,
    Map<String, String> headers = const {},
    int? position,
    Map<String, String> extraOptions = const {},
  }) async {
    final options = <String, String>{
      'dir': directory,
      'split': split.toString(),
      'max-connection-per-server': split.toString(),
      ..._fileNameOption(fileName),
      if (headers.isNotEmpty)
        'header': headers.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
      ...extraOptions,
    };
    final params = <Object?>[
      [url],
      options,
    ];
    if (position != null) params.add(position);
    return call<String>('aria2.addUri', params);
  }

  Future<String> addTorrent({
    required List<int> torrentBytes,
    required String directory,
    int? position,
    Map<String, String> extraOptions = const {},
  }) async {
    final options = <String, String>{
      'dir': directory,
      ...extraOptions,
    };
    final encoded = base64Encode(torrentBytes);
    final params = <Object?>[
      encoded,
      <String>[],
      options,
    ];
    if (position != null) params.add(position);
    return call<String>('aria2.addTorrent', params);
  }

  Future<void> pause(String gid) => callVoid('aria2.pause', [gid]);

  Future<void> unpause(String gid) => callVoid('aria2.unpause', [gid]);

  Future<void> remove(String gid) => callVoid('aria2.remove', [gid]);

  Future<void> changePosition(String gid, int position) {
    return callVoid('aria2.changePosition', [gid, position, 'POS_SET']);
  }

  Future<void> saveSession() => callVoid('aria2.saveSession');

  Future<void> shutdown() => callVoid('aria2.shutdown');

  Future<Map<String, Object?>> getVersion() {
    return call<Map<String, Object?>>('aria2.getVersion');
  }

  Future<Aria2Status> tellStatus(String gid) async {
    final result = await call<Map<String, Object?>>('aria2.tellStatus', [
      gid,
      _statusKeys,
    ]);
    return Aria2Status.fromJson(result);
  }

  Future<List<Aria2Status>> tellActive() async {
    final result = await call<List<Object?>>('aria2.tellActive', [_statusKeys]);
    return result
        .whereType<Map>()
        .map((item) => Aria2Status.fromJson(item.cast<String, Object?>()))
        .toList();
  }

  Future<List<Aria2Status>> tellWaiting({
    int offset = 0,
    int limit = 100,
  }) async {
    final result = await call<List<Object?>>('aria2.tellWaiting', [
      offset,
      limit,
      _statusKeys,
    ]);
    return result
        .whereType<Map>()
        .map((item) => Aria2Status.fromJson(item.cast<String, Object?>()))
        .toList();
  }

  Future<List<Aria2Status>> tellStopped({
    int offset = 0,
    int limit = 100,
  }) async {
    final result = await call<List<Object?>>('aria2.tellStopped', [
      offset,
      limit,
      _statusKeys,
    ]);
    return result
        .whereType<Map>()
        .map((item) => Aria2Status.fromJson(item.cast<String, Object?>()))
        .toList();
  }

  Future<void> callVoid(
    String method, [
    List<Object?> params = const [],
  ]) async {
    await _call(method, params);
  }

  Future<T> call<T>(String method, [List<Object?> params = const []]) async {
    final result = await _call(method, params);
    return result as T;
  }

  Future<Object?> _call(
    String method, [
    List<Object?> params = const [],
  ]) async {
    final request = await _http.post(endpoint.host, endpoint.port, '/jsonrpc');
    request.headers.contentType = ContentType.json;
    request.persistentConnection = false;
    final id = (++_requestId).toString();
    final payload = utf8.encode(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': ['token:${endpoint.secret}', ...params],
      }),
    );
    request.contentLength = payload.length;
    request.add(payload);

    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Aria2Exception('aria2 HTTP ${response.statusCode}: $body');
    }

    final decoded = jsonDecode(body) as Map<String, Object?>;
    final error = decoded['error'];
    if (error is Map) {
      final errorCode = error['code'];
      throw Aria2Exception(
        error['message']?.toString() ?? 'aria2 RPC error',
        code: errorCode is int ? errorCode : int.tryParse('$errorCode'),
      );
    }
    return decoded['result'];
  }

  void close() {
    _http.close(force: true);
  }
}

const _statusKeys = [
  'gid',
  'status',
  'totalLength',
  'completedLength',
  'downloadSpeed',
  'uploadSpeed',
  'connections',
  'pieceLength',
  'numPieces',
  'bitfield',
  'errorCode',
  'errorMessage',
  'files',
  'numSeeders',
  'numPeers',
];

Map<String, String> _fileNameOption(String? fileName) {
  final outputName = fileName?.trim();
  if (outputName == null || outputName.isEmpty) return const {};
  return {'out': outputName};
}

class Aria2Exception implements Exception {
  Aria2Exception(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => message;
}
