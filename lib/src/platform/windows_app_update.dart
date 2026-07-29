import 'dart:io';

import 'package:path/path.dart' as p;

import '../app_update/app_update_service.dart';
import 'bundled_executable.dart';

class WindowsAppUpdate {
  static bool get isSupported => Platform.isWindows;

  static Future<void> applyAndRestart({required String zipPath}) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('applyAndRestart is only available on Windows');
    }

    final installDir = appExecutableDirectory();
    final scriptPath = p.join(installDir, 'apply_update.ps1');
    final script = File(scriptPath);
    if (!await script.exists()) {
      throw AppUpdateException(
        'apply_update.ps1 was not found next to the app. '
        'In-app updates require an installed copy (see README), or download the zip from GitHub.',
      );
    }

    final zip = File(zipPath);
    if (!await zip.exists()) {
      throw AppUpdateException('Update package is missing.');
    }

    await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-InstallDir',
        installDir,
        '-ZipPath',
        zip.absolute.path,
        '-ExeName',
        'geonode-download-manager.exe',
      ],
      mode: ProcessStartMode.detached,
    );

    await Future<void>.delayed(const Duration(milliseconds: 400));
    exit(0);
  }
}
