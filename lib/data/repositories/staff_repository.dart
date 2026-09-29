import 'dart:convert';

import '../../core/security/audit_log.dart';
import '../../core/utils/app_exception.dart';
import '../../models/announcement.dart';
import '../../models/campus_event.dart';
import '../../models/pass.dart';
import '../../models/safety.dart';
import '../../models/user.dart';
import '../datasources/api_client.dart';
import '../datasources/demo_catalog.dart';
import '../datasources/local_store.dart';
import 'gate_pass_repository.dart';
import 'visitor_pass_repository.dart';

/// Security desk operations.
abstract class SecurityRepository {
  Future<List<GatePass>> activeGatePasses();
  Future<List<VisitorPass>> activeVisitorPasses();
  Future<List<GateMovement>> recentMovements();
  Future<List<IncidentReport>> incidents();
  Future<IncidentReport> reportIncident({
    required String title,
    required String description,
    required String severity,
    required String location,
    required String reportedBy,
  });
  Future<ScanResult> verifyPass(String rawQr);
  Future<VehicleRecord?> verifyVehicle(String number);
}

/// Warden (hostel) operations.
abstract class WardenRepository {
  Future<List<GatePass>> gatePassRequests();
  Future<List<VisitorPass>> visitorRequests();
  Future<List<Complaint>> hostelComplaints();
  Future<List<GateMovement>> lateReturns();
  Future<AppUser?> studentProfile(String studentId);
}

/// Administrator operations.
class AdminStats {
  const AdminStats({
    required this.totalStudents,
    required this.activeUsers,
    required this.pendingRequests,
    required this.activeGatePasses,
    required this.visitorsToday,
    required this.emergencyAlerts,
    required this.events,
    required this.complaints,
    required this.attendanceTrend,
    required this.gatePassTrend,
    required this.visitorTrend,
    required this.eventTrend,
    required this.transportUsage,
  });

  final int totalStudents;
  final int activeUsers;
  final int pendingRequests;
  final int activeGatePasses;
  final int visitorsToday;
  final int emergencyAlerts;
  final int events;
  final int complaints;
  final List<double> attendanceTrend;
  final List<double> gatePassTrend;
  final List<double> visitorTrend;
  final List<double> eventTrend;
  final List<(String, double)> transportUsage;
}

abstract class AdminRepository {
  Future<AdminStats> stats();
  Future<List<AppUser>> users();
  Future<void> publishAnnouncement({
    required String title,
    required String body,
    required AnnouncementCategory category,
  });
  Future<CampusEvent?> createEvent(CampusEvent draft);
  Future<void> setUserRole({required String userId, required String role});
  Future<List<AuditRow>> auditLog();
}

class AuditRow {
  const AuditRow({
    required this.action,
    required this.actor,
    required this.role,
    required this.time,
    this.detail = '',
  });
  final String action;
  final String actor;
  final String role;
  final DateTime time;
  final String detail;
}

// ------------------------------------------------------------------ security

class DemoSecurityRepository implements SecurityRepository {
  DemoSecurityRepository({
    required this.store,
    required this.audit,
    required this.gateRepository,
    required this.visitorRepository,
  });

  final LocalStore store;
  final AuditLog audit;
  final DemoGatePassRepository gateRepository;
  final DemoVisitorPassRepository visitorRepository;

