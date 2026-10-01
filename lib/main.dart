import 'package:flutter/material.dart';

import 'app/app_scope.dart';
import 'app/app_state.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/academics/academic_calendar_screen.dart';
import 'features/academics/academics_screen.dart';
import 'features/academics/attendance_screen.dart';
import 'features/academics/courses_screen.dart';
import 'features/academics/exams_screen.dart';
import 'features/academics/timetable_screen.dart';
import 'features/account/about_screen.dart';
import 'features/account/help_screen.dart';
import 'features/account/login_activity_screen.dart';
import 'features/account/privacy_screen.dart';
import 'features/account/settings_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/campus_services/cafeteria_screen.dart';
import 'features/campus_services/campus_map_screen.dart';
import 'features/campus_services/gate_pass_screen.dart';
import 'features/campus_services/health_centre_screen.dart';
import 'features/campus_services/hostel_screen.dart';
import 'features/campus_services/library_screen.dart';
import 'features/campus_services/lost_found_screen.dart';
import 'features/campus_services/smart_queue_screen.dart';
import 'features/campus_services/service_request_screen.dart';
import 'features/campus_services/transport_screen.dart';
import 'features/campus_services/visitor_pass_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/safety/complaints_screen.dart';
import 'features/safety/emergency_screen.dart';
import 'features/safety/report_incident_screen.dart';
import 'features/safety/scanner_screen.dart';
import 'features/search/search_screen.dart';
import 'features/staff/admin_dashboard_screen.dart';
import 'features/staff/announcements_screen.dart';
import 'features/staff/audit_log_screen.dart';
import 'features/staff/security_dashboard_screen.dart';
import 'features/staff/warden_dashboard_screen.dart';
import 'models/user.dart';
import 'navigation/app_shell.dart';

/// Composition root and entry point.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final AppDependencies deps = AppDependencies();
  final AppState state = AppState(deps);

  runApp(AvitCampusPlus(state: state));
}

/// Root widget: owns [AppScope], the theme mode and the route generator.
class AvitCampusPlus extends StatefulWidget {
  const AvitCampusPlus({super.key, required this.state});

  final AppState state;

  @override
  State<AvitCampusPlus> createState() => _AvitCampusPlusState();
}

class _AvitCampusPlusState extends State<AvitCampusPlus> {
  AppState get _state => widget.state;

  /// Role gates for staff-only destinations.
  bool _hasRole(String route, AppUser? user) {
    if (user == null) return false;
    return switch (route) {
      Routes.security =>
        user.role == UserRole.security || user.role == UserRole.admin,
      Routes.reportIncident =>
        user.role == UserRole.security || user.role == UserRole.admin,
      Routes.warden =>
        user.role == UserRole.warden || user.role == UserRole.admin,
      Routes.admin ||
      Routes.announcements ||
      Routes.auditLog =>
        user.role == UserRole.admin,
      _ => true,
    };
  }

  Widget _shellFor(RouteSettings settings) => AppShell(
    initialIndex: AppShell.tabIndexForRoute(settings.name ?? Routes.dashboard),
  );

  Route<dynamic> _build(RouteSettings settings, Widget screen) =>
      MaterialPageRoute<dynamic>(
        settings: settings,
        builder: (_) => screen,
      );

  /// Auth + role guard, then the concrete screen for [settings.name].
  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final String name = settings.name ?? Routes.splash;
    final AppUser? user = _state.user;

    // Protected destinations require a session.
    if (Routes.protected.contains(name) && user == null) {
      return _build(
        RouteSettings(name: Routes.login, arguments: settings.arguments),
        const LoginScreen(),
      );
    }

    // Authenticated but not allowed for this role.
    if (Routes.protected.contains(name) && !_hasRole(name, user)) {
      return _build(settings, _AccessDeniedScreen(routeName: name));
    }

    final Widget screen = switch (name) {
      // Authentication
      Routes.splash => const SplashScreen(),
      Routes.welcome => const WelcomeScreen(),
      Routes.login => const LoginScreen(),
      Routes.signup => const SignUpScreen(),
      Routes.otp => settings.arguments is OtpArguments
          ? OtpScreen(arguments: settings.arguments! as OtpArguments)
          : const LoginScreen(),
      Routes.forgotPassword => const ForgotPasswordScreen(),
      Routes.resetPassword => const ForgotPasswordScreen(),

      // Bottom navigation sections
      Routes.dashboard ||
      Routes.campus ||
      Routes.activities ||
      Routes.alerts ||
      Routes.profile => _shellFor(settings),

      // Academics
      Routes.academics => const AcademicsScreen(),
      Routes.timetable => const TimetableScreen(),
      Routes.attendance => const AttendanceScreen(),
      Routes.courses => const CoursesScreen(),
      Routes.examinations => const ExamsScreen(),
      Routes.academicCalendar => const AcademicCalendarScreen(),

      // Campus services
      Routes.gatePass => const GatePassScreen(),
      Routes.serviceRequest => const ServiceRequestScreen(),
      Routes.transport => const TransportScreen(),
      Routes.visitorPass => const VisitorPassScreen(),
      Routes.smartQueue => const SmartQueueScreen(),
      Routes.campusMap => const CampusMapScreen(),
      Routes.library => const LibraryScreen(),
      Routes.cafeteria => const CafeteriaScreen(),
      Routes.hostel => const HostelScreen(),
      Routes.lostFound => const LostFoundScreen(),
      Routes.healthCentre => const HealthCentreScreen(),

      // Discovery
      Routes.search => const SearchScreen(),

      // Safety
      Routes.emergency => const EmergencyScreen(),
      Routes.reportIncident => const ReportIncidentScreen(),
      Routes.complaints => const ComplaintsScreen(),
      Routes.scanner => const ScannerScreen(),

      // Staff
      Routes.security => const SecurityDashboardScreen(),
      Routes.warden => const WardenDashboardScreen(),
      Routes.admin => const AdminDashboardScreen(),
      Routes.announcements => const AnnouncementsScreen(),
      Routes.auditLog => const AuditLogScreen(),

      // Account
      Routes.settings => const SettingsScreen(),
      Routes.help => const HelpScreen(),
      Routes.about => const AboutScreen(),
      Routes.privacy => const PrivacyScreen(),
      Routes.loginActivity => const LoginActivityScreen(),
      Routes.editProfile => const EditProfileScreen(),

      _ => const WelcomeScreen(),
    };

    return _build(settings, screen);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: ListenableBuilder(
        listenable: _state,
        builder: (BuildContext context, _) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          showPerformanceOverlay: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _state.themeMode,
          initialRoute: Routes.splash,
          onGenerateRoute: onGenerateRoute,
          onUnknownRoute: (RouteSettings settings) => _build(
            const RouteSettings(name: Routes.welcome),
            const WelcomeScreen(),
          ),
        ),
      ),
    );
  }
}

/// Shown when an authenticated user opens a route their role cannot access.
class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen({required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not available')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.lock_rounded,
                size: 56,
                color: AppColors.danger,
              ),
              const SizedBox(height: 16),
              Text(
                'Your role does not have access to this section.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                routeName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
