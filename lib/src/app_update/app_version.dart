class Semver {
  const Semver(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  @override
  bool operator ==(Object other) {
    return other is Semver &&
        major == other.major &&
        minor == other.minor &&
        patch == other.patch;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch);

  static Semver? parseReleaseTag(String tag) {
    final trimmed = tag.trim();
    final withoutV =
        trimmed.startsWith('v') ? trimmed.substring(1) : trimmed;
    final core = withoutV.split('+').first;
    final parts = core.split('.');
    if (parts.length < 3) return null;
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = int.tryParse(parts[2]);
    if (major == null || minor == null || patch == null) return null;
    return Semver(major, minor, patch);
  }

  static Semver? parseAppVersion(String version) {
    final core = version.trim().split('+').first;
    return parseReleaseTag(core);
  }

  bool isGreaterThan(Semver other) {
    if (major != other.major) return major > other.major;
    if (minor != other.minor) return minor > other.minor;
    return patch > other.patch;
  }
}

bool isNewerRelease(String currentVersion, String releaseVersion) {
  final current = Semver.parseAppVersion(currentVersion);
  final release = Semver.parseReleaseTag(releaseVersion);
  if (current == null || release == null) return false;
  return release.isGreaterThan(current);
}
