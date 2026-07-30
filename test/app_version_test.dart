import 'package:flutter_test/flutter_test.dart';
import 'package:downlink/src/app_update/app_version.dart';

void main() {
  group('Semver', () {
    test('parses release tags', () {
      expect(Semver.parseReleaseTag('v1.2.3'), Semver(1, 2, 3));
      expect(Semver.parseReleaseTag('1.0.0'), Semver(1, 0, 0));
    });

    test('parses app versions with build suffix', () {
      expect(Semver.parseAppVersion('0.1.0+42'), Semver(0, 1, 0));
    });
  });

  group('isNewerRelease', () {
    test('detects newer patch', () {
      expect(isNewerRelease('0.1.0', '0.1.1'), isTrue);
    });

    test('detects newer minor', () {
      expect(isNewerRelease('0.1.9', '0.2.0'), isTrue);
    });

    test('same version is not newer', () {
      expect(isNewerRelease('1.0.0+5', '1.0.0'), isFalse);
    });

    test('older release is not newer', () {
      expect(isNewerRelease('2.0.0', '1.9.9'), isFalse);
    });
  });
}
