import 'package:flutter_test/flutter_test.dart';

import 'package:avit_campus_plus/app/app_state.dart';
import 'package:avit_campus_plus/core/security/secure_store.dart';
import 'package:avit_campus_plus/core/utils/app_exception.dart';
import 'package:avit_campus_plus/data/datasources/demo_catalog.dart';
import 'package:avit_campus_plus/data/repositories/auth_repository.dart';
import 'package:avit_campus_plus/data/repositories/staff_repository.dart';
import 'package:avit_campus_plus/models/announcement.dart';
import 'package:avit_campus_plus/models/app_notification.dart';
import 'package:avit_campus_plus/models/campus_event.dart';
import 'package:avit_campus_plus/models/campus_services.dart';
import 'package:avit_campus_plus/models/pass.dart';
import 'package:avit_campus_plus/models/safety.dart';
import 'package:avit_campus_plus/models/user.dart';

/// End-to-end coverage of every repository the UI depends on, exercised
/// exactly the way the app composes them (demo implementations).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppDependencies deps() => AppDependencies(
    secureStore: InMemorySecureStore(),
  );

  final String studentId = DemoCatalog.student.studentId!;

  group('auth', () {
    test('demo sign-in returns the seeded student', () async {
      final AppDependencies d = deps();
      final AuthResult result = await d.auth.login(
        identifier: 'student@avit.ac.in',
        password: 'Avit@2026Demo',
      );
      expect(result.user.role, UserRole.student);
      expect(result.user.email, 'student@avit.ac.in');
    });

    test('wrong password is rejected with a typed error', () async {
      final AppDependencies d = deps();
      await expectLater(
        () => d.auth.login(
          identifier: 'student@avit.ac.in',
          password: 'wrong-password',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('OTP request, verify and one-time-use enforcement', () async {
      final AppDependencies d = deps();
      await d.auth.requestOtp('student@avit.ac.in');
      final String? code = (d.auth as DemoAuthRepository).debugLastOtp;
      expect(code, isNotNull);
      expect(code, hasLength(6));
      await d.auth.verifyOtp('student@avit.ac.in', code!);
      await expectLater(
        () => d.auth.verifyOtp('student@avit.ac.in', code),
        throwsA(isA<AppException>()),
      );
    });

    test('session list works after sign-in and logout clears it', () async {
      final AppDependencies d = deps();
      await d.auth.login(
        identifier: 'student@avit.ac.in',
        password: 'Avit@2026Demo',
      );
      expect(await d.auth.sessions(), isNotEmpty);
      await d.auth.logout();
    });
  });

  group('academics content', () {
    test('every catalogue list is populated', () async {
      final AppDependencies d = deps();
      expect(await d.content.announcements(), isNotEmpty);
      expect(await d.content.courses(), isNotEmpty);
      expect(await d.content.timetable(), isNotEmpty);
      expect(await d.content.attendance(), isNotEmpty);
      expect(await d.content.exams(), isNotEmpty);
      expect(await d.content.academicCalendar(), isNotEmpty);
      expect(await d.content.overallAttendance(), inInclusiveRange(0, 100));
    });
  });

  group('activities', () {
    test('events, clubs and notifications are populated', () async {
      final AppDependencies d = deps();
      expect(await d.activities.events(), isNotEmpty);
      expect(await d.activities.clubs(), isNotEmpty);
      expect(await d.activities.notifications(), isNotEmpty);
    });

    test('registration round-trips and notifications can be cleared', () async {
      final AppDependencies d = deps();
      final String eventId = (await d.activities.events()).first.id;
      final CampusEvent registered = await d.activities.register(
        eventId: eventId,
      );
      expect(registered.registered, isTrue);
      final CampusEvent unregistered = await d.activities.unregister(
        eventId: eventId,
      );
      expect(unregistered.registered, isFalse);

      await d.activities.markAllRead();
      final notifications = await d.activities.notifications();
      expect(notifications, isNotEmpty);
      expect(notifications.every((AppNotification n) => n.read), isTrue);
    });
  });

  group('campus services', () {
    test('routes, queue counters and map locations exist', () async {
      final AppDependencies d = deps();
      expect(await d.campus.busRoutes(), isNotEmpty);
      expect(await d.campus.queueCounters(), isNotEmpty);
      expect(await d.campus.locations(), isNotEmpty);
    });

    test('transport seat request and queue token', () async {
      final AppDependencies d = deps();
      final BusRoute route = (await d.campus.busRoutes()).first;
      final TransportRequest seat = await d.campus.requestSeat(
        routeId: route.id,
        studentId: studentId,
        pickupPoint: route.pickupPoints.first,
      );
      expect(seat.routeId, route.id);

      final QueueCounter counter = (await d.campus.queueCounters()).first;
      final QueueCounter token = await d.campus.takeToken(
        counter.id,
        studentId,
      );
      expect(token.yourToken, greaterThan(0));
    });

    test('complaint is submitted and visible in history', () async {
      final AppDependencies d = deps();
      final Complaint complaint = await d.campus.submitComplaint(
        category: 'Academics',
        subject: 'Lab equipment not working',
        description: 'The oscilloscope in the signal lab powers off randomly.',
        raisedBy: DemoCatalog.student.fullName,
        raisedById: studentId,
      );
      expect(complaint.id, isNotEmpty);
      final List<Complaint> mine = await d.campus.myComplaints(studentId);
      expect(mine.any((Complaint c) => c.id == complaint.id), isTrue);
    });

    test('emergency is raised and listed', () async {
      final AppDependencies d = deps();
      final EmergencyRequest emergency = await d.campus.raiseEmergency(
        type: EmergencyType.medical,
        raisedBy: DemoCatalog.student.fullName,
        locationNote: 'Block B corridor',
        locationShared: true,
        notes: 'Student fainted during lab.',
      );
      expect(emergency.id, isNotEmpty);
      final List<EmergencyRequest> mine = await d.campus.myEmergencies();
      expect(mine.any((EmergencyRequest e) => e.id == emergency.id), isTrue);
    });
  });

  group('gate pass lifecycle', () {
    test('create, approve, QR scan, one-time use', () async {
      final AppDependencies d = deps();
      expect(await d.gatePasses.myPasses(studentId), isNotEmpty);
      expect(await d.gatePasses.pendingReview(), isNotEmpty);

      final GatePass created = await d.gatePasses.create(
        studentId: studentId,
        studentName: DemoCatalog.student.fullName,
        reason: 'Aadhaar update',
        destination: 'Post Office, Camp Road',
        outAt: DateTime.now().add(const Duration(days: 2, hours: 2)),
        inBy: DateTime.now().add(const Duration(days: 2, hours: 7)),
      );
      final GatePass approved = await d.gatePasses.decide(
        passId: created.id,
        approve: true,
        reviewer: 'Deepa Menon',
        comment: 'Approved for one day',
      );
      expect(approved.status, PassStatus.approved);
      expect(approved.qrToken, isNotNull);

      final ScanResult first = await d.gatePasses.verifyQr(approved.qrToken!);
      expect(first.status, QrScanStatus.valid);

      final ScanResult second = await d.gatePasses.verifyQr(approved.qrToken!);
      expect(second.status, QrScanStatus.used);
    });

    test('invalid time windows are rejected', () async {
      final AppDependencies d = deps();
      await expectLater(
        () => d.gatePasses.create(
          studentId: studentId,
          studentName: DemoCatalog.student.fullName,
          reason: 'Test',
          destination: 'Test',
          outAt: DateTime.now().add(const Duration(days: 9)),
          inBy: DateTime.now().add(const Duration(days: 8)),
        ),
        throwsA(isA<AppException>()),
      );

      // Overlaps the seeded approved pass window.
      final GatePass active = (await d.gatePasses.myPasses(studentId))
          .firstWhere((GatePass p) => p.status == PassStatus.approved);
      await expectLater(
        () => d.gatePasses.create(
          studentId: studentId,
          studentName: DemoCatalog.student.fullName,
          reason: 'Overlap probe',
          destination: 'Elsewhere',
          outAt: active.outAt.add(const Duration(hours: 1)),
          inBy: active.inBy.add(const Duration(hours: 1)),
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('visitor pass lifecycle', () {
    test('create, approve, QR scan, one-time use', () async {
      final AppDependencies d = deps();
      expect(await d.visitorPasses.myPasses(studentId), isNotEmpty);

      final VisitorPass created = await d.visitorPasses.create(
        hostStudentId: studentId,
        hostStudentName: DemoCatalog.student.fullName,
        visitorName: 'Ramesh Kumar',
        visitorPhone: '9840012345',
        idType: 'Aadhaar',
        visitDate: DateTime.now().add(const Duration(days: 1)),
        purpose: 'Parent visit',
      );
      expect(await d.visitorPasses.pendingReview(), isNotEmpty);

      final VisitorPass approved = await d.visitorPasses.decide(
        passId: created.id,
        approve: true,
        reviewer: 'Deepa Menon',
      );
      expect(approved.qrToken, isNotNull);

      final ScanResult first = await d.visitorPasses.verifyQr(
        approved.qrToken!,
      );
      expect(first.status, QrScanStatus.valid);
      final ScanResult second = await d.visitorPasses.verifyQr(
        approved.qrToken!,
      );
      expect(second.status, QrScanStatus.used);
    });

    test('visits in the past are rejected', () async {
      final AppDependencies d = deps();
      await expectLater(
        () => d.visitorPasses.create(
          hostStudentId: studentId,
          hostStudentName: DemoCatalog.student.fullName,
          visitorName: 'Old Visitor',
          visitorPhone: '9000000000',
          idType: 'Aadhaar',
          visitDate: DateTime.now().subtract(const Duration(days: 3)),
          purpose: 'Too late',
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('security desk', () {
    test('movements, incidents and active passes are populated', () async {
      final AppDependencies d = deps();
      expect(await d.security.activeGatePasses(), isNotEmpty);
      expect(await d.security.activeVisitorPasses(), isNotEmpty);
      expect(await d.security.recentMovements(), isNotEmpty);
      expect(await d.security.incidents(), isNotEmpty);
    });

    test('incident reporting validates the title', () async {
      final AppDependencies d = deps();
      await expectLater(
        () => d.security.reportIncident(
          title: 'Bad',
          description: 'Something happened near the gate.',
          severity: 'high',
          location: 'Main Gate',
          reportedBy: 'Security Desk',
        ),
        throwsA(isA<AppException>()),
      );
      final IncidentReport report = await d.security.reportIncident(
        title: 'Suspicious person near hostel',
        description: 'Unknown person photographing vehicles.',
        severity: 'high',
        location: 'Hostel Block A',
        reportedBy: 'Security Desk',
      );
      expect(report.id, isNotEmpty);
    });

    test('vehicle lookup matches the seeded plates only', () async {
      final AppDependencies d = deps();
      final VehicleRecord? known = await d.security.verifyVehicle(
        'tn 09 ab 4521',
      );
      expect(known, isNotNull);
      expect(known!.verified, isTrue);
      expect(await d.security.verifyVehicle('ZZ 99 ZZ 9999'), isNull);
    });
  });

  group('warden desk', () {
    test('requests, complaints and late returns are populated', () async {
      final AppDependencies d = deps();
      expect(await d.warden.gatePassRequests(), isNotEmpty);
      expect(await d.warden.visitorRequests(), isNotEmpty);
      expect(await d.warden.hostelComplaints(), isNotEmpty);
      expect(await d.warden.lateReturns(), isNotEmpty);
      expect(await d.warden.studentProfile(studentId), isNotNull);
    });
  });

  group('admin desk', () {
    test('stats, users and audit log are populated', () async {
      final AppDependencies d = deps();
      final AdminStats stats = await d.admin.stats();
      expect(stats.totalStudents, greaterThan(0));
      expect(stats.attendanceTrend, hasLength(greaterThan(1)));
      expect(stats.transportUsage, isNotEmpty);
      expect(await d.admin.users(), isNotEmpty);

      await d.admin.setUserRole(userId: 'u_p1', role: 'student');
      expect(await d.admin.auditLog(), isNotEmpty);
    });

    test('publishing an announcement is visible to students', () async {
      final AppDependencies d = deps();
      await d.admin.publishAnnouncement(
        title: 'Semester exam timetable published',
        body: 'Check the academics section for the detailed schedule.',
        category: AnnouncementCategory.academic,
      );
      final List<Announcement> list = await d.content.announcements();
      expect(
        list.any((Announcement a) => a.title == 'Semester exam timetable'),
        isFalse,
      );
      expect(
        list.any(
          (Announcement a) =>
              a.title == 'Semester exam timetable published',
        ),
        isTrue,
      );
    });

    test('creating an event is visible in activities', () async {
      final AppDependencies d = deps();
      final CampusEvent? created = await d.admin.createEvent(
        CampusEvent(
          id: 'ev_new',
          title: 'HackAVIT 2026',
          description: '24 hour hackathon.',
          startsAt: DateTime.now().add(const Duration(days: 10)),
          location: 'Innovation Lab',
          organizer: 'AVIT CSE',
          capacity: 120,
          registeredCount: 0,
        ),
      );
      expect(created, isNotNull);
      final List<CampusEvent> events = await d.activities.events();
      expect(
        events.any((CampusEvent e) => e.title == 'HackAVIT 2026'),
        isTrue,
      );
    });
  });
}
