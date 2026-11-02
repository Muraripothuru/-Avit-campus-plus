import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/routes/app_routes.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/core/utils/formatters.dart';
import 'package:avit_campus_plus/features/campus_services/facility_booking_screen.dart';
import 'package:avit_campus_plus/main.dart';
import 'package:avit_campus_plus/models/facility_booking.dart';

/// Facility booking lab: the four rules boundaries (past, hours, 30-day
/// range, half-open overlap) as unit tests, plus the full form → review →
/// confirm flow, its rejection paths and cancellation as widget tests.
void main() {
  const String student = 'student@avit.ac.in';
  const String security = 'security@avit.ac.in';
  const String password = 'Avit@2026Demo';
  const String facility = 'Library Discussion Room';

  Future<void> pumpFrames(
    WidgetTester tester, {
    int count = 8,
    Duration step = const Duration(milliseconds: 300),
  }) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  /// Boots the app signed in and hands back the state so a test can seed
  /// bookings before the route opens. A tall window keeps every form control
  /// on screen so taps never need scrolling.
  Future<AppState> bootSignedIn(
    WidgetTester tester, {
    String email = student,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
    await pumpFrames(tester);
  }

  /// Tomorrow at 09:00 — always in the future, always inside the
  /// 08:00–22:00 window, so widget tests never depend on the wall clock.
  DateTime tomorrowMorning() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return today.add(const Duration(days: 1, hours: 9));
  }

  Future<void> pickDay(WidgetTester tester, DateTime target) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Select date'));
    await pumpFrames(tester, count: 3);

    final Finder dialog = find.byType(DatePickerDialog);
    expect(dialog, findsOneWidget, reason: 'the date picker must open');

    final DateTime now = DateTime.now();
    final bool otherMonth =
        target.year != now.year || target.month != now.month;
    if (otherMonth) {
      await tester.tap(
        find.descendant(of: dialog, matching: find.byIcon(Icons.chevron_right)),
      );
      await pumpFrames(tester, count: 3);
    }

    final Finder dayCell = find.descendant(
      of: dialog,
      matching: find.text('${target.day}'),
    );
    expect(dayCell, findsOneWidget, reason: 'day ${target.day} on the grid');
    await tester.tap(dayCell);
    await pumpFrames(tester, count: 2);

    // The day tap only selects — the dialog closes on OK.
    await tester.tap(find.descendant(of: dialog, matching: find.text('OK')));
    await pumpFrames(tester, count: 3);
    expect(find.byType(DatePickerDialog), findsNothing);
  }

  /// Types the time into the picker's hour/minute fields and sets AM/PM —
  /// dismissal never happens, only OK returns a value.
  Future<void> pickTime(
    WidgetTester tester, {
    required int hour,
    required int minute,
    required bool pm,
  }) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Select time'));
    await pumpFrames(tester, count: 3);

    final Finder dialog = find.byType(TimePickerDialog);
    expect(dialog, findsOneWidget, reason: 'the time picker must open');

    final Finder fields = find.descendant(
      of: dialog,
      matching: find.byType(TextField),
    );
    expect(fields, findsNWidgets(2), reason: 'hour and minute fields');
    await tester.enterText(fields.first, '$hour');
    await tester.pump();
    await tester.enterText(fields.last, minute.toString().padLeft(2, '0'));
    await tester.pump();

    await tester.tap(
      find.descendant(of: dialog, matching: find.text(pm ? 'PM' : 'AM')),
    );
    await pumpFrames(tester, count: 2);

    await tester.tap(find.descendant(of: dialog, matching: find.text('OK')));
    await pumpFrames(tester, count: 3);
    expect(find.byType(TimePickerDialog), findsNothing);
  }

  Future<void> fillForm(
    WidgetTester tester, {
    required DateTime day,
    required int hour,
    required int minute,
    required bool pm,
    String name = facility,
    String purpose = 'Group study session',
  }) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await pumpFrames(tester, count: 3);
    await tester.tap(find.text(name).last);
    await pumpFrames(tester, count: 3);

    await tester.enterText(find.byType(TextFormField).first, purpose);
    await tester.pump();

    await pickDay(tester, day);
    await pickTime(tester, hour: hour, minute: minute, pm: pm);
  }

  Future<void> tapReview(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Review booking'));
    await pumpFrames(tester, count: 4);
  }

  group('booking rules', () {
    // Fixed clock: Sunday 2 November 2026, 10:00 local.
    final DateTime now = DateTime(2026, 11, 2, 10, 0);

    String? slot({
      required String facilityId,
      required DateTime start,
      required DateTime end,
      List<Booking> bookings = const <Booking>[],
    }) => BookingRules.slot(
      facilityId: facilityId,
      start: start,
      end: end,
      bookings: bookings,
      now: now,
    );

    test('a start time already in the past is rejected', () {
      expect(
        slot(
          facilityId: 'lib_discussion',
          start: DateTime(2026, 11, 2, 9, 0),
          end: DateTime(2026, 11, 2, 10, 0),
        ),
        BookingRules.pastTime,
      );
    });

    test('21:30 plus 60 minutes runs past the 22:00 close', () {
      expect(
        slot(
          facilityId: 'lib_discussion',
          start: DateTime(2026, 11, 2, 21, 30),
          end: DateTime(2026, 11, 2, 22, 30),
        ),
        BookingRules.outsideHours,
      );
    });

    test('21:00 plus 60 minutes ends exactly at 22:00 and is allowed', () {
      expect(
        slot(
          facilityId: 'lib_discussion',
          start: DateTime(2026, 11, 2, 21, 0),
          end: DateTime(2026, 11, 2, 22, 0),
        ),
        isNull,
      );
    });

    test('a start before opening hours is rejected', () {
      expect(
        slot(
          facilityId: 'lib_discussion',
          start: DateTime(2026, 11, 3, 7, 0),
          end: DateTime(2026, 11, 3, 8, 0),
        ),
        BookingRules.outsideHours,
      );
    });

    test('a day beyond today plus 30 is rejected', () {
      expect(
        slot(
          facilityId: 'lib_discussion',
          start: DateTime(2026, 12, 3, 10, 0),
          end: DateTime(2026, 12, 3, 11, 0),
        ),
        BookingRules.dayRange,
      );
    });

    test('an overlapping slot on the same facility conflicts', () {
      final List<Booking> bookings = <Booking>[
        Booking(
          facilityId: 'lib_discussion',
          purpose: 'Existing session',
          start: DateTime(2026, 11, 2, 14, 0),
          end: DateTime(2026, 11, 2, 15, 0),
        ),
      ];
      expect(
        slot(
          facilityId: 'lib_discussion',
          start: DateTime(2026, 11, 2, 14, 30),
          end: DateTime(2026, 11, 2, 15, 30),
          bookings: bookings,
        ),
        BookingRules.conflict,
      );
    });

    test('a slot that merely touches the previous booking is free', () {
      final List<Booking> bookings = <Booking>[
        Booking(
          facilityId: 'lib_discussion',
          purpose: 'Existing session',
          start: DateTime(2026, 11, 2, 14, 0),
          end: DateTime(2026, 11, 2, 15, 0),
        ),
      ];
      expect(
        slot(
          facilityId: 'lib_discussion',
          start: DateTime(2026, 11, 2, 15, 0),
          end: DateTime(2026, 11, 2, 16, 0),
          bookings: bookings,
        ),
        isNull,
        reason: 'half-open intervals: 15:00 does not overlap 14:00–15:00',
      );
    });

    test('the same hour on a different facility does not conflict', () {
      final List<Booking> bookings = <Booking>[
        Booking(
          facilityId: 'lib_discussion',
          purpose: 'Existing session',
          start: DateTime(2026, 11, 2, 14, 0),
          end: DateTime(2026, 11, 2, 15, 0),
        ),
      ];
      expect(
        slot(
          facilityId: 'sports_hall',
          start: DateTime(2026, 11, 2, 14, 0),
          end: DateTime(2026, 11, 2, 15, 0),
          bookings: bookings,
        ),
        isNull,
      );
    });

    test('facility and purpose validators catch empty input', () {
      expect(BookingRules.facility(null), BookingRules.missingFacility);
      expect(BookingRules.facility(''), BookingRules.missingFacility);
      expect(BookingRules.facility('lib_discussion'), isNull);
      expect(BookingRules.purpose('   '), BookingRules.missingPurpose);
      expect(BookingRules.purpose('ab'), isNotNull);
      expect(BookingRules.purpose('Group study'), isNull);
    });
  });

  group('booking form', () {
    testWidgets('a student books a facility end to end', (
      WidgetTester tester,
    ) async {
      final AppState state = await bootSignedIn(tester);
      await openRoute(tester, Routes.facilityBooking);
      expect(
        find.byType(FacilityBookingScreen, skipOffstage: false),
        findsOneWidget,
      );

      final DateTime start = tomorrowMorning();
      await fillForm(tester, day: start, hour: 9, minute: 0, pm: false);
      await tester.tap(find.text('90 min'));
      await tester.pump();

      // The computed window is shown before anything is submitted.
      expect(
        find.text(
          'Starts: ${Formatters.dayShort.format(start)}, '
          '${Formatters.time.format(start)}',
        ),
        findsOneWidget,
      );
      final DateTime end = start.add(const Duration(minutes: 90));
      expect(
        find.text('Ends: ${Formatters.time.format(end)}'),
        findsOneWidget,
        reason: 'the 90-minute choice extends the computed end',
      );

      await tapReview(tester);
      expect(find.text('Confirm facility booking'), findsOneWidget);
      expect(find.textContaining(facility), findsWidgets);
      expect(find.textContaining('Purpose: Group study session'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await pumpFrames(tester, count: 4);

      expect(find.textContaining('Booking confirmed'), findsOneWidget);
      expect(state.facilityBookings, hasLength(1));
      final Booking saved = state.facilityBookings.single;
      expect(saved.facilityId, 'lib_discussion');
      expect(saved.purpose, 'Group study session');
      expect(saved.start, start);
      expect(saved.end, end);

      // The form resets and the booking lands in the confirmed list.
      expect(find.text('Choose a facility'), findsWidgets);
      expect(find.text('Select date'), findsOneWidget);
      expect(find.text('Select time'), findsOneWidget);
      expect(find.text('No bookings yet'), findsNothing);
      expect(find.text('Group study session'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelling the confirmation dialog saves nothing', (
      WidgetTester tester,
    ) async {
      final AppState state = await bootSignedIn(tester);
      await openRoute(tester, Routes.facilityBooking);

      await fillForm(
        tester,
        day: tomorrowMorning(),
        hour: 9,
        minute: 0,
        pm: false,
      );
      await tapReview(tester);
      expect(find.text('Confirm facility booking'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await pumpFrames(tester, count: 4);

      expect(find.text('Confirm facility booking'), findsNothing);
      expect(state.facilityBookings, isEmpty);
      expect(find.textContaining('Booking confirmed'), findsNothing);
      // The chosen values stay in the form for a second attempt.
      expect(find.text('Select date'), findsNothing);
      expect(find.text('Select time'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping outside the dialog saves nothing', (
      WidgetTester tester,
    ) async {
      final AppState state = await bootSignedIn(tester);
      await openRoute(tester, Routes.facilityBooking);

      await fillForm(
        tester,
        day: tomorrowMorning(),
        hour: 9,
        minute: 0,
        pm: false,
      );
      await tapReview(tester);
      expect(find.text('Confirm facility booking'), findsOneWidget);

      await tester.tapAt(const Offset(10, 1500));
      await pumpFrames(tester, count: 4);

      expect(find.text('Confirm facility booking'), findsNothing);
      expect(state.facilityBookings, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an overlapping slot is rejected before any dialog', (
      WidgetTester tester,
    ) async {
      final AppState state = await bootSignedIn(tester);
      final DateTime start = tomorrowMorning();
      state.addFacilityBooking(
        Booking(
          facilityId: 'lib_discussion',
          purpose: 'Already booked',
          start: start,
          end: start.add(const Duration(hours: 1)),
        ),
      );
      await openRoute(tester, Routes.facilityBooking);

      await fillForm(tester, day: start, hour: 9, minute: 0, pm: false);
      await tapReview(tester);

      expect(find.text(BookingRules.conflict), findsOneWidget);
      expect(find.text('Confirm facility booking'), findsNothing);
      expect(state.facilityBookings, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a slot before opening hours is rejected', (
      WidgetTester tester,
    ) async {
      final AppState state = await bootSignedIn(tester);
      await openRoute(tester, Routes.facilityBooking);

      // Tomorrow 07:00 — always future, always before the 08:00 open.
      final DateTime early = tomorrowMorning().add(const Duration(hours: -2));
      await fillForm(tester, day: early, hour: 7, minute: 0, pm: false);
      await tapReview(tester);

      expect(find.text(BookingRules.outsideHours), findsOneWidget);
      expect(find.text('Confirm facility booking'), findsNothing);
      expect(state.facilityBookings, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a start time already passed is rejected', (
      WidgetTester tester,
    ) async {
      final AppState state = await bootSignedIn(tester);
      await openRoute(tester, Routes.facilityBooking);

      // Midnight today is always behind the wall clock (bar one millisecond
      // at the turn of the day).
      final DateTime now = DateTime.now();
      final DateTime midnight = DateTime(now.year, now.month, now.day);
      await fillForm(tester, day: midnight, hour: 12, minute: 0, pm: false);
      await tapReview(tester);

      expect(find.text(BookingRules.pastTime), findsOneWidget);
      expect(find.text('Confirm facility booking'), findsNothing);
      expect(state.facilityBookings, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('submitting an empty form reports every missing field', (
      WidgetTester tester,
    ) async {
      final AppState state = await bootSignedIn(tester);
      await openRoute(tester, Routes.facilityBooking);

      await tapReview(tester);

      expect(find.text(BookingRules.missingFacility), findsWidgets);
      expect(find.text(BookingRules.missingPurpose), findsOneWidget);
      expect(find.textContaining(BookingRules.missingDay), findsOneWidget);
      expect(find.textContaining(BookingRules.missingTime), findsOneWidget);
      expect(find.text('Confirm facility booking'), findsNothing);
      expect(state.facilityBookings, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a confirmed booking can be cancelled after confirmation', (
      WidgetTester tester,
    ) async {
      final AppState state = await bootSignedIn(tester);
      final DateTime start = tomorrowMorning();
      state.addFacilityBooking(
        Booking(
          facilityId: 'sports_hall',
          purpose: 'Badminton practice',
          start: start,
          end: start.add(const Duration(hours: 1)),
        ),
      );
      await openRoute(tester, Routes.facilityBooking);

      final Finder rowCancel = find.widgetWithText(TextButton, 'Cancel');
      await tester.ensureVisible(rowCancel);
      await pumpFrames(tester, count: 2);
      await tester.tap(rowCancel);
      await pumpFrames(tester, count: 3);

      expect(find.text('Cancel this booking?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Yes, cancel'));
      await pumpFrames(tester, count: 4);

      expect(find.textContaining('Booking cancelled'), findsOneWidget);
      expect(state.facilityBookings, isEmpty);
      expect(find.text('No bookings yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('staff cannot open the student booking route', (
      WidgetTester tester,
    ) async {
      await bootSignedIn(tester, email: security);
      await openRoute(tester, Routes.facilityBooking);
      expect(find.text('Not available', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
