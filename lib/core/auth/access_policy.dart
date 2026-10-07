import '../../models/app_notification.dart';
import '../../models/user.dart';
import '../routes/app_routes.dart';

/// Role-based authorization — the single source of truth for which named
/// routes each role may open, which bottom-navigation set its shell shows
/// and where it lands after sign-in.
///
/// Students keep the whole protected catalogue apart from staff dashboards;
/// staff accounts only ever see [common] plus their own duty pages, so a
/// security login can never surface student options (and vice versa).
abstract final class AccessPolicy {
  /// Destinations every signed-in role shares: notifications, account
  /// management, search and the safety screens.
  static const Set<String> common = <String>{
    Routes.alerts,
    Routes.profile,
    Routes.search,
    Routes.settings,
    Routes.help,
    Routes.about,
    Routes.privacy,
    Routes.loginActivity,
    Routes.editProfile,
    Routes.emergency,
    Routes.reportIncident,
    Routes.scanner,
  };

  /// Staff destinations no student may open.
  static const Set<String> staffOnly = <String>{
    Routes.security,
    Routes.warden,
    Routes.admin,
    Routes.announcements,
    Routes.auditLog,
  };

  static const Set<String> _security = <String>{Routes.security};

  /// The warden reviews gate and visitor requests and handles hostel life,
  /// so those student screens double as staff tools for this role.
  static const Set<String> _warden = <String>{
    Routes.warden,
    Routes.gatePass,
    Routes.visitorPass,
    Routes.hostel,
    Routes.complaints,
  };

  static const Set<String> _admin = <String>{
    Routes.admin,
    Routes.announcements,
    Routes.auditLog,
  };

  /// Whether [role] may open the protected destination [route].
  static bool allows(UserRole role, String route) => switch (role) {
    UserRole.student => !staffOnly.contains(route),
    UserRole.security => common.contains(route) || _security.contains(route),
    UserRole.warden => common.contains(route) || _warden.contains(route),
    UserRole.admin => common.contains(route) || _admin.contains(route),
  };

  /// Alert categories each role subscribes to on the Alerts screen.
  ///
  /// A security officer works the gate and the incident desk, so only
  /// security and system-wide notices belong on their list — academic,
  /// events, hostel and transport chatter stays with the other roles.
  static bool seesAlertCategory(UserRole role, NotificationCategory category) =>
      switch (role) {
        UserRole.security =>
          category == NotificationCategory.security ||
              category == NotificationCategory.system,
        _ => true,
      };

  /// Landing destination after sign-in or a restored session.
  static String homeRouteFor(UserRole? role) => switch (role) {
    UserRole.security => Routes.security,
    UserRole.warden => Routes.warden,
    UserRole.admin => Routes.admin,
    _ => Routes.dashboard,
  };
}