  static Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 260));

  @override
  Future<List<GatePass>> activeGatePasses() async {
    await _delay();
    return store.gatePasses
        .where((GatePass p) => !p.status.isTerminal)
        .toList();
  }

  @override
  Future<List<VisitorPass>> activeVisitorPasses() async {
    await _delay();
    return store.visitorPasses
        .where((VisitorPass p) => !p.status.isTerminal)
        .toList();
  }

  @override
  Future<List<GateMovement>> recentMovements() async {
    await _delay();
    return DemoCatalog.movements();
  }

  @override
  Future<List<IncidentReport>> incidents() async {
    await _delay();
    return DemoCatalog.incidents();
  }

  @override
  Future<IncidentReport> reportIncident({
    required String title,
    required String description,
    required String severity,
    required String location,
    required String reportedBy,
  }) async {
    await _delay();
    if (title.trim().length < 5) {
      throw const AppException(
        'Please give a clearer title',
        kind: 'validation',
      );
    }
    audit.record(
      AuditAction.incidentReported,
      actorId: reportedBy,
      role: 'security',
      detail: title,
    );
    return IncidentReport(
      id: 'inc_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      description: description.trim(),
      severity: severity,
      location: location,
      reportedBy: reportedBy,
      reportedAt: DateTime.now(),
    );
  }

  @override
  Future<ScanResult> verifyPass(String rawQr) async {
    // A guard does not know which pass type was scanned, so try both.
    final String? hinted = _payloadType(rawQr);
    if (hinted == 'gate') return gateRepository.verifyQr(rawQr);
    if (hinted == 'visitor') return visitorRepository.verifyQr(rawQr);
    final ScanResult gate = await gateRepository.verifyQr(rawQr);
    if (gate.status != QrScanStatus.invalid) return gate;
    return visitorRepository.verifyQr(rawQr);
  }

  /// Best-effort local hint only. The server remains authoritative in live
  /// mode.
  static String? _payloadType(String raw) {
    try {
      final List<String> parts = raw.split('.');
      if (parts.length != 3) return null;
      final String padded = parts[1] + '=' * ((4 - parts[1].length % 4) % 4);
      final String decoded = utf8.decode(base64Url.decode(padded));
      return RegExp('"t":"([a-z]+)"').firstMatch(decoded)?.group(1);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<VehicleRecord?> verifyVehicle(String number) async {
    await _delay();
    final String query = number.trim().toUpperCase();
    for (final VehicleRecord v in DemoCatalog.vehicles()) {
      if (v.number.toUpperCase() == query) return v;
    }
    return null;
  }
}

/// Small adapters so [DemoSecurityRepository] can reuse the demo pass logic
/// without exposing store internals.
class DemoGatePassAdapter {
  DemoGatePassAdapter(this.store, this.audit);
  final LocalStore store;
  final AuditLog audit;

  Future<ScanResult> verify(String rawQr) async {
    final int index = store.gatePasses
        .indexWhere((GatePass p) => p.qrToken == rawQr);
    if (index < 0) {
      return const ScanResult(
        status: QrScanStatus.invalid,
        message: 'No gate pass matches this code',
        title: 'INVALID',
      );
    }
    final GatePass pass = store.gatePasses[index];
    if (pass.status == PassStatus.used) {
      return ScanResult(
        status: QrScanStatus.used,
        message: 'This pass was already used',
        title: 'ALREADY USED',
        holderName: pass.studentName,
      );
    }
    if (pass.status != PassStatus.approved) {
      return ScanResult(
        status: QrScanStatus.revoked,
        message: 'This pass is ${pass.status.label.toLowerCase()}',
        title: 'REVOKED',
        holderName: pass.studentName,
      );
    }
    if (pass.inBy.isBefore(DateTime.now())) {
      return ScanResult(
        status: QrScanStatus.expired,
        message: 'This pass expired on ${pass.inBy}',
        title: 'EXPIRED',
        holderName: pass.studentName,
      );
    }
    store.gatePasses[index] = pass.copyWith(
      status: PassStatus.used,
      usedAt: DateTime.now(),
    );
    audit.record(
      AuditAction.gatePassUsed,
      actorId: pass.studentId,
      role: 'security',
      detail: pass.id,
    );
    return ScanResult(
      status: QrScanStatus.valid,
      message: 'Exit allowed',
      title: 'VALID',
      holderName: pass.studentName,
    );
  }
}

class DemoVisitorPassAdapter {
  DemoVisitorPassAdapter(this.store);
  final LocalStore store;

  Future<ScanResult> verify(String rawQr) async {
    final int index = store.visitorPasses
        .indexWhere((VisitorPass p) => p.qrToken == rawQr);
    if (index < 0) {
      return const ScanResult(
        status: QrScanStatus.invalid,
        message: 'No visitor pass matches this code',
        title: 'INVALID',
      );
    }
    final VisitorPass pass = store.visitorPasses[index];
    if (pass.status == PassStatus.used) {
      return ScanResult(
        status: QrScanStatus.used,
        message: 'This pass was already used',
        title: 'ALREADY USED',
        holderName: pass.visitorName,
      );
    }
    if (pass.status != PassStatus.approved) {
      return ScanResult(
        status: QrScanStatus.revoked,
        message: 'This pass is ${pass.status.label.toLowerCase()}',
        title: 'REVOKED',
        holderName: pass.visitorName,
      );
    }
    if (pass.visitDate.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    )) {
      return ScanResult(
        status: QrScanStatus.expired,
        message: 'This pass expired on ${pass.visitDate}',
        title: 'EXPIRED',
        holderName: pass.visitorName,
      );
    }
    store.visitorPasses[index] = pass.copyWith(
      status: PassStatus.used,
      usedAt: DateTime.now(),
    );
    return ScanResult(
      status: QrScanStatus.valid,
      message: 'Visitor entry allowed',
      title: 'VALID',
      holderName: pass.visitorName,
    );
  }
}

