import 'dart:convert';

/// Seeding policy for BitTorrent downloads.
enum TorrentSeedMode {
  stop,
  ratio,
  time;

  static TorrentSeedMode parse(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'ratio' => TorrentSeedMode.ratio,
      'time' => TorrentSeedMode.time,
      _ => TorrentSeedMode.stop,
    };
  }

  String get storageValue => name;
}

class TorrentDownloadOptions {
  const TorrentDownloadOptions({
    required this.kind,
    this.torrentPath = '',
    this.seedMode = TorrentSeedMode.stop,
    this.seedRatio = 1.0,
    this.seedTimeMinutes = 60,
  });

  static const kindMagnet = 'magnet';
  static const kindTorrent = 'torrent';

  /// Either [kindMagnet] or [kindTorrent].
  final String kind;
  final String torrentPath;
  final TorrentSeedMode seedMode;
  final double seedRatio;
  final int seedTimeMinutes;

  bool get isMagnet => kind == kindMagnet;
  bool get isTorrentFile => kind == kindTorrent;

  Map<String, Object?> toJson() {
    return {
      'kind': kind,
      if (torrentPath.isNotEmpty) 'torrentPath': torrentPath,
      'seedMode': seedMode.storageValue,
      'seedRatio': seedRatio,
      'seedTimeMinutes': seedTimeMinutes,
    };
  }

  factory TorrentDownloadOptions.fromJson(Map<String, Object?> json) {
    final kind = json['kind']?.toString() ?? kindMagnet;
    return TorrentDownloadOptions(
      kind: kind == kindTorrent ? kindTorrent : kindMagnet,
      torrentPath: json['torrentPath']?.toString() ?? '',
      seedMode: TorrentSeedMode.parse(json['seedMode']?.toString()),
      seedRatio: _parseDouble(json['seedRatio'], 1.0),
      seedTimeMinutes: _parseInt(json['seedTimeMinutes'], 60),
    );
  }

  /// aria2 per-download options for seeding behavior.
  Map<String, String> toAria2SeedOptions() {
    return switch (seedMode) {
      TorrentSeedMode.stop => {
          'seed-time': '0',
          'seed-ratio': '0.0',
        },
      TorrentSeedMode.ratio => {
          'seed-ratio': seedRatio.toString(),
        },
      TorrentSeedMode.time => {
          'seed-time': seedTimeMinutes.clamp(1, 10080).toString(),
          'seed-ratio': '0.0',
        },
    };
  }

  static double _parseDouble(Object? value, double fallback) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _parseInt(Object? value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

TorrentDownloadOptions? torrentOptionsFromJson(String? optionsJson) {
  if (optionsJson == null || optionsJson.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(optionsJson);
    if (decoded is! Map) return null;
    final map = decoded.cast<String, Object?>();
    final kind = map['kind']?.toString();
    if (kind != TorrentDownloadOptions.kindMagnet &&
        kind != TorrentDownloadOptions.kindTorrent) {
      return null;
    }
    return TorrentDownloadOptions.fromJson(map);
  } catch (_) {
    return null;
  }
}

bool isTorrentDownloadOptions(String? optionsJson) {
  return torrentOptionsFromJson(optionsJson) != null;
}

TorrentDownloadOptions? torrentOptionsFromMap(Map<String, Object?>? map) {
  if (map == null) return null;
  final kind = map['kind']?.toString();
  if (kind != TorrentDownloadOptions.kindMagnet &&
      kind != TorrentDownloadOptions.kindTorrent) {
    return null;
  }
  return TorrentDownloadOptions.fromJson(map);
}
