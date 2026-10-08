import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/features/campus_services/gate_pass_screen.dart';
import 'package:avit_campus_plus/main.dart';
import 'package:avit_campus_plus/models/pass.dart';
import 'package:avit_campus_plus/widgets/avit_cards.dart';
import 'package:avit_campus_plus/widgets/avit_content_cards.dart';

/// The gate pass lifecycle end to end: a student raises a request, it lands
/// in the warden's approval inbox (the gate pass section is approvals only),
/// approval issues the signed QR, and security can scan that QR at the gate.
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
    return state;
  }

  Future<void> openRoute(WidgetTester tester, String route) async {
    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamedAndRemoveUntil(route, (Route<dynamic> r) => false);
    await pumpFrames(tester, count: 12);
  }

  /// End one session and start another inside the same app state, so the
  /// demo store (and any request raised along the way) survives the switch.
  Future<void> switchTo(
    WidgetTester tester,
    AppState state,
    String email,
    String route,
  ) async {
    state.signOut();
    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamedAndRemoveUntil('/login', (Route<dynamic> r) => false);
    await pumpFrames(tester, count: 6);
    final Future<bool> signedIn = state.signIn(
      identifier: email,
      password: password,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(await signedIn, isTrue, reason: 're-sign-in for $email');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    nav.pushNamedAndRemoveUntil(route, (Route<dynamic> r) => false);
    await pumpFrames(tester, count: 12);
  }

  testWidgets('a student request reaches the warden and approval issues the '
      'QR security scans', (WidgetTester tester) async {
    const String reason = 'Weekend lab material pickup run';
    const String destination = 'Phoenix Marketcity';
    final AppState state = await boot(tester, email: student);
    await openRoute(tester, '/gate-pass');

    // Student UI: own passes with status filters and the create button.
    expect(find.byType(GatePassScreen, skipOffstage: false), findsOneWidget);
    expect(find.byTooltip('New gate pass'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    // Raise a new request through the form.
    await tester.tap(find.byTooltip('New gate pass'));
    await pumpFrames(tester, count: 8);
    final Finder fields = find.byType(TextFormField, skipOffstage: false);
    expect(fields, findsNWidgets(2), reason: 'reason + destination');
    await tester.enterText(fields.at(0), reason);
    await tester.enterText(fields.at(1), destination);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Submit request'));
    await pumpFrames(tester, count: 8);
    expect(
      find.text('Request submitted — waiting for warden approval'),
      findsOneWidget,
      reason: 'the student is told it goes to the warden',
    );
    await tester.pump(const Duration(seconds: 4));
    await pumpFrames(tester, count: 6);
    expect(find.text(reason), findsOneWidget, reason: 'pending on my list');
    expect(tester.takeException(), isNull);

    // Warden: the same request is waiting in the gate pass section.
    await switchTo(tester, state, warden, '/gate-pass');
    expect(find.byType(GatePassScreen, skipOffstage: false), findsOneWidget);
    expect(
      find.text(reason),
      findsOneWidget,
      reason: 'the new request reached the warden',
    );

    final Finder card = find.ancestor(
      of: find.text(reason),
      matching: find.byType(AVITApprovalCard),
    );
    final Finder approve = find.descendant(
      of: card,
      matching: find.widgetWithText(ElevatedButton, 'Approve'),
    );
    expect(approve, findsOneWidget);
    await tester.tap(approve);
    await pumpFrames(tester, count: 10);
    expect(
      find.text('Request approved — QR issued to the student'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    await pumpFrames(tester, count: 6);
    expect(
      find.text(reason),
      findsNothing,
      reason: 'reviewed — left the inbox',
    );
    expect(tester.takeException(), isNull);

    // Student: the approved pass now carries the gate QR.
    await switchTo(tester, state, student, '/gate-pass');
    final Finder myCard = find.ancestor(
      of: find.text(reason),
      matching: find.byType(AVITCard),
    );
    final Finder showQr = find.descendant(
      of: myCard,
      matching: find.text('Show QR code'),
    );
    expect(showQr, findsOneWidget, reason: 'approval unlocks the QR');
    await tester.tap(showQr);
    await pumpFrames(tester, count: 6);
    expect(find.byType(AVITQrPanel, skipOffstage: false), findsOneWidget);
    expect(find.text('Gate pass QR'), findsOneWidget);

    // Security scans that very token at the gate. Pump a loop instead of
    // awaiting directly: the demo verification chains timers that only fire
    // as the test clock advances, and a bare await would deadlock.
    final String token =
        tester.widget<SelectableText>(find.byType(SelectableText)).data ?? '';
    expect(token, isNotEmpty);
    ScanResult? scan;
    state.deps.security.verifyPass(token).then((ScanResult r) => scan = r);
    for (int i = 0; i < 40 && scan == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(scan, isNotNull, reason: 'security scan completes');
    expect(scan!.status, QrScanStatus.valid, reason: 'access granted at gate');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the warden gate pass section keeps approvals only', (
    WidgetTester tester,
  ) async {
    await boot(tester, email: warden);
    await openRoute(tester, '/gate-pass');
    await pumpFrames(tester, count: 8);

    // No student-only controls.
    expect(find.byTooltip('New gate pass'), findsNothing);
    expect(find.text('New pass'), findsNothing);
    expect(find.text('History'), findsNothing);
    expect(find.text('All'), findsNothing);

    // Only the approval inbox.
    expect(find.text('Pending requests'), findsOneWidget);
    expect(find.text('Bank work'), findsOneWidget, reason: 'pending listed');
    expect(find.widgetWithText(ElevatedButton, 'Approve'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the warden console lists only undecided requests', (
    WidgetTester tester,
  ) async {
    await boot(tester, email: warden);
    await openRoute(tester, '/warden');
    await pumpFrames(tester, count: 8);

    // Reviewed passes are no longer dressed up as pending approvals.
    expect(find.text('Medical appointment'), findsNothing);
    expect(find.text('Home visit'), findsNothing);
    // Newest undecided request is the first approval card.
    expect(
      find.text('Family event'),
      findsOneWidget,
      reason: 'still undecided',
    );
    expect(tester.takeException(), isNull);
  });
}
