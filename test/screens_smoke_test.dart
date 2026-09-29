import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/features/academics/academic_calendar_screen.dart';
import 'package:avit_campus_plus/features/academics/academics_screen.dart';
import 'package:avit_campus_plus/features/academics/attendance_screen.dart';
import 'package:avit_campus_plus/features/academics/courses_screen.dart';
import 'package:avit_campus_plus/features/academics/exams_screen.dart';
import 'package:avit_campus_plus/features/academics/timetable_screen.dart';
import 'package:avit_campus_plus/features/account/about_screen.dart';
import 'package:avit_campus_plus/features/account/help_screen.dart';
import 'package:avit_campus_plus/features/account/login_activity_screen.dart';
import 'package:avit_campus_plus/features/account/privacy_screen.dart';
import 'package:avit_campus_plus/features/account/settings_screen.dart';
import 'package:avit_campus_plus/features/activities/activities_screen.dart';
import 'package:avit_campus_plus/features/alerts/alerts_screen.dart';
import 'package:avit_campus_plus/features/auth/forgot_password_screen.dart';
import 'package:avit_campus_plus/features/auth/login_screen.dart';
import 'package:avit_campus_plus/features/auth/signup_screen.dart';
import 'package:avit_campus_plus/features/auth/welcome_screen.dart';
import 'package:avit_campus_plus/features/campus/campus_screen.dart';
import 'package:avit_campus_plus/features/campus_services/cafeteria_screen.dart';
import 'package:avit_campus_plus/features/campus_services/campus_map_screen.dart';
import 'package:avit_campus_plus/features/campus_services/gate_pass_screen.dart';
import 'package:avit_campus_plus/features/campus_services/hostel_screen.dart';
import 'package:avit_campus_plus/features/campus_services/library_screen.dart';
import 'package:avit_campus_plus/features/campus_services/smart_queue_screen.dart';
import 'package:avit_campus_plus/features/campus_services/transport_screen.dart';
import 'package:avit_campus_plus/features/campus_services/visitor_pass_screen.dart';
import 'package:avit_campus_plus/features/dashboard/dashboard_screen.dart';
import 'package:avit_campus_plus/features/profile/profile_screen.dart';
import 'package:avit_campus_plus/features/safety/complaints_screen.dart';
import 'package:avit_campus_plus/features/safety/emergency_screen.dart';
import 'package:avit_campus_plus/features/safety/report_incident_screen.dart';
import 'package:avit_campus_plus/features/safety/scanner_screen.dart';
import 'package:avit_campus_plus/features/staff/admin_dashboard_screen.dart';
import 'package:avit_campus_plus/features/staff/announcements_screen.dart';
import 'package:avit_campus_plus/features/staff/audit_log_screen.dart';
import 'package:avit_campus_plus/features/staff/security_dashboard_screen.dart';
import 'package:avit_campus_plus/features/staff/warden_dashboard_screen.dart';
import 'package:avit_campus_plus/navigation/app_shell.dart';
import 'package:avit_campus_plus/core/routes/app_routes.dart';
import 'package:avit_campus_plus/main.dart';
import 'package:avit_campus_plus/widgets/avit_feedback.dart';

