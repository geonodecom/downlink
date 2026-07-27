import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/app_database.dart';
import 'data/download_repository.dart';
import 'engine/android_download_engine.dart';
import 'engine/aria2_download_engine.dart';
import 'engine/composite_download_engine.dart';
import 'engine/download_engine.dart';
import 'engine/explode_youtube_download_engine.dart';
import 'engine/ytdlp_download_engine.dart';
import 'extension/download_capture.dart';
import 'facebook/facebook_session.dart';
import 'instagram/instagram_session.dart';
import 'tiktok/tiktok_session.dart';
import 'services/diagnostics.dart';
import 'services/download_service.dart';
import 'ytdlp/youtube_metadata_client.dart';

enum ShellSection { downloads, queue, history, settings, diagnostics }

class ShellSectionNotifier extends Notifier<ShellSection> {
  @override
  ShellSection build() => ShellSection.downloads;

  void select(ShellSection section) {
    state = section;
  }
}

class AddDownloadRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() {
    state++;
  }
}

class DownloadCaptureQueueNotifier extends Notifier<List<DownloadCapture>> {
  @override
  List<DownloadCapture> build() => const [];

  void enqueue(DownloadCapture capture) {
    state = [...state, capture];
  }

  DownloadCapture? takeNext() {
    if (state.isEmpty) return null;
    final next = state.first;
    state = state.sublist(1);
    return next;
  }
}

final shellSectionProvider =
    NotifierProvider<ShellSectionNotifier, ShellSection>(
      ShellSectionNotifier.new,
    );

final addDownloadRequestProvider =
    NotifierProvider<AddDownloadRequestNotifier, int>(
      AddDownloadRequestNotifier.new,
    );

final downloadCaptureQueueProvider =
    NotifierProvider<DownloadCaptureQueueNotifier, List<DownloadCapture>>(
      DownloadCaptureQueueNotifier.new,
    );

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(ref.watch(databaseProvider));
});

final facebookSessionProvider = Provider<FacebookSession>((ref) {
  return FacebookSession();
});

final instagramSessionProvider = Provider<InstagramSession>((ref) {
  return InstagramSession();
});

final tiktokSessionProvider = Provider<TikTokSession>((ref) {
  return TikTokSession();
});

final downloadEngineProvider = Provider<DownloadEngine>((ref) {
  final diagnostics = ref.watch(diagnosticsLogProvider);
  final facebookSession = ref.watch(facebookSessionProvider);
  final instagramSession = ref.watch(instagramSessionProvider);
  final tiktokSession = ref.watch(tiktokSessionProvider);
  final repository = ref.watch(downloadRepositoryProvider);
  // Read cookie settings on demand so saving Settings does not recreate the
  // engine and drop in-flight yt-dlp jobs.
  Future<FacebookCookieArgs> facebookCookieArgs() async {
    final settings = await repository.getSettings();
    return FacebookCookieArgs(
      cookiesPath: settings.facebookCookiesPath,
      fromBrowser: settings.facebookCookiesFromBrowser,
    );
  }

  Future<InstagramCookieArgs> instagramCookieArgs() async {
    final settings = await repository.getSettings();
    return InstagramCookieArgs(
      cookiesPath: settings.instagramCookiesPath,
      fromBrowser: settings.instagramCookiesFromBrowser,
    );
  }

  Future<TikTokCookieArgs> tiktokCookieArgs() async {
    final settings = await repository.getSettings();
    return TikTokCookieArgs(
      cookiesPath: settings.tiktokCookiesPath,
      fromBrowser: settings.tiktokCookiesFromBrowser,
    );
  }

  final base = Platform.isAndroid
      ? AndroidDownloadEngine()
      : Aria2DownloadEngine(diagnostics: diagnostics);
  final youtube = Platform.isAndroid
      ? ExplodeYoutubeDownloadEngine()
      : YtdlpDownloadEngine(
          facebookCookieArgsProvider: facebookCookieArgs,
          facebookSession: facebookSession,
          instagramCookieArgsProvider: instagramCookieArgs,
          instagramSession: instagramSession,
          tiktokCookieArgsProvider: tiktokCookieArgs,
          tiktokSession: tiktokSession,
        );
  return CompositeDownloadEngine(
    baseEngine: base,
    youtubeEngine: youtube,
    facebookCookieHeader: facebookSession.cookieHeader,
    instagramCookieHeader: instagramSession.cookieHeader,
    tiktokCookieHeader: tiktokSession.cookieHeader,
  );
});

final ytdlpClientProvider = Provider<YoutubeMetadataClient>((ref) {
  final settings = ref.watch(settingsProvider).maybeWhen(
        data: (value) => value,
        orElse: () => null,
      );
  return createYoutubeMetadataClient(
    ytdlpOverride: settings?.ytdlpPath ?? '',
    ffmpegOverride: settings?.ffmpegPath ?? '',
    facebookCookieArgs: FacebookCookieArgs(
      cookiesPath: settings?.facebookCookiesPath ?? '',
      fromBrowser: settings?.facebookCookiesFromBrowser ?? '',
    ),
    facebookSession: ref.watch(facebookSessionProvider),
    instagramCookieArgs: InstagramCookieArgs(
      cookiesPath: settings?.instagramCookiesPath ?? '',
      fromBrowser: settings?.instagramCookiesFromBrowser ?? '',
    ),
    instagramSession: ref.watch(instagramSessionProvider),
    tiktokCookieArgs: TikTokCookieArgs(
      cookiesPath: settings?.tiktokCookiesPath ?? '',
      fromBrowser: settings?.tiktokCookiesFromBrowser ?? '',
    ),
    tiktokSession: ref.watch(tiktokSessionProvider),
  );
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final service = DownloadService(
    repository: ref.watch(downloadRepositoryProvider),
    engine: ref.watch(downloadEngineProvider),
    diagnostics: ref.watch(diagnosticsLogProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final startupProvider = FutureProvider<void>((ref) async {
  await ref.watch(downloadServiceProvider).start();
});

final downloadsProvider = StreamProvider<List<DownloadEntity>>((ref) {
  return ref.watch(downloadRepositoryProvider).watchDownloads();
});

final downloadProvider = StreamProvider.family<DownloadEntity?, String>((
  ref,
  id,
) {
  return ref.watch(downloadRepositoryProvider).watchDownload(id);
});

final activeProvider = StreamProvider<List<DownloadEntity>>((ref) {
  return ref.watch(downloadRepositoryProvider).watchActive();
});

final queueProvider = StreamProvider<List<DownloadEntity>>((ref) {
  return ref.watch(downloadRepositoryProvider).watchQueue();
});

final historyProvider = StreamProvider<List<DownloadEntity>>((ref) {
  return ref.watch(downloadRepositoryProvider).watchHistory();
});

final settingsProvider = StreamProvider<GeonodeSettings>((ref) {
  return ref.watch(downloadRepositoryProvider).watchSettings();
});
