import '../../core/security/audit_log.dart';
import '../../core/utils/app_exception.dart';
import '../../models/campus_services.dart';
import '../../models/safety.dart';
import '../datasources/api_client.dart';
import '../datasources/demo_catalog.dart';
import '../datasources/local_store.dart';

/// Transport, smart queue, campus map, complaints and emergency services.
abstract class CampusRepository {
  Future<List<BusRoute>> busRoutes();
  Future<TransportRequest> requestSeat({
    required String routeId,
    required String studentId,
    required String pickupPoint,
    int seats = 1,
  });
  Future<List<QueueCounter>> queueCounters();
  Future<QueueCounter> takeToken(String counterId, String studentId);
  Future<List<CampusLocation>> locations();
  Future<List<Complaint>> myComplaints(String studentId);
  Future<Complaint> submitComplaint({
    required String category,
    required String subject,
    required String description,
    required String raisedBy,
    required String raisedById,
  });
  Future<EmergencyRequest> raiseEmergency({
    required EmergencyType type,
    required String raisedBy,
    required String locationNote,
    required bool locationShared,
    String notes = '',
  });
  Future<List<EmergencyRequest>> myEmergencies();

  // Lost & found -----------------------------------------------------------
  Future<List<LostFoundItem>> lostFoundItems();
  Future<LostFoundItem> reportLostFound({
    required LostFoundKind kind,
    required String title,
    required String category,
    required String description,
    required String location,
    required String reportedBy,
    required String reportedById,
    String contact = '',
  });
  Future<LostFoundItem> claimLostFound({
    required String itemId,
    required String claimedBy,
    required String claimedById,
  });

  // Health centre ----------------------------------------------------------
  Future<List<HealthService>> healthServices();
  Future<List<HealthAppointment>> myAppointments(String studentId);
  Future<HealthAppointment> bookAppointment({
    required String serviceId,
    required String patientName,
    required String studentId,
    required DateTime scheduledFor,
    required String reason,
  });
  Future<HealthAppointment> cancelAppointment(String appointmentId);
}

class DemoCampusRepository implements CampusRepository {
  DemoCampusRepository({
    required this.store,
    required this.audit,
    required this.studentNameOf,
  });

  final LocalStore store;
  final AuditLog audit;
  final String Function() studentNameOf;

