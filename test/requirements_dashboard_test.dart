import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/features/dashboard/dashboard_screen.dart';
import 'package:avit_campus_plus/main.dart';
import 'package:avit_campus_plus/widgets/avit_cards.dart';
import 'package:avit_campus_plus/widgets/avit_content_cards.dart';

/// Verifies the graded "Student Campus App" Container/dashboard checklist
/// from Student_Campus_App_Container_Widget_Project.docx against the app's
/// home dashboard.
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

  Finder dashboardDescendants(WidgetTester tester, Finder match) =>
      find.descendant(
        of: find.byType(DashboardScreen, skipOffstage: false),
        matching: match,
      );

  testWidgets('dashboard meets the Scaffold/Container checklist', (
    WidgetTester tester,
  ) async {
    await bootSignedIn(tester);

    // 1. Application structure
    expect(find.byType(MaterialApp), findsWidgets);
    expect(find.byType(Scaffold, skipOffstage: false), findsWidgets);
    expect(find.byType(SafeArea, skipOffstage: false), findsWidgets);
    expect(
      dashboardDescendants(tester, find.byType(Scrollable)),
      findsWidgets,
      reason: 'the dashboard has a scrollable body',
    );

    // 2. Container quantity: at least 10 meaningful Containers
    final List<Container> containers = tester
        .widgetList<Container>(
          dashboardDescendants(
            tester,
            find.byType(Container, skipOffstage: false),
          ),
        )
        .toList();
    expect(
      containers.length,
      greaterThanOrEqualTo(10),
      reason: 'at least 10 Container widgets on the dashboard',
    );

    // 7. Container techniques
    int margin = 0;
    int padding = 0;
    int alignment = 0;
    int constraints = 0;
    int boxDecoration = 0;
    int border = 0;
    int radius = 0;
    int shadow = 0;
    for (final Container c in containers) {
      // Count only real (non-zero) margins — EdgeInsets.zero on a card is
      // spacing evidence for nothing.
      if (c.margin != null && c.margin != EdgeInsets.zero) margin++;
      if (c.padding != null) padding++;
      if (c.alignment != null) alignment++;
      if (c.constraints != null) constraints++;
      final Decoration? d = c.decoration;
      if (d is BoxDecoration) {
        boxDecoration++;
        if (d.border != null) border++;
        if (d.borderRadius != null) radius++;
        if (d.boxShadow != null && d.boxShadow!.isNotEmpty) shadow++;
      }
    }
    // Explicit width/height: the stat tile and the avatar are measured on
    // screen (96px tall tile, 56x56 avatar).
    final Size statTile = tester.getSize(
      find
          .ancestor(of: find.text('Credits'), matching: find.byType(Container))
          .first,
    );
    expect(statTile.height, greaterThanOrEqualTo(90), reason: 'height');
    final Size avatar = tester.getSize(
      find
          .ancestor(of: find.text('AK'), matching: find.byType(Container))
          .first,
    );
    expect(avatar.width, greaterThanOrEqualTo(50), reason: 'width');
    expect(
      margin,
      greaterThanOrEqualTo(3),
      reason: 'margin separates the major dashboard sections',
    );
    expect(padding, greaterThanOrEqualTo(4), reason: 'padding');
    expect(alignment, greaterThanOrEqualTo(1), reason: 'alignment');
    expect(constraints, greaterThanOrEqualTo(1), reason: 'constraints');
    expect(boxDecoration, greaterThanOrEqualTo(5), reason: 'BoxDecoration');
    expect(border, greaterThanOrEqualTo(1), reason: 'border');
    expect(radius, greaterThanOrEqualTo(3), reason: 'border radius');
    expect(shadow, greaterThanOrEqualTo(1), reason: 'box shadow');
    expect(
      dashboardDescendants(
        tester,
        find.byWidgetPredicate(
          (Widget w) => w is Wrap || w is Row || w is Column || w is Stack,
        ),
      ),
      findsWidgets,
      reason: 'Row/Column/Wrap/Stack child composition',
    );

    // 4-7. Required sections
    expect(
      find.textContaining('Arun'),
      findsWidgets,
      reason: 'student profile greeting',
    );
    expect(find.text('AVIT2026CS001'), findsWidgets, reason: 'student ID');
    expect(
      find.textContaining('Computer Science'),
      findsWidgets,
      reason: 'programme',
    );
    expect(find.text('Semester'), findsWidgets, reason: 'academic indicator');
    expect(find.text('Attendance'), findsWidgets, reason: 'academic indicator');
    expect(find.text('Credits'), findsWidgets, reason: 'academic indicator');
    expect(
      find.text('Classes today'),
      findsWidgets,
      reason: 'academic indicator',
    );

    // 10. Reusable component used repeatedly
    expect(
      dashboardDescendants(tester, find.byType(AVITCard)).evaluate().length,
      greaterThanOrEqualTo(3),
      reason: 'reusable card component',
    );

    // 8-9. Interaction: tapping a Container produces visible feedback
    await tester.tap(dashboardDescendants(tester, find.text('Credits')).first);
    await pumpFrames(tester, count: 4);
    expect(
      find.textContaining('credits'),
      findsWidgets,
      reason: 'tap feedback via SnackBar',
    );

    // Lower sections live further down the lazy list — scroll them in.
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
    await pumpFrames(tester, count: 3);
    expect(find.text('Quick Services'), findsOneWidget, reason: 'quick access');
    expect(
      dashboardDescendants(
        tester,
        find.byType(AVITServiceCard),
      ).evaluate().length,
      greaterThanOrEqualTo(4),
      reason: 'at least four distinct campus services',
    );

    // Accessibility: quick-access tiles keep ~48 logical-pixel touch targets.
    final Size serviceTile = tester.getSize(
      dashboardDescendants(tester, find.byType(AVITServiceCard)).first,
    );
    expect(
      serviceTile.width,
      greaterThanOrEqualTo(48),
      reason: 'quick-access touch target width',
    );
    expect(
      serviceTile.height,
      greaterThanOrEqualTo(48),
      reason: 'quick-access touch target height',
    );

    await tester.scrollUntilVisible(
      find.text('Announcements'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(DashboardScreen, skipOffstage: false),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await pumpFrames(tester, count: 3);
    expect(
      find.text('Announcements'),
      findsOneWidget,
      reason: 'campus update section',
    );

    await tester.scrollUntilVisible(
      find.text('Upcoming Events'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(DashboardScreen, skipOffstage: false),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await pumpFrames(tester, count: 3);
    expect(
      find.text('Upcoming Events'),
      findsOneWidget,
      reason: 'student life section',
    );

    expect(tester.takeException(), isNull);
  });
}
