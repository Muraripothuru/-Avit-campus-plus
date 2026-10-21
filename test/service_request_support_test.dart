import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/data/datasources/demo_catalog.dart';
import 'package:avit_campus_plus/features/account/help_screen.dart';
import 'package:avit_campus_plus/features/campus_services/service_request_screen.dart';
import 'package:avit_campus_plus/main.dart';
import 'package:avit_campus_plus/widgets/avit_cards.dart';

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

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
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

  Finder mainScrollable() => find
      .descendant(
        of: find.byType(ServiceRequestScreen),
        matching: find.byType(Scrollable),
      )
      .first;

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

  /// Submits one request and dismisses the confirmation dialog.
  Future<void> submitOneRequest(WidgetTester tester) async {
    await fillDetails(tester);
    await tester.ensureVisible(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.ensureVisible(find.text('Submit request'));
    await tester.pump();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Submit request'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Request submitted'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('Quick Help opens the help centre', (WidgetTester tester) async {
    await pumpForm(tester);

    await tester.scrollUntilVisible(
      find.text('Quick Help'),
      400,
      scrollable: mainScrollable(),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Quick Help'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(HelpScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Common Issues picks a category and prefills the form', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);

    await tester.scrollUntilVisible(
      find.text('Common Issues'),
      400,
      scrollable: mainScrollable(),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Common Issues'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Common issues'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Wi-Fi / Internet'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text(
        'Category set to Wi-Fi / Internet — describe the problem '
        'and submit.',
      ),
      findsOneWidget,
    );
    expect(find.text('Wi-Fi / Internet'), findsWidgets);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Request Status shows the empty state with a start shortcut', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);

    await tester.scrollUntilVisible(
      find.text('Request Status'),
      400,
      scrollable: mainScrollable(),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Request Status'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('No request submitted yet'), findsOneWidget);

    await tester.tap(find.text('Start a request'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('No request submitted yet'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('submitted records stay visible and search filters them', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    await submitOneRequest(tester);

    // The records list survives the submitted state.
    await tester.scrollUntilVisible(
      find.text('Your recent requests'),
      400,
      scrollable: mainScrollable(),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Your recent requests'), findsOneWidget);
    expect(
      find.text(
        '${DemoCatalog.student.fullName} • ${DemoCatalog.student.studentId}',
      ),
      findsOneWidget,
    );

    // Search by subject.
    final Finder search = find.byType(TextField);
    expect(search, findsOneWidget);
    await tester.ensureVisible(search);
    await tester.pump();
    await tester.enterText(search, 'projector');
    await tester.pump();
    expect(find.text('Projector shows no signal in AB-204'), findsOneWidget);
    expect(find.textContaining('1 of 1 match'), findsOneWidget);

    // Search by student ID.
    await tester.enterText(search, DemoCatalog.student.studentId!);
    await tester.pump();
    expect(find.text('Projector shows no signal in AB-204'), findsOneWidget);

    // A query with no hits shows the empty card.
    await tester.enterText(search, 'zzz-nothing');
    await tester.pump();
    expect(find.text('No requests match "zzz-nothing"'), findsOneWidget);
    expect(find.text('Projector shows no signal in AB-204'), findsNothing);

    // Clearing restores the full list.
    await tester.enterText(search, '');
    await tester.pump();
    expect(find.text('Projector shows no signal in AB-204'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Service Request card jumps back to a fresh form after '
      'submitting', (WidgetTester tester) async {
    await pumpForm(tester);
    await submitOneRequest(tester);

    await tester.scrollUntilVisible(
      find.widgetWithText(AVITCard, 'Service Request'),
      400,
      scrollable: mainScrollable(),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(AVITCard, 'Service Request'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Start a new request'), findsNothing);
    expect(find.text('Pick the unit you need'), findsOneWidget);

    // The submitted record is still trackable after the reset.
    await tester.scrollUntilVisible(
      find.text('Your recent requests'),
      400,
      scrollable: mainScrollable(),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Your recent requests'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('previous requests load again after a dashboard round trip', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    await submitOneRequest(tester);

    // Leave for the dashboard — this disposes the request screen's State.
    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamedAndRemoveUntil('/dashboard', (Route<dynamic> r) => false);
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(
      find.byType(ServiceRequestScreen, skipOffstage: false),
      findsNothing,
    );

    // Come back: the student's previous requests must be reloaded.
    nav.pushNamedAndRemoveUntil('/service-request', (r) => false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.scrollUntilVisible(
      find.text('Your recent requests'),
      400,
      scrollable: mainScrollable(),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Your recent requests'), findsOneWidget);
    expect(find.text('Projector shows no signal in AB-204'), findsOneWidget);
    expect(
      find.text(
        '${DemoCatalog.student.fullName} • ${DemoCatalog.student.studentId}',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('SR-'), findsWidgets);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the search options menu scopes the records query', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    await submitOneRequest(tester);

    await tester.scrollUntilVisible(
      find.text('Your recent requests'),
      400,
      scrollable: mainScrollable(),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final Finder search = find.byType(TextField);
    expect(search, findsOneWidget);

    // Open the scope menu and restrict matching to the student name.
    await tester.ensureVisible(find.byTooltip('Search options'));
    await tester.pump();
    await tester.tap(find.byTooltip('Search options'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('By student name'), findsOneWidget);
    await tester.tap(find.text('By student name'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The hint now advertises the active scope.
    expect(find.text('Search in student name'), findsOneWidget);

    // 'projector' only appears in the subject — no match under name scope.
    await tester.ensureVisible(search);
    await tester.pump();
    await tester.enterText(search, 'projector');
    await tester.pump();
    expect(find.text('No requests match "projector"'), findsOneWidget);
    expect(find.textContaining('1 of 1 match'), findsNothing);

    // The student's name matches under the same scope.
    await tester.enterText(search, 'arun');
    await tester.pump();
    expect(find.text('Projector shows no signal in AB-204'), findsOneWidget);
    expect(find.textContaining('1 of 1 match "arun"'), findsOneWidget);
    expect(find.textContaining('by student name'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the requests page carries a visible scrollbar', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    await submitOneRequest(tester);

    expect(
      find.descendant(
        of: find.byType(ServiceRequestScreen, skipOffstage: false),
        matching: find.byType(Scrollbar),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}
