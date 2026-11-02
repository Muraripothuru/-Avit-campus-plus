import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/routes/app_routes.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/features/campus_services/library_screen.dart';
import 'package:avit_campus_plus/features/campus/service_detail_screen.dart';
import 'package:avit_campus_plus/features/content/announcement_detail_screen.dart';
import 'package:avit_campus_plus/features/content/campus_announcements_screen.dart';
import 'package:avit_campus_plus/features/content/services_grid_screen.dart';
import 'package:avit_campus_plus/main.dart';
import 'package:avit_campus_plus/models/campus_content.dart';

/// The student content section: the Announcements list (with bookmarks that
/// survive a detail round trip) and the responsive Services grid.
void main() {
  const String student = 'student@avit.ac.in';
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

  Future<void> bootSignedIn(WidgetTester tester, {String email = student}) async {
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
  }

  Future<void> openRoute(WidgetTester tester, String route) async {
    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamedAndRemoveUntil(route, (Route<dynamic> r) => false);
    await pumpFrames(tester);
  }

  Finder scrollerUnder(Finder of, Finder root) => find
      .descendant(of: root, matching: find.byType(Scrollable))
      .first;

  group('announcements list', () {
    testWidgets('shows all eight announcements, newest pinned first', (
      WidgetTester tester,
    ) async {
      await bootSignedIn(tester);
      await openRoute(tester, Routes.campusAnnouncements);

      expect(
        find.byType(CampusAnnouncementsScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Main Gate restricted entry 10 PM - 5 AM'), findsOneWidget);

      // The list is lazy — scroll the eighth item into the viewport.
      await tester.scrollUntilVisible(
        find.text('Guest Lecture: Zero Trust Architectures'),
        400,
        scrollable: scrollerUnder(
          find.byType(CampusAnnouncementsScreen),
          find.byType(CampusAnnouncementsScreen),
        ),
      );
      await pumpFrames(tester, count: 3);

      expect(
        find.text('Guest Lecture: Zero Trust Architectures'),
        findsOneWidget,
        reason: 'the eighth demo announcement must be reachable',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a bookmark survives the detail-screen round trip', (
      WidgetTester tester,
    ) async {
      await bootSignedIn(tester);
      await openRoute(tester, Routes.campusAnnouncements);
      await pumpFrames(tester);

      // Bookmark the first announcement from the list.
      await tester.tap(find.byTooltip('Bookmark').first);
      await pumpFrames(tester, count: 2);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);

      // Open its detail screen — the list stays mounted underneath.
      await tester.tap(find.text('Main Gate restricted entry 10 PM - 5 AM'));
      await pumpFrames(tester);
      expect(
        find.byType(AnnouncementDetailScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('Overnight entry is allowed only'),
        findsOneWidget,
        reason: 'the detail screen shows the full body',
      );
      expect(
        find.byIcon(Icons.bookmark_rounded),
        findsOneWidget,
        reason: 'the detail screen reflects the bookmark',
      );

      // Toggle the bookmark off from the detail screen, then go back.
      await tester.tap(find.byTooltip('Remove bookmark'));
      await pumpFrames(tester, count: 2);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await pumpFrames(tester);

      expect(
        find.byType(CampusAnnouncementsScreen, skipOffstage: false),
        findsOneWidget,
        reason: 'back reveals the list, not a new copy',
      );
      expect(
        find.byIcon(Icons.bookmark_rounded),
        findsNothing,
        reason: 'the list kept the toggle made on the detail screen',
      );
      expect(find.byIcon(Icons.bookmark_border_rounded), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('services grid', () {
    /// Resolves how many columns the grid laid out by measuring which tile
    /// sits below the first one: the first tile of row two is always in the
    /// same column as the first tile of row one.
    int columnsOf(WidgetTester tester) {
      Offset pos(int index) => tester.getTopLeft(
        find.byKey(ValueKey<String>(demoCampusServices[index].id)),
      );

      if ((pos(0).dx - pos(2).dx).abs() < 1) return 2;
      if ((pos(0).dx - pos(3).dx).abs() < 1) return 3;
      expect(
        (pos(0).dx - pos(4).dx).abs(),
        lessThan(1),
        reason: 'with four columns, tile 4 starts row two',
      );
      return 4;
    }

    testWidgets('reflows 2 / 3 / 4 columns by available width', (
      WidgetTester tester,
    ) async {
      Future<int> columnsAt(double width) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          const MaterialApp(home: ServicesGridScreen()),
        );
        await tester.pump();
        return columnsOf(tester);
      }

      expect(await columnsAt(400), 2, reason: 'phones get two columns');
      expect(await columnsAt(500), 3, reason: 'medium widths get three');
      expect(await columnsAt(800), 4, reason: 'wide layouts get four');
      expect(tester.takeException(), isNull);
    });

    testWidgets('tiles keep the lab aspect ratio of 1.2', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: ServicesGridScreen()));
      await tester.pump();

      final Size tile = tester.getSize(
        find.byKey(const ValueKey<String>('svc_library')),
      );
      expect(
        tile.width / tile.height,
        closeTo(1.2, 0.01),
        reason: 'grid childAspectRatio is 1.2',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('every tile label from the lab is on the grid', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: ServicesGridScreen()));
      await tester.pump();

      for (final CampusService service in demoCampusServices) {
        expect(find.text(service.label), findsOneWidget);
      }
      expect(demoCampusServices.length, 6);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tile opens its detail and the functional route', (
      WidgetTester tester,
    ) async {
      await bootSignedIn(tester);
      await openRoute(tester, Routes.servicesGrid);

      await tester.tap(find.text('Library'));
      await pumpFrames(tester);
      expect(
        find.byType(ServiceDetailScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('library@avit.ac.in'), findsOneWidget);

      // The returned result is confirmed with a SnackBar.
      await tester.tap(find.text('Request information'));
      await pumpFrames(tester);
      expect(find.textContaining('Request sent'), findsOneWidget);

      // Open Library pushes the functional route on top.
      await tester.tap(find.text('Library'));
      await pumpFrames(tester);
      await tester.tap(find.text('Open Library'));
      await pumpFrames(tester);
      expect(
        find.byType(LibraryScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('role gating', () {
    testWidgets('staff cannot open the student announcements route', (
      WidgetTester tester,
    ) async {
      await bootSignedIn(tester, email: security);
      await openRoute(tester, Routes.campusAnnouncements);
      expect(find.text('Not available', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('staff cannot open the services grid route', (
      WidgetTester tester,
    ) async {
      await bootSignedIn(tester, email: security);
      await openRoute(tester, Routes.servicesGrid);
      expect(find.text('Not available', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
