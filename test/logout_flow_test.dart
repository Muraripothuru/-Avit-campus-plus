import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/features/auth/login_screen.dart';
import 'package:avit_campus_plus/features/dashboard/dashboard_screen.dart';
import 'package:avit_campus_plus/main.dart';

/// Every interface (student home, security, warden, admin) exposes the same
/// sign-out flow: confirm → session cleared → login. The student dashboard
/// has its own account pill, staff use the app-bar action, and the drawer
/// offers it to everyone.
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

  Future<AppState> bootSignedIn(
    WidgetTester tester, {
    String email = student,
    String route = '/dashboard',
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
    await pumpFrames(tester, count: 12);
    return state;
  }

  Future<void> confirmAndVerify(
    WidgetTester tester,
    AppState state, {
    required String reason,
  }) async {
    expect(find.byType(AlertDialog), findsOneWidget, reason: reason);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign out'));
    await pumpFrames(tester, count: 14);

    expect(state.isAuthenticated, isFalse, reason: '$reason — session ends');
    expect(find.byType(LoginScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(DashboardScreen, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  }

  Finder signOutPill() => find.descendant(
    of: find.byType(DashboardScreen, skipOffstage: false),
    matching: find.text('Sign out'),
  );

  testWidgets('confirming sign-out ends the session and returns to login', (
    WidgetTester tester,
  ) async {
    final AppState state = await bootSignedIn(tester);

    expect(state.isAuthenticated, isTrue);
    expect(signOutPill(), findsOneWidget);

    await tester.tap(signOutPill());
    await pumpFrames(tester, count: 3);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('You will need your ID and password to sign back in.'),
      findsOneWidget,
    );

    await confirmAndVerify(tester, state, reason: 'student dashboard');
  });

  testWidgets('cancelling keeps the dashboard and session intact', (
    WidgetTester tester,
  ) async {
    final AppState state = await bootSignedIn(tester);

    await tester.tap(signOutPill());
    await pumpFrames(tester, count: 3);

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await pumpFrames(tester, count: 6);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(DashboardScreen, skipOffstage: false), findsOneWidget);
    expect(state.isAuthenticated, isTrue, reason: 'still signed in');
    expect(tester.takeException(), isNull);
  });

  testWidgets('every staff role signs out from the app bar', (
    WidgetTester tester,
  ) async {
    const List<(String, String)> roles = <(String, String)>[
      (security, '/security'),
      (warden, '/warden'),
      (admin, '/admin'),
    ];

    for (final (String email, String route) in roles) {
      final AppState state = await bootSignedIn(
        tester,
        email: email,
        route: route,
      );
      expect(state.isAuthenticated, isTrue, reason: '$email signed in');

      final Finder logout = find.byTooltip('Sign out');
      expect(
        logout,
        findsOneWidget,
        reason: '$email sees the app-bar sign out',
      );

      await tester.tap(logout);
      await pumpFrames(tester, count: 3);
      await confirmAndVerify(tester, state, reason: '$email app bar');
    }
  });

  testWidgets('the drawer offers sign out to every interface', (
    WidgetTester tester,
  ) async {
    final AppState state = await bootSignedIn(tester);

    await tester.tap(find.byTooltip('Open menu'));
    await pumpFrames(tester, count: 6);

    // The tile sits at the bottom of the drawer's lazy list — scroll it in.
    final Finder tile = find.descendant(
      of: find.byType(Drawer, skipOffstage: false),
      matching: find.text('Sign out'),
    );
    await tester.scrollUntilVisible(
      tile,
      400,
      scrollable: find
          .descendant(
            of: find.byType(Drawer, skipOffstage: false),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await pumpFrames(tester, count: 3);

    expect(tile, findsOneWidget, reason: 'drawer sign-out tile');

    await tester.tap(tile);
    await pumpFrames(tester, count: 3);
    await confirmAndVerify(tester, state, reason: 'drawer');
  });
}
