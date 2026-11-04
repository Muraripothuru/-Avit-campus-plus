import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/routes/app_routes.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/data/repositories/service_request_store.dart';
import 'package:avit_campus_plus/features/campus_services/service_records_screen.dart';
import 'package:avit_campus_plus/features/staff/admin_dashboard_screen.dart';
import 'package:avit_campus_plus/features/staff/admin_requests_screen.dart';
import 'package:avit_campus_plus/main.dart';
import 'package:avit_campus_plus/models/facility_booking.dart';

/// Admin operations inbox: the store's admin surface (all() plus
/// updateStatus), the status filter, and the screen flows — seeing every
/// request and booking, triaging a status and cancelling a booking.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, String> rec({
    String ref = 'SR-2026-1000',
    String subject = 'Projector shows no signal',
    String category = 'IT Helpdesk',
    String urgency = 'Normal',
    String name = 'Arun Kumar',
    String studentId = 'AVIT2026001',
    String status = 'Submitted',
    String createdAt = '2026-11-01T10:00:00.000',
  }) => <String, String>{
    'ref': ref,
    'subject': subject,
    'category': category,
    'urgency': urgency,
    'name': name,
    'studentId': studentId,
    'description': '',
    'status': status,
    'preferredDate': '',
    'createdAt': createdAt,
  };

  group('DemoServiceRequestStore admin surface', () {
    test('all() returns every record from every student', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final DemoServiceRequestStore store = DemoServiceRequestStore(
        persistence: await PrefsServiceRequestPersistence.tryCreate(),
      );
      await store.submit(<String, Object?>{
        'subject': 'Wifi drops in hostel',
        'category': 'IT Helpdesk',
        'urgency': 'High',
        'studentName': 'Arun Kumar',
        'studentId': 'AVIT2026001',
      });
      await store.submit(<String, Object?>{
        'subject': 'Fee receipt needed',
        'category': 'Finance',
        'urgency': 'Low',
        'studentName': 'Sita Menon',
        'studentId': 'AVIT2026042',
      });

      final List<Map<String, String>> all = await store.all();
      expect(all, hasLength(2));
      expect(
        all.map((Map<String, String> r) => r['name']).toList(),
        <String>['Sita Menon', 'Arun Kumar'],
        reason: 'newest first, both students present',
      );
      expect(await store.all(limit: 1), hasLength(1));
    });

    test('updateStatus mutates the record and survives a restart', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final DemoServiceRequestStore store = DemoServiceRequestStore(
        persistence: await PrefsServiceRequestPersistence.tryCreate(),
      );
      final String ref = await store.submit(<String, Object?>{
        'subject': 'Locker key replacement',
        'category': 'Hostel & Mess',
        'urgency': 'Normal',
        'studentId': 'AVIT2026001',
      });

      await store.updateStatus(ref, 'In progress');
      expect((await store.all()).single['status'], 'In progress');

      await store.updateStatus('SR-2026-0000', 'Resolved');
      expect(await store.all(), hasLength(1), reason: 'unknown refs are ignored');

      final DemoServiceRequestStore second = DemoServiceRequestStore(
        persistence: await PrefsServiceRequestPersistence.tryCreate(),
      );
      expect((await second.all()).single['status'], 'In progress');
    });

    test('the status filter narrows the list', () {
      final List<Map<String, String>> records = <Map<String, String>>[
        rec(ref: 'a', status: 'Submitted'),
        rec(ref: 'b', status: 'In progress'),
        rec(ref: 'c', status: 'Resolved'),
      ];

      expect(
        ServiceRecordQuery.apply(records, status: 'In progress')
            .map((Map<String, String> r) => r['ref'])
            .toList(),
        <String>['b'],
      );
      expect(
        ServiceRecordQuery.apply(records, status: 'Resolved').single['ref'],
        'c',
      );
      expect(ServiceRecordQuery.apply(records), hasLength(3));
    });
  });

  const String admin = 'admin@avit.ac.in';
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

  Future<AppState> openRoute(
    WidgetTester tester,
    String route, {
    String email = admin,
    Future<void> Function(AppState state)? seed,
  }) async {
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

    if (seed != null) await seed(state);

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamedAndRemoveUntil(route, (Route<dynamic> r) => false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await pumpFrames(tester, count: 6);
    return state;
  }

  testWidgets('admin sees every request and triages its status', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    String? feeRef;
    final AppState state = await openRoute(
      tester,
      Routes.adminRequests,
      seed: (AppState s) async {
        await s.submitServiceRequest(<String, Object?>{
          'subject': 'Projector shows no signal',
          'category': 'IT Helpdesk',
          'urgency': 'High',
          'studentName': 'Arun Kumar',
          'studentId': 'AVIT2026001',
          'description': 'The classroom projector shows no signal since morning.',
        });
        feeRef = await s.submitServiceRequest(<String, Object?>{
          'subject': 'Fee receipt needed',
          'category': 'Finance',
          'urgency': 'Low',
          'studentName': 'Sita Menon',
          'studentId': 'AVIT2026042',
        });
      },
    );

    expect(
      find.byType(AdminRequestsScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Requests (2)'), findsOneWidget);
    expect(find.text('Fee receipt needed'), findsOneWidget);
    expect(find.text('Sita Menon • AVIT2026042'), findsOneWidget);

    await tester.ensureVisible(find.text('Fee receipt needed'));
    await tester.pump();
    await tester.tap(find.text('Fee receipt needed'));
    await pumpFrames(tester, count: 4);
    expect(find.byType(AlertDialog), findsOneWidget);

    final TextButton update = tester.widget<TextButton>(
      find.byKey(const ValueKey<String>('update-status')),
    );
    expect(update.onPressed, isNull, reason: 'no change is no-op');

    await tester.tap(
      find.byKey(const ValueKey<String>('dialog-status-In progress')),
    );
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey<String>('update-status')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey<String>('update-status')));
    await pumpFrames(tester, count: 6);

    expect(find.text('Status updated to In progress'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(ValueKey<String>('record-$feeRef')),
        matching: find.text('In progress'),
      ),
      findsOneWidget,
      reason: 'the card now carries the new status chip',
    );

    await tester.tap(find.byKey(const ValueKey<String>('status-Resolved')));
    await tester.pump();
    expect(find.text('No matching requests'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('status-All')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(ValueKey<String>('record-$feeRef')),
        matching: find.text('In progress'),
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Projector shows no signal'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Projector shows no signal'), findsOneWidget);
    expect(find.text('Arun Kumar • AVIT2026001'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(state.user?.role, isNotNull);
  });

  testWidgets('admin sees every booking and can cancel one', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await openRoute(
      tester,
      Routes.adminRequests,
      seed: (AppState s) async {
        s.addFacilityBooking(
          Booking(
            facilityId: 'sports_hall',
            purpose: 'Basketball practice for the inter-college match',
            start: DateTime(2026, 11, 12, 15),
            end: DateTime(2026, 11, 12, 16),
            studentName: 'Arun Kumar',
            studentId: 'AVIT2026001',
          ),
        );
        s.addFacilityBooking(
          Booking(
            facilityId: 'lib_discussion',
            purpose: 'Group study for the mid-terms',
            start: DateTime(2026, 11, 13, 10),
            end: DateTime(2026, 11, 13, 11),
          ),
        );
      },
    );

    expect(find.text('No requests yet'), findsOneWidget);
    expect(find.text('Requests (0)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('view-bookings')));
    await tester.pump();

    expect(find.text('Bookings (2)'), findsOneWidget);
    expect(find.text('Sports Hall'), findsOneWidget);
    expect(find.text('Library Discussion Room'), findsOneWidget);
    expect(find.text('Arun Kumar • AVIT2026001'), findsOneWidget);
    expect(find.text('Student not recorded'), findsOneWidget);

    await tester.ensureVisible(find.text('Sports Hall'));
    await tester.pump();
    await tester.tap(find.text('Sports Hall'));
    await pumpFrames(tester, count: 4);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Sports Hall'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('cancel-booking')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-cancel-booking')),
    );
    await pumpFrames(tester, count: 6);

    expect(find.text('Booking cancelled'), findsOneWidget);
    expect(find.text('Bookings (1)'), findsOneWidget);
    expect(find.text('Sports Hall'), findsNothing);
    expect(find.text('Library Discussion Room'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the admin dashboard opens the operations inbox', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await openRoute(tester, Routes.admin);

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    await pumpFrames(tester, count: 15);
    await tester.scrollUntilVisible(
      find.text('Quick actions'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Quick actions'), findsOneWidget);

    await tester.ensureVisible(find.text('Requests & bookings'));
    await tester.pump();
    await tester.tap(find.text('Requests & bookings'));
    await pumpFrames(tester, count: 6);

    expect(
      find.byType(AdminRequestsScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('students cannot open the admin requests route', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await openRoute(tester, Routes.adminRequests, email: student);
    expect(find.text('Not available', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
