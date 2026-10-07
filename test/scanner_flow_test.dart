import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/qr_token_service.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/features/safety/scanner_screen.dart';
import 'package:avit_campus_plus/main.dart';

/// Verify Pass must accept a real issued token and let the same token be
/// re-checked — the manual entry path may never silently swallow a retry.
void main() {
  const String security = 'security@avit.ac.in';
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

  Future<void> openRoute(WidgetTester tester, String route) async {
    final AppState state = AppState(
      AppDependencies(secureStore: InMemorySecureStore()),
    );
    await tester.pumpWidget(AvitCampusPlus(state: state));
    await tester.pump();

    final Future<bool> signedIn = state.signIn(
      identifier: security,
      password: password,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(await signedIn, isTrue, reason: 'security sign-in');

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamedAndRemoveUntil(route, (Route<dynamic> r) => false);
    await pumpFrames(tester, count: 10);
  }

  /// A fresh signed token for the seeded approved gate pass `gp_1`.
  String gateToken() => QrTokenService.issue(
    type: 'gate',
    requestId: 'gp_1',
    holderId: 'AVIT2026CS001',
    expiresAt: DateTime.now().add(const Duration(days: 1)),
  );

  Future<void> verifyOnce(WidgetTester tester, String token) async {
    final Finder field = find.byType(TextFormField, skipOffstage: false);
    expect(field, findsOneWidget, reason: 'the manual entry field');
    await tester.enterText(field, token);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Verify pass'));
    await pumpFrames(tester, count: 8);
  }

  testWidgets('security verifies an issued gate pass token', (
    WidgetTester tester,
  ) async {
    await openRoute(tester, '/scanner');
    expect(find.byType(ScannerScreen, skipOffstage: false), findsOneWidget);

    await verifyOnce(tester, gateToken());

    expect(find.text('Verification result'), findsOneWidget);
    expect(find.text('Entry allowed'), findsOneWidget);
    expect(find.text('VALID'), findsWidgets);
    expect(find.text('Holder: Arun Kumar'), findsOneWidget);

    await pumpFrames(tester, count: 16);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same token can be verified again — no silent drop', (
    WidgetTester tester,
  ) async {
    await openRoute(tester, '/scanner');

    final String token = gateToken();
    await verifyOnce(tester, token);
    expect(find.text('Entry allowed'), findsOneWidget);
    // Drain the success snackbar so the second tap lands on the button.
    await pumpFrames(tester, count: 16);

    await tester.tap(find.text('Verify pass'));
    await pumpFrames(tester, count: 8);
    // Drain the error snackbar so only the result card carries the message.
    await pumpFrames(tester, count: 16);

    expect(find.text('Entry blocked'), findsOneWidget);
    expect(find.text('This pass was already used'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a malformed token is rejected with a clear message', (
    WidgetTester tester,
  ) async {
    await openRoute(tester, '/scanner');

    await verifyOnce(tester, 'AVITQR1.bogus.token');
    await pumpFrames(tester, count: 16);

    expect(find.text('Entry blocked'), findsOneWidget);
    expect(find.text('Pass code signature is invalid'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
