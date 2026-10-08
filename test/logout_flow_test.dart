import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/features/auth/login_screen.dart';
import 'package:avit_campus_plus/features/dashboard/dashboard_screen.dart';
import 'package:avit_campus_plus/main.dart';

/// The dashboard's account card exposes a sign-out option: confirming ends
/// the session and lands the user back on login, while cancelling keeps the
/// dashboard mounted and the session intact.
void main() {
  const String student = 'student@avit.ac.in';
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

  Future<AppState> bootSignedIn(WidgetTester tester) async {
    final AppState state = AppState(
      AppDependencies(secureStore: InMemorySecureStore()),
    );
    await tester.pumpWidget(AvitCampusPlus(state: state));
    await tester.pump();
    final Future<bool> signedIn = state.signIn(
      identifier: student,
      password: password,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(await signedIn, isTrue);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamedAndRemoveUntil('/dashboard', (Route<dynamic> r) => false);
    await pumpFrames(tester, count: 12);
    return state;
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

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign out'));
    await pumpFrames(tester, count: 14);

    expect(state.isAuthenticated, isFalse, reason: 'session is cleared');
    expect(find.byType(LoginScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(DashboardScreen, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
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
}
