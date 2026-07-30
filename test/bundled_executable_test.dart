import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/platform/bundled_executable.dart';
import 'package:path/path.dart' as p;

String _toolName(String baseName) {
  return Platform.isWindows ? '$baseName.exe' : baseName;
}

void main() {
  tearDown(() {
    setAppDirectoryOverrideForTesting(null);
  });

  test('findBundledExecutable returns tool from app bin directory', () async {
    final root = await Directory.systemTemp.createTemp('downlink-bin-test');
    addTearDown(() => root.deleteSync(recursive: true));
    final bin = Directory(p.join(root.path, 'bin'))..createSync();
    final toolName = _toolName('yt-dlp');
    File(p.join(bin.path, toolName)).writeAsStringSync('stub');
    setAppDirectoryOverrideForTesting(root.path);

    final found = await findBundledExecutable('yt-dlp');
    expect(found, isNotNull);
    expect(p.basename(found!), toolName);
    expect(p.normalize(p.dirname(found)), p.normalize(bin.path));
  });

  test('resolveExecutable prefers override then bundled then PATH', () async {
    final root = await Directory.systemTemp.createTemp('downlink-resolve-test');
    addTearDown(() => root.deleteSync(recursive: true));
    final bin = Directory(p.join(root.path, 'bin'))..createSync();
    final bundledName = _toolName('ffmpeg');
    final bundled = File(p.join(bin.path, bundledName))
      ..writeAsStringSync('stub');
    setAppDirectoryOverrideForTesting(root.path);

    final overridePath = p.join(root.path, _toolName('custom-ffmpeg'));
    File(overridePath).writeAsStringSync('override');

    final fromOverride = await resolveExecutable(
      baseName: 'ffmpeg',
      override: overridePath,
      notFoundMessage: 'missing',
      findOnPathFallback: () async => 'path-ffmpeg',
    );
    expect(fromOverride, overridePath);

    final fromBundled = await resolveExecutable(
      baseName: 'ffmpeg',
      override: '',
      notFoundMessage: 'missing',
      findOnPathFallback: () async => 'path-ffmpeg',
    );
    expect(p.normalize(fromBundled), p.normalize(bundled.path));

    setAppDirectoryOverrideForTesting(p.join(root.path, 'empty'));
    final fromPath = await resolveExecutable(
      baseName: 'ffmpeg',
      override: '',
      notFoundMessage: 'missing',
      findOnPathFallback: () async => 'path-ffmpeg',
    );
    expect(fromPath, 'path-ffmpeg');
  });

  test('desktopBundledToolsReady requires aria2 yt-dlp and ffmpeg', () async {
    final root = await Directory.systemTemp.createTemp('downlink-all-test');
    addTearDown(() => root.deleteSync(recursive: true));
    final bin = Directory(p.join(root.path, 'bin'))..createSync();
    setAppDirectoryOverrideForTesting(root.path);

    expect(await desktopBundledToolsReady(), isFalse);

    for (final name in ['aria2c', 'yt-dlp', 'ffmpeg']) {
      File(p.join(bin.path, _toolName(name))).writeAsStringSync('stub');
    }

    expect(await desktopBundledToolsReady(), isTrue);
  });
}
