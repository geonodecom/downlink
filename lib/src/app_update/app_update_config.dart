class AppUpdateConfig {
  const AppUpdateConfig._();

  static const String githubRepo = 'geonodecom/downlink';

  /// Minimum interval between automatic background checks.
  static const Duration backgroundCheckInterval = Duration(hours: 24);
}
