import 'dart:convert';

class YoutubeDownloadOptions {
  const YoutubeDownloadOptions({
    required this.formatId,
    required this.title,
    required this.ext,
  });

  static const kind = 'youtube';

  final String formatId;
  final String title;
  final String ext;

  Map<String, Object?> toJson() {
    return {
      'kind': kind,
      'formatId': formatId,
      'title': title,
      'ext': ext,
    };
  }

  factory YoutubeDownloadOptions.fromJson(Map<String, Object?> json) {
    return YoutubeDownloadOptions(
      formatId: json['formatId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      ext: json['ext']?.toString() ?? 'mp4',
    );
  }

  String get sanitizedFileName {
    final base = _sanitizeFileName(title);
    if (base.isEmpty) return 'video.$ext';
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

YoutubeDownloadOptions? youtubeOptionsFromJson(String? optionsJson) {
  if (optionsJson == null || optionsJson.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(optionsJson);
    if (decoded is! Map) return null;
    final map = decoded.cast<String, Object?>();
    if (map['kind']?.toString() != YoutubeDownloadOptions.kind) return null;
    return YoutubeDownloadOptions.fromJson(map);
  } catch (_) {
    return null;
  }
}

bool isYoutubeDownloadOptions(String? optionsJson) {
  return youtubeOptionsFromJson(optionsJson) != null;
}

class YtdlpFormat {
  const YtdlpFormat({
    required this.formatId,
    required this.ext,
    required this.resolution,
    required this.note,
    required this.fileSize,
    required this.vcodec,
    required this.acodec,
    required this.format,
  });

  final String formatId;
  final String ext;
  final String resolution;
  final String note;
  final int? fileSize;
  final String vcodec;
  final String acodec;
  final String format;

  bool get hasVideo => vcodec != 'none';
  bool get hasAudio => acodec != 'none';
  bool get isCombined => hasVideo && hasAudio;

  String get label {
    final parts = <String>[];
    if (resolution.isNotEmpty) parts.add(resolution);
    if (ext.isNotEmpty) parts.add(ext.toUpperCase());
    if (note.isNotEmpty) parts.add(note);
    if (fileSize != null && fileSize! > 0) {
      parts.add(_formatBytes(fileSize!));
    }
    if (!isCombined) {
      if (hasVideo && !hasAudio) parts.add('video only');
      if (hasAudio && !hasVideo) parts.add('audio only');
    }
    return parts.join(' · ');
  }

  factory YtdlpFormat.fromJson(Map<String, Object?> json) {
    final height = _parseInt(json['height']);
    final width = _parseInt(json['width']);
    final resolution = height > 0
        ? '${width > 0 ? width : '?'}x$height'
        : json['resolution']?.toString() ?? '';
    final formatId = json['format_id']?.toString() ?? '';
    final ext = json['ext']?.toString() ?? '';
    final note = json['format_note']?.toString() ?? '';
    var vcodec = _codecOrNone(json['vcodec']);
    var acodec = _codecOrNone(json['acodec']);
    final hasUrl = (json['url']?.toString() ?? '').trim().isNotEmpty;

    // Facebook (and some other extractors) emit progressive mp4 entries without
    // vcodec/acodec. Treat those as combined so they appear in the picker.
    if (vcodec == 'none' && acodec == 'none') {
      final lowerExt = ext.toLowerCase();
      if (lowerExt == 'm4a' ||
          lowerExt == 'mp3' ||
          lowerExt == 'aac' ||
          lowerExt == 'opus' ||
          lowerExt == 'ogg') {
        acodec = 'unknown';
      } else if (_isLikelyProgressiveMuxed(
        ext: ext,
        formatId: formatId,
        note: note,
        hasUrl: hasUrl,
      )) {
        vcodec = 'unknown';
        acodec = 'unknown';
      }
    }

    return YtdlpFormat(
      formatId: formatId,
      ext: ext,
      resolution: resolution,
      note: note,
      fileSize: _parseNullableInt(json['filesize'] ?? json['filesize_approx']),
      vcodec: vcodec,
      acodec: acodec,
      format: json['format']?.toString() ?? '',
    );
  }

  static String _codecOrNone(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return 'none';
    return text;
  }

  static bool _isLikelyProgressiveMuxed({
    required String ext,
    required String formatId,
    required String note,
    required bool hasUrl,
  }) {
    final lowerExt = ext.toLowerCase();
    if (lowerExt == 'mp4' ||
        lowerExt == 'mov' ||
        lowerExt == 'webm' ||
        lowerExt == 'mkv') {
      return true;
    }
    final id = formatId.toLowerCase();
    if (id == 'hd' || id == 'sd' || id == 'http-hd' || id == 'http-sd') {
      return true;
    }
    final lowerNote = note.toLowerCase();
    if (lowerNote.contains('progressive') ||
        lowerNote == 'hd' ||
        lowerNote == 'sd') {
      return true;
    }
    return hasUrl && lowerExt.isNotEmpty && lowerExt != 'mhtml';
  }
}

class YtdlpVideoInfo {
  const YtdlpVideoInfo({
    required this.id,
    required this.title,
    required this.duration,
    required this.formats,
  });

  final String id;
  final String title;
  final int duration;
  final List<YtdlpFormat> formats;

  factory YtdlpVideoInfo.fromJson(Map<String, Object?> json) {
    final formatsJson = json['formats'];
    final formats = formatsJson is List
        ? formatsJson
              .whereType<Map>()
              .map((item) => YtdlpFormat.fromJson(item.cast<String, Object?>()))
              .where((format) => format.formatId.isNotEmpty)
              .toList()
        : const <YtdlpFormat>[];

    return YtdlpVideoInfo(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      duration: _parseInt(json['duration']),
      formats: formats,
    );
  }

  List<YtdlpFormat> selectableFormats() {
    final combined = formats.where((f) => f.isCombined).toList();
    final videoOnly = formats.where((f) => f.hasVideo && !f.hasAudio).toList();
    final audioOnly = formats.where((f) => f.hasAudio && !f.hasVideo).toList();

    combined.sort(_compareFormats);
    videoOnly.sort(_compareFormats);
    audioOnly.sort(_compareFormats);

    final result = <YtdlpFormat>[...combined];

    for (final video in videoOnly.take(6)) {
      final bestAudio = _bestAudioForMerge(audioOnly);
      if (bestAudio == null) continue;
      result.add(
        YtdlpFormat(
          formatId: '${video.formatId}+${bestAudio.formatId}',
          ext: 'mp4',
          resolution: video.resolution,
          note: '${video.note} + ${bestAudio.note}'.trim(),
          fileSize: _sumSizes(video.fileSize, bestAudio.fileSize),
          vcodec: video.vcodec,
          acodec: bestAudio.acodec,
          format: '${video.format} + ${bestAudio.format}',
        ),
      );
    }

    result.addAll(audioOnly.take(4));
    final deduped = _dedupeEquivalentFormats(_dedupeByFormatId(result));
    if (deduped.isNotEmpty) return deduped;

    // Last resort: show raw entries so Facebook-style metadata still works.
    final fallback = formats.where((f) => f.formatId.isNotEmpty).toList()
      ..sort(_compareFormats);
    return _dedupeEquivalentFormats(_dedupeByFormatId(fallback));
  }

  String? defaultFormatId(YoutubeFormatPreset preset) {
    final selectable = selectableFormats();
    if (selectable.isEmpty) return null;
    return switch (preset) {
      YoutubeFormatPreset.bestMp4 => _pickBestMp4(selectable),
      YoutubeFormatPreset.bestQuality => selectable.first.formatId,
      YoutubeFormatPreset.audioOnly => _pickAudioOnly(selectable),
    };
  }
}

class YtdlpPlaylistEntry {
  const YtdlpPlaylistEntry({
    required this.id,
    required this.title,
    required this.url,
  });

  final String id;
  final String title;
  final String url;

  factory YtdlpPlaylistEntry.fromJson(Map<String, Object?> json) {
    final id = json['id']?.toString() ?? '';
    final url = json['url']?.toString() ??
        json['webpage_url']?.toString() ??
        (id.isEmpty ? '' : 'https://www.youtube.com/watch?v=$id');
    return YtdlpPlaylistEntry(
      id: id,
      title: json['title']?.toString() ?? 'Untitled',
      url: url,
    );
  }
}

class YtdlpPlaylistInfo {
  const YtdlpPlaylistInfo({
    required this.id,
    required this.title,
    required this.entries,
  });

  final String id;
  final String title;
  final List<YtdlpPlaylistEntry> entries;

  factory YtdlpPlaylistInfo.fromJson(Map<String, Object?> json) {
    final entriesJson = json['entries'];
    final entries = <YtdlpPlaylistEntry>[];
    if (entriesJson is List) {
      for (final item in entriesJson) {
        if (item is! Map) continue;
        final entry = YtdlpPlaylistEntry.fromJson(item.cast<String, Object?>());
        if (entry.id.isEmpty && entry.url.isEmpty) continue;
        entries.add(entry);
      }
    }

    return YtdlpPlaylistInfo(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Playlist',
      entries: entries,
    );
  }
}

enum YoutubeFormatPreset { bestMp4, bestQuality, audioOnly }

String presetStorageKey(YoutubeFormatPreset preset) {
  return switch (preset) {
    YoutubeFormatPreset.bestMp4 => 'best_mp4',
    YoutubeFormatPreset.bestQuality => 'best',
    YoutubeFormatPreset.audioOnly => 'audio_only',
  };
}

YoutubeFormatPreset presetFromStorage(String? value) {
  return switch (value) {
    'best' => YoutubeFormatPreset.bestQuality,
    'audio_only' => YoutubeFormatPreset.audioOnly,
    _ => YoutubeFormatPreset.bestMp4,
  };
}

int _compareFormats(YtdlpFormat a, YtdlpFormat b) {
  final heightA = _heightFromResolution(a.resolution);
  final heightB = _heightFromResolution(b.resolution);
  if (heightA != heightB) return heightB.compareTo(heightA);
  return (b.fileSize ?? 0).compareTo(a.fileSize ?? 0);
}

int _heightFromResolution(String resolution) {
  final match = RegExp(r'(\d+)x(\d+)').firstMatch(resolution);
  if (match == null) return 0;
  return int.tryParse(match.group(2) ?? '') ?? 0;
}

YtdlpFormat? _bestAudioForMerge(List<YtdlpFormat> audioOnly) {
  if (audioOnly.isEmpty) return null;
  return audioOnly.reduce((a, b) {
    final aSize = a.fileSize ?? 0;
    final bSize = b.fileSize ?? 0;
    return bSize > aSize ? b : a;
  });
}

int? _sumSizes(int? a, int? b) {
  if (a == null && b == null) return null;
  return (a ?? 0) + (b ?? 0);
}

List<YtdlpFormat> _dedupeByFormatId(List<YtdlpFormat> formats) {
  final seen = <String>{};
  final result = <YtdlpFormat>[];
  for (final format in formats) {
    if (seen.add(format.formatId)) {
      result.add(format);
    }
  }
  return result;
}

/// Collapses TikTok-style `-0`/`-1` twins that share the same picker label.
List<YtdlpFormat> _dedupeEquivalentFormats(List<YtdlpFormat> formats) {
  final seen = <String>{};
  final result = <YtdlpFormat>[];
  for (final format in formats) {
    final key = [
      format.resolution,
      format.ext.toLowerCase(),
      '${format.fileSize ?? 0}',
      format.vcodec,
      format.acodec,
      format.note.toLowerCase(),
      format.hasVideo ? 'v' : '',
      format.hasAudio ? 'a' : '',
    ].join('|');
    if (seen.add(key)) {
      result.add(format);
    }
  }
  return result;
}

String _pickBestMp4(List<YtdlpFormat> formats) {
  final mp4 = formats.where((f) => f.ext == 'mp4' && f.isCombined);
  if (mp4.isNotEmpty) return mp4.first.formatId;
  final merged = formats.where((f) => f.ext == 'mp4' && f.formatId.contains('+'));
  if (merged.isNotEmpty) return merged.first.formatId;
  return formats.first.formatId;
}

String _pickAudioOnly(List<YtdlpFormat> formats) {
  final audio = formats.where((f) => f.hasAudio && !f.hasVideo);
  if (audio.isNotEmpty) return audio.first.formatId;
  return formats.last.formatId;
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _parseNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}
