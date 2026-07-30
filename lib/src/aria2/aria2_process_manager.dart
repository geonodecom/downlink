import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/executable_finder.dart';
import '../services/diagnostics.dart';
import 'aria2_client.dart';
import 'aria2_models.dart';

class Aria2ProcessManager {
  Aria2ProcessManager({DiagnosticsLog? diagnostics})
    : _diagnostics = diagnostics;

  Process? _process;
  Aria2Endpoint? _endpoint;
  Aria2Client? _client;
  final DiagnosticsLog? _diagnostics;

  Aria2Endpoint? get endpoint => _endpoint;

  bool get isRunning => _process != null;

  Future<bool> get isHealthy async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.getVersion();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Aria2Endpoint> start({
    required String downloadDirectory,
    required int maxActiveDownloads,
    required int defaultSplit,
    String executableOverride = '',
  }) async {
    if (_endpoint != null && await isHealthy) return _endpoint!;
    if (_endpoint != null) {
      stderr.writeln('[downlink] aria2 RPC is stale; starting a new process');
      _clearState();
    }

    final executable = await _findExecutable(executableOverride);
    final appDir = await getApplicationSupportDirectory();
    final runtimeDir = Directory(p.join(appDir.path, 'aria2'));
    await runtimeDir.create(recursive: true);
    await Directory(downloadDirectory).create(recursive: true);

    final sessionFile = File(p.join(runtimeDir.path, 'session.txt'));
    if (!await sessionFile.exists()) await sessionFile.create(recursive: true);

    final port = await _findFreePort();
    final secret = _randomSecret();
    final endpoint = Aria2Endpoint(
      host: '127.0.0.1',
      port: port,
      secret: secret,
    );

    final args = [
      '--enable-rpc=true',
      '--rpc-listen-all=false',
      '--rpc-listen-port=$port',
      '--rpc-secret=$secret',
      '--rpc-allow-origin-all=false',
      '--daemon=false',
      '--enable-color=false',
      '--continue=true',
      '--input-file=${sessionFile.path}',
      '--save-session=${sessionFile.path}',
      '--save-session-interval=30',
      '--max-concurrent-downloads=$maxActiveDownloads',
      '--split=$defaultSplit',
      '--max-connection-per-server=$defaultSplit',
      '--dir=$downloadDirectory',
      '--enable-dht=true',
      '--bt-enable-lpd=true',
      '--enable-peer-exchange=true',
      '--listen-port=6881-6999',
      '--dht-listen-port=6881-6999',
      '--bt-max-peers=55',
      '--follow-torrent=true',
      // Private trackers (e.g. TorrentBD) often whitelist clients by peer ID /
      // User-Agent and reject aria2's defaults with "banned client".
      '--peer-id-prefix=-qB4620-',
      '--peer-agent=qBittorrent/4.6.2',
      '--user-agent=qBittorrent/4.6.2',
      // Keep Flutter diagnostics readable; progress is polled via RPC.
      '--console-log-level=warn',
      '--summary-interval=0',
    ];

    stderr.writeln(
      '[downlink] starting aria2: $executable --rpc-listen-port=$port --dir=$downloadDirectory',
    );
    _process = await Process.start(executable, args);
    _watchProcess(_process!);
    _drain(_process!.stdout, 'stdout');
    _drain(_process!.stderr, 'stderr');
    _endpoint = endpoint;
    _client = Aria2Client(endpoint);
    await _waitUntilReady(_client!);
    _diagnostics?.info(
      'aria2 RPC listening on ${endpoint.host}:${endpoint.port}',
    );
    stderr.writeln(
      '[downlink] aria2 RPC ready on ${endpoint.host}:${endpoint.port}',
    );
    return endpoint;
  }

  Aria2Client client() {
    final client = _client;
    if (client == null) throw StateError('aria2 is not running');
    return client;
  }

  Future<void> shutdown() async {
    final client = _client;
    if (client != null) {
      try {
        await client.saveSession();
        await client.shutdown();
      } catch (_) {
        _process?.kill();
      } finally {
        client.close();
      }
    }
    _process?.kill();
    _clearState();
  }

  Future<String> _findExecutable(String override) async {
    try {
      return await findAria2Executable(override: override);
    } on StateError catch (error) {
      throw Aria2Exception(error.message);
    }
  }

  Future<int> _findFreePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<void> _waitUntilReady(Aria2Client client) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        await client.getVersion();
        return;
      } catch (err) {
        lastError = err;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    throw Aria2Exception('aria2 did not become ready: $lastError');
  }

  void _watchProcess(Process process) {
    unawaited(
      process.exitCode.then((code) {
        if (code == 0) {
          _diagnostics?.info('aria2 process exited normally (code 0).');
        } else {
          _diagnostics?.error('aria2 process exited with code $code.');
        }
        stderr.writeln('[downlink] aria2 exited with code $code');
        if (!identical(_process, process)) return;
        _clearState();
      }),
    );
  }

  void _clearState() {
    _client?.close();
    _process = null;
    _endpoint = null;
    _client = null;
  }

  void _drain(Stream<List<int>> stream, String name) {
    stream.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      stderr.writeln('[aria2:$name] $line');
      if (line.contains('[ERROR]')) {
        _diagnostics?.error('aria2: $line');
      } else if (line.contains('[WARN]')) {
        _diagnostics?.warn('aria2: $line');
      }
    });
  }

  String _randomSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
