import 'dart:io';

import 'package:flutter/services.dart';

class AndroidAppUpdate {
  static const _channel =
      MethodChannel('com.geonode.geonode_download_manager/app_update');

  static bool get isSupported => Platform.isAndroid;

  static Future<void> installApk(String path) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('installApk is only available on Android');
    }
    try {
      await _channel.invokeMethod<void>('installApk', {'path': path});
    } on PlatformException catch (e) {
      throw AndroidAppUpdateException(
        e.message ?? 'Could not start the APK installer',
      );
    }
  }
}

class AndroidAppUpdateException implements Exception {
  AndroidAppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
