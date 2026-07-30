import 'dart:convert';
import 'dart:io';

import 'package:downlink/src/aria2/aria2_client.dart';
import 'package:downlink/src/aria2/aria2_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Aria2Client sends JSON-RPC bodies with a content length', () async {
    late Map<String, Object?> requestJson;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    final serving = server.first.then((request) async {
      expect(request.headers.chunkedTransferEncoding, isFalse);
      expect(request.headers.contentLength, greaterThan(0));

      final body = await utf8.decoder.bind(request).join();
      requestJson = jsonDecode(body) as Map<String, Object?>;

      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': requestJson['id'],
            'result': '0000000000000001',
          }),
        );
      await request.response.close();
    });

    final client = Aria2Client(
      Aria2Endpoint(
        host: InternetAddress.loopbackIPv4.host,
        port: server.port,
        secret: 'test-secret',
      ),
    );

    addTearDown(() async {
      client.close();
      await server.close(force: true);
    });

    final gid = await client.addUri(
      url: 'https://ash-speed.hetzner.com/1GB.bin',
      directory: '/tmp',
      split: 16,
    );

    expect(gid, '0000000000000001');
    expect(requestJson['method'], 'aria2.addUri');
    expect(requestJson['params'], [
      'token:test-secret',
      ['https://ash-speed.hetzner.com/1GB.bin'],
      {'dir': '/tmp', 'split': '16', 'max-connection-per-server': '16'},
    ]);

    await serving;
  });

  test('Aria2Client includes captured headers in addUri options', () async {
    late Map<String, Object?> requestJson;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    final serving = server.first.then((request) async {
      final body = await utf8.decoder.bind(request).join();
      requestJson = jsonDecode(body) as Map<String, Object?>;
      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': requestJson['id'],
            'result': '0000000000000002',
          }),
        );
      await request.response.close();
    });

    final client = Aria2Client(
      Aria2Endpoint(
        host: InternetAddress.loopbackIPv4.host,
        port: server.port,
        secret: 'test-secret',
      ),
    );

    addTearDown(() async {
      client.close();
      await server.close(force: true);
    });

    await client.addUri(
      url: 'https://example.com/file.iso',
      directory: '/tmp',
      split: 16,
      headers: const {
        'Referer': 'https://example.com/',
        'User-Agent': 'Downlink test',
      },
    );

    expect(requestJson['params'], [
      'token:test-secret',
      ['https://example.com/file.iso'],
      {
        'dir': '/tmp',
        'split': '16',
        'max-connection-per-server': '16',
        'header': 'Referer: https://example.com/\nUser-Agent: Downlink test',
      },
    ]);

    await serving;
  });
}
