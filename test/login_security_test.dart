import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/features/auth/forgot_password_screen.dart';
import 'package:avit_campus_plus/features/auth/login_screen.dart';
import 'package:avit_campus_plus/features/dashboard/dashboard_screen.dart';
import 'package:avit_campus_plus/main.dart';

/// Tight sign-in barrier shared by every portal: wrong credentials raise the
/// blocking "check your email" popup, only college emails pass the domain
/// gate, and flexible student IDs still reach the credential check.
void main() {
  const List<String> portals = <String>[
    'student@avit.ac.in',
    'warden@avit.ac.in',
    'security@avit.ac.in',
    'admin@avit.ac.in',
  ];

  Future<void> pumpFrames(
    WidgetTester tester, {
    int count = 6,
    Duration step = const Duration(milliseconds: 300),
  }) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  Future<AppState> bootToLogin(WidgetTester tester) async {
    final AppState state = AppState(
      AppDependencies(secureStore: InMemorySecureStore()),
    );
    await tester.pumpWidget(AvitCampusPlus(state: state));
    await tester.pump();
    // Leave the splash before its timer can auto-start the demo session —
    // these tests need a genuinely signed-out state.
    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamedAndRemoveUntil('/login', (Route<dynamic> r) => false);
    await pumpFrames(tester, count: 10);
    expect(state.isAuthenticated, isFalse, reason: 'boots signed out');
    return state;
  }

  Future<void> fillAndSubmit(
    WidgetTester tester,
    String identifier,
    String pw,
  ) async {
    final Finder fields = find.byType(TextFormField, skipOffstage: false);
    expect(fields, findsNWidgets(2), reason: 'identifier + password');
    await tester.enterText(fields.at(0), identifier);
    await tester.enterText(fields.at(1), pw);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Login'));
    // Demo auth resolves on the test clock; give it time to fail + show the
    // popup.
    await pumpFrames(tester, count: 8);
  }

  testWidgets('wrong credentials raise the check-your-email popup for every '
      'portal account', (WidgetTester tester) async {
    final AppState state = await bootToLogin(tester);

    for (int i = 0; i < portals.length; i++) {
      final String email = portals[i];
      await fillAndSubmit(tester, email, 'WrongPassword1!');

      expect(
        find.text('Check your email or password'),
        findsOneWidget,
        reason: '$email is blocked by the popup',
      );
      expect(
        find.textContaining('Check your registered college email'),
        findsOneWidget,
        reason: '$email — popup tells the user what to check',
      );
      final int left = 5 - (i + 1);
      expect(
        find.textContaining(
          '$left attempt${left == 1 ? '' : 's'} left before sign-in is paused',
        ),
        findsOneWidget,
        reason: 'attempts remaining are shown',
      );
      expect(state.isAuthenticated, isFalse, reason: '$email never enters');
      expect(find.byType(DashboardScreen, skipOffstage: false), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await pumpFrames(tester, count: 4);
      expect(
        find.byType(LoginScreen, skipOffstage: false),
        findsOneWidget,
        reason: 'popup dismisses back to the sign-in screen',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('emails outside the college domain cannot enter any portal', (
    WidgetTester tester,
  ) async {
    final AppState state = await bootToLogin(tester);

    await fillAndSubmit(tester, 'someone@gmail.com', 'Whatever1!');

    expect(find.text('Check your email'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('@avit.ac.in'),
      ),
      findsOneWidget,
      reason: 'the popup states the college-domain rule',
    );
    expect(state.isAuthenticated, isFalse);
    expect(find.byType(DashboardScreen, skipOffstage: false), findsNothing);

    // The popup offers the reset route straight away.
    await tester.tap(find.widgetWithText(TextButton, 'Reset password'));
    await pumpFrames(tester, count: 8);
    expect(
      find.byType(ForgotPasswordScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a plain-number student ID still reaches the credential check', (
    WidgetTester tester,
  ) async {
    final AppState state = await bootToLogin(tester);

    await fillAndSubmit(tester, '12345', 'WrongPassword1!');

    expect(
      find.text('Enter a valid student ID or email'),
      findsNothing,
      reason: 'loose student IDs pass format validation',
    );
    expect(
      find.text('Check your email or password'),
      findsOneWidget,
      reason: 'the store rejects the unknown ID with the same popup',
    );
    expect(state.isAuthenticated, isFalse);
    expect(find.byType(DashboardScreen, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
