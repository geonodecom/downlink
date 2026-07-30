import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

/// Describes how the native host reaches the Flutter app extension bridge.
sealed class ExtensionEndpoint {
  const ExtensionEndpoint();
}

class UnixExtensionEndpoint extends ExtensionEndpoint {
  const UnixExtensionEndpoint(this.path);

  final String path;
}

class TcpExtensionEndpoint extends ExtensionEndpoint {
  const TcpExtensionEndpoint({
    required this.host,
    required this.port,
    required this.secret,
  });

  final String host;
  final int port;
  final String secret;

  Map<String, Object?> toJson() => {
    'host': host,
    'port': port,
    'secret': secret,
  };

  static TcpExtensionEndpoint fromJson(Map<String, Object?> json) {
    return TcpExtensionEndpoint(
      host: json['host']?.toString() ?? '127.0.0.1',
      port: (json['port'] as num?)?.toInt() ?? 0,
      secret: json['secret']?.toString() ?? '',
    );
  }
}

/// Default Unix domain socket path (Linux / macOS).
String extensionSocketPath({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final runtimeDir = env['XDG_RUNTIME_DIR'];
  if (runtimeDir != null && runtimeDir.trim().isNotEmpty) {
    return p.join(runtimeDir, 'downlink', 'extension.sock');
  }
  final uid = env['UID'] ?? env['USER'] ?? 'user';
  return p.join('/tmp', 'downlink-$uid', 'extension.sock');
}

/// Absolute path of the Windows endpoint discovery file.
///
/// Shared by the Flutter app and native host (no path_provider) so both sides
/// agree: `%LOCALAPPDATA%\downlink\extension-endpoint.json`.
String windowsEndpointFilePath({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final override = env['DOWNLINK_EXTENSION_ENDPOINT'];
  if (override != null && override.trim().isNotEmpty) return override;
  final localAppData = env['LOCALAPPDATA'];
  if (localAppData != null && localAppData.trim().isNotEmpty) {
    return p.join(localAppData, 'downlink', 'extension-endpoint.json');
  }
  final temp = env['TEMP'] ?? env['TMP'] ?? '.';
  return p.join(temp, 'downlink', 'extension-endpoint.json');
}

Future<void> writeWindowsEndpoint(
  TcpExtensionEndpoint endpoint, {
  String? filePath,
}) async {
  final path = filePath ?? windowsEndpointFilePath();
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(endpoint.toJson()),
  );
}

Future<void> clearWindowsEndpoint({String? filePath}) async {
  final path = filePath ?? windowsEndpointFilePath();
  final file = File(path);
  if (await file.exists()) await file.delete();
}

TcpExtensionEndpoint? readWindowsEndpoint({
  Map<String, String>? environment,
  String? filePath,
}) {
  final path = filePath ?? windowsEndpointFilePath(environment: environment);
  final file = File(path);
  if (!file.existsSync()) return null;
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) return null;
    return TcpExtensionEndpoint.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  } catch (_) {
    return null;
  }
}

String randomExtensionSecret() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Platform default endpoint descriptor for the native host client.
ExtensionEndpoint defaultExtensionEndpoint({
  Map<String, String>? environment,
  String? unixSocketPath,
}) {
  if (Platform.isWindows) {
    final tcp = readWindowsEndpoint(environment: environment);
    if (tcp != null) return tcp;
    return const TcpExtensionEndpoint(host: '127.0.0.1', port: 0, secret: '');
  }
  return UnixExtensionEndpoint(
    unixSocketPath ?? extensionSocketPath(environment: environment),
  );
}
