/// Central registry of named routes.
///
/// Authenticated routes are guarded by `AuthGuard` in `onGenerateRoute`;
/// unauthenticated users can never construct a protected screen.
abstract final class Routes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String otp = '/otp';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // Bottom navigation sections
  static const String dashboard = '/dashboard';
  static const String campus = '/campus';
  static const String activities = '/activities';
  static const String alerts = '/alerts';
  static const String profile = '/profile';

  // Academic
  static const String academics = '/academics';
  static const String timetable = '/timetable';
  static const String attendance = '/attendance';
  static const String courses = '/courses';
  static const String examinations = '/examinations';
  static const String academicCalendar = '/academic-calendar';

  // Campus services
  static const String gatePass = '/gate-pass';
  static const String serviceRequest = '/service-request';

  /// Service details is pushed directly (it needs the selected
  /// `ServiceEntry`), so it is never resolved from a name — but it stays in
  /// [protected] so an accidental deep link can never expose it unsigned.
  static const String serviceDetail = '/service-detail';
  static const String transport = '/transport';
  static const String visitorPass = '/visitor-pass';
  static const String smartQueue = '/smart-queue';
  static const String campusMap = '/campus-map';
  static const String library = '/library';
  static const String cafeteria = '/cafeteria';
  static const String hostel = '/hostel';
  static const String lostFound = '/lost-found';
  static const String healthCentre = '/health-centre';

  // Discovery
  static const String search = '/search';

  // Safety
  static const String emergency = '/emergency';
  static const String reportIncident = '/report-incident';
  static const String complaints = '/complaints';
  static const String scanner = '/scanner';

  // Staff
  static const String security = '/security';
  static const String warden = '/warden';
  static const String admin = '/admin';
  static const String announcements = '/announcements';
  static const String auditLog = '/audit-log';

  // Account
  static const String settings = '/settings';
  static const String help = '/help';
  static const String about = '/about';
  static const String privacy = '/privacy';
  static const String loginActivity = '/login-activity';
  static const String editProfile = '/edit-profile';

  /// Routes that require an authenticated session.
  static const Set<String> protected = <String>{
    dashboard,
    campus,
    activities,
    alerts,
    profile,
    academics,
    timetable,
    attendance,
    courses,
    examinations,
    academicCalendar,
    gatePass,
    serviceRequest,
    serviceDetail,
    transport,
    visitorPass,
    smartQueue,
    campusMap,
    library,
    cafeteria,
    hostel,
    lostFound,
    healthCentre,
    search,
    emergency,
    reportIncident,
    complaints,
    scanner,
    security,
    warden,
    admin,
    announcements,
    auditLog,
    settings,
    help,
    about,
    privacy,
    loginActivity,
    editProfile,
  };
}
