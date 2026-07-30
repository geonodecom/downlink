import 'dart:convert';
import 'dart:io';

import 'package:downlink/src/extension/app_extension_bridge.dart';
import 'package:downlink/src/extension/download_capture.dart';
import 'package:downlink/src/extension/extension_socket.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('app extension bridge accepts capture commands', () async {
    final captures = <DownloadCapture>[];
    final harness = await _startBridge(
      onShow: () async {},
      onCapture: (capture) async => captures.add(capture),
    );
    addTearDown(harness.dispose);

    final response = await harness.send({
      'id': '1',
      'command': 'capture_download',
      'data': {
        'url': 'https://example.com/file.iso',
        'filename': 'file.iso',
        'headers': {'Referer': 'https://example.com/'},
        'source_page_url': 'https://example.com/',
        'trace_id': 'trace-1',
        'source': 'context_menu',
      },
    });

    expect(response['success'], true);
    expect(captures, hasLength(1));
    expect(captures.single.url, 'https://example.com/file.iso');
    expect(captures.single.headers['Referer'], 'https://example.com/');
  });

  test('app extension bridge rejects unsupported URLs', () async {
    final harness = await _startBridge(
      onShow: () async {},
      onCapture: (_) async {},
    );
    addTearDown(harness.dispose);

    final response = await harness.send({
      'id': '1',
      'command': 'capture_download',
      'data': {'url': 'ftp://example.com/file.iso'},
    });

    expect(response['success'], false);
    expect(response['error'], 'unsupported_url');
  });

  test(
    'windows tcp bridge rejects wrong secret',
    () async {
      final harness = await _startBridge(
        onShow: () async {},
        onCapture: (_) async {},
      );
      addTearDown(harness.dispose);

      final response = await harness.send(
        {'id': '1', 'command': 'ping'},
        secretOverride: 'wrong-secret',
      );
      expect(response['success'], false);
      expect(response['error'], 'unauthorized');
    },
    skip: !Platform.isWindows,
  );

  test('windows endpoint file round-trips', () async {
    final dir = await Directory.systemTemp.createTemp('downlink-endpoint-');
    final path = p.join(dir.path, 'extension-endpoint.json');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final endpoint = TcpExtensionEndpoint(
      host: '127.0.0.1',
      port: 4242,
      secret: 'test-secret',
    );
    await writeWindowsEndpoint(endpoint, filePath: path);
    final decoded = readWindowsEndpoint(filePath: path)!;
    expect(decoded.host, '127.0.0.1');
    expect(decoded.port, 4242);
    expect(decoded.secret, 'test-secret');

    await clearWindowsEndpoint(filePath: path);
    expect(readWindowsEndpoint(filePath: path), isNull);
  });
}

Future<_BridgeHarness> _startBridge({
  required ShowHandler onShow,
  required CaptureHandler onCapture,
}) async {
  if (Platform.isWindows) {
    final dir = await Directory.systemTemp.createTemp('downlink-bridge-');
    final endpointFile = p.join(dir.path, 'extension-endpoint.json');
    final bridge = AppExtensionBridge(
      onShow: onShow,
      onCapture: onCapture,
      windowsEndpointFile: endpointFile,
    );
    await bridge.start();
    final tcp = bridge.tcpEndpoint!;
    return _BridgeHarness(
      bridge: bridge,
      send: (message, {secretOverride}) async {
        final socket = await Socket.connect(tcp.host, tcp.port);
        try {
          final payload = Map<String, Object?>.from(message);
          payload['secret'] = secretOverride ?? tcp.secret;
          socket.writeln(jsonEncode(payload));
          await socket.flush();
          final body = await utf8.decoder
              .bind(socket)
              .transform(const LineSplitter())
              .first;
          final decoded = jsonDecode(body);
          return (decoded as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          );
        } finally {
          await socket.close();
        }
      },
      dispose: () async {
        await bridge.stop();
        if (await dir.exists()) await dir.delete(recursive: true);
      },
    );
  }

  final dir = await Directory.systemTemp.createTemp();
  final socketPath = p.join(dir.path, 'downlink.sock');
  final bridge = AppExtensionBridge(
    socketPath: socketPath,
    onShow: onShow,
    onCapture: onCapture,
  );
  await bridge.start();
  return _BridgeHarness(
    bridge: bridge,
    send: (message, {secretOverride}) async {
      final socket = await Socket.connect(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      try {
        socket.writeln(jsonEncode(message));
        await socket.flush();
        final body = await utf8.decoder
            .bind(socket)
            .transform(const LineSplitter())
            .first;
        final decoded = jsonDecode(body);
        return (decoded as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        );
      } finally {
        await socket.close();
      }
    },
    dispose: () async {
      await bridge.stop();
      if (await dir.exists()) await dir.delete(recursive: true);
    },
  );
}

class _BridgeHarness {
  _BridgeHarness({
    required this.bridge,
    required this.send,
    required this.dispose,
  });

  final AppExtensionBridge bridge;
  final Future<Map<String, Object?>> Function(
    Map<String, Object?> message, {
    String? secretOverride,
  })
  send;
  final Future<void> Function() dispose;
}
