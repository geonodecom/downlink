import '../data/app_database.dart';

class Aria2Endpoint {
  const Aria2Endpoint({
    required this.host,
    required this.port,
    required this.secret,
  });

  final String host;
  final int port;
  final String secret;
}

class Aria2File {
  const Aria2File({
    required this.path,
    required this.length,
    required this.completedLength,
    this.uris = const [],
  });

  final String path;
  final int length;
  final int completedLength;
  final List<String> uris;

  factory Aria2File.fromJson(Map<String, Object?> json) {
    final urisJson = json['uris'];
    return Aria2File(
      path: json['path']?.toString() ?? '',
      length: _parseInt(json['length']),
      completedLength: _parseInt(json['completedLength']),
      uris: urisJson is List
          ? urisJson
                .whereType<Map>()
                .map((item) => item['uri']?.toString())
                .whereType<String>()
                .toList()
          : const [],
    );
  }
}

class Aria2Status {
  const Aria2Status({
    required this.gid,
    required this.status,
    required this.totalLength,
    required this.completedLength,
    required this.downloadSpeed,
    this.uploadSpeed = 0,
    required this.connections,
    required this.pieceLength,
    required this.numPieces,
    required this.bitfield,
    required this.errorCode,
    required this.errorMessage,
    required this.files,
    this.numSeeders = 0,
    this.numPeers = 0,
  });

  final String gid;
  final String status;
  final int totalLength;
  final int completedLength;
  final int downloadSpeed;
  final int uploadSpeed;
  final int connections;
  final int pieceLength;
  final int numPieces;
  final String? bitfield;
  final int? errorCode;
  final String? errorMessage;
  final List<Aria2File> files;
  final int numSeeders;
  final int numPeers;

  bool get isSeeding {
    return status == 'active' &&
        totalLength > 0 &&
        completedLength >= totalLength &&
        uploadSpeed > 0;
  }

  String? get fileName {
    if (files.isEmpty || files.first.path.isEmpty) return null;
    final path = files.first.path.trim();
    if (path.isEmpty) return null;
    // Handle both Windows (\) and POSIX (/) separators from aria2 / yt-dlp.
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    final base = parts.isEmpty ? path : parts.last;
    return base.isEmpty ? null : base;
  }

  String? get sourceUrl {
    if (files.isEmpty || files.first.uris.isEmpty) return null;
    return files.first.uris.first;
  }

  factory Aria2Status.fromJson(Map<String, Object?> json) {
    final filesJson = json['files'];
    return Aria2Status(
      gid: json['gid']?.toString() ?? '',
      status: json['status']?.toString() ?? 'waiting',
      totalLength: _parseInt(json['totalLength']),
      completedLength: _parseInt(json['completedLength']),
      downloadSpeed: _parseInt(json['downloadSpeed']),
      uploadSpeed: _parseInt(json['uploadSpeed']),
      connections: _parseInt(json['connections']),
      pieceLength: _parseInt(json['pieceLength']),
      numPieces: _parseInt(json['numPieces']),
      bitfield: json['bitfield']?.toString(),
      errorCode: _parseNullableInt(json['errorCode']),
      errorMessage: json['errorMessage']?.toString(),
      files: filesJson is List
          ? filesJson
                .whereType<Map>()
                .map((item) => Aria2File.fromJson(item.cast<String, Object?>()))
                .toList()
          : const [],
      numSeeders: _parseInt(json['numSeeders']),
      numPeers: _parseInt(json['numPeers']),
    );
  }

  DownloadStatus toDownloadStatus() {
    return switch (status) {
      'active' => DownloadStatus.active,
      'waiting' => DownloadStatus.queued,
      'paused' => DownloadStatus.paused,
      'complete' => DownloadStatus.completed,
      'stopped' => DownloadStatus.completed,
      'error' => DownloadStatus.error,
      'removed' => DownloadStatus.removed,
      _ => DownloadStatus.queued,
    };
  }
}

class PieceInfo {
  const PieceInfo({required this.index, required this.complete});

  final int index;
  final bool complete;
}

List<PieceInfo> piecesFromBitfield(String? bitfield, int numPieces) {
  if (bitfield == null || bitfield.isEmpty || numPieces <= 0) return const [];
  final pieces = <PieceInfo>[];
  for (final char in bitfield.split('')) {
    final value = int.tryParse(char, radix: 16) ?? 0;
    for (var bit = 3; bit >= 0 && pieces.length < numPieces; bit--) {
      pieces.add(
        PieceInfo(index: pieces.length, complete: (value & (1 << bit)) != 0),
      );
    }
  }
  return pieces;
}

int _parseInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _parseNullableInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
