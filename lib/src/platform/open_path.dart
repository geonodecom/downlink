import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

const _engineChannel = MethodChannel(
  'com.geonode.downlink/engine',
);

/// Opens a file, directory, content URI, or http(s) URL with the platform default app.
Future<void> openPath(String path) async {
  if (path.startsWith('content:') || Platform.isAndroid) {
    await _engineChannel.invokeMethod<void>('openUri', {'uri': path});
    return;
  }
  if (Platform.isWindows) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      await Process.start(
        'cmd',
        ['/c', 'start', '', path],
        mode: ProcessStartMode.detached,
      );
      return;
    }
    await Process.start('explorer', [path], mode: ProcessStartMode.detached);
    return;
  }
  if (Platform.isMacOS) {
    await Process.start('open', [path], mode: ProcessStartMode.detached);
    return;
  }
  await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
}

/// Fallback Downloads directory when [getDownloadsDirectory] is unavailable.
String defaultDownloadsFallback() {
  if (Platform.isAndroid) {
    return 'Downloads';
  }
  if (Platform.isWindows) {
    final profile = Platform.environment['USERPROFILE'];
    if (profile != null && profile.trim().isNotEmpty) {
      return p.join(profile, 'Downloads');
    }
  }
  final home = Platform.environment['HOME'];
  if (home != null && home.trim().isNotEmpty) {
    return p.join(home, 'Downloads');
  }
  return p.join('.', 'Downloads');
}