  static Future<void> _delay([int ms = 280]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  @override
  Future<List<BusRoute>> busRoutes() async {
    await _delay();
    return DemoCatalog.busRoutes();
  }

  @override
  Future<TransportRequest> requestSeat({
    required String routeId,
    required String studentId,
    required String pickupPoint,
    int seats = 1,
  }) async {
    await _delay();
    final BusRoute? route = DemoCatalog.busRoutes()
        .where((BusRoute r) => r.id == routeId)
        .cast<BusRoute?>()
        .firstWhere((BusRoute? r) => r != null, orElse: () => null);
    if (route == null) throw AppException.notFound;
    if (!route.hasSeats) {
      throw const AppException(
        'This bus is full right now. Try another route.',
        kind: 'validation',
      );
    }
    return TransportRequest(
      id: 'tr_${DateTime.now().millisecondsSinceEpoch}',
      routeId: route.id,
      routeName: route.routeName,
      studentId: studentId,
      pickupPoint: pickupPoint,
      createdAt: DateTime.now(),
      status: 'Confirmed',
      seats: seats,
    );
  }

  @override
  Future<List<QueueCounter>> queueCounters() async {
    await _delay(220);
    return DemoCatalog.queueCounters()
        .map(
          (QueueCounter c) => QueueCounter(
            id: c.id,
            name: c.name,
            icon: c.icon,
            currentToken: c.currentToken,
            yourToken: store.queueTokens[c.id] ?? c.yourToken,
            avgServiceMinutes: c.avgServiceMinutes,
            location: c.location,
            open: c.open,
          ),
        )
        .toList();
  }

  @override
  Future<QueueCounter> takeToken(String counterId, String studentId) async {
    await _delay();
    final QueueCounter? counter = DemoCatalog.queueCounters()
        .where((QueueCounter c) => c.id == counterId)
        .cast<QueueCounter?>()
        .firstWhere((QueueCounter? c) => c != null, orElse: () => null);
    if (counter == null) throw AppException.notFound;
    if (!counter.open) {
      throw const AppException(
        'This counter is closed right now',
        kind: 'validation',
      );
    }
    if (store.queueTokens.containsKey(counterId)) {
      throw const AppException(
        'You already hold a token at this counter',
        kind: 'validation',
      );
    }
    final int token = counter.yourToken + 1;
    store.queueTokens[counterId] = token;
    return QueueCounter(
      id: counter.id,
      name: counter.name,
      icon: counter.icon,
      currentToken: counter.currentToken,
      yourToken: token,
      avgServiceMinutes: counter.avgServiceMinutes,
      location: counter.location,
      open: counter.open,
    );
  }

  @override
  Future<List<CampusLocation>> locations() async {
    await _delay(180);
    return DemoCatalog.locations();
  }

  @override
  Future<List<Complaint>> myComplaints(String studentId) async {
    await _delay();
    return List<Complaint>.of(store.complaints)
      ..sort((Complaint a, Complaint b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Complaint> submitComplaint({
    required String category,
    required String subject,
    required String description,
    required String raisedBy,
    required String raisedById,
  }) async {
    await _delay();
    if (subject.trim().length < 5) {
      throw const AppException(
        'Please give a more descriptive subject',
        kind: 'validation',
      );
    }
    final Complaint complaint = Complaint(
      id: 'cmp_${DateTime.now().millisecondsSinceEpoch}',
      category: category,
      subject: subject.trim(),
      description: description.trim(),
      raisedBy: raisedBy,
      createdAt: DateTime.now(),
    );
    store.complaints.insert(0, complaint);
    return complaint;
  }

  @override
  Future<EmergencyRequest> raiseEmergency({
    required EmergencyType type,
    required String raisedBy,
    required String locationNote,
    required bool locationShared,
    String notes = '',
  }) async {
    await _delay(520);
    final EmergencyRequest request = EmergencyRequest(
      id: 'em_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      raisedBy: raisedBy,
      raisedAt: DateTime.now(),
      locationNote: locationNote,
      locationShared: locationShared,
      notes: notes,
      status: EmergencyStatus.dispatched,
      responder: 'Campus Security Control Room',
    );
    store.emergencies.insert(0, request);
    audit.record(
      AuditAction.emergencyRaised,
      actorId: raisedBy,
      role: 'student',
      detail: type.label,
    );
    return request;
  }

  @override
  Future<List<EmergencyRequest>> myEmergencies() async {
    await _delay(160);
    return List<EmergencyRequest>.of(store.emergencies);
  }

  // ---------------------------------------------------------------------------
  // Lost & found
  // ---------------------------------------------------------------------------

  @override
  Future<List<LostFoundItem>> lostFoundItems() async {
    await _delay();
    return List<LostFoundItem>.of(store.lostFoundItems)
      ..sort(
        (LostFoundItem a, LostFoundItem b) => b.createdAt.compareTo(a.createdAt),
      );
  }

  @override
  Future<LostFoundItem> reportLostFound({
    required LostFoundKind kind,
    required String title,
    required String category,
    required String description,
    required String location,
    required String reportedBy,
    required String reportedById,
    String contact = '',
  }) async {
    await _delay();
    if (title.trim().length < 5) {
      throw const AppException(
        'Please describe the item in at least 5 characters',
        kind: 'validation',
      );
    }
    if (description.trim().length < 15) {
      throw const AppException(
        'Add a few more details so it can be identified',
        kind: 'validation',
      );
    }
    if (location.trim().isEmpty) {
      throw const AppException(
        'Tell us where the item was lost or found',
        kind: 'validation',
      );
    }
    final LostFoundItem item = LostFoundItem(
      id: 'lf_${DateTime.now().millisecondsSinceEpoch}',
      kind: kind,
      title: title.trim(),
      category: category,
      description: description.trim(),
      location: location.trim(),
      reportedBy: reportedBy,
      reportedById: reportedById,
      createdAt: DateTime.now(),
      contact: contact.trim(),
    );
    store.lostFoundItems.insert(0, item);
    return item;
  }

  @override
  Future<LostFoundItem> claimLostFound({
    required String itemId,
    required String claimedBy,
    required String claimedById,
  }) async {
    await _delay();
    final int index = store.lostFoundItems.indexWhere(
      (LostFoundItem i) => i.id == itemId,
    );
    if (index < 0) throw AppException.notFound;
    final LostFoundItem item = store.lostFoundItems[index];
    if (!item.isClaimable) {
      throw const AppException(
        'This item has already been claimed',
        kind: 'validation',
      );
    }
    if (item.ownedBy(claimedById)) {
      throw const AppException(
        'You reported this item — bring your ID to the help desk to close it',
        kind: 'validation',
      );
    }
    final LostFoundItem updated = item.copyWith(
      status: LostFoundStatus.claimed,
      claimedBy: claimedBy,
      claimedAt: DateTime.now(),
    );
    store.lostFoundItems[index] = updated;
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Health centre
  // ---------------------------------------------------------------------------

  @override
  Future<List<HealthService>> healthServices() async {
    await _delay(200);
    return DemoCatalog.healthServices();
  }

  @override
  Future<List<HealthAppointment>> myAppointments(String studentId) async {
    await _delay();
    return List<HealthAppointment>.of(store.healthAppointments)
      ..sort(
        (HealthAppointment a, HealthAppointment b) =>
            b.scheduledFor.compareTo(a.scheduledFor),
      );
  }

  @override
  Future<HealthAppointment> bookAppointment({
    required String serviceId,
    required String patientName,
    required String studentId,
    required DateTime scheduledFor,
    required String reason,
  }) async {
    await _delay();
    final HealthService? service = DemoCatalog.healthServices()
        .where((HealthService s) => s.id == serviceId)
        .cast<HealthService?>()
        .firstWhere((HealthService? s) => s != null, orElse: () => null);
    if (service == null) throw AppException.notFound;
    if (!service.walkIn && scheduledFor.difference(DateTime.now()).inHours < 2) {
      throw const AppException(
        'This service needs at least 2 hours notice — pick a later slot',
        kind: 'validation',
      );
    }
    if (scheduledFor.isBefore(DateTime.now())) {
      throw const AppException(
        'Appointments can only be booked for a future time',
        kind: 'validation',
      );
    }
    if (reason.trim().length < 10) {
      throw const AppException(
        'Describe the reason so the health centre can prepare',
        kind: 'validation',
      );
    }
    final bool clash = store.healthAppointments.any(
      (HealthAppointment a) =>
          a.studentId == studentId &&
          a.status == HealthAppointmentStatus.scheduled &&
          a.scheduledFor.difference(scheduledFor).abs().inMinutes < 60,
    );
    if (clash) {
      throw const AppException(
        'You already have an appointment within an hour of that time',
        kind: 'validation',
      );
    }

    final HealthAppointment appointment = HealthAppointment(
      id: 'ha_${DateTime.now().millisecondsSinceEpoch}',
      serviceId: service.id,
      serviceName: service.name,
      patientName: patientName,
      studentId: studentId,
      scheduledFor: scheduledFor,
      reason: reason.trim(),
      createdAt: DateTime.now(),
    );
    store.healthAppointments.insert(0, appointment);
    return appointment;
  }

  @override
  Future<HealthAppointment> cancelAppointment(String appointmentId) async {
    await _delay(220);
    final int index = store.healthAppointments.indexWhere(
      (HealthAppointment a) => a.id == appointmentId,
    );
    if (index < 0) throw AppException.notFound;
    final HealthAppointment appointment = store.healthAppointments[index];
    if (!appointment.canCancel) {
      throw const AppException(
        'Only scheduled appointments can be cancelled',
        kind: 'validation',
      );
    }
    final HealthAppointment updated = appointment.copyWith(
      status: HealthAppointmentStatus.cancelled,
    );
    store.healthAppointments[index] = updated;
    return updated;
  }
}

class RemoteCampusRepository implements CampusRepository {
  RemoteCampusRepository({required this.api, required this.audit});

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
  Future<List<BusRoute>> busRoutes() async => _items(
    await api.get('/transport/routes'),
    (Map<String, Object?> j) => BusRoute(
      id: j['id'] as String? ?? '',
      routeName: j['routeName'] as String? ?? '',
      busNumber: j['busNumber'] as String? ?? '',
      driverName: j['driverName'] as String? ?? '',
      driverPhone: j['driverPhone'] as String? ?? '',
      pickupPoints:
          (j['pickupPoints'] as List?)?.whereType<String>().toList() ??
          <String>[],
      departure: j['departure'] as String? ?? '',
      arrival: j['arrival'] as String? ?? '',
      totalSeats: (j['totalSeats'] as num?)?.toInt() ?? 0,
      bookedSeats: (j['bookedSeats'] as num?)?.toInt() ?? 0,
      status: j['status'] as String? ?? 'On time',
      ac: j['ac'] as bool? ?? true,
      lastUpdated: DateTime.tryParse(j['lastUpdated'] as String? ?? ''),
    ),
  );

  @override
  Future<TransportRequest> requestSeat({
    required String routeId,
    required String studentId,
    required String pickupPoint,
    int seats = 1,
  }) async {
    final Map<String, Object?> res = await api.post(
      '/transport/requests',
      body: <String, Object?>{
        'routeId': routeId,
        'pickupPoint': pickupPoint,
        'seats': seats,
      },
    );
    return TransportRequest(
      id: res['id'] as String? ?? '',
      routeId: routeId,
      routeName: res['routeName'] as String? ?? '',
      studentId: studentId,
      pickupPoint: pickupPoint,
      createdAt:
          DateTime.tryParse(res['createdAt'] as String? ?? '') ?? DateTime.now(),
      status: res['status'] as String? ?? 'Pending',
      seats: seats,
    );
  }

  @override
  Future<List<QueueCounter>> queueCounters() async => _items(
    await api.get('/queue'),
    (Map<String, Object?> j) => QueueCounter(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      icon: j['icon'] as String? ?? 'people',
      currentToken: (j['currentToken'] as num?)?.toInt() ?? 0,
      yourToken: (j['yourToken'] as num?)?.toInt() ?? 0,
      avgServiceMinutes: (j['avgServiceMinutes'] as num?)?.toInt() ?? 3,
      location: j['location'] as String? ?? '',
      open: j['open'] as bool? ?? true,
    ),
  );

  @override
  Future<QueueCounter> takeToken(String counterId, String studentId) async {
    final Map<String, Object?> res = await api.post('/queue/$counterId/token');
    return QueueCounter(
      id: counterId,
      name: res['name'] as String? ?? '',
      icon: res['icon'] as String? ?? 'people',
      currentToken: (res['currentToken'] as num?)?.toInt() ?? 0,
      yourToken: (res['yourToken'] as num?)?.toInt() ?? 0,
      avgServiceMinutes: (res['avgServiceMinutes'] as num?)?.toInt() ?? 3,
      location: res['location'] as String? ?? '',
      open: res['open'] as bool? ?? true,
    );
  }

  @override
  Future<List<CampusLocation>> locations() async => _items(
    await api.get('/campus/locations'),
    (Map<String, Object?> j) => CampusLocation(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      category: j['category'] as String? ?? '',
      description: j['description'] as String? ?? '',
      x: (j['x'] as num?)?.toDouble() ?? 0.5,
      y: (j['y'] as num?)?.toDouble() ?? 0.5,
      hours: j['hours'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
    ),
  );

  @override
  Future<List<Complaint>> myComplaints(String studentId) async => _items(
    await api.get('/complaints', query: <String, String>{'mine': '1'}),
    (Map<String, Object?> j) => Complaint(
      id: j['id'] as String? ?? '',
      category: j['category'] as String? ?? '',
      subject: j['subject'] as String? ?? '',
      description: j['description'] as String? ?? '',
      raisedBy: j['raisedBy'] as String? ?? '',
      createdAt:
          DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      status: j['status'] as String? ?? 'Open',
      response: j['response'] as String? ?? '',
      assignedTo: j['assignedTo'] as String? ?? '',
      rating: (j['rating'] as num?)?.toInt(),
    ),
  );

  @override
  Future<Complaint> submitComplaint({
    required String category,
    required String subject,
    required String description,
    required String raisedBy,
    required String raisedById,
  }) async {
    final Map<String, Object?> res = await api.post(
      '/complaints',
      body: <String, Object?>{
        'category': category,
        'subject': subject,
        'description': description,
      },
    );
    return Complaint(
      id: res['id'] as String? ?? '',
      category: category,
      subject: subject,
      description: description,
      raisedBy: raisedBy,
      createdAt: DateTime.now(),
      status: res['status'] as String? ?? 'Open',
    );
  }

  @override
  Future<EmergencyRequest> raiseEmergency({
    required EmergencyType type,
    required String raisedBy,
    required String locationNote,
    required bool locationShared,
    String notes = '',
  }) async {
    final Map<String, Object?> res = await api.post(
      '/emergency',
      body: <String, Object?>{
        'type': type.apiValue,
        'locationNote': locationNote,
        'locationShared': locationShared,
        'notes': notes,
      },
    );
    audit.record(
      AuditAction.emergencyRaised,
      actorId: raisedBy,
      role: 'student',
      detail: type.label,
    );
    return EmergencyRequest(
      id: res['id'] as String? ?? '',
      type: type,
      raisedBy: raisedBy,
      raisedAt: DateTime.now(),
      locationNote: locationNote,
      locationShared: locationShared,
      status: EmergencyStatus.dispatched,
      responder: res['responder'] as String? ?? 'Campus Security',
    );
  }

  @override
  Future<List<EmergencyRequest>> myEmergencies() async => _items(
    await api.get('/emergency'),
    (Map<String, Object?> j) => EmergencyRequest(
      id: j['id'] as String? ?? '',
      type: EmergencyType.values.firstWhere(
        (EmergencyType t) => t.apiValue == j['type'],
        orElse: () => EmergencyType.security,
      ),
      raisedBy: j['raisedBy'] as String? ?? '',
      raisedAt:
          DateTime.tryParse(j['raisedAt'] as String? ?? '') ?? DateTime.now(),
      locationNote: j['locationNote'] as String? ?? '',
      locationShared: j['locationShared'] as bool? ?? false,
      status: EmergencyStatus.values.firstWhere(
        (EmergencyStatus s) => s.name == j['status'],
        orElse: () => EmergencyStatus.raised,
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Lost & found
  // ---------------------------------------------------------------------------

  @override
  Future<List<LostFoundItem>> lostFoundItems() async => _items(
    await api.get('/lost-found'),
    (Map<String, Object?> j) => LostFoundItem.fromJson(j),
  );

  @override
  Future<LostFoundItem> reportLostFound({
    required LostFoundKind kind,
    required String title,
    required String category,
    required String description,
    required String location,
    required String reportedBy,
    required String reportedById,
    String contact = '',
  }) async {
    final Map<String, Object?> res = await api.post(
      '/lost-found',
      body: <String, Object?>{
        'kind': kind.apiValue,
        'title': title.trim(),
        'category': category,
        'description': description.trim(),
        'location': location.trim(),
        'contact': contact.trim(),
      },
    );
    return LostFoundItem.fromJson(<String, Object?>{
      ...res,
      'reportedBy': reportedBy,
      'reportedById': reportedById,
      if (!res.containsKey('createdAt')) 'createdAt': DateTime.now().toIso8601String(),
      if (!res.containsKey('status')) 'status': 'open',
      if (!res.containsKey('kind')) 'kind': kind.apiValue,
      if (!res.containsKey('title')) 'title': title.trim(),
      if (!res.containsKey('category')) 'category': category,
      if (!res.containsKey('description')) 'description': description.trim(),
      if (!res.containsKey('location')) 'location': location.trim(),
      if (!res.containsKey('contact')) 'contact': contact.trim(),
    });
  }

  @override
  Future<LostFoundItem> claimLostFound({
    required String itemId,
    required String claimedBy,
    required String claimedById,
  }) async {
    final Map<String, Object?> res = await api.post('/lost-found/$itemId/claim');
    return LostFoundItem.fromJson(<String, Object?>{
      ...res,
      'id': res['id'] ?? itemId,
      'claimedBy': claimedBy,
      if (!res.containsKey('reportedBy')) 'reportedBy': '',
      if (!res.containsKey('reportedById')) 'reportedById': '',
      if (!res.containsKey('createdAt')) 'createdAt': DateTime.now().toIso8601String(),
      if (!res.containsKey('status')) 'status': 'claimed',
      if (!res.containsKey('kind')) 'kind': 'lost',
      if (!res.containsKey('title')) 'title': '',
      if (!res.containsKey('category')) 'category': '',
      if (!res.containsKey('description')) 'description': '',
      if (!res.containsKey('location')) 'location': '',
      if (!res.containsKey('claimedAt')) 'claimedAt': DateTime.now().toIso8601String(),
    });
  }

  // ---------------------------------------------------------------------------
  // Health centre
  // ---------------------------------------------------------------------------

  @override
  Future<List<HealthService>> healthServices() async => _items(
    await api.get('/health/services'),
    (Map<String, Object?> j) => HealthService(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      description: j['description'] as String? ?? '',
      location: j['location'] as String? ?? '',
      hours: j['hours'] as String? ?? '',
      fee: (j['fee'] as num?)?.toInt() ?? 0,
      phone: j['phone'] as String? ?? '',
      walkIn: j['walkIn'] as bool? ?? true,
    ),
  );

  @override
  Future<List<HealthAppointment>> myAppointments(String studentId) async =>
      _items(
        await api.get('/health/appointments', query: <String, String>{'mine': '1'}),
        (Map<String, Object?> j) => HealthAppointment.fromJson(j),
      );

  @override
  Future<HealthAppointment> bookAppointment({
    required String serviceId,
    required String patientName,
    required String studentId,
    required DateTime scheduledFor,
    required String reason,
  }) async {
    final Map<String, Object?> res = await api.post(
      '/health/appointments',
      body: <String, Object?>{
        'serviceId': serviceId,
        'scheduledFor': scheduledFor.toIso8601String(),
        'reason': reason.trim(),
      },
    );
    return HealthAppointment.fromJson(<String, Object?>{
      ...res,
      'serviceId': res['serviceId'] ?? serviceId,
      'patientName': patientName,
      'studentId': studentId,
      'scheduledFor': res['scheduledFor'] ?? scheduledFor.toIso8601String(),
      'reason': res['reason'] ?? reason.trim(),
      'createdAt': res['createdAt'] ?? DateTime.now().toIso8601String(),
      'serviceName': res['serviceName'] ?? '',
      'status': res['status'] ?? 'scheduled',
      'note': res['note'] ?? '',
    });
  }

  @override
  Future<HealthAppointment> cancelAppointment(String appointmentId) async {
    final Map<String, Object?> res = await api.post(
      '/health/appointments/$appointmentId/cancel',
    );
    return HealthAppointment.fromJson(<String, Object?>{
      ...res,
      'id': res['id'] ?? appointmentId,
      'serviceId': res['serviceId'] ?? '',
      'patientName': res['patientName'] ?? '',
      'studentId': res['studentId'] ?? '',
      'scheduledFor': res['scheduledFor'] ??
          DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'reason': res['reason'] ?? '',
      'createdAt': res['createdAt'] ?? DateTime.now().toIso8601String(),
      'serviceName': res['serviceName'] ?? '',
      'status': res['status'] ?? 'cancelled',
      'note': res['note'] ?? '',
    });
  }
}
