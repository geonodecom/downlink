import 'dart:convert';

import '../instagram/instagram_models.dart';
import '../tiktok/tiktok_models.dart';
import '../torrent/torrent_models.dart';
import '../ytdlp/ytdlp_models.dart';

class FacebookDownloadOptions {
  const FacebookDownloadOptions({
    required this.formatId,
    required this.title,
    required this.ext,
    this.directUrl = '',
  });

  static const kind = 'facebook';

  final String formatId;
  final String title;
  final String ext;

  /// Progressive CDN URL used on Android HTTP downloads.
  final String directUrl;

  Map<String, Object?> toJson() {
    return {
      'kind': kind,
      'formatId': formatId,
      'title': title,
      'ext': ext,
      if (directUrl.isNotEmpty) 'directUrl': directUrl,
    };
  }

  factory FacebookDownloadOptions.fromJson(Map<String, Object?> json) {
    return FacebookDownloadOptions(
      formatId: json['formatId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      ext: json['ext']?.toString() ?? 'mp4',
      directUrl: json['directUrl']?.toString() ?? '',
    );
  }

  String get sanitizedFileName {
    final base = _sanitizeFileName(title);
    if (base.isEmpty) return 'facebook_video.$ext';
    return '$base.$ext';
  }

  static String _sanitizeFileName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    return cleaned.length > 180 ? cleaned.substring(0, 180) : cleaned;
  }
}

FacebookDownloadOptions? facebookOptionsFromJson(String? optionsJson) {
  if (optionsJson == null || optionsJson.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(optionsJson);
    if (decoded is! Map) return null;
    final map = decoded.cast<String, Object?>();
    if (map['kind']?.toString() != FacebookDownloadOptions.kind) return null;
    return FacebookDownloadOptions.fromJson(map);
  } catch (_) {
    return null;
  }
}

bool isFacebookDownloadOptions(String? optionsJson) {
  return facebookOptionsFromJson(optionsJson) != null;
}

bool isExtractorDownloadOptions(String? optionsJson) {
  return isYoutubeDownloadOptions(optionsJson) ||
      isFacebookDownloadOptions(optionsJson) ||
      isInstagramDownloadOptions(optionsJson) ||
      isTikTokDownloadOptions(optionsJson) ||
      isTorrentDownloadOptions(optionsJson);
}
