import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/features/alerts/alerts_screen.dart';
import 'package:avit_campus_plus/features/campus/campus_screen.dart';
import 'package:avit_campus_plus/features/campus_services/gate_pass_screen.dart';
import 'package:avit_campus_plus/features/dashboard/dashboard_screen.dart';
import 'package:avit_campus_plus/features/staff/admin_dashboard_screen.dart';
import 'package:avit_campus_plus/features/staff/security_dashboard_screen.dart';
import 'package:avit_campus_plus/features/staff/warden_dashboard_screen.dart';
import 'package:avit_campus_plus/main.dart';
import 'package:avit_campus_plus/navigation/app_shell.dart';
import 'package:avit_campus_plus/widgets/avit_bottom_nav.dart';

/// Role-based authorization: each role lands on its own desk, the bottom
/// navigation only offers its tab set and cross-role routes are refused.
void main() {
  const String student = 'student@avit.ac.in';
  const String security = 'security@avit.ac.in';
  const String warden = 'warden@avit.ac.in';
  const String admin = 'admin@avit.ac.in';
  const String password = 'Avit@2026Demo';

  Future<void> pumpFrames(
    WidgetTester tester, {
    int count = 8,
    Duration step = const Duration(milliseconds: 300),
  }) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  /// Boots the app, signs [email] in and lets the splash land on the role's
  /// home route.
  Future<AppState> boot(WidgetTester tester, {required String email}) async {
    final AppState state = AppState(
      AppDependencies(secureStore: InMemorySecureStore()),
    );
    await tester.pumpWidget(AvitCampusPlus(state: state));
    await tester.pump();

    final Future<bool> signedIn = state.signIn(
      identifier: email,
      password: password,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(await signedIn, isTrue, reason: 'sign-in for $email');

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    await pumpFrames(tester, count: 12);
    return state;
  }

  Future<void> openRoute(
    WidgetTester tester,
    String route, {
    required String email,
  }) async {
    final AppState state = AppState(
      AppDependencies(secureStore: InMemorySecureStore()),
    );
    await tester.pumpWidget(AvitCampusPlus(state: state));
    await tester.pump();

    final Future<bool> signedIn = state.signIn(
      identifier: email,
      password: password,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(await signedIn, isTrue, reason: 'sign-in for $email');

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamedAndRemoveUntil(route, (Route<dynamic> r) => false);
    await pumpFrames(tester, count: 10);
  }

  Finder navLabel(String label) => find.descendant(
    of: find.byType(AVITBottomNavigation, skipOffstage: false),
    matching: find.text(label),
  );

  group('role landing and tab sets', () {
    testWidgets('security lands on the security desk, not the student home', (
      WidgetTester tester,
    ) async {
      final AppState state = await boot(tester, email: security);

      expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);
      expect(
        find.byType(SecurityDashboardScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byType(DashboardScreen, skipOffstage: false),
        findsNothing,
        reason: 'students only see their home tab',
      );
      expect(find.byType(CampusScreen, skipOffstage: false), findsNothing);
      expect(navLabel('Security'), findsOneWidget);
      expect(navLabel('Alerts'), findsOneWidget);
      expect(navLabel('Profile'), findsOneWidget);
      expect(navLabel('Campus'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(state.user?.email, security);
    });

    testWidgets('warden lands on the warden console with its own tabs', (
      WidgetTester tester,
    ) async {
      final AppState state = await boot(tester, email: warden);

      expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);
      expect(
        find.byType(WardenDashboardScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(DashboardScreen, skipOffstage: false), findsNothing);
      expect(navLabel('Warden'), findsOneWidget);
      expect(navLabel('Campus'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(state.user?.email, warden);
    });

    testWidgets('admin lands on administration with bulletins and audit', (
      WidgetTester tester,
    ) async {
      final AppState state = await boot(tester, email: admin);

      expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);
      expect(
        find.byType(AdminDashboardScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(DashboardScreen, skipOffstage: false), findsNothing);
      expect(navLabel('Admin'), findsOneWidget);
      expect(navLabel('Bulletins'), findsOneWidget);
      expect(navLabel('Audit'), findsOneWidget);
      expect(navLabel('Campus'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(state.user?.email, admin);
    });

    testWidgets('student keeps the campus bottom-navigation set', (
      WidgetTester tester,
    ) async {
      final AppState state = await boot(tester, email: student);

      expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);
      expect(find.byType(DashboardScreen, skipOffstage: false), findsOneWidget);
      expect(navLabel('Home'), findsOneWidget);
      expect(navLabel('Campus'), findsOneWidget);
      expect(navLabel('Activities'), findsOneWidget);
      expect(navLabel('Security'), findsNothing);
      expect(navLabel('Admin'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(state.user?.email, student);
    });
  });

  group('cross-role routes are refused', () {
    testWidgets('student cannot open the security desk', (
      WidgetTester tester,
    ) async {
      await openRoute(tester, '/security', email: student);
      expect(find.text('Not available', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('security cannot open the student dashboard', (
      WidgetTester tester,
    ) async {
      await openRoute(tester, '/dashboard', email: security);
      expect(find.text('Not available', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('security cannot open the timetable', (
      WidgetTester tester,
    ) async {
      await openRoute(tester, '/timetable', email: security);
      expect(find.text('Not available', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('warden cannot open the service request form', (
      WidgetTester tester,
    ) async {
      await openRoute(tester, '/service-request', email: warden);
      expect(find.text('Not available', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('admin cannot open the student campus tab', (
      WidgetTester tester,
    ) async {
      await openRoute(tester, '/campus', email: admin);
      expect(find.text('Not available', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('security alerts are filtered', () {
    testWidgets('security only receives security and system alerts', (
      WidgetTester tester,
    ) async {
      await openRoute(tester, '/alerts', email: security);

      expect(find.byType(AlertsScreen, skipOffstage: false), findsOneWidget);
      expect(find.text('Gate pass approved'), findsOneWidget);
      expect(find.text('Password changed'), findsOneWidget);
      expect(find.text('Exam time table published'), findsNothing);
      expect(find.text('Hackathon registration closing soon'), findsNothing);
      expect(find.text('Academic'), findsNothing);
      expect(find.text('Hostel'), findsNothing);
      expect(find.text('Transport'), findsNothing);
      expect(find.text('Security'), findsWidgets);
      expect(find.text('System'), findsWidgets);

      // Announcements are duty notices only — no student bulletins. The
      // section sits below the fold, so scroll it into the viewport first.
      await tester.scrollUntilVisible(
        find.text('Main Gate restricted entry 10 PM - 5 AM'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(AlertsScreen, skipOffstage: false),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await pumpFrames(tester, count: 3);

      expect(
        find.text('Main Gate restricted entry 10 PM - 5 AM'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Emergency preparedness drill on Friday',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('End Semester Examination', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.textContaining('Hackathon', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.textContaining('Hostel Water Maintenance', skipOffstage: false),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening a security alert never reaches a student screen', (
      WidgetTester tester,
    ) async {
      await openRoute(tester, '/alerts', email: security);

      await tester.tap(find.text('Gate pass approved'));
      await pumpFrames(tester, count: 6);

      expect(find.byType(GatePassScreen, skipOffstage: false), findsNothing);
      expect(find.byType(AlertsScreen, skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('students still receive every alert category', (
      WidgetTester tester,
    ) async {
      await openRoute(tester, '/alerts', email: student);

      expect(find.text('Gate pass approved'), findsOneWidget);
      expect(find.text('Exam time table published'), findsOneWidget);
      expect(find.text('Academic'), findsWidgets);
      expect(find.text('Hostel'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
