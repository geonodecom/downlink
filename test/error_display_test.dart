import 'package:downlink/src/data/app_database.dart';
import 'package:downlink/src/utils/error_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('aria2ErrorLabel', () {
    test('returns label for known code', () {
      expect(aria2ErrorLabel(3), 'File not found');
      expect(aria2ErrorLabel(9), 'Disk full');
      expect(aria2ErrorLabel(22), 'Server response error');
    });

    test('returns null for unknown code', () {
      expect(aria2ErrorLabel(99), null);
      expect(aria2ErrorLabel(0), null);
    });

    test('returns null for null code', () {
      expect(aria2ErrorLabel(null), null);
    });
  });

  group('errorIsRetryable', () {
    test('timeout and network errors are retryable', () {
      expect(errorIsRetryable(_fakeDownload(aria2ErrorCode: 2)), isTrue);
      expect(errorIsRetryable(_fakeDownload(aria2ErrorCode: 6)), isTrue);
    });

    test('disk-full and i/o errors are not retryable', () {
      expect(errorIsRetryable(_fakeDownload(aria2ErrorCode: 9)), isFalse);
      expect(errorIsRetryable(_fakeDownload(aria2ErrorCode: 18)), isFalse);
    });

    test('no error code but has raw error string is retryable', () {
      expect(
        errorIsRetryable(_fakeDownload(error: 'Connection refused')),
        isTrue,
      );
    });

    test('no error code, no error string, status=error is retryable', () {
      expect(errorIsRetryable(_fakeDownload(status: 'error')), isTrue);
    });

    test('no error code, active status is not retryable', () {
      expect(errorIsRetryable(_fakeDownload(status: 'active')), isFalse);
    });
  });

  group('friendlyErrorSummary', () {
    test('prefers raw engine message over aria2 code label', () {
      expect(
        friendlyErrorSummary(
          _fakeDownload(
            aria2ErrorCode: 1,
            error: 'ProcessException: Permission denied',
          ),
        ),
        'ProcessException: Permission denied',
      );
    });

    test('falls back to aria2 label when raw error is empty', () {
      expect(
        friendlyErrorSummary(_fakeDownload(aria2ErrorCode: 9, error: '')),
        'Disk full',
      );
      expect(
        friendlyErrorSummary(_fakeDownload(aria2ErrorCode: 3)),
        'File not found',
      );
    });
    test('maps banned client tracker messages', () {
      expect(
        friendlyErrorSummary(
          _fakeDownload(
            error:
                'Tracker returned failure reason: banned client',
          ),
        ),
        contains('banned client'),
      );
    });
  });
}

DownloadEntity _fakeDownload({
  int? aria2ErrorCode,
  String? error,
  String status = 'error',
}) {
  return DownloadEntity(
    id: 'test',
    gid: null,
    url: 'https://example.com',
    fileName: null,
    directory: '/tmp',
    status: status,
    queuePosition: 1,
    totalLength: 0,
    completedLength: 0,
    downloadSpeed: 0,
    uploadSpeed: 0,
    connections: 0,
    split: 16,
    pieceLength: 0,
    numPieces: 0,
    bitfield: null,
    aria2ErrorCode: aria2ErrorCode,
    error: error,
    source: 'manual',
    optionsJson: null,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    completedAt: null,
  );
}
