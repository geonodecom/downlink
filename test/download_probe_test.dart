import 'dart:io';

import 'package:downlink/src/data/download_repository.dart';
import 'package:downlink/src/services/download_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('probe reads filename and size before a download starts', () async {
    server.listen((request) {
      expect(request.method, 'HEAD');
      request.response
        ..headers.set(
          'content-disposition',
          'attachment; filename="archive.tar.zst"',
        )
        ..contentLength = 123456
        ..close();
    });

    final metadata = await DownloadProbe().probe(
      NewDownload(
        url: 'http://${server.address.host}:${server.port}/download',
        directory: '/tmp',
        fileName: '',
        split: 16,
        startImmediately: false,
      ),
    );

    expect(metadata.fileName, 'archive.tar.zst');
    expect(metadata.totalLength, 123456);
  });

  test('probe falls back to url filename when headers are sparse', () async {
    server.listen((request) {
      request.response.close();
    });

    final metadata = await DownloadProbe().probe(
      NewDownload(
        url: 'http://${server.address.host}:${server.port}/files/video.mkv',
        directory: '/tmp',
        fileName: '',
        split: 16,
        startImmediately: false,
      ),
    );

    expect(metadata.fileName, 'video.mkv');
    expect(metadata.totalLength, 0);
  });

  test('probe decodes percent-encoded url filenames', () async {
    server.listen((request) {
      request.response.close();
    });

    final metadata = await DownloadProbe().probe(
      NewDownload(
        url:
            'http://${server.address.host}:${server.port}/files/Troy%20(2004)%201080p%20BluRay.mp4',
        directory: '/tmp',
        fileName: '',
        split: 16,
        startImmediately: false,
      ),
    );

    expect(metadata.fileName, 'Troy (2004) 1080p BluRay.mp4');
  });

  test('probe uses range request when head does not include size', () async {
    final methods = <String>[];
    server.listen((request) {
      methods.add(request.method);
      if (request.method == 'GET') {
        expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=0-0');
        request.response
          ..statusCode = HttpStatus.partialContent
          ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-0/104857600')
          ..write([0])
          ..close();
        return;
      }
      request.response.close();
    });

    final metadata = await DownloadProbe().probe(
      NewDownload(
        url: 'http://${server.address.host}:${server.port}/100MB.bin',
        directory: '/tmp',
        fileName: '',
        split: 16,
        startImmediately: false,
      ),
    );

    expect(methods, ['HEAD', 'GET']);
    expect(metadata.fileName, '100MB.bin');
    expect(metadata.totalLength, 104857600);
  });

  test('probe still tries range request when head fails', () async {
    final methods = <String>[];
    server.listen((request) {
      methods.add(request.method);
      if (request.method == 'HEAD') {
        request.response
          ..statusCode = HttpStatus.methodNotAllowed
          ..close();
        return;
      }
      request.response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-0/104857600')
        ..write([0])
        ..close();
    });

    final metadata = await DownloadProbe().probe(
      NewDownload(
        url: 'http://${server.address.host}:${server.port}/100MB.bin',
        directory: '/tmp',
        fileName: '',
        split: 16,
        startImmediately: false,
      ),
    );

    expect(methods, ['HEAD', 'GET']);
    expect(metadata.fileName, '100MB.bin');
    expect(metadata.totalLength, 104857600);
  });
}
