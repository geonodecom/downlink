import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_update_config.dart';
import 'app_update_models.dart';

class GitHubReleasesClient {
  GitHubReleasesClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _accept = 'application/vnd.github+json';

  Future<UpdateOffer?> fetchLatestOffer(String currentVersion) async {
    final uri = Uri.parse(
      'https://api.github.com/repos/${AppUpdateConfig.githubRepo}/releases/latest',
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': _accept,
        'User-Agent': 'downlink',
      },
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw GitHubReleasesException(
        'GitHub releases API returned HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final tagName = decoded['tag_name'] as String? ?? '';
    final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    if (version.isEmpty) return null;

    final assets = decoded['assets'];
    if (assets is! List) return null;

    final asset = _pickAsset(assets, version);
    if (asset == null) return null;

    final downloadUrl = asset['browser_download_url'] as String? ?? '';
    final fileName = asset['name'] as String? ?? '';
    final size = asset['size'];
    final expectedSize = size is int ? size : int.tryParse('$size') ?? 0;
    if (downloadUrl.isEmpty || fileName.isEmpty) return null;

    final notes = decoded['body'] as String? ?? '';

    return UpdateOffer(
      version: version,
      releaseNotes: notes.trim(),
      downloadUrl: downloadUrl,
      fileName: fileName,
      expectedSize: expectedSize,
    );
  }

  Map<String, dynamic>? _pickAsset(List<dynamic> assets, String version) {
    final pattern = _assetNamePattern(version);
    for (final entry in assets) {
      if (entry is! Map<String, dynamic>) continue;
      final name = entry['name'] as String? ?? '';
      if (pattern.hasMatch(name)) return entry;
    }
    return null;
  }

  RegExp _assetNamePattern(String version) {
    if (Platform.isAndroid) {
      return RegExp('^downlink-$version\\.apk\$');
    }
    if (Platform.isWindows) {
      return RegExp(
        '^downlink-$version-windows-x64\\.zip\$',
      );
    }
    return RegExp(r'^$');
  }

  void close() => _client.close();
}

class GitHubReleasesException implements Exception {
  GitHubReleasesException(this.message);

  final String message;

  @override
  String toString() => message;
}

UpdateOffer? parseLatestReleaseJson(
  Map<String, dynamic> json, {
  required bool android,
}) {
  final tagName = json['tag_name'] as String? ?? '';
  final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
  final assets = json['assets'];
  if (assets is! List || version.isEmpty) return null;

  final pattern = android
      ? RegExp('^downlink-$version\\.apk\$')
      : RegExp('^downlink-$version-windows-x64\\.zip\$');

  Map<String, dynamic>? asset;
  for (final entry in assets) {
    if (entry is! Map<String, dynamic>) continue;
    final name = entry['name'] as String? ?? '';
    if (pattern.hasMatch(name)) {
      asset = entry;
      break;
    }
  }
  if (asset == null) return null;

  final downloadUrl = asset['browser_download_url'] as String? ?? '';
  final fileName = asset['name'] as String? ?? '';
  final size = asset['size'];
  final expectedSize = size is int ? size : int.tryParse('$size') ?? 0;
  if (downloadUrl.isEmpty || fileName.isEmpty) return null;

  return UpdateOffer(
    version: version,
    releaseNotes: (json['body'] as String? ?? '').trim(),
    downloadUrl: downloadUrl,
    fileName: fileName,
    expectedSize: expectedSize,
  );
}
