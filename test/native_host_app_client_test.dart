import 'dart:async';
import 'dart:io';

import 'package:downlink/src/extension/extension_socket.dart';
import 'package:downlink/src/native_host/app_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'automatic capture does not launch Downlink when the app socket is absent',
    () async {
      final fixture = await _launchFixture();
      final client = NativeHostAppClient(
        endpoint: fixture.endpoint,
        appPath: fixture.appPath,
        windowsEndpointFile: fixture.endpointFile,
        timeout: const Duration(milliseconds: 20),
        launchTimeout: const Duration(milliseconds: 80),
      );

      await expectLater(
        client.send({
          'command': 'capture_download',
          'launch_app': false,
          'data': {'url': 'https://example.com/file.iso'},
        }),
        throwsA(isA<SocketException>()),
      );

      expect(await File(fixture.markerPath).exists(), false);
    },
  );

  test('user capture may launch Downlink when the app socket is absent', () async {
    final fixture = await _launchFixture();
    final client = NativeHostAppClient(
      endpoint: fixture.endpoint,
      appPath: fixture.appPath,
      windowsEndpointFile: fixture.endpointFile,
      timeout: const Duration(milliseconds: 20),
      launchTimeout: const Duration(milliseconds: 150),
    );

    await expectLater(
      client.send({
        'command': 'capture_download',
        'launch_app': true,
        'data': {'url': 'https://example.com/file.iso'},
      }),
      throwsA(isA<TimeoutException>()),
    );

    expect(await File(fixture.markerPath).exists(), true);
  });
}

Future<_LaunchFixture> _launchFixture() async {
  final dir = await Directory.systemTemp.createTemp('downlink-host-test-');
  final markerPath = p.join(dir.path, 'launched');
  late final String appPath;
  if (Platform.isWindows) {
    appPath = p.join(dir.path, 'downlink.cmd');
    await File(appPath).writeAsString(
      '@echo launched> "$markerPath"\r\n',
    );
  } else {
    appPath = p.join(dir.path, 'downlink');
    await File(appPath).writeAsString(
      '#!/bin/sh\nprintf launched > "$markerPath"\n',
    );
    await Process.run('chmod', ['755', appPath]);
  }

  final ExtensionEndpoint endpoint;
  String? endpointFile;
  if (Platform.isWindows) {
    endpointFile = p.join(dir.path, 'missing-endpoint.json');
    endpoint = const TcpExtensionEndpoint(
      host: '127.0.0.1',
      port: 0,
      secret: '',
    );
  } else {
    endpoint = UnixExtensionEndpoint(p.join(dir.path, 'missing.sock'));
  }

  return _LaunchFixture(
    endpoint: endpoint,
    endpointFile: endpointFile,
    appPath: appPath,
    markerPath: markerPath,
  );
}

class _LaunchFixture {
  const _LaunchFixture({
    required this.endpoint,
    required this.appPath,
    required this.markerPath,
    this.endpointFile,
  });

  final ExtensionEndpoint endpoint;
  final String? endpointFile;
  final String appPath;
  final String markerPath;
}
