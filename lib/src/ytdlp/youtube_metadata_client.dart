import 'dart:io';

import '../facebook/facebook_session.dart';
import '../instagram/instagram_session.dart';
import 'explode_youtube_client.dart';
import 'ytdlp_client.dart';
import 'ytdlp_models.dart';

/// Shared YouTube metadata API used by the add-download UI.
abstract class YoutubeMetadataClient {
  Future<bool> checkHealth();

  Future<YtdlpVideoInfo> fetchInfo(String url);

  Future<YtdlpPlaylistInfo> fetchPlaylist(String url);
}

/// Desktop uses yt-dlp; Android uses youtube_explode_dart (no native process).
YoutubeMetadataClient createYoutubeMetadataClient({
  String ytdlpOverride = '',
  String ffmpegOverride = '',
  FacebookCookieArgs facebookCookieArgs = const FacebookCookieArgs(),
  FacebookSession? facebookSession,
  InstagramCookieArgs instagramCookieArgs = const InstagramCookieArgs(),
  InstagramSession? instagramSession,
}) {
  if (Platform.isAndroid) {
    return ExplodeYoutubeClient();
  }
  return YtdlpClient(
    ytdlpOverride: ytdlpOverride,
    ffmpegOverride: ffmpegOverride,
    facebookCookieArgs: facebookCookieArgs,
    facebookSession: facebookSession,
    instagramCookieArgs: instagramCookieArgs,
    instagramSession: instagramSession,
  );
}
