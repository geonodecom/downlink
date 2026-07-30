import 'dart:async';

import 'package:flutter/services.dart';

import '../aria2/aria2_models.dart';
import 'download_engine.dart';

/// Android [DownloadEngine] that talks to [DownloadForegroundService].
class AndroidDownloadEngine implements DownloadEngine {
  AndroidDownloadEngine({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methods =
           methodChannel ??
           const MethodChannel('com.geonode.downlink/engine'),
       _events =
           eventChannel ??
           const EventChannel(
             'com.geonode.downlink/engine_events',
           );

  final MethodChannel _methods;
  final EventChannel _events;
  StreamSubscription<dynamic>? _eventSub;
  bool _started = false;

  @override
  Future<bool> get isHealthy async {
    try {
      final result = await _methods.invokeMethod<bool>('isHealthy');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> start({
    required String downloadDirectory,
    required int maxActiveDownloads,
    required int defaultSplit,
    String executableOverride = '',
    String ytdlpPath = '',
    String ffmpegPath = '',
  }) async {
    await _methods.invokeMethod<void>('start', {
      'downloadDirectory': downloadDirectory,
      'maxActiveDownloads': maxActiveDownloads,
      'defaultSplit': defaultSplit,
    });
    _eventSub ??= _events.receiveBroadcastStream().listen((_) {});
    _started = true;
  }

  @override
  Future<void> shutdown() async {
    await _eventSub?.cancel();
    _eventSub = null;
    if (!_started) return;
    await _methods.invokeMethod<void>('shutdown');
    _started = false;
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
    final gid = await _methods.invokeMethod<String>('addUri', {
      'url': url,
      'directory': directory,
      'split': split,
      'fileName': fileName,
      'headers': headers,
      'position': position,
      'options': optionsJson ?? const <String, Object?>{},
    });
    if (gid == null || gid.isEmpty) {
      throw StateError('Android engine did not return a task id');
    }
    return gid;
  }

  @override
  Future<void> pause(String gid) => _methods.invokeMethod('pause', {'gid': gid});

  @override
  Future<void> unpause(String gid) =>
      _methods.invokeMethod('unpause', {'gid': gid});

  @override
  Future<void> remove(String gid) =>
      _methods.invokeMethod('remove', {'gid': gid});

  @override
  Future<void> changePosition(String gid, int position) =>
      _methods.invokeMethod('changePosition', {
        'gid': gid,
        'position': position,
      });

  @override
  Future<Aria2Status> tellStatus(String gid) async {
    final raw = await _methods.invokeMethod<Map>('tellStatus', {'gid': gid});
    return Aria2Status.fromJson(_asStringKeyedMap(raw));
  }

  @override
  Future<List<Aria2Status>> tellActive() => _listStatuses('tellActive');

  @override
  Future<List<Aria2Status>> tellWaiting({int offset = 0, int limit = 100}) {
    return _listStatuses('tellWaiting', {
      'offset': offset,
      'limit': limit,
    });
  }

  @override
  Future<List<Aria2Status>> tellStopped({int offset = 0, int limit = 100}) {
    return _listStatuses('tellStopped', {
      'offset': offset,
      'limit': limit,
    });
  }

  @override
  Future<void> resetSession() => _methods.invokeMethod('resetSession');

  Future<List<Aria2Status>> _listStatuses(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    final raw = await _methods.invokeMethod<List>(method, args);
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Aria2Status.fromJson(_asStringKeyedMap(item)))
        .toList();
  }

  Map<String, Object?> _asStringKeyedMap(Map? raw) {
    if (raw == null) return const {};
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
}