class RemoteSecurityRepository implements SecurityRepository {
  RemoteSecurityRepository({required this.api, required this.audit});

  final ApiClient api;
  final AuditLog audit;

  static List<T> _items<T>(
    Map<String, Object?> res,
    T Function(Map<String, Object?>) map,
  ) {
    final Object? items = res['items'];
    if (items is! List) return <T>[];
    return items.whereType<Map<String, Object?>>().map(map).toList();
  }

  @override
  Future<List<GatePass>> activeGatePasses() async => _items(
    await api.get('/gate-passes', query: <String, String>{'status': 'active'}),
    GatePass.fromJson,
  );

  @override
  Future<List<VisitorPass>> activeVisitorPasses() async => _items(
    await api.get(
      '/visitor-passes',
      query: <String, String>{'status': 'active'},
    ),
    VisitorPass.fromJson,
  );

  @override
  Future<List<GateMovement>> recentMovements() async => _items(
    await api.get('/security/movements'),
    (Map<String, Object?> j) => GateMovement(
      id: j['id'] as String? ?? '',
      personName: j['personName'] as String? ?? '',
      personId: j['personId'] as String? ?? '',
      type: j['type'] as String? ?? 'entry',
      time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
      method: j['method'] as String? ?? 'QR',
      gate: j['gate'] as String? ?? 'Main Gate',
      vehicleNumber: j['vehicleNumber'] as String?,
    ),
  );

  @override
  Future<List<IncidentReport>> incidents() async => _items(
    await api.get('/security/incidents'),
    (Map<String, Object?> j) => IncidentReport(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      severity: j['severity'] as String? ?? 'low',
      location: j['location'] as String? ?? '',
      reportedBy: j['reportedBy'] as String? ?? '',
      reportedAt:
          DateTime.tryParse(j['reportedAt'] as String? ?? '') ?? DateTime.now(),
      status: j['status'] as String? ?? 'Open',
    ),
  );

  @override
  Future<IncidentReport> reportIncident({
    required String title,
    required String description,
    required String severity,
    required String location,
    required String reportedBy,
  }) async {
    final Map<String, Object?> res = await api.post(
      '/security/incidents',
      body: <String, Object?>{
        'title': title,
        'description': description,
        'severity': severity,
        'location': location,
      },
    );
    audit.record(
      AuditAction.incidentReported,
      actorId: reportedBy,
      role: 'security',
      detail: title,
    );
    return IncidentReport(
      id: res['id'] as String? ?? '',
      title: title,
      description: description,
      severity: severity,
      location: location,
      reportedBy: reportedBy,
      reportedAt: DateTime.now(),
    );
  }

  @override
  Future<ScanResult> verifyPass(String rawQr) async {
    try {
      final Map<String, Object?> res = await api.post(
        '/passes/scan',
        body: <String, Object?>{'code': rawQr},
      );
      final String status = res['status'] as String? ?? 'invalid';
      return ScanResult(
        status: switch (status) {
          'valid' => QrScanStatus.valid,
          'expired' => QrScanStatus.expired,
          'used' => QrScanStatus.used,
          'revoked' => QrScanStatus.revoked,
          _ => QrScanStatus.invalid,
        },
        message: res['message'] as String? ?? '',
        title: status.toUpperCase(),
        holderName: res['holderName'] as String? ?? '',
      );
    } catch (_) {
      return const ScanResult(
        status: QrScanStatus.invalid,
        message: 'Unable to verify this pass right now',
        title: 'INVALID',
      );
    }
  }

