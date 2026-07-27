import 'dart:convert';

class TikTokDownloadOptions {
  const TikTokDownloadOptions({
    required this.formatId,
    required this.title,
    required this.ext,
    this.directUrl = '',
    this.cookieHeader = '',
  });

  static const kind = 'tiktok';

  final String formatId;
  final String title;
  final String ext;

  /// Progressive CDN URL used on Android HTTP downloads.
  final String directUrl;

  /// Optional Cookie header captured during Android metadata fetch.
  final String cookieHeader;

  Map<String, Object?> toJson() {
    return {
      'kind': kind,
      'formatId': formatId,
      'title': title,
      'ext': ext,
      if (directUrl.isNotEmpty) 'directUrl': directUrl,
      if (cookieHeader.isNotEmpty) 'cookieHeader': cookieHeader,
    };
  }

  factory TikTokDownloadOptions.fromJson(Map<String, Object?> json) {
    return TikTokDownloadOptions(
      formatId: json['formatId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      ext: json['ext']?.toString() ?? 'mp4',
      directUrl: json['directUrl']?.toString() ?? '',
      cookieHeader: json['cookieHeader']?.toString() ?? '',
    );
  }

  String get sanitizedFileName {
    final base = _sanitizeFileName(title);
    final safeExt = ext.trim().isEmpty ? 'mp4' : ext.trim();
    if (base.isEmpty) return 'tiktok_video.$safeExt';
    return '$base.$safeExt';
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

TikTokDownloadOptions? tiktokOptionsFromJson(String? optionsJson) {
  if (optionsJson == null || optionsJson.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(optionsJson);
    if (decoded is! Map) return null;
    final map = decoded.cast<String, Object?>();
    if (map['kind']?.toString() != TikTokDownloadOptions.kind) return null;
    return TikTokDownloadOptions.fromJson(map);
  } catch (_) {
    return null;
  }
}

bool isTikTokDownloadOptions(String? optionsJson) {
  return tiktokOptionsFromJson(optionsJson) != null;
}
