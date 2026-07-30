import 'dart:io';

import 'package:flutter/services.dart';

const _engineChannel = MethodChannel(
  'com.geonode.downlink/engine',
);

/// Resolves the jniLibs-packaged ffmpeg (`libffmpeg.so`) on Android.
Future<String> resolveAndroidFfmpegPath() async {
  if (!Platform.isAndroid) {
    throw StateError('resolveAndroidFfmpegPath is only valid on Android.');
  }

  final path = await _engineChannel.invokeMethod<String>('getFfmpegPath');
  if (path == null || path.isEmpty) {
    throw StateError(
      'Bundled ffmpeg (libffmpeg.so) was not found. '
      'Rebuild with tool/android/fetch_deps.ps1.',
    );
  }

  final file = File(path);
  if (!await file.exists()) {
    throw StateError(
      'Bundled ffmpeg was not found at $path. '
      'Rebuild with tool/android/fetch_deps.ps1.',
    );
  }
  return path;
}

Future<bool> androidFfmpegAvailable() async {
  try {
    await resolveAndroidFfmpegPath();
    return true;
  } catch (_) {
    return false;
  }
}
