import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/features/academics/timetable_screen.dart';
import 'package:avit_campus_plus/features/auth/forgot_password_screen.dart';
import 'package:avit_campus_plus/features/auth/login_screen.dart';
import 'package:avit_campus_plus/features/auth/signup_screen.dart';
import 'package:avit_campus_plus/features/auth/welcome_screen.dart';
import 'package:avit_campus_plus/features/campus/campus_screen.dart';
import 'package:avit_campus_plus/features/campus/service_detail_screen.dart';
import 'package:avit_campus_plus/main.dart';
import 'package:avit_campus_plus/navigation/unknown_route_screen.dart';

/// Finds widgets that may still be offstage during a route transition.
Finder screen<T>() => find.byType(T, skipOffstage: false);

/// Verifies the graded Navigator checklist from
/// Flutter_Routes_Navigator_Student_Campus_App_Customization_Project.docx:
/// a direct `Navigator.push(MaterialPageRoute)` into Service Details, the
/// selected object travelling through the route, a returned result shown as
/// a SnackBar, at least four registered named routes opened with
/// `pushNamed`, correct stack behaviour, and the unknown-route fallback.
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
    return state;
  }

  /// Replaces the stack with the Campus services list, mirroring the
  /// assignment flow: Dashboard → Campus Services → Service Details.
  Future<NavigatorState> openCampus(WidgetTester tester) async {
    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamedAndRemoveUntil('/campus', (Route<dynamic> route) => false);
    await pumpFrames(tester, count: 12);
    expect(find.byType(CampusScreen, skipOffstage: false), findsOneWidget);
    return nav;
  }

  testWidgets('a service tap opens Service Details with the selected object', (
    WidgetTester tester,
  ) async {
    await bootSignedIn(tester);
    await openCampus(tester);

    await tester.tap(find.text('Timetable'));
    await pumpFrames(tester, count: 6);

    expect(
      find.byType(ServiceDetailScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'the direct MaterialPageRoute push opened Service Details',
    );
    // The detail route renders the tapped object's own data — the Timetable
    // entry, not a hard-coded copy shared by every item.
    expect(
      find.text('Academic Block A • published by the Registrar'),
      findsOneWidget,
    );
    expect(find.text('registrar@avit.ac.in'), findsOneWidget);
    expect(find.textContaining('weekly class timetable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Service Details returns a result confirmed by a SnackBar', (
    WidgetTester tester,
  ) async {
    await bootSignedIn(tester);
    await openCampus(tester);

    await tester.tap(find.text('Timetable'));
    await pumpFrames(tester, count: 6);
    expect(
      find.byType(ServiceDetailScreen, skipOffstage: false),
      findsOneWidget,
    );

    await tester.tap(find.text('Request information'));
    await pumpFrames(tester, count: 8);

    expect(
      find.byType(CampusScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'pop revealed the previous route instead of a new copy',
    );
    expect(find.byType(ServiceDetailScreen, skipOffstage: false), findsNothing);
    expect(
      find.textContaining('Request sent'),
      findsOneWidget,
      reason: 'the returned result is shown as a SnackBar',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('open pushes the functional route and back keeps the stack', (
    WidgetTester tester,
  ) async {
    await bootSignedIn(tester);
    final NavigatorState nav = await openCampus(tester);

    await tester.tap(find.text('Timetable'));
    await pumpFrames(tester, count: 6);
    expect(
      find.byType(ServiceDetailScreen, skipOffstage: false),
      findsOneWidget,
    );

    await tester.tap(find.text('Open Timetable'));
    await pumpFrames(tester, count: 6);
    expect(
      find.byType(TimetableScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'the named route opens on top of Service Details',
    );

    nav.pop();
    await pumpFrames(tester, count: 6);
    expect(
      find.byType(ServiceDetailScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'system back reveals Service Details again',
    );
    expect(
      find.byType(CampusScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'the stack is Services → Details → Timetable, one copy each',
    );

    nav.pop();
    await pumpFrames(tester, count: 6);
    expect(find.byType(CampusScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(ServiceDetailScreen, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('four registered named routes open with pushNamed', (
    WidgetTester tester,
  ) async {
    await bootSignedIn(tester);
    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );

    nav.pushNamed('/login');
    await pumpFrames(tester, count: 4);
    expect(screen<LoginScreen>(), findsOneWidget);
    nav.pop();
    await pumpFrames(tester, count: 4);

    nav.pushNamed('/welcome');
    await pumpFrames(tester, count: 4);
    expect(screen<WelcomeScreen>(), findsOneWidget);
    nav.pop();
    await pumpFrames(tester, count: 4);

    nav.pushNamed('/signup');
    await pumpFrames(tester, count: 4);
    expect(screen<SignUpScreen>(), findsOneWidget);
    nav.pop();
    await pumpFrames(tester, count: 4);

    nav.pushNamed('/forgot-password');
    await pumpFrames(tester, count: 4);
    expect(screen<ForgotPasswordScreen>(), findsOneWidget);
    nav.pop();
    await pumpFrames(tester, count: 4);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an unregistered name opens the 404 screen showing the route', (
    WidgetTester tester,
  ) async {
    await bootSignedIn(tester);
    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );

    nav.pushNamed('/route-that-does-not-exist');
    await pumpFrames(tester, count: 4);

    expect(
      find.byType(UnknownRouteScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('/route-that-does-not-exist', skipOffstage: false),
      findsOneWidget,
      reason: 'the 404 screen names the route that could not be opened',
    );
    expect(tester.takeException(), isNull);
  });
}