  @override
  Future<VehicleRecord?> verifyVehicle(String number) async {
    final Map<String, Object?> res = await api.get(
      '/security/vehicles',
      query: <String, String>{'number': number},
    );
    final Map<String, Object?>? item =
        res['item'] as Map<String, Object?>?;
    if (item == null) return null;
    return VehicleRecord(
      number: item['number'] as String? ?? number,
      owner: item['owner'] as String? ?? '',
      type: item['type'] as String? ?? '',
      verified: item['verified'] as bool? ?? false,
    );
  }
}

// ------------------------------------------------------------------- warden

class DemoWardenRepository implements WardenRepository {
  DemoWardenRepository(this.store);

  final LocalStore store;

  static Future<void> _delay([int ms = 250]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  @override
  Future<List<GatePass>> gatePassRequests() async {
    await _delay();
    return List<GatePass>.of(store.gatePasses)
      ..sort((GatePass a, GatePass b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<VisitorPass>> visitorRequests() async {
    await _delay();
    return List<VisitorPass>.of(store.visitorPasses)
      ..sort(
        (VisitorPass a, VisitorPass b) => b.createdAt.compareTo(a.createdAt),
      );
  }

  @override
  Future<List<Complaint>> hostelComplaints() async {
    await _delay();
    return store.complaints
        .where((Complaint c) => c.category == 'Hostel')
        .toList();
  }

  @override
  Future<List<GateMovement>> lateReturns() async {
    await _delay();
    return DemoCatalog.movements()
        .where((GateMovement m) => m.type == 'entry')
        .toList();
  }

  @override
  Future<AppUser?> studentProfile(String studentId) async {
    await _delay(180);
    if (studentId == DemoCatalog.student.studentId) return DemoCatalog.student;
    return AppUser(
      id: 'u_lookup',
      fullName: 'Priya Raghavan',
      email: 'student2@avit.ac.in',
      role: UserRole.student,
      studentId: studentId,
      programme: 'B.Tech Electronics and Communication',
      semester: 5,
      hostel: 'Block A — Room 118',
      emailVerified: true,
    );
  }
}

class RemoteWardenRepository implements WardenRepository {
  RemoteWardenRepository(this.api);

  final ApiClient api;

  static List<T> _items<T>(
    Map<String, Object?> res,
    T Function(Map<String, Object?>) map,
  ) {
    final Object? items = res['items'];
    if (items is! List) return <T>[];
    return items.whereType<Map<String, Object?>>().map(map).toList();
  }

  @override
  Future<List<GatePass>> gatePassRequests() async => _items(
    await api.get('/gate-passes', query: <String, String>{'scope': 'hostel'}),
    GatePass.fromJson,
  );

  @override
  Future<List<VisitorPass>> visitorRequests() async => _items(
    await api.get('/visitor-passes', query: <String, String>{'scope': 'hostel'}),
    VisitorPass.fromJson,
  );

  @override
  Future<List<Complaint>> hostelComplaints() async => _items(
    await api.get('/complaints', query: <String, String>{'category': 'Hostel'}),
    (Map<String, Object?> j) => Complaint(
      id: j['id'] as String? ?? '',
      category: j['category'] as String? ?? 'Hostel',
      subject: j['subject'] as String? ?? '',
      description: j['description'] as String? ?? '',
      raisedBy: j['raisedBy'] as String? ?? '',
      createdAt:
          DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      status: j['status'] as String? ?? 'Open',
      response: j['response'] as String? ?? '',
      assignedTo: j['assignedTo'] as String? ?? '',
    ),
  );

  @override
  Future<List<GateMovement>> lateReturns() async => _items(
    await api.get('/security/movements', query: <String, String>{'late': '1'}),
    (Map<String, Object?> j) => GateMovement(
      id: j['id'] as String? ?? '',
      personName: j['personName'] as String? ?? '',
      personId: j['personId'] as String? ?? '',
      type: j['type'] as String? ?? 'entry',
      time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
    ),
  );

  @override
  Future<AppUser?> studentProfile(String studentId) async {
    final Map<String, Object?> res = await api.get(
      '/students/$studentId',
    );
    final Map<String, Object?>? item = res['item'] as Map<String, Object?>?;
    return item == null ? null : AppUser.fromJson(item);
  }
}

// -------------------------------------------------------------------- admin

class DemoAdminRepository implements AdminRepository {
  DemoAdminRepository({
    required this.store,
    required this.audit,
    required this.isRemote,
  });

  final LocalStore store;
  final AuditLog audit;
  final bool isRemote;

  static Future<void> _delay([int ms = 300]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  @override
  Future<AdminStats> stats() async {
    await _delay();
    final int activeGatePasses = store.gatePasses
        .where((GatePass p) => p.status == PassStatus.approved)
        .length;
    final int visitorsToday = store.visitorPasses
        .where(
          (VisitorPass p) =>
              DateTime.now().difference(p.createdAt).inHours < 24,
        )
        .length;
    final int pending =
        store.gatePasses.where((GatePass p) => p.status == PassStatus.pending).length +
        store.visitorPasses
            .where((VisitorPass p) => p.status == PassStatus.pending)
            .length;

    return AdminStats(
      totalStudents: 4820,
      activeUsers: 3164,
      pendingRequests: pending,
      activeGatePasses: activeGatePasses,
      visitorsToday: visitorsToday,
      emergencyAlerts: store.emergencies.length,
      events: store.events.length,
      complaints: store.complaints
          .where((Complaint c) => c.status != 'Resolved')
          .length,
      attendanceTrend: const <double>[82, 84, 83, 86, 88, 87, 89],
      gatePassTrend: const <double>[38, 52, 44, 61, 49, 57, 43],
      visitorTrend: const <double>[22, 31, 27, 44, 36, 39, 48],
      eventTrend: const <double>[3, 5, 4, 8, 6, 9, 7],
      transportUsage: const <(String, double)>[
        ('Route 1', 0.85),
        ('Route 2', 1.0),
        ('Route 3', 0.68),
        ('Route 4', 0.48),
        ('Route 5', 0.92),
      ],
    );
  }

  @override
  Future<List<AppUser>> users() async {
    await _delay();
    return <AppUser>[
      for (final (UserRole _, AppUser user, String _) in DemoCatalog.accounts)
        user,
      const AppUser(
        id: 'u_p1',
        fullName: 'Priya Raghavan',
        email: 'student2@avit.ac.in',
        role: UserRole.student,
        studentId: 'AVIT2026EC014',
        programme: 'B.Tech Electronics and Communication',
        semester: 5,
        emailVerified: true,
      ),
      const AppUser(
        id: 'u_p2',
        fullName: 'Karthik Subramani',
        email: 'student3@avit.ac.in',
        role: UserRole.student,
        studentId: 'AVIT2026ME009',
        programme: 'B.Tech Mechanical Engineering',
        semester: 5,
        emailVerified: true,
      ),
    ];
  }

  @override
  Future<void> publishAnnouncement({
    required String title,
    required String body,
    required AnnouncementCategory category,
  }) async {
    await _delay();
    store.announcements.insert(
      0,
      Announcement(
        id: 'ann_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
        category: category,
        publishedAt: DateTime.now(),
        author: 'AVIT Administration',
      ),
    );
    audit.record(
      AuditAction.announcementPublished,
      actorId: 'admin',
      role: 'admin',
      detail: title,
    );
  }

  @override
  Future<CampusEvent?> createEvent(CampusEvent draft) async {
    await _delay();
    store.events.add(draft);
    return draft;
  }

  @override
  Future<void> setUserRole({
    required String userId,
    required String role,
  }) async {
    await _delay();
    audit.record(
      AuditAction.roleChanged,
      actorId: 'admin',
      role: 'admin',
      detail: '$userId → $role',
    );
  }

  @override
  Future<List<AuditRow>> auditLog() async {
    await _delay(160);
    return audit.entries
        .map(
          (e) => AuditRow(
            action: e.action.label,
            actor: e.actorId,
            role: e.role,
            time: e.timestamp,
            detail: e.detail,
          ),
        )
        .toList();
  }
}

class RemoteAdminRepository implements AdminRepository {
  RemoteAdminRepository({required this.api, required this.audit});

  final ApiClient api;
  final AuditLog audit;

  static List<T> _items<T>(
    Map<String, Object?> res,
    T Function(Map<String, Object?>) map,
  ) {
    final Object? items = res['items'];
    if (items is! List) return <T>[];
    return items.whereType<Map<String, Object?>>().map(map).toList();
  }

  @override
  Future<AdminStats> stats() async {
    final Map<String, Object?> res = await api.get('/admin/stats');
    return AdminStats(
      totalStudents: (res['totalStudents'] as num?)?.toInt() ?? 0,
      activeUsers: (res['activeUsers'] as num?)?.toInt() ?? 0,
      pendingRequests: (res['pendingRequests'] as num?)?.toInt() ?? 0,
      activeGatePasses: (res['activeGatePasses'] as num?)?.toInt() ?? 0,
      visitorsToday: (res['visitorsToday'] as num?)?.toInt() ?? 0,
      emergencyAlerts: (res['emergencyAlerts'] as num?)?.toInt() ?? 0,
      events: (res['events'] as num?)?.toInt() ?? 0,
      complaints: (res['complaints'] as num?)?.toInt() ?? 0,
      attendanceTrend: _doubles(res['attendanceTrend']),
      gatePassTrend: _doubles(res['gatePassTrend']),
      visitorTrend: _doubles(res['visitorTrend']),
      eventTrend: _doubles(res['eventTrend']),
      transportUsage: ((res['transportUsage'] as List?) ?? const <Object?>[])
          .whereType<Map<String, Object?>>()
          .map(
            (Map<String, Object?> j) => (
              j['name'] as String? ?? '',
              (j['value'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(),
    );
  }

  static List<double> _doubles(Object? value) => (value as List? ?? const [])
      .whereType<num>()
      .map((num n) => n.toDouble())
      .toList();

  @override
  Future<List<AppUser>> users() async => _items(
    await api.get('/admin/users'),
    AppUser.fromJson,
  );

  @override
  Future<void> publishAnnouncement({
    required String title,
    required String body,
    required AnnouncementCategory category,
  }) async {
    await api.post(
      '/announcements',
      body: <String, Object?>{
        'title': title,
        'body': body,
        'category': category.apiValue,
      },
    );
    audit.record(
      AuditAction.announcementPublished,
      actorId: 'admin',
      role: 'admin',
      detail: title,
    );
  }

  @override
  Future<CampusEvent?> createEvent(CampusEvent draft) async {
    final Map<String, Object?> res = await api.post(
      '/events',
      body: <String, Object?>{
        'title': draft.title,
        'description': draft.description,
        'startsAt': draft.startsAt.toIso8601String(),
        'location': draft.location,
        'organizer': draft.organizer,
        'capacity': draft.capacity,
        'category': draft.category,
      },
    );
    return CampusEvent.fromJson(res['item'] as Map<String, Object?>? ?? res);
  }

  @override
  Future<void> setUserRole({
    required String userId,
    required String role,
  }) async {
    await api.put('/admin/users/$userId/role', body: <String, Object?>{
      'role': role,
    });
    audit.record(
      AuditAction.roleChanged,
      actorId: 'admin',
      role: 'admin',
      detail: '$userId → $role',
    );
  }

  @override
  Future<List<AuditRow>> auditLog() async => _items(
    await api.get('/admin/audit-log'),
    (Map<String, Object?> j) => AuditRow(
      action: j['action'] as String? ?? '',
      actor: j['actor'] as String? ?? '',
      role: j['role'] as String? ?? '',
      time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
      detail: j['detail'] as String? ?? '',
    ),
  );
}
