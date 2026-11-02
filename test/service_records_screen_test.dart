import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/data/repositories/service_request_store.dart';
import 'package:avit_campus_plus/features/campus_services/service_records_screen.dart';
import 'package:avit_campus_plus/features/campus_services/service_request_screen.dart';
import 'package:avit_campus_plus/main.dart';

/// Request records: the pure query, the shared_preferences persistence and
/// the records screen flow (search, urgency filter, details, restart).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, String> rec({
    String ref = 'SR-2026-1000',
    String subject = 'Projector shows no signal',
    String category = 'IT Helpdesk',
    String urgency = 'Normal',
    String name = 'Arun Kumar',
    String studentId = 'AVIT2026001',
    String description = '',
    String createdAt = '2026-11-01T10:00:00.000',
    String preferredDate = '',
  }) => <String, String>{
    'ref': ref,
    'subject': subject,
    'category': category,
    'urgency': urgency,
    'name': name,
    'studentId': studentId,
    'description': description,
    'status': 'Submitted',
    'preferredDate': preferredDate,
    'createdAt': createdAt,
  };

  group('ServiceRecordQuery', () {
    test('search matches subject, description, reference and name', () {
      final List<Map<String, String>> records = <Map<String, String>>[
        rec(ref: 'SR-2026-1001', subject: 'Wifi drops in hostel'),
        rec(
          ref: 'SR-2026-1002',
          subject: 'Fee receipt needed',
          name: 'Sita Menon',
          description: 'Semester payment confirmation for AB-204',
        ),
      ];

      expect(
        ServiceRecordQuery.apply(records, query: 'wifi')
            .map((Map<String, String> r) => r['ref'])
            .toList(),
        <String>['SR-2026-1001'],
      );
      expect(
        ServiceRecordQuery.apply(records, query: 'ab-204')
            .map((Map<String, String> r) => r['ref'])
            .toList(),
        <String>['SR-2026-1002'],
        reason: 'the description is searchable too',
      );
      expect(
        ServiceRecordQuery.apply(records, query: 'sr-2026-1002').single['ref'],
        'SR-2026-1002',
      );
      expect(
        ServiceRecordQuery.apply(records, query: 'arun').single['ref'],
        'SR-2026-1001',
      );
      expect(ServiceRecordQuery.apply(records, query: 'zzz'), isEmpty);
    });

    test('urgency and service filters narrow the list', () {
      final List<Map<String, String>> records = <Map<String, String>>[
        rec(ref: 'a', urgency: 'High', category: 'IT Helpdesk'),
        rec(ref: 'b', urgency: 'Low', category: 'Hostel & Mess'),
        rec(ref: 'c', urgency: 'High', category: 'Hostel & Mess'),
      ];

      expect(
        ServiceRecordQuery.apply(records, urgency: 'High')
            .map((Map<String, String> r) => r['ref'])
            .toList(),
        <String>['a', 'c'],
      );
      expect(
        ServiceRecordQuery.apply(records, service: 'Hostel & Mess')
            .map((Map<String, String> r) => r['ref'])
            .toList(),
        <String>['b', 'c'],
      );
      expect(
        ServiceRecordQuery.apply(records, urgency: 'Low', service: 'IT Helpdesk'),
        isEmpty,
      );
      expect(ServiceRecordQuery.apply(records), hasLength(3));
    });

    test('newest and oldest sorts follow createdAt', () {
      final List<Map<String, String>> records = <Map<String, String>>[
        rec(ref: 'old', createdAt: '2026-10-01T09:00:00.000'),
        rec(ref: 'new', createdAt: '2026-11-02T09:00:00.000'),
        rec(ref: 'mid', createdAt: '2026-10-15T09:00:00.000'),
      ];

      expect(
        ServiceRecordQuery.apply(records)
            .map((Map<String, String> r) => r['ref'])
            .toList(),
        <String>['new', 'mid', 'old'],
      );
      expect(
        ServiceRecordQuery.apply(records, sort: 'Oldest first')
            .map((Map<String, String> r) => r['ref'])
            .toList(),
        <String>['old', 'mid', 'new'],
      );
    });

    test('urgency sort ranks High, Normal, Low then unknown', () {
      final List<Map<String, String>> records = <Map<String, String>>[
        rec(ref: 'n', urgency: 'Normal'),
        rec(ref: 'x', urgency: 'Mystery'),
        rec(ref: 'l', urgency: 'Low'),
        rec(ref: 'h', urgency: 'High'),
      ];

      expect(
        ServiceRecordQuery.apply(records, sort: 'Urgency: High to Low')
            .map((Map<String, String> r) => r['ref'])
            .toList(),
        <String>['h', 'n', 'l', 'x'],
      );
    });

    test('student sort is alphabetical and preferred date leaves blanks last', () {
      final List<Map<String, String>> records = <Map<String, String>>[
        rec(ref: 'x', name: 'nita desai'),
        rec(ref: 'y', name: 'arun kumar'),
        rec(ref: 'z', name: 'chitra rao'),
      ];
      expect(
        ServiceRecordQuery.apply(records, sort: 'Student: A to Z')
            .map((Map<String, String> r) => r['ref'])
            .toList(),
        <String>['y', 'z', 'x'],
      );

      final List<Map<String, String>> dated = <Map<String, String>>[
        rec(ref: 'none'),
        rec(ref: 'late', preferredDate: '2026-12-01T00:00:00.000'),
        rec(ref: 'early', preferredDate: '2026-11-05T00:00:00.000'),
      ];
      expect(
        ServiceRecordQuery.apply(dated, sort: 'Preferred date')
            .map((Map<String, String> r) => r['ref'])
            .toList(),
        <String>['early', 'late', 'none'],
      );
    });

    test('servicesOf lists unique categories alphabetically', () {
      final List<Map<String, String>> records = <Map<String, String>>[
        rec(category: 'Transport & Mobility'),
        rec(category: 'IT Helpdesk'),
        rec(category: 'IT Helpdesk'),
        rec(category: ''),
      ];
      expect(
        ServiceRecordQuery.servicesOf(records),
        <String>['IT Helpdesk', 'Transport & Mobility'],
      );
    });
  });

  group('demo store persistence', () {
    test('submissions survive creating a fresh store instance', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final DemoServiceRequestStore first = DemoServiceRequestStore(
        persistence: await PrefsServiceRequestPersistence.tryCreate(),
      );
      final String ref = await first.submit(<String, Object?>{
        'subject': 'Locker key replacement',
        'category': 'Lost Student ID Card',
        'urgency': 'Low',
        'studentName': 'Arun Kumar',
        'studentId': 'AVIT2026001',
        'description': 'The old key snapped inside the locker last night.',
        'preferredDate': '2026-11-20T00:00:00.000',
      });
      expect(ref, startsWith('SR-'));

      // A brand-new store (as after an app restart) reads the same prefs.
      final DemoServiceRequestStore second = DemoServiceRequestStore(
        persistence: await PrefsServiceRequestPersistence.tryCreate(),
      );
      final List<Map<String, String>> records = await second.recent();
      expect(records, hasLength(1));
      final Map<String, String> record = records.single;
      expect(record['ref'], ref);
      expect(record['subject'], 'Locker key replacement');
      expect(record['description'], 'The old key snapped inside the locker last night.');
      expect(record['status'], 'Submitted');
      expect(record['preferredDate'], '2026-11-20T00:00:00.000');
      expect(DateTime.tryParse(record['createdAt'] ?? ''), isNotNull);
    });

    test('a broken persistence layer degrades to in-memory records', () async {
      final DemoServiceRequestStore store = DemoServiceRequestStore(
        persistence: _ThrowingPersistence(),
      );
      await store.submit(<String, Object?>{
        'subject': 'Still works offline',
        'category': 'Other',
        'urgency': 'Normal',
        'studentId': 'AVIT2026001',
      });
      final List<Map<String, String>> records = await store.recent();
      expect(records.single['subject'], 'Still works offline');
    });
  });

  const String student = 'student@avit.ac.in';
  const String warden = 'warden@avit.ac.in';
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

  Future<void> openRoute(
    WidgetTester tester,
    String route, {
    String email = student,
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

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamedAndRemoveUntil(route, (Route<dynamic> r) => false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await pumpFrames(tester, count: 6);
  }

  Future<void> fillDetails(WidgetTester tester, {String urgency = 'High'}) async {
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

    await tester.ensureVisible(find.text(urgency));
    await tester.pump();
    await tester.tap(find.text(urgency));
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

  Finder mainScrollable() => find
      .descendant(
        of: find.byType(ServiceRequestScreen),
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets('the empty records screen offers the start shortcut', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await openRoute(tester, '/service-records');

    expect(find.byType(ServiceRecordsScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('No requests yet'), findsOneWidget);
    expect(
      find.text(
        'Submit a campus service request and every submission is kept here '
        'for you.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Start a request'));
    await tester.pump();
    await tester.tap(find.text('Start a request'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await pumpFrames(tester, count: 4);
    expect(find.byType(ServiceRequestScreen, skipOffstage: false), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff cannot open the request records route', (
    WidgetTester tester,
  ) async {
    await openRoute(tester, '/service-records', email: warden);
    expect(find.text('Not available', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('See all opens records with search, urgency filter and details', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await openRoute(tester, '/service-request');
    await submitOneRequest(tester);

    await tester.scrollUntilVisible(
      find.text('Your recent requests'),
      400,
      scrollable: mainScrollable(),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Your recent requests'), findsOneWidget);

    await tester.ensureVisible(find.text('See all'));
    await tester.pump();
    await tester.tap(find.text('See all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byType(ServiceRecordsScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Projector shows no signal in AB-204'), findsOneWidget);
    expect(find.text('Showing 1 of 1 request'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);

    // Urgency chips filter the list.
    await tester.tap(find.byKey(const ValueKey<String>('urgency-Low')));
    await tester.pump();
    expect(find.text('No matching requests'), findsOneWidget);
    expect(find.text('Projector shows no signal in AB-204'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('urgency-All')));
    await tester.pump();
    expect(find.text('Projector shows no signal in AB-204'), findsOneWidget);

    // Free-text search narrows and restores.
    final Finder search = find.byType(TextField);
    expect(search, findsOneWidget);
    await tester.enterText(search, 'zzz-nothing');
    await tester.pump();
    expect(find.text('No matching requests'), findsOneWidget);

    await tester.enterText(search, 'projector');
    await tester.pump();
    expect(find.text('Projector shows no signal in AB-204'), findsOneWidget);

    // Clear filters resets the query (single occurrence while matching).
    expect(find.text('Clear filters'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.text('Showing 1 of 1 request'), findsOneWidget);

    // The detail sheet shows the stored fields.
    await tester.ensureVisible(find.text('View details'));
    await tester.pump();
    await tester.tap(find.text('View details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Request details'), findsOneWidget);
    expect(find.text('Reference'), findsOneWidget);
    expect(find.textContaining('SR-'), findsWidgets);
    expect(find.text('Description'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Request details'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('records submitted in one session open after a restart', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // Session one: submit and wait for the confirmation to land.
    await openRoute(tester, '/service-request');
    await submitOneRequest(tester);

    // Session two: a fresh AppState + widget tree, as after an app restart.
    final AppState restarted = AppState(
      AppDependencies(secureStore: InMemorySecureStore()),
    );
    await tester.pumpWidget(AvitCampusPlus(state: restarted));
    await tester.pump();
    final Future<bool> signedIn = restarted.signIn(
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
    nav.pushNamedAndRemoveUntil('/service-records', (Route<dynamic> r) => false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await pumpFrames(tester, count: 6);

    expect(
      find.byType(ServiceRecordsScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Projector shows no signal in AB-204'), findsOneWidget);
    expect(find.textContaining('SR-'), findsWidgets);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}

/// Persistence that always blows up — proves the store never depends on it.
class _ThrowingPersistence implements ServiceRequestPersistence {
  @override
  Future<List<Map<String, String>>?> read() async =>
      throw StateError('storage unavailable');

  @override
  Future<void> write(List<Map<String, String>> records) async =>
      throw StateError('storage unavailable');
}
