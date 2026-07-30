class UpdateOffer {
  const UpdateOffer({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.fileName,
    required this.expectedSize,
  });

  final String version;
  final String releaseNotes;
  final String downloadUrl;
  final String fileName;
  final int expectedSize;
}

class AppUpdateProgress {
  const AppUpdateProgress({required this.received, this.total});

  final int received;
  final int? total;

  double? get fraction {
    if (total == null || total! <= 0) return null;
    return received / total!;
  }
}
