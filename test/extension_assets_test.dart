import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chromium manifest is valid and keeps native messaging permission', () {
    final manifest =
        jsonDecode(File('extensions/chrome/manifest.json').readAsStringSync())
            as Map<String, Object?>;
    final permissions = (manifest['permissions'] as List).cast<String>();

    expect(manifest['manifest_version'], 3);
    expect(permissions, contains('nativeMessaging'));
    expect(permissions, contains('downloads'));
    expect(manifest['key'], isA<String>());
  });

  test('content script excludes stale package extensions', () {
    final content = File('extensions/chrome/content.js').readAsStringSync();

    expect(content, isNot(contains('.apk')));
    expect(content, isNot(contains('.xapk')));
    expect(content, isNot(contains('.torrent')));
  });

  test('popup uses app-oriented connection states', () {
    final popup = File('extensions/chrome/popup/popup.js').readAsStringSync();

    expect(popup, contains('Downlink not running'));
    expect(popup, contains('Native host not installed'));
    expect(popup, isNot(contains('Daemon not running')));
  });
}
