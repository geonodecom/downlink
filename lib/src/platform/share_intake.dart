import 'dart:io';

import 'package:flutter/services.dart';

import '../extension/download_capture.dart';

typedef ShareUrlHandler = void Function(DownloadCapture capture);

/// Listens for Android share/view intents carrying HTTP(S) URLs.
class ShareIntake {
  static const _channel = MethodChannel(
    'com.geonode.geonode_download_manager/share',
  );

  ShareUrlHandler? _onCapture;

  Future<void> start({required ShareUrlHandler onCapture}) async {
    if (!Platform.isAndroid) return;
    _onCapture = onCapture;
    _channel.setMethodCallHandler(_handleMethod);
    final pending = await _channel.invokeMethod<String>('takePendingUrl');
    if (pending != null) {
      _emit(pending);
    }
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler(null);
    _onCapture = null;
  }

  Future<void> _handleMethod(MethodCall call) async {
    if (call.method == 'onShareUrl') {
      final url = call.arguments?.toString();
      if (url != null) _emit(url);
    }
  }

  void _emit(String url) {
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://') &&
        !trimmed.startsWith('magnet:?')) {
      return;
    }
    _onCapture?.call(
      DownloadCapture(
        url: trimmed,
        filename: '',
        headers: const {},
        source: 'android_share',
      ),
    );
  }
}
