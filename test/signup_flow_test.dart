import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/data/repositories/auth_repository.dart';
import 'package:avit_campus_plus/features/auth/login_screen.dart';
import 'package:avit_campus_plus/features/auth/otp_screen.dart';
import 'package:avit_campus_plus/features/dashboard/dashboard_screen.dart';
import 'package:avit_campus_plus/main.dart';
import 'package:avit_campus_plus/navigation/app_shell.dart';

/// End-to-end account creation: form -> OTP -> dashboard -> sign back in.
void main() {
  const String password = 'Avit@2026Demo';
  const String freshId = 'AVIT2026CS042';
  const String freshEmail = 'meera.iyer@avit.ac.in';

  Future<void> pumpFrames(
    WidgetTester tester, {
    int count = 6,
    Duration step = const Duration(milliseconds: 300),
  }) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  Future<AppState> boot(WidgetTester tester, {SecureStore? store}) async {
    final AppState state = AppState(
      AppDependencies(secureStore: store ?? InMemorySecureStore()),
    );
    // Tall surface so the whole sign-up form is visible without scrolling.
    await tester.binding.setSurfaceSize(const Size(1100, 1700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(AvitCampusPlus(state: state));
    await tester.pump();
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

  Future<void> submitSignupForm(WidgetTester tester) async {
    await openRoute(tester, '/signup');
    final Finder fields = find.byType(TextFormField, skipOffstage: false);
    expect(fields, findsNWidgets(6));

    await tester.enterText(fields.at(0), 'Meera Iyer');
    await tester.enterText(fields.at(1), freshId);
    await tester.enterText(fields.at(2), freshEmail);
    await tester.enterText(fields.at(3), '9876543210');
    await tester.enterText(fields.at(4), password);
    await tester.enterText(fields.at(5), password);
    await tester.pump(const Duration(milliseconds: 200));

    final Finder dropdowns = find.byWidgetPredicate(
      (Widget w) => w is DropdownButtonFormField,
      skipOffstage: false,
    );
    expect(dropdowns, findsNWidgets(2));

    await tester.tap(dropdowns.at(0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.text('B.Tech Computer Science and Engineering').last,
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(dropdowns.at(1));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Semester 3').last);
    await tester.pump(const Duration(milliseconds: 400));

    // Consent starts ticked; only tap if the box is unchecked.
    final Finder consent = find.byType(Checkbox, skipOffstage: false);
    if (tester.widget<Checkbox>(consent).value ?? false) {
      // already accepted
    } else {
      await tester.tap(consent);
      await tester.pump(const Duration(milliseconds: 200));
    }

    await tester.tap(find.text('Send verification code'));
    await pumpFrames(tester, count: 6);
  }

  Future<void> verifyWithDemoCode(
    WidgetTester tester,
    AppState state,
  ) async {
    expect(find.text('Verification code'), findsOneWidget);
    final DemoAuthRepository repo =
        state.deps.auth as DemoAuthRepository;
    final String? code = repo.debugLastOtp;
    expect(code, isNotNull, reason: 'demo OTP was issued');

    // Scope to the OTP route: the sign-up route below it is still in the
    // tree (offstage) and would otherwise be matched first.
    final Finder codeField = find.descendant(
      of: find.byType(OtpScreen, skipOffstage: false),
      matching: find.byType(TextFormField),
    );
    expect(codeField, findsOneWidget);
    await tester.enterText(codeField, code!);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Verify code'));
    await pumpFrames(tester, count: 10);
  }

  testWidgets('creating an account reaches the dashboard', (
    WidgetTester tester,
  ) async {
    final AppState state = await boot(tester);
    await submitSignupForm(tester);
    await verifyWithDemoCode(tester, state);

    expect(
      find.byType(AppShell, skipOffstage: false),
      findsOneWidget,
      reason: 'a new account lands in the tab shell',
    );
    expect(
      find.byType(DashboardScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    expect(state.user?.studentId, freshId);
    expect(state.user?.email, freshEmail);
  });

  testWidgets('a signed-up account can sign out and sign back in', (
    WidgetTester tester,
  ) async {
    final AppState state = await boot(tester);
    await submitSignupForm(tester);
    await verifyWithDemoCode(tester, state);
    expect(state.user?.studentId, freshId);

    await state.signOut();
    await tester.pump(const Duration(milliseconds: 300));

    await openRoute(tester, '/login');
    expect(find.byType(LoginScreen, skipOffstage: false), findsOneWidget);

    final Finder fields = find.byType(TextFormField, skipOffstage: false);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), freshEmail);
    await tester.enterText(fields.at(1), password);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Login'));
    await pumpFrames(tester, count: 8);

    expect(
      find.byType(AppShell, skipOffstage: false),
      findsOneWidget,
      reason: 'the credentials created during sign-up work for sign-in',
    );
    expect(state.user?.studentId, freshId);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a signed-up account survives an app restart', (
    WidgetTester tester,
  ) async {
    final InMemorySecureStore store = InMemorySecureStore();
    final AppState first = await boot(tester, store: store);
    await submitSignupForm(tester);
    await verifyWithDemoCode(tester, first);
    expect(first.user?.studentId, freshId);

    // Tear the widget tree down, as if the process had restarted.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    final AppState restarted = AppState(
      AppDependencies(secureStore: store),
    );
    await tester.pumpWidget(AvitCampusPlus(state: restarted));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byType(DashboardScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'the restored session opens the dashboard without a re-login',
    );
    expect(restarted.user?.studentId, freshId);

    // Drain the dashboard's loading chain so no demo-repo timer outlives
    // the test.
    await pumpFrames(tester, count: 15, step: const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
