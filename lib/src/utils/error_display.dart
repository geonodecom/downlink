import '../data/app_database.dart';

const _errorLabels = <int, String>{
  1: 'Unknown error',
  2: 'Connection timed out',
  3: 'File not found',
  4: 'File not found',
  5: 'Download too slow',
  6: 'Network error',
  7: 'Incomplete download',
  8: 'Resume not supported',
  9: 'Disk full',
  10: 'Piece length mismatch',
  11: 'Duplicate info hash',
  12: 'Duplicate download',
  13: 'Duplicate file',
  14: 'File verification failed',
  15: 'Cannot create directory',
  16: 'Cannot open file',
  17: 'Cannot allocate file',
  18: 'File I/O error',
  19: 'Cannot create directory',
  20: 'Name resolution failed',
  21: 'Invalid metalink file',
  22: 'Server response error',
  23: 'Bad HTTP header',
  24: 'Redirect error',
  25: 'Authorization failed',
  26: 'Invalid torrent file',
  27: 'Corrupt torrent file',
  28: 'Invalid magnet URI',
  29: 'Bad option value',
  30: 'Cannot write to temp file',
  31: 'Invalid content-disposition',
  32: 'Checksum mismatch',
};

String? aria2ErrorLabel(int? errorCode) {
  if (errorCode == null) return null;
  return _errorLabels[errorCode];
}

String? friendlyErrorSummary(DownloadEntity download) {
  final raw = download.error?.trim();
  if (raw != null && raw.isNotEmpty) {
    final lower = raw.toLowerCase();
    if (lower.contains('banned client')) {
      return 'Tracker rejected this client (banned client). '
          'Restart Downlink so torrent client identity is refreshed, then retry.';
    }
    if (lower.contains('tracker returned failure')) {
      return 'Tracker rejected the announce. Check your passkey / account, then retry.';
    }
    return raw;
  }

  final label = aria2ErrorLabel(download.aria2ErrorCode);
  if (label != null) return label;
  return null;
}

bool errorIsRetryable(DownloadEntity download) {
  final code = download.aria2ErrorCode;
  if (code == null) {
    // If we only have a raw error string (e.g. from probe / local failure),
    // assume retry may help.
    if (download.error != null && download.error!.trim().isNotEmpty) {
      return true;
    }
    // A failed download with no error details at all. Probably still worth
    // telling the user they can retry.
    if (download.status == 'error') return true;
    return false;
  }
  // These usually need a user action before retrying can help.
  const permanent = {
    9, // disk full
    13, // duplicate file
    14, // file verification failed
    15, // cannot create directory
    16, // cannot open file
    17, // cannot allocate file
    18, // file I/O error
    19, // cannot create directory (dup)
    21, // invalid metalink
    25, // authorization failed
    26, // invalid torrent
    27, // corrupt torrent
    28, // invalid magnet
    29, // bad option
    31, // invalid content-disposition
    32, // checksum mismatch
  };
  return !permanent.contains(code);
}
