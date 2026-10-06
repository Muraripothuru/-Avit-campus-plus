import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/media/avatar_photo.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/core/utils/app_exception.dart';
import 'package:avit_campus_plus/core/routes/app_routes.dart';
import 'package:avit_campus_plus/data/datasources/demo_catalog.dart';
import 'package:avit_campus_plus/data/repositories/auth_repository.dart'
    show AuthResult;
import 'package:avit_campus_plus/features/campus_services/gate_pass_screen.dart';
import 'package:avit_campus_plus/features/campus_services/health_centre_screen.dart';
import 'package:avit_campus_plus/features/campus_services/lost_found_screen.dart';
import 'package:avit_campus_plus/features/profile/edit_profile_screen.dart';
import 'package:avit_campus_plus/features/search/search_screen.dart';
import 'package:avit_campus_plus/main.dart';
import 'package:avit_campus_plus/models/campus_services.dart';
import 'package:avit_campus_plus/models/user.dart';
import 'package:avit_campus_plus/widgets/avit_avatar.dart';

/// The four features added after the overflow sweep: profile editing, the
/// offline/sync indicator, global search, and lost & found / health centre.
void main() {
  const String student = 'student@avit.ac.in';
  const String password = 'Avit@2026Demo';

  AppDependencies deps() => AppDependencies(secureStore: InMemorySecureStore());

  Future<void> pumpFrames(
    WidgetTester tester, {
    int count = 6,
    Duration step = const Duration(milliseconds: 300),
  }) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  Future<AppState> boot(
    WidgetTester tester, {
    String? email,
    AvatarPhotoPicker? photos,
  }) async {
    final AppState state = AppState(
      AppDependencies(secureStore: InMemorySecureStore(), photoPicker: photos),
    );
    await tester.pumpWidget(AvitCampusPlus(state: state));
    await tester.pump();
    if (email != null) {
      final Future<bool> signedIn = state.signIn(
        identifier: email,
        password: password,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(await signedIn, isTrue, reason: 'sign-in for $email');
    }
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

  /// The scrollable that hosts [of], resolved without depending on [of]
  /// already being built (lazy lists only build what is on screen).
  Finder scrollerUnder(Finder of, Finder root) =>
      find.descendant(of: root, matching: find.byType(Scrollable)).first;

  // ---------------------------------------------------------------------
  // Repository rules
  // ---------------------------------------------------------------------

  group('lost & found rules', () {
    test('a reporter cannot claim their own report', () async {
      final AppDependencies d = deps();
      final List<LostFoundItem> items = await d.campus.lostFoundItems();
      final LostFoundItem mine = items.firstWhere(
        (LostFoundItem i) =>
            i.reportedById == DemoCatalog.student.studentId && i.isClaimable,
      );
      await expectLater(
        () => d.campus.claimLostFound(
          itemId: mine.id,
          claimedBy: DemoCatalog.student.fullName,
          claimedById: DemoCatalog.student.studentId!,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('a report needs a descriptive title and details', () async {
      final AppDependencies d = deps();
      await expectLater(
        () => d.campus.reportLostFound(
          kind: LostFoundKind.lost,
          title: 'bag',
          category: 'Bag',
          description: 'Too short to identify anything.',
          location: 'Library',
          reportedBy: 'Arun Kumar',
          reportedById: DemoCatalog.student.studentId!,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test(
      'reporting adds an item that can then be claimed by someone else',
      () async {
        final AppDependencies d = deps();
        final LostFoundItem filed = await d.campus.reportLostFound(
          kind: LostFoundKind.found,
          title: 'Blue umbrella near the amphitheatre',
          category: 'Other',
          description: 'Left leaning against the third row of seats.',
          location: 'Other',
          reportedBy: 'Cafeteria Staff',
          reportedById: 'cafeteria_1',
        );
        final LostFoundItem claimed = await d.campus.claimLostFound(
          itemId: filed.id,
          claimedBy: DemoCatalog.student.fullName,
          claimedById: DemoCatalog.student.studentId!,
        );
        expect(claimed.status, LostFoundStatus.claimed);
        expect(claimed.claimedBy, DemoCatalog.student.fullName);

        await expectLater(
          () => d.campus.claimLostFound(
            itemId: filed.id,
            claimedBy: 'Someone Else',
            claimedById: 'AVIT2023CS1004',
          ),
          throwsA(isA<AppException>()),
          reason: 'a claimed item cannot be claimed twice',
        );
      },
    );
  });

  group('health centre rules', () {
    test('a past slot is rejected', () async {
      final AppDependencies d = deps();
      await expectLater(
        () => d.campus.bookAppointment(
          serviceId: 'hs_1',
          patientName: DemoCatalog.student.fullName,
          studentId: DemoCatalog.student.studentId!,
          scheduledFor: DateTime.now().subtract(const Duration(hours: 3)),
          reason: 'Persistent fever since last night.',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('a vague reason is rejected', () async {
      final AppDependencies d = deps();
      await expectLater(
        () => d.campus.bookAppointment(
          serviceId: 'hs_1',
          patientName: DemoCatalog.student.fullName,
          studentId: DemoCatalog.student.studentId!,
          scheduledFor: DateTime.now().add(const Duration(days: 1)),
          reason: 'sick',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test(
      'booking succeeds and a completed visit cannot be cancelled',
      () async {
        final AppDependencies d = deps();
        final HealthAppointment booked = await d.campus.bookAppointment(
          serviceId: 'hs_2',
          patientName: DemoCatalog.student.fullName,
          studentId: DemoCatalog.student.studentId!,
          scheduledFor: DateTime.now().add(const Duration(days: 3, hours: 9)),
          reason: 'Sprained my ankle during practice yesterday evening.',
        );
        expect(booked.status, HealthAppointmentStatus.scheduled);

        final HealthAppointment cancelled = await d.campus.cancelAppointment(
          booked.id,
        );
        expect(cancelled.status, HealthAppointmentStatus.cancelled);

        final List<HealthAppointment> mine = await d.campus.myAppointments(
          DemoCatalog.student.studentId!,
        );
        final HealthAppointment completed = mine.firstWhere(
          (HealthAppointment a) =>
              a.status == HealthAppointmentStatus.completed,
        );
        await expectLater(
          () => d.campus.cancelAppointment(completed.id),
          throwsA(isA<AppException>()),
        );
      },
    );
  });

  group('profile edits', () {
    test('identity fields survive an edit', () async {
      final AppDependencies d = deps();
      final AuthResult initial = await d.auth.login(
        identifier: student,
        password: password,
      );
      final AppUser edited = await d.auth.updateProfile(
        initial.user.copyWith(
          fullName: 'Arun K',
          phone: '9000000000',
          email: 'attacker@example.com',
          avatarUrl: 'avit://avatar/0',
        ),
      );

      expect(edited.fullName, 'Arun K');
      expect(edited.phone, '9000000000');
      expect(edited.avatarUrl, 'avit://avatar/0');
      expect(
        edited.email,
        student,
        reason: 'email is decided by the institution, not the client',
      );
      expect(edited.studentId, DemoCatalog.student.studentId);
    });
  });

  // ---------------------------------------------------------------------
  // Widget flows
  // ---------------------------------------------------------------------

  testWidgets('a student edits their profile and the change is saved', (
    WidgetTester tester,
  ) async {
    final AppState state = await boot(tester, email: student);
    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamed(Routes.dashboard);
    await pumpFrames(tester, count: 4);
    nav.pushNamed(Routes.editProfile);
    await pumpFrames(tester, count: 8);

    expect(find.byType(EditProfileScreen, skipOffstage: false), findsOneWidget);

    final Finder fields = find.byType(TextFormField, skipOffstage: false);
    await tester.enterText(fields.at(0), 'Arun Kumar Reddy');
    await tester.pump(const Duration(milliseconds: 300));

    final Finder save = find.text('Save changes');
    final Finder scroller = scrollerUnder(
      save,
      find.byType(EditProfileScreen, skipOffstage: false),
    );
    await tester.scrollUntilVisible(save, 300, scrollable: scroller);
    await tester.pump();
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await pumpFrames(tester, count: 8);

    expect(state.user?.fullName, 'Arun Kumar Reddy');
    expect(
      find.byType(EditProfileScreen, skipOffstage: false),
      findsNothing,
      reason: 'saving pops back to the screen you came from',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an invalid mobile number blocks the save', (
    WidgetTester tester,
  ) async {
    final AppState state = await boot(tester, email: student);
    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamed(Routes.dashboard);
    await pumpFrames(tester, count: 4);
    nav.pushNamed(Routes.editProfile);
    await pumpFrames(tester, count: 8);

    final Finder fields = find.byType(TextFormField, skipOffstage: false);
    final String before = state.user!.phone;
    await tester.enterText(fields.at(2), '12345');
    await tester.pump(const Duration(milliseconds: 300));

    final Finder save = find.text('Save changes');
    final Finder scroller = scrollerUnder(
      save,
      find.byType(EditProfileScreen, skipOffstage: false),
    );
    await tester.scrollUntilVisible(save, 300, scrollable: scroller);
    await tester.pump();
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await pumpFrames(tester, count: 6);

    expect(
      find.byType(EditProfileScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'validation failure must not close the form',
    );
    expect(state.user?.phone, before, reason: 'nothing was persisted');

    final Finder error = find.text(
      'Enter a valid 10-digit mobile number',
      skipOffstage: false,
    );
    await tester.dragUntilVisible(error, scroller, const Offset(0, 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(error, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an offline shell shows a retry that clears on reconnect', (
    WidgetTester tester,
  ) async {
    final AppState state = await boot(tester, email: student);
    await openRoute(tester, Routes.dashboard);
    await pumpFrames(tester, count: 4);

    expect(find.textContaining("You're offline"), findsNothing);

    state.deps.connectivity.debugSet(false);
    await pumpFrames(tester, count: 4);
    expect(
      find.textContaining("You're offline"),
      findsOneWidget,
      reason: 'the banner appears as soon as the platform reports offline',
    );
    expect(find.text('Try again'), findsOneWidget);

    state.deps.connectivity.debugSet(true);
    await pumpFrames(tester, count: 4);
    expect(find.textContaining("You're offline"), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('global search finds a service and opens it', (
    WidgetTester tester,
  ) async {
    await boot(tester, email: student);
    await openRoute(tester, Routes.search);
    expect(find.byType(SearchScreen, skipOffstage: false), findsOneWidget);

    final Finder field = find.byType(TextField, skipOffstage: false);
    await tester.enterText(field, 'gate');
    await pumpFrames(tester, count: 6);

    final Finder gatePass = find.text('Gate Pass', skipOffstage: false);
    expect(gatePass, findsWidgets, reason: 'the service is in the results');

    await tester.tap(gatePass.last);
    await pumpFrames(tester, count: 10);
    expect(find.byType(GatePassScreen, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lost & found filters and files a report', (
    WidgetTester tester,
  ) async {
    await boot(tester, email: student);
    await openRoute(tester, Routes.lostFound);
    expect(find.byType(LostFoundScreen, skipOffstage: false), findsOneWidget);
    await pumpFrames(tester, count: 6);

    // Seeded reports are on screen.
    expect(
      find.text('AVIT college ID card — Rahul S.', skipOffstage: false),
      findsOneWidget,
    );

    // The student's own reports never offer a claim button.
    await tester.tap(find.text('Mine'));
    await pumpFrames(tester, count: 6);
    expect(find.text('This is mine — claim it'), findsNothing);
    expect(find.text('You reported this item.'), findsWidgets);

    await tester.tap(find.text('All'));
    await pumpFrames(tester, count: 6);

    await tester.tap(find.text('Report item').last);
    await pumpFrames(tester, count: 6);
    expect(find.text('Report an item'), findsOneWidget);

    final Finder fields = find.byType(TextFormField, skipOffstage: false);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'Blue water bottle');
    await tester.enterText(
      fields.at(1),
      'Left on the table outside the signal lab after the evening class.',
    );
    await tester.pump(const Duration(milliseconds: 300));

    final Finder submit = find.text('Report as lost');
    await tester.ensureVisible(submit);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(submit);
    await pumpFrames(tester, count: 12);

    expect(find.text('Report an item'), findsNothing);
    expect(
      find.text('Blue water bottle', skipOffstage: false),
      findsWidgets,
      reason: 'the filed report is listed',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a student claims somebody else\'s found item', (
    WidgetTester tester,
  ) async {
    await boot(tester, email: student);
    await openRoute(tester, Routes.lostFound);
    await pumpFrames(tester, count: 6);

    final Finder claim = find.text('This is mine — claim it');
    expect(claim, findsWidgets, reason: 'an open item is claimable');
    await tester.tap(claim.first);
    await pumpFrames(tester, count: 6);

    expect(find.text('Is this yours?'), findsOneWidget);
    await tester.tap(find.text('Yes, claim it'));
    await pumpFrames(tester, count: 12);

    expect(find.text('Is this yours?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a student books and then cancels a health appointment', (
    WidgetTester tester,
  ) async {
    await boot(tester, email: student);
    await openRoute(tester, Routes.healthCentre);
    expect(
      find.byType(HealthCentreScreen, skipOffstage: false),
      findsOneWidget,
    );
    await pumpFrames(tester, count: 6);

    // The seeded counselling slot is upcoming, so it offers a cancel action.
    final Finder cancel = find.text('Cancel appointment');
    expect(cancel, findsWidgets);
    await tester.tap(cancel.first);
    await pumpFrames(tester, count: 6);

    expect(find.text('Cancel appointment?'), findsOneWidget);
    await tester.tap(find.text('Yes, cancel it'));
    await pumpFrames(tester, count: 12);

    expect(find.text('Cancel appointment?'), findsNothing);
    expect(find.text('Cancel appointment'), findsNothing);
    expect(find.text('Cancelled'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a chosen picture is shown across the app, not just the profile',
    (WidgetTester tester) async {
      final AppState state = await boot(tester, email: student);
      final NavigatorState nav = tester.state<NavigatorState>(
        find.byType(Navigator),
      );

      nav.pushNamed(Routes.editProfile);
      await pumpFrames(tester, count: 8);
      expect(
        find.byType(EditProfileScreen, skipOffstage: false),
        findsOneWidget,
      );

      final Finder choice = find.byType(AvatarSilhouette);
      expect(choice, findsOneWidget, reason: 'no picture is selected yet');
      await tester.tap(choice);
      await pumpFrames(tester, count: 4);
      expect(
        find.byType(AvatarSilhouette),
        findsNWidgets(2),
        reason: 'the preview above the grid reflects the tap immediately',
      );

      final Finder save = find.text('Save changes');
      final Finder scroller = scrollerUnder(
        save,
        find.byType(EditProfileScreen, skipOffstage: false),
      );
      await tester.scrollUntilVisible(save, 300, scrollable: scroller);
      await tester.pump();
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save);
      await pumpFrames(tester, count: 10);

      expect(state.user?.avatarUrl, 'avit://avatar/0');

      // Back on the dashboard the greeting tile and the app bar carry the
      // picture now, without navigating anywhere new.
      final int before = find.byType(AvatarSilhouette).evaluate().length;
      expect(
        before,
        greaterThanOrEqualTo(2),
        reason: 'app bar + greeting tile',
      );

      // ...and so does the drawer header.
      await tester.tap(find.byTooltip('Open menu').first);
      await pumpFrames(tester, count: 8);
      expect(
        find.byType(AvatarSilhouette).evaluate().length,
        before + 1,
        reason: 'the drawer header joins them',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a student can upload their own picture and it shows everywhere', (
    WidgetTester tester,
  ) async {
    const String tinyPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    final AvatarPhotoPicker picker = AvatarPhotoPicker(
      source: () async => Uint8List.fromList(<int>[0]),
      encode: (Uint8List _) async => '${kAvatarDataPrefix}png;base64,$tinyPng',
    );

    final AppState state = await boot(tester, email: student, photos: picker);
    final Finder shots = find.byWidgetPredicate(
      (Widget w) => w is Image && w.image is MemoryImage,
    );

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamed(Routes.editProfile);
    await pumpFrames(tester, count: 8);
    expect(find.byType(EditProfileScreen, skipOffstage: false), findsOneWidget);
    expect(shots, findsNothing, reason: 'the account still shows initials');

    await tester.tap(find.byTooltip('Upload a photo'));
    await pumpFrames(tester, count: 6);
    expect(shots, findsOneWidget, reason: 'the preview adopts it at once');
    expect(
      state.user?.avatarUrl ?? '',
      isNot(contains('data:image')),
      reason: 'nothing is stored until the form is submitted',
    );

    final Finder save = find.text('Save changes');
    final Finder scroller = scrollerUnder(
      save,
      find.byType(EditProfileScreen, skipOffstage: false),
    );
    await tester.scrollUntilVisible(save, 300, scrollable: scroller);
    await tester.pump();
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await pumpFrames(tester, count: 10);

    expect(
      state.user?.avatarUrl ?? '',
      startsWith('${kAvatarDataPrefix}png;base64,'),
    );
    expect(
      shots.evaluate().length,
      greaterThanOrEqualTo(2),
      reason: 'app bar + greeting tile',
    );

    await tester.tap(find.byTooltip('Open menu').first);
    await pumpFrames(tester, count: 8);
    expect(
      shots.evaluate().length,
      greaterThanOrEqualTo(3),
      reason: 'plus the drawer header',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a picture that cannot be read is reported, not swallowed', (
    WidgetTester tester,
  ) async {
    final AvatarPhotoPicker picker = AvatarPhotoPicker(
      source: () async => Uint8List.fromList(<int>[1, 2, 3]),
      encode: (Uint8List _) async => null,
    );
    final AppState state = await boot(tester, email: student, photos: picker);

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamed(Routes.editProfile);
    await pumpFrames(tester, count: 8);

    expect(find.text('Your initials until you pick a picture'), findsOneWidget);

    await tester.tap(find.byTooltip('Upload a photo'));
    await pumpFrames(tester, count: 8);

    expect(
      find.text("We couldn't read that picture. Please try another one."),
      findsOneWidget,
    );
    expect(state.user?.avatarUrl ?? '', isNot(contains('data:image')));
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an oversized picture is refused with a message', (
    WidgetTester tester,
  ) async {
    final String huge = base64Encode(List<int>.filled(300 * 1024, 0));
    final AvatarPhotoPicker picker = AvatarPhotoPicker(
      source: () async => Uint8List.fromList(<int>[0]),
      encode: (Uint8List _) async => '${kAvatarDataPrefix}jpeg;base64,$huge',
    );
    final AppState state = await boot(tester, email: student, photos: picker);

    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator),
    );
    nav.pushNamed(Routes.editProfile);
    await pumpFrames(tester, count: 8);

    await tester.tap(find.byTooltip('Upload a photo'));
    await pumpFrames(tester, count: 8);

    expect(
      find.text('That picture is too large. Please pick a smaller one.'),
      findsOneWidget,
    );
    expect(state.user?.avatarUrl ?? '', isNot(contains('data:image')));
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  test('encodeAvatarPhoto scales a picture down and keeps it small', () async {
    final img.Image source = img.Image(width: 600, height: 400);
    for (int y = 0; y < 400; y++) {
      for (int x = 0; x < 600; x++) {
        source.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
      }
    }
    final Uint8List original = Uint8List.fromList(img.encodePng(source));

    final String? uri = await encodeAvatarPhoto(original);
    expect(uri, isNotNull);
    expect(uri!.startsWith('${kAvatarDataPrefix}jpeg;base64,'), isTrue);

    final Uint8List encoded = base64Decode(uri.substring(uri.indexOf(',') + 1));
    expect(encoded.lengthInBytes, lessThan(kMaxAvatarPhotoBytes));

    final img.Image? out = img.decodeImage(encoded);
    expect(out, isNotNull, reason: 'the result is a readable JPEG');
    expect(out!.width, 512);
    expect(out.height, 341);

    expect(await encodeAvatarPhoto(Uint8List.fromList(<int>[1, 2, 3])), isNull);
  });
}
