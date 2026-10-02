import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/features/account/help_screen.dart';
import 'package:avit_campus_plus/features/dashboard/dashboard_screen.dart';
import 'package:avit_campus_plus/main.dart';
import 'package:avit_campus_plus/widgets/avit_content_cards.dart';
import 'package:avit_campus_plus/widgets/avit_metallic_border.dart';

/// Covers the metallic silver border treatment (v0 "Metallic Silver Border
/// Card") that dresses the dashboard's Quick Services tiles.
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

  Future<void> bootSignedIn(WidgetTester tester) async {
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
  }

  Finder dashboardDescendants(WidgetTester tester, Finder match) =>
      find.descendant(
        of: find.byType(DashboardScreen, skipOffstage: false),
        matching: match,
      );

  Future<void> scrollToQuickServices(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Quick Services'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(DashboardScreen, skipOffstage: false),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await pumpFrames(tester, count: 4);
  }

  testWidgets('the metallic border paints a card on its own', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 140,
              height: 180,
              child: AVITMetallicBorder(child: Text('Card')),
            ),
          ),
        ),
      ),
    );

    // The border animates forever, so pump a few frames rather than settle.
    await pumpFrames(tester, count: 5);

    expect(find.byType(AVITMetallicBorder), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'paints without errors');
  });

  testWidgets('every Quick Services container wears the metallic border', (
    WidgetTester tester,
  ) async {
    await bootSignedIn(tester);
    await scrollToQuickServices(tester);

    expect(find.text('Quick Services'), findsOneWidget);

    final int serviceCards = dashboardDescendants(
      tester,
      find.byType(AVITServiceCard),
    ).evaluate().length;
    final int metallic = dashboardDescendants(
      tester,
      find.byType(AVITMetallicBorder),
    ).evaluate().length;

    expect(serviceCards, greaterThanOrEqualTo(4), reason: 'quick services');
    expect(
      metallic,
      serviceCards,
      reason: 'each and only the Quick Services containers are metallic',
    );
    expect(tester.takeException(), isNull, reason: 'no layout exceptions');
  });

  testWidgets('a metallic tile still reports its own tap', (
    WidgetTester tester,
  ) async {
    await bootSignedIn(tester);
    await scrollToQuickServices(tester);

    final Finder help = find.text('Help');
    expect(help, findsOneWidget);

    final Finder card = find.ancestor(
      of: help,
      matching: find.byType(AVITServiceCard),
    );
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(AVITMetallicBorder)),
      findsOneWidget,
      reason: 'the border wraps the tile itself',
    );

    await tester.tap(card);
    await pumpFrames(tester, count: 6);
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
