import 'dart:io';

import 'package:flutter/foundation.dart';

import '../platform/bundled_executable.dart';

/// User-facing message when YouTube tools are unavailable.
Future<String> youtubeToolsUnavailableMessage() async {
  if (Platform.isAndroid) {
    return 'YouTube support is temporarily unavailable. Try again, or check '
        'your network connection.';
  }

  final bundled = await desktopYoutubeToolsReady();
  if (!bundled && !kDebugMode) {
    return 'Bundled YouTube tools are missing from this install. '
        'Reinstall Downlink from an official release package.';
  }

  if (kDebugMode) {
    return 'YouTube tools were not found. Run tool/windows/fetch_deps.ps1 '
        '(Windows) or make fetch-deps (Linux), or configure paths in Settings.';
  }

  return 'YouTube tools were not found. Configure yt-dlp and ffmpeg paths in '
      'Settings, or reinstall from an official release package.';
}