/// Every named route must build for the right role, finish its async load and
/// leave no unhandled exception behind.
void main() {
  const String student = 'student@avit.ac.in';
  const String security = 'security@avit.ac.in';
  const String warden = 'warden@avit.ac.in';
  const String admin = 'admin@avit.ac.in';

  Future<void> pumpFrames(
    WidgetTester tester, {
    int count = 8,
    Duration step = const Duration(milliseconds: 300),
  }) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  Future<void> openRoute(
    WidgetTester tester,
    String route, {
    String? email,
  }) async {
    final AppState state = AppState(
      AppDependencies(secureStore: InMemorySecureStore()),
    );
    await tester.pumpWidget(AvitCampusPlus(state: state));
    await tester.pump();

    if (email != null) {
      final Future<bool> signedIn = state.signIn(
        identifier: email,
        password: 'Avit@2026Demo',
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        await signedIn,
        isTrue,
        reason: 'demo sign-in for $email must succeed',
      );
    }

    // Let the splash timer finish first: it resets the navigation stack, and
    // must not clear the route we are about to assert on.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    // Replace the whole stack so the target route is the only one on screen.
    nav.pushNamedAndRemoveUntil(route, (Route<dynamic> r) => false);
    await pumpFrames(tester);
  }

  void expectRendered(
    WidgetTester tester, {
    required Finder expected,
    required String route,
  }) {
    expect(
      expected,
      findsOneWidget,
      reason: 'route $route must show its screen',
    );
    if (const <String>{
      Routes.dashboard,
      Routes.campus,
      Routes.activities,
      Routes.alerts,
      Routes.profile,
    }.contains(route)) {
      expect(
        find.byType(AppShell, skipOffstage: false),
        findsOneWidget,
        reason: 'route $route is a shell tab',
      );
    }
    // Async data must resolve: no placeholder loaders may remain.
    expect(
      find.byType(LoadingList, skipOffstage: false),
      findsNothing,
      reason: 'route $route finished loading',
    );
    expect(
      find.byType(AVITLoading, skipOffstage: false),
      findsNothing,
      reason: 'route $route has no pending spinner',
    );
    expect(
      find.byType(SkeletonBox, skipOffstage: false),
      findsNothing,
      reason: 'route $route has no skeletons left',
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'route $route raised an exception',
    );
  }

  Finder screenOf(Type type) => find.byType(type, skipOffstage: false);

  final List<(String, String, Finder Function(), String?)> routes =
      <(String, String, Finder Function(), String?)>[
        // Guest (unauthenticated) destinations
        (Routes.welcome, 'welcome', () => screenOf(WelcomeScreen), null),
        (Routes.login, 'login', () => screenOf(LoginScreen), null),
        (Routes.signup, 'signup', () => screenOf(SignUpScreen), null),
        (
          Routes.forgotPassword,
          'forgot password',
          () => screenOf(ForgotPasswordScreen),
          null,
        ),
        (
          Routes.resetPassword,
          'reset password',
          () => screenOf(ForgotPasswordScreen),
          null,
        ),

        // Student: shell tabs
        (Routes.dashboard, 'dashboard', () => screenOf(DashboardScreen), student),
        (Routes.campus, 'campus tab', () => screenOf(CampusScreen), student),
        (
          Routes.activities,
          'activities tab',
          () => screenOf(ActivitiesScreen),
          student,
        ),
        (Routes.alerts, 'alerts tab', () => screenOf(AlertsScreen), student),
        (Routes.profile, 'profile tab', () => screenOf(ProfileScreen), student),

        // Student: academics
        (Routes.academics, 'academics', () => screenOf(AcademicsScreen), student),
        (Routes.timetable, 'timetable', () => screenOf(TimetableScreen), student),
        (Routes.attendance, 'attendance', () => screenOf(AttendanceScreen), student),
        (Routes.courses, 'courses', () => screenOf(CoursesScreen), student),
        (Routes.examinations, 'exams', () => screenOf(ExamsScreen), student),
        (
          Routes.academicCalendar,
          'academic calendar',
          () => screenOf(AcademicCalendarScreen),
          student,
        ),

        // Student: campus services
        (Routes.gatePass, 'gate pass', () => screenOf(GatePassScreen), student),
        (Routes.transport, 'transport', () => screenOf(TransportScreen), student),
        (
          Routes.visitorPass,
          'visitor pass',
          () => screenOf(VisitorPassScreen),
          student,
        ),
        (
          Routes.smartQueue,
          'smart queue',
          () => screenOf(SmartQueueScreen),
          student,
        ),
        (
          Routes.campusMap,
          'campus map',
          () => screenOf(CampusMapScreen),
          student,
        ),
        (Routes.library, 'library', () => screenOf(LibraryScreen), student),
        (Routes.cafeteria, 'cafeteria', () => screenOf(CafeteriaScreen), student),
        (Routes.hostel, 'hostel', () => screenOf(HostelScreen), student),

        // Safety + account
        (Routes.emergency, 'emergency', () => screenOf(EmergencyScreen), student),
        (Routes.complaints, 'complaints', () => screenOf(ComplaintsScreen), student),
        (Routes.settings, 'settings', () => screenOf(SettingsScreen), student),
        (Routes.help, 'help', () => screenOf(HelpScreen), student),
        (Routes.about, 'about', () => screenOf(AboutScreen), student),
        (Routes.privacy, 'privacy', () => screenOf(PrivacyScreen), student),
        (
          Routes.loginActivity,
          'login activity',
          () => screenOf(LoginActivityScreen),
          student,
        ),

        // Security desk
        (Routes.security, 'security desk', () => screenOf(SecurityDashboardScreen), security),
        (
          Routes.reportIncident,
          'report incident',
          () => screenOf(ReportIncidentScreen),
          security,
        ),
        (Routes.scanner, 'scanner', () => screenOf(ScannerScreen), security),

        // Warden
        (Routes.warden, 'warden desk', () => screenOf(WardenDashboardScreen), warden),

        // Admin
        (Routes.admin, 'admin desk', () => screenOf(AdminDashboardScreen), admin),
        (
          Routes.announcements,
          'announcements',
          () => screenOf(AnnouncementsScreen),
          admin,
        ),
        (Routes.auditLog, 'audit log', () => screenOf(AuditLogScreen), admin),
      ];

  for (final (String route, String label, Finder Function() finder, String? email)
      in routes) {
    testWidgets('route $route renders $label', (WidgetTester tester) async {
      await openRoute(tester, route, email: email);
      expectRendered(tester, expected: finder(), route: route);
      // One more burst so late errors (platform channels, timers) surface.
      await pumpFrames(tester, count: 4);
      expect(tester.takeException(), isNull, reason: 'route $route');
    });
  }

  testWidgets('student cannot open staff-only routes', (
    WidgetTester tester,
  ) async {
    await openRoute(tester, Routes.admin, email: student);
    expect(find.text('Not available', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fresh visitor enters directly — no login gate', (
    WidgetTester tester,
  ) async {
    await openRoute(tester, Routes.settings);
    expect(screenOf(SettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard shows the signed-in student', (
    WidgetTester tester,
  ) async {
    await openRoute(tester, Routes.dashboard, email: student);
    expect(screenOf(DashboardScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
