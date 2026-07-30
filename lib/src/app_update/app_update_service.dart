import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/download_repository.dart';
import '../platform/android_app_update.dart';
import '../platform/windows_app_update.dart';
import 'app_update_config.dart';
import 'app_update_models.dart';
import 'app_version.dart';
import 'github_releases_client.dart';

class AppUpdateService {
  AppUpdateService({
    required DownloadRepository repository,
    GitHubReleasesClient? releasesClient,
    http.Client? httpClient,
  })  : _repository = repository,
        _releasesClient = releasesClient ?? GitHubReleasesClient(client: httpClient),
        _httpClient = httpClient ?? http.Client();

  final DownloadRepository _repository;
  final GitHubReleasesClient _releasesClient;
  final http.Client _httpClient;

  Future<PackageInfo> packageInfo() => PackageInfo.fromPlatform();

  Future<String> currentVersionLabel() async {
    final info = await packageInfo();
    return '${info.version}+${info.buildNumber}';
  }

  Future<UpdateOffer?> checkForUpdate({bool ignoreSkip = false}) async {
    if (!Platform.isAndroid && !Platform.isWindows) return null;

    final info = await packageInfo();
    final settings = await _repository.getSettings();

    final offer = await _releasesClient.fetchLatestOffer(info.version);
    if (offer == null) return null;

    if (!isNewerRelease(info.version, offer.version)) return null;

    if (!ignoreSkip &&
        settings.skippedUpdateVersion == offer.version) {
      return null;
    }

    await _recordCheckTime();
    return offer;
  }

  Future<bool> shouldRunBackgroundCheck() async {
    final settings = await _repository.getSettings();
    final last = settings.lastUpdateCheckAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >=
        AppUpdateConfig.backgroundCheckInterval;
  }

  Future<void> skipVersion(String version) async {
    final settings = await _repository.getSettings();
    await _repository.saveSettings(
      settings.copyWith(skippedUpdateVersion: version),
    );
  }

  Future<File> downloadUpdate(
    UpdateOffer offer, {
    void Function(AppUpdateProgress progress)? onProgress,
  }) async {
    final dir = await _updateCacheDirectory();
    final target = File(p.join(dir.path, offer.fileName));
    if (await target.exists()) {
      await target.delete();
    }

    final request = http.Request('GET', Uri.parse(offer.downloadUrl));
    request.headers['User-Agent'] = 'downlink';
    final response = await _httpClient.send(request);
    if (response.statusCode != 200) {
      throw AppUpdateException(
        'Update download failed (HTTP ${response.statusCode})',
      );
    }

    final total = response.contentLength;
    var received = 0;
    final sink = target.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(AppUpdateProgress(received: received, total: total));
      }
    } catch (e) {
      await sink.close();
      if (await target.exists()) await target.delete();
      throw AppUpdateException('Update download failed: $e');
    }
    await sink.close();

    if (offer.expectedSize > 0 && received != offer.expectedSize) {
      await target.delete();
      throw AppUpdateException(
        'Update file size mismatch (expected ${offer.expectedSize}, got $received)',
      );
    }

    return target;
  }

  Future<void> applyUpdate(File file) async {
    if (Platform.isAndroid) {
      try {
        await AndroidAppUpdate.installApk(file.path);
      } on AndroidAppUpdateException catch (e) {
        throw AppUpdateException(e.message);
      }
      return;
    }
    if (Platform.isWindows) {
      await WindowsAppUpdate.applyAndRestart(zipPath: file.path);
      return;
    }
    throw AppUpdateException('Updates are not supported on this platform.');
  }

  Future<void> dispose() async {
    _releasesClient.close();
    _httpClient.close();
  }

  Future<void> _recordCheckTime() async {
    final settings = await _repository.getSettings();
    await _repository.saveSettings(
      settings.copyWith(lastUpdateCheckAt: DateTime.now()),
    );
  }

  Future<Directory> _updateCacheDirectory() async {
    final base = await getApplicationCacheDirectory();
    final dir = Directory(p.join(base.path, 'app_update'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

class AppUpdateException implements Exception {
  AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
