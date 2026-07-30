import 'dart:io';

import 'package:downlink/src/platform/executable_finder.dart';
import 'package:downlink/src/platform/open_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('defaultDownloadsFallback uses a Downloads directory', () {
    final path = defaultDownloadsFallback();
    expect(p.basename(path), 'Downloads');
  });

  test('isExecutablePath rejects missing files', () async {
    expect(await isExecutablePath(p.join('no-such', 'aria2c.exe')), isFalse);
  });

  test('isExecutablePath accepts existing file on this platform', () async {
    final dir = await Directory.systemTemp.createTemp('downlink-exe-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final path = Platform.isWindows
        ? p.join(dir.path, 'aria2c.exe')
        : p.join(dir.path, 'aria2c');
    await File(path).writeAsString('placeholder');
    if (!Platform.isWindows) {
      await Process.run('chmod', ['755', path]);
    }
    expect(await isExecutablePath(path), isTrue);
  });
}
