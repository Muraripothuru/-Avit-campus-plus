import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/data/datasources/demo_catalog.dart';
import 'package:avit_campus_plus/features/campus_services/service_request_screen.dart';
import 'package:avit_campus_plus/main.dart';

void main() {
  Future<AppState> pumpForm(WidgetTester tester) async {
    final AppState state = AppState(
      AppDependencies(secureStore: InMemorySecureStore()),
    );
    await tester.pumpWidget(AvitCampusPlus(state: state));
    await tester.pump();

    final Future<bool> signedIn = state.signIn(
      identifier: 'student@avit.ac.in',
      password: 'Avit@2026Demo',
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(await signedIn, isTrue);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));

    final NavigatorState nav =
        tester.state<NavigatorState>(find.byType(Navigator));
    nav.pushNamedAndRemoveUntil(
      '/service-request',
      (Route<dynamic> r) => false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byType(ServiceRequestScreen, skipOffstage: false),
      findsOneWidget,
    );
    return state;
  }

  /// Fills every required step-1 control with valid sample data.
  Future<void> fillDetails(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Pick the unit you need'));
    await tester.pump();
    await tester.tap(find.text('Pick the unit you need'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('IT Helpdesk'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(find.byType(TextFormField).at(4));
    await tester.pump();
    await tester.enterText(
      find.byType(TextFormField).at(4),
      'Projector shows no signal in AB-204',
    );
    await tester.pump();

    await tester.ensureVisible(find.byType(TextFormField).at(5));
    await tester.pump();
    await tester.enterText(
      find.byType(TextFormField).at(5),
      'The classroom projector shows no signal since the morning lab. '
          'Please send a technician before the afternoon batch arrives.',
    );
    await tester.pump();

    await tester.ensureVisible(find.text('High'));
    await tester.pump();
    await tester.tap(find.text('High'));
    await tester.pump();
    await tester.tap(find.text('Email'));
    await tester.pump();

    await tester.ensureVisible(find.text('Not chosen yet'));
    await tester.pump();
    await tester.tap(find.text('Not chosen yet'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('form renders with the signed-in student prefilled', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    expect(find.text('AVIT Campus+ Service Desk'), findsOneWidget);
    expect(find.text('Student details'), findsOneWidget);
    expect(find.text('Request details'), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
    expect(
      find.widgetWithText(
        TextFormField,
        DemoCatalog.student.fullName,
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('submitting an empty details step shows field errors', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    await tester.ensureVisible(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Choose a service category'), findsOneWidget);
    expect(find.text('Add a short subject for your request'), findsOneWidget);
    expect(
      find.text('Describe what you need (20-500 characters)'),
      findsOneWidget,
    );
    expect(find.text('Select how urgent this request is'), findsOneWidget);
    expect(
      find.text('Choose how the team should reach you'),
      findsOneWidget,
    );
    expect(find.text('Pick a preferred response date'), findsOneWidget);
    expect(find.text('Review your request'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a bad campus email shows a specific format error', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    await tester.ensureVisible(find.byType(TextFormField).at(2));
    await tester.pump();
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'friend@gmail.com',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Use your campus email (@avit.ac.in)'),
      findsOneWidget,
    );
    expect(find.text('Review your request'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid details reach the review step, declaration gates '
      'submit, then a summary with a reference is confirmed', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    await fillDetails(tester);

    await tester.ensureVisible(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Review your request'), findsOneWidget);
    expect(
      find.text('Projector shows no signal in AB-204'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Submit request'));
    await tester.pump();
    await tester.tap(find.text('Submit request'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Accept the declaration before submitting'),
      findsOneWidget,
    );
    expect(find.text('Request submitted'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Submit request'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Request submitted'), findsOneWidget);
    expect(find.textContaining('SR-'), findsWidgets);

    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.textContaining('SR-'), findsWidgets);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset returns every field and selection to its start state', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    await fillDetails(tester);
    await tester.ensureVisible(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Review your request'), findsOneWidget);

    await tester.ensureVisible(find.text('Reset'));
    await tester.pump();
    await tester.tap(find.text('Reset'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Review your request'), findsNothing);
    expect(find.text('Pick the unit you need'), findsOneWidget);
    expect(find.text('Form cleared — ready for a new request.'), findsOneWidget);

    await tester.ensureVisible(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Select how urgent this request is'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('facilities category reveals the conditional block field', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    expect(find.text('Block / room number'), findsNothing);

    await tester.ensureVisible(find.text('Pick the unit you need'));
    await tester.pump();
    await tester.tap(find.text('Pick the unit you need'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Facilities & Maintenance'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Block / room number'), findsOneWidget);

    await tester.ensureVisible(find.text('Facilities & Maintenance'));
    await tester.pump();
    await tester.tap(find.text('Facilities & Maintenance'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('IT Helpdesk'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Block / room number'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a saved draft is restored when the form reopens', (
    WidgetTester tester,
  ) async {
    final AppState state = await pumpForm(tester);

    await tester.ensureVisible(find.byType(TextFormField).at(4));
    await tester.pump();
    await tester.enterText(
      find.byType(TextFormField).at(4),
      'Mess closing too early at night',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Save draft'));
    await tester.pump();
    await tester.tap(find.text('Save draft'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(state.serviceRequestDraft, isNotNull);
    expect(find.textContaining('Draft saved'), findsOneWidget);

    final NavigatorState nav =
        tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pump(const Duration(milliseconds: 400));
    nav.pushNamed('/service-request');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Draft restored — pick up where you left off.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        TextFormField,
        'Mess closing too early at night',
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  group('ServiceRequestRules', () {
    test('preferred date rejects the past and empty values', () {
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      expect(
        ServiceRequestRules.preferredDate(null),
        'Pick a preferred response date',
      );
      expect(
        ServiceRequestRules.preferredDate(
          today.subtract(const Duration(days: 1)),
        ),
        'The preferred date cannot be in the past',
      );
      expect(ServiceRequestRules.preferredDate(today), isNull);
    });

    test('campus email requires the @avit.ac.in domain', () {
      expect(ServiceRequestRules.campusEmail(''), isNotNull);
      expect(ServiceRequestRules.campusEmail('not-an-email'), isNotNull);
      expect(
        ServiceRequestRules.campusEmail('friend@gmail.com'),
        'Use your campus email (@avit.ac.in)',
      );
      expect(ServiceRequestRules.campusEmail('student@avit.ac.in'), isNull);
    });

    test('phone is optional but must be a valid mobile when entered', () {
      expect(ServiceRequestRules.optionalPhone(''), isNull);
      expect(ServiceRequestRules.optionalPhone(null), isNull);
      expect(ServiceRequestRules.optionalPhone('12345'), isNotNull);
      expect(ServiceRequestRules.optionalPhone('9876543210'), isNull);
      expect(ServiceRequestRules.optionalPhone('+91 98765 43210'), isNull);
    });

    test('details enforce the 20-500 character window', () {
      expect(ServiceRequestRules.details(''), isNotNull);
      expect(ServiceRequestRules.details('Too short'), isNotNull);
      expect(
        ServiceRequestRules.details('Exactly twenty chars ok?'),
        isNull,
      );
      expect(ServiceRequestRules.details('x' * 501), isNotNull);
    });

    test('full name needs at least two words', () {
      expect(ServiceRequestRules.fullName('Cher'), isNotNull);
      expect(ServiceRequestRules.fullName('Ananya Sharma'), isNull);
    });
  });
}
