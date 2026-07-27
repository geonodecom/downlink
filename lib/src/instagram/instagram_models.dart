import 'dart:convert';

class InstagramDownloadOptions {
  const InstagramDownloadOptions({
    required this.formatId,
    required this.title,
    required this.ext,
    this.directUrl = '',
  });

  static const kind = 'instagram';

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

  factory InstagramDownloadOptions.fromJson(Map<String, Object?> json) {
    return InstagramDownloadOptions(
      formatId: json['formatId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      ext: json['ext']?.toString() ?? 'mp4',
      directUrl: json['directUrl']?.toString() ?? '',
    );
  }

  String get sanitizedFileName {
    final base = _sanitizeFileName(title);
    if (base.isEmpty) return 'instagram_video.$ext';
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

InstagramDownloadOptions? instagramOptionsFromJson(String? optionsJson) {
  if (optionsJson == null || optionsJson.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(optionsJson);
    if (decoded is! Map) return null;
    final map = decoded.cast<String, Object?>();
    if (map['kind']?.toString() != InstagramDownloadOptions.kind) return null;
    return InstagramDownloadOptions.fromJson(map);
  } catch (_) {
    return null;
  }
}

bool isInstagramDownloadOptions(String? optionsJson) {
  return instagramOptionsFromJson(optionsJson) != null;
}
