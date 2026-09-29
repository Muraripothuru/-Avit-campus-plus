/// Application-wide constants.
///
/// No secrets are stored here. Anything sensitive is injected at build time
/// via `--dart-define` (see `AppConfig`).
abstract final class AppConstants {
  static const String appName = 'AVIT Campus+';
  static const String universityName = 'Aarupadai Veedu Institute of Technology';
  static const String universityShort = 'AVIT';
  static const String tagline = 'Your Campus. Your Community. Your Safety.';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  static const String supportEmail = 'campusplus@avit.ac.in';
  static const String securityDesk = '+91 44 4747 2300';
  static const String emergencyNumber = '112';
  static const String institutionalEmailDomain = 'avit.ac.in';

  /// Session policy.
  static const Duration accessTokenTtl = Duration(minutes: 30);
  static const Duration refreshTokenTtl = Duration(days: 7);
  static const Duration otpTtl = Duration(minutes: 5);
  static const Duration otpCooldown = Duration(seconds: 30);

  /// Brute-force protection.
  static const int maxLoginAttempts = 5;
  static const Duration loginLockDuration = Duration(minutes: 15);
  static const int maxOtpAttempts = 5;

  /// Data refresh cadence for live screens.
  static const Duration softRefreshInterval = Duration(seconds: 45);
}

/// Build-time configuration.
///
/// Values are supplied with e.g.
/// `flutter run --dart-define=API_BASE_URL=https://api.avit.ac.in/v1`.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String apiPublicKey = String.fromEnvironment('API_PUBLIC_KEY');
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');

  static bool get hasLiveBackend => apiBaseUrl.isNotEmpty;
  static bool get isProduction => environment == 'production';
}

/// Shared demo (development only) account identifiers.
///
/// These accounts exist only while [AppConfig.hasLiveBackend] is false.
abstract final class DemoAccounts {
  static const String studentId = 'AVIT2026CS001';
  static const String securityId = 'AVITSEC001';
  static const String wardenId = 'AVITWRD001';
  static const String adminId = 'AVITADM001';
  static const String password = 'Avit@2026Demo';
  static const List<(String, String)> credentials = [
    (studentId, password),
    (securityId, password),
    (wardenId, password),
    (adminId, password),
  ];
}
