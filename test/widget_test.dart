import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/routes/app_routes.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/features/auth/login_screen.dart';
import 'package:avit_campus_plus/features/auth/splash_screen.dart';
import 'package:avit_campus_plus/features/auth/welcome_screen.dart';
import 'package:avit_campus_plus/features/dashboard/dashboard_screen.dart';
import 'package:avit_campus_plus/main.dart';

/// Finds widgets that may still be offstage during a route transition.
Finder screen<T>() => find.byType(T, skipOffstage: false);

void main() {
  AppState buildState() =>
      AppState(AppDependencies(secureStore: InMemorySecureStore()));

  /// Lets the splash delay (2.1s) and bounded secure-storage reads (3s each)
  /// elapse so no timers leak out of the test.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 3));
    }
    // Indeterminate loaders keep scheduling frames, so avoid pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('app boots into the AVIT splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(AvitCampusPlus(state: buildState()));
    await tester.pump();

    expect(screen<SplashScreen>(), findsOneWidget);
    expect(find.text('AVIT Campus+', skipOffstage: false), findsOneWidget);

    await settle(tester);
    expect(screen<DashboardScreen>(), findsOneWidget);
  });

  testWidgets('protected routes require a session', (WidgetTester tester) async {
    await tester.pumpWidget(AvitCampusPlus(state: buildState()));
    await tester.pump();

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamed(Routes.settings);
    await tester.pump(const Duration(milliseconds: 400));

    expect(screen<LoginScreen>(), findsOneWidget);

    // The splash finishes and resets the stack to a single root route —
    // the public demo opens straight into the dashboard.
    await settle(tester);
    expect(screen<DashboardScreen>(), findsOneWidget);
  });

  testWidgets('unknown routes fall back to welcome', (WidgetTester tester) async {
    await tester.pumpWidget(AvitCampusPlus(state: buildState()));
    await tester.pump();

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamed('/does-not-exist');
    await tester.pump(const Duration(milliseconds: 400));

    expect(screen<WelcomeScreen>(), findsOneWidget);

    await settle(tester);
  });
}
