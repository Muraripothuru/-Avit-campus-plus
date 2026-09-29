import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/features/campus/campus_screen.dart';
import 'package:avit_campus_plus/features/dashboard/dashboard_screen.dart';
import 'package:avit_campus_plus/features/safety/complaints_screen.dart';
import 'package:avit_campus_plus/features/staff/warden_dashboard_screen.dart';
import 'package:avit_campus_plus/main.dart';
import 'package:avit_campus_plus/navigation/app_shell.dart';
import 'package:avit_campus_plus/widgets/avit_bottom_nav.dart';

/// Critical user journeys driven through real taps and form entry.
void main() {
  const String student = 'student@avit.ac.in';
  const String warden = 'warden@avit.ac.in';
  const String password = 'Avit@2026Demo';

  Future<void> pumpFrames(
    WidgetTester tester, {
    int count = 6,
    Duration step = const Duration(milliseconds: 300),
  }) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  /// Boots the app, lets the splash settle and optionally signs the user in.
  Future<AppState> boot(
    WidgetTester tester, {
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
        password: password,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(await signedIn, isTrue, reason: 'sign-in for $email');
    }
    // Let the splash timer fire and reset the stack.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  Future<void> openRoute(WidgetTester tester, String route) async {
    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamedAndRemoveUntil(route, (Route<dynamic> r) => false);
    await pumpFrames(tester);
  }

  testWidgets('student signs in through the login form', (
    WidgetTester tester,
  ) async {
    final AppState state = await boot(tester);
    await openRoute(tester, '/login');
    expect(find.byType(DashboardScreen, skipOffstage: false), findsNothing);

    final Finder fields = find.byType(TextFormField, skipOffstage: false);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), student);
    await tester.enterText(fields.at(1), password);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Login'));
    await pumpFrames(tester, count: 8);

    expect(
      find.byType(AppShell, skipOffstage: false),
      findsOneWidget,
      reason: 'successful login lands on the tab shell',
    );
    expect(
      find.byType(DashboardScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    expect(state.user?.email, student);
  });

  testWidgets('bottom navigation switches between tabs', (
    WidgetTester tester,
  ) async {
    await boot(tester, email: student);
    await openRoute(tester, '/dashboard');
    expect(find.byType(DashboardScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AVITBottomNavigation),
        matching: find.text('Campus'),
      ),
    );
    await pumpFrames(tester, count: 4);

    expect(
      find.byType(CampusScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'tapping the Campus tab shows the campus screen',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('student files a complaint through the composer', (
    WidgetTester tester,
  ) async {
    await boot(tester, email: student);
    await openRoute(tester, '/complaints');
    expect(find.byType(ComplaintsScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('New complaint'));
    await pumpFrames(tester, count: 3);
    expect(find.text('Raise a complaint'), findsOneWidget);

    final Finder fields = find.byType(TextFormField, skipOffstage: false);
    expect(fields, findsNWidgets(2));
    const String subject = 'Water cooler on floor 3 is leaking';
    const String description =
        'The water cooler outside the signal lab is leaking onto the floor '
        'and has become a slipping hazard.';
    await tester.enterText(fields.at(0), subject);
    await tester.enterText(fields.at(1), description);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Submit complaint'));
    await pumpFrames(tester, count: 8);

    expect(find.text('Raise a complaint'), findsNothing);
    expect(
      find.text(subject, skipOffstage: false),
      findsWidgets,
      reason: 'the filed complaint is listed',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings offers no sign out — the app is always open', (
    WidgetTester tester,
  ) async {
    await boot(tester, email: student);
    await openRoute(tester, '/settings');
    await pumpFrames(tester, count: 3);

    expect(find.text('Sign out'), findsNothing);
    expect(find.text('Logout'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warden approves a pending gate request', (
    WidgetTester tester,
  ) async {
    final AppState state = await boot(tester, email: warden);
    await openRoute(tester, '/warden');
    expect(
      find.byType(WardenDashboardScreen, skipOffstage: false),
      findsOneWidget,
    );

    final Finder approve = find.widgetWithText(
      ElevatedButton,
      'Approve',
    );
    expect(approve, findsWidgets, reason: 'pending requests are listed');
    await tester.tap(approve.first);
    await pumpFrames(tester, count: 10);

    expect(tester.takeException(), isNull);
    expect(state.user?.email, warden);
  });
}
