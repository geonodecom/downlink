import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/download_repository.dart';

class DownloadProbe {
  DownloadProbe({HttpClient? httpClient}) : _httpClient = httpClient;

  final HttpClient? _httpClient;

  Future<DownloadMetadata> probe(NewDownload input) async {
    final uri = Uri.parse(input.url);
    final fallbackFileName = _fileNameFromUrl(uri);

    final client = _httpClient ?? HttpClient();
    try {
      final head = await _probeHead(
        client,
        uri,
        input,
      ).catchError((_) => DownloadMetadata(fileName: fallbackFileName));
      if (head.totalLength > 0) return head;

      final ranged = await _probeRange(
        client,
        uri,
        input,
      ).catchError((_) => const DownloadMetadata());
      return DownloadMetadata(
        fileName: head.fileName ?? ranged.fileName ?? fallbackFileName,
        totalLength: ranged.totalLength,
      );
    } catch (_) {
      return DownloadMetadata(fileName: fallbackFileName);
    } finally {
      if (_httpClient == null) client.close(force: true);
    }
  }

  Future<DownloadMetadata> _probeHead(
    HttpClient client,
    Uri uri,
    NewDownload input,
  ) async {
    final request = await client.headUrl(uri);
    _applyHeaders(request, input.headers);
    final response = await request.close();
    try {
      return DownloadMetadata(
        fileName:
            _fileNameFromContentDisposition(
              response.headers.value('content-disposition'),
            ) ??
            _fileNameFromUrl(uri),
        totalLength: _contentLength(response),
      );
    } finally {
      await response.drain<void>();
    }
  }

  Future<DownloadMetadata> _probeRange(
    HttpClient client,
    Uri uri,
    NewDownload input,
  ) async {
    final request = await client.getUrl(uri);
    _applyHeaders(request, input.headers);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
    final response = await request.close();
    try {
      return DownloadMetadata(
        fileName:
            _fileNameFromContentDisposition(
              response.headers.value('content-disposition'),
            ) ??
            _fileNameFromUrl(uri),
        totalLength:
            _lengthFromContentRange(
              response.headers.value(HttpHeaders.contentRangeHeader),
            ) ??
            _contentLength(response),
      );
    } finally {
      await response.listen(null).cancel();
    }
  }

  void _applyHeaders(HttpClientRequest request, Map<String, String> headers) {
    for (final header in headers.entries) {
      request.headers.set(header.key, header.value);
    }
  }

  int _contentLength(HttpClientResponse response) {
    return response.contentLength > 0 ? response.contentLength : 0;
  }

  int? _lengthFromContentRange(String? value) {
    if (value == null) return null;
    final match = RegExp(r'/(\d+)$').firstMatch(value.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  String? _fileNameFromUrl(Uri uri) {
    final basename = p.basename(uri.path);
    if (basename.isEmpty || basename == '.') return null;
    try {
      return Uri.decodeComponent(basename);
    } on ArgumentError {
      return basename;
    }
  }

  String? _fileNameFromContentDisposition(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final encoded = RegExp(
      r'''filename\*=([^']*)''([^;]+)''',
      caseSensitive: false,
    ).firstMatch(value);
    if (encoded != null) {
      return _cleanFileName(Uri.decodeComponent(encoded.group(2)!));
    }

    final quoted = RegExp(
      r'''filename="([^"]+)"''',
      caseSensitive: false,
    ).firstMatch(value);
    if (quoted != null) return _cleanFileName(quoted.group(1));

    final plain = RegExp(
      r'''filename=([^;]+)''',
      caseSensitive: false,
    ).firstMatch(value);
    return _cleanFileName(plain?.group(1));
  }

  String? _cleanFileName(String? value) {
    final trimmed = value?.trim().replaceAll(r'\', '/');
    if (trimmed == null || trimmed.isEmpty) return null;
    final clean = p.basename(trimmed);
    if (clean.isEmpty || clean == '.') return null;
    try {
      return Uri.decodeComponent(clean);
    } on ArgumentError {
      return clean;
    }
  }
}
