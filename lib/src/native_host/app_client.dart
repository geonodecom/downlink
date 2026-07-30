import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../extension/extension_socket.dart';

abstract class NativeHostAppConnection {
  Future<Map<String, Object?>> ping(Map<String, Object?> command);

  Future<Map<String, Object?>> send(Map<String, Object?> command);
}

class NativeHostAppClient implements NativeHostAppConnection {
  NativeHostAppClient({
    ExtensionEndpoint? endpoint,
    String? socketPath,
    String? appPath,
    String? windowsEndpointFile,
    Duration timeout = const Duration(seconds: 3),
    Duration launchTimeout = const Duration(seconds: 6),
  }) : _endpoint =
           endpoint ??
           defaultExtensionEndpoint(unixSocketPath: socketPath),
       _appPath = appPath ?? _defaultAppPath(),
       _windowsEndpointFile = windowsEndpointFile,
       _timeout = timeout,
       _launchTimeout = launchTimeout;

  final ExtensionEndpoint _endpoint;
  final String _appPath;
  final String? _windowsEndpointFile;
  final Duration _timeout;
  final Duration _launchTimeout;

  @override
  Future<Map<String, Object?>> ping(Map<String, Object?> command) {
    return _send(command, launchIfUnavailable: false);
  }

  @override
  Future<Map<String, Object?>> send(Map<String, Object?> command) {
    return _send(command, launchIfUnavailable: _shouldLaunchApp(command));
  }

  Future<Map<String, Object?>> _send(
    Map<String, Object?> command, {
    required bool launchIfUnavailable,
  }) async {
    try {
      return await _sendOnce(command);
    } on SocketException {
      if (!launchIfUnavailable) rethrow;
      await _launchApp();
      return _retryUntilReady(command);
    }
  }

  Future<Map<String, Object?>> _retryUntilReady(
    Map<String, Object?> command,
  ) async {
    final deadline = DateTime.now().add(_launchTimeout);
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        return await _sendOnce(command);
      } catch (error) {
        lastError = error;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    throw TimeoutException('Downlink did not become available: $lastError');
  }

  Future<Map<String, Object?>> _sendOnce(Map<String, Object?> command) async {
    final endpoint = _resolveEndpoint();
    final socket = await _connect(endpoint);
    try {
      final payload = Map<String, Object?>.from(command);
      if (endpoint is TcpExtensionEndpoint) {
        payload['secret'] = endpoint.secret;
      }
      socket.writeln(jsonEncode(payload));
      await socket.flush();
      final body = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .first
          .timeout(_timeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map) return _error(command, 'invalid_response');
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } finally {
      await socket.close();
    }
  }

  ExtensionEndpoint _resolveEndpoint() {
    if (_endpoint is UnixExtensionEndpoint) return _endpoint;
    // Re-read the endpoint file so a freshly launched app is discovered.
    final tcp = readWindowsEndpoint(filePath: _windowsEndpointFile);
    if (tcp != null) return tcp;
    return _endpoint;
  }

  Future<Socket> _connect(ExtensionEndpoint endpoint) async {
    switch (endpoint) {
      case UnixExtensionEndpoint(:final path):
        return Socket.connect(
          InternetAddress(path, type: InternetAddressType.unix),
          0,
          timeout: _timeout,
        );
      case TcpExtensionEndpoint(:final host, :final port):
        if (port <= 0) {
          throw const SocketException('extension endpoint unavailable');
        }
        return Socket.connect(host, port, timeout: _timeout);
    }
  }

  Future<void> _launchApp() async {
    final file = File(_appPath);
    if (!await file.exists()) {
      throw const NativeHostAppException('app_unavailable');
    }
    await Process.start(_appPath, const [], mode: ProcessStartMode.detached);
  }

  Map<String, Object?> _error(Map<String, Object?> command, String error) {
    return {
      if (command['id'] != null) 'id': command['id'],
      'command': command['command']?.toString() ?? '',
      'success': false,
      'error': error,
    };
  }
}

String _defaultAppPath() {
  final override = Platform.environment['DOWNLINK_APP_PATH'];
  if (override != null && override.trim().isNotEmpty) return override;
  final dir = p.dirname(Platform.resolvedExecutable);
  if (Platform.isWindows) {
    return p.join(dir, 'downlink.exe');
  }
  return p.join(dir, 'downlink');
}

bool _shouldLaunchApp(Map<String, Object?> command) {
  return command['command'] == 'show' || command['launch_app'] == true;
}

class NativeHostAppException implements Exception {
  const NativeHostAppException(this.code);

  final String code;

  @override
  String toString() => 'NativeHostAppException($code)';
}
