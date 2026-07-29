class AppUpdateConfig {
  const AppUpdateConfig._();

  static const String githubRepo = 'geonodecom/geonode-download-manager';

  /// Minimum interval between automatic background checks.
  static const Duration backgroundCheckInterval = Duration(hours: 24);
}
