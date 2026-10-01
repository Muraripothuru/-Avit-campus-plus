/// A campus bus route with timing and seat data.
class BusRoute {
  const BusRoute({
    required this.id,
    required this.routeName,
    required this.busNumber,
    required this.driverName,
    required this.driverPhone,
    required this.pickupPoints,
    required this.departure,
    required this.arrival,
    required this.totalSeats,
    required this.bookedSeats,
    this.status = 'On time',
    this.lastUpdated,
    this.ac = true,
  });

  final String id;
  final String routeName;
  final String busNumber;
  final String driverName;
  final String driverPhone;
  final List<String> pickupPoints;
  final String departure;
  final String arrival;
  final int totalSeats;
  final int bookedSeats;
  final String status;
  final DateTime? lastUpdated;
  final bool ac;

  int get availableSeats => (totalSeats - bookedSeats).clamp(0, totalSeats);
  bool get hasSeats => availableSeats > 0;
  double get occupancy => totalSeats == 0 ? 0 : bookedSeats / totalSeats;
}

/// A seat/request the student raised for a route.
class TransportRequest {
  const TransportRequest({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.studentId,
    required this.pickupPoint,
    required this.createdAt,
    this.status = 'Pending',
    this.seats = 1,
  });

  final String id;
  final String routeId;
  final String routeName;
  final String studentId;
  final String pickupPoint;
  final DateTime createdAt;
  final String status;
  final int seats;
}

/// Smart Queue (token) system.
class QueueCounter {
  const QueueCounter({
    required this.id,
    required this.name,
    required this.icon,
    required this.currentToken,
    required this.yourToken,
    required this.avgServiceMinutes,
    this.location = 'Admin Block, Ground Floor',
    this.open = true,
  });

  final String id;
  final String name;
  final String icon;
  final int currentToken;
  final int yourToken;
  final int avgServiceMinutes;
  final String location;
  final bool open;

  int get peopleAhead => (yourToken - currentToken).clamp(0, 999);
  int get estimatedWaitMinutes => peopleAhead * avgServiceMinutes;

  double get progress {
    if (peopleAhead <= 0) return 1;
    final int total = yourToken - currentToken > 0
        ? yourToken - currentToken
        : 1;
    final int served = 0;
    return (served / total).clamp(0, 1);
  }
}

/// A campus location for the map / search.
class CampusLocation {
  const CampusLocation({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.x, // normalised 0..1 coordinates on the campus canvas
    required this.y,
    this.hours = '',
    this.phone = '',
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final double x;
  final double y;
  final String hours;
  final String phone;

  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    final String q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q);
  }
}

/// Whether an item was lost by the reporter or found by them.
enum LostFoundKind {
  lost('Lost', 'lost'),
  found('Found', 'found');

  const LostFoundKind(this.label, this.apiValue);
  final String label;
  final String apiValue;

  static LostFoundKind fromApi(String value) =>
      LostFoundKind.values.firstWhere(
        (LostFoundKind k) => k.apiValue == value,
        orElse: () => LostFoundKind.lost,
      );
}

/// Lifecycle of a lost-and-found report.
enum LostFoundStatus {
  open('Open', 'open'),
  claimed('Claimed', 'claimed'),
  closed('Closed', 'closed');

  const LostFoundStatus(this.label, this.apiValue);
  final String label;
  final String apiValue;

  static LostFoundStatus fromApi(String value) =>
      LostFoundStatus.values.firstWhere(
        (LostFoundStatus s) => s.apiValue == value,
        orElse: () => LostFoundStatus.open,
      );
}

/// A lost-and-found report filed at the campus help desk.
class LostFoundItem {
  const LostFoundItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.category,
    required this.description,
    required this.location,
    required this.reportedBy,
    required this.reportedById,
    required this.createdAt,
    this.status = LostFoundStatus.open,
    this.contact = '',
    this.claimedBy = '',
    this.claimedAt,
  });

  final String id;
  final LostFoundKind kind;
  final String title;
  final String category;
  final String description;
  final String location;
  final String reportedBy;
  final String reportedById;
  final DateTime createdAt;
  final LostFoundStatus status;

  /// Phone or email the reporter is happy to be contacted on.
  final String contact;
  final String claimedBy;
  final DateTime? claimedAt;

  bool get isClaimable => status == LostFoundStatus.open;
  bool ownedBy(String studentId) =>
      studentId.isNotEmpty && reportedById == studentId;

  LostFoundItem copyWith({LostFoundStatus? status, String? claimedBy, DateTime? claimedAt}) =>
      LostFoundItem(
        id: id,
        kind: kind,
        title: title,
        category: category,
        description: description,
        location: location,
        reportedBy: reportedBy,
        reportedById: reportedById,
        createdAt: createdAt,
        status: status ?? this.status,
        contact: contact,
        claimedBy: claimedBy ?? this.claimedBy,
        claimedAt: claimedAt ?? this.claimedAt,
      );

  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    final String q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q) ||
        location.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q);
  }

  factory LostFoundItem.fromJson(Map<String, Object?> json) => LostFoundItem(
    id: json['id'] as String? ?? '',
    kind: LostFoundKind.fromApi(json['kind'] as String? ?? 'lost'),
    title: json['title'] as String? ?? '',
    category: json['category'] as String? ?? '',
    description: json['description'] as String? ?? '',
    location: json['location'] as String? ?? '',
    reportedBy: json['reportedBy'] as String? ?? '',
    reportedById: json['reportedById'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: LostFoundStatus.fromApi(json['status'] as String? ?? 'open'),
    contact: json['contact'] as String? ?? '',
    claimedBy: json['claimedBy'] as String? ?? '',
    claimedAt: json['claimedAt'] == null
        ? null
        : DateTime.tryParse(json['claimedAt'] as String),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.apiValue,
    'title': title,
    'category': category,
    'description': description,
    'location': location,
    'reportedBy': reportedBy,
    'reportedById': reportedById,
    'createdAt': createdAt.toIso8601String(),
    'status': status.apiValue,
    'contact': contact,
    'claimedBy': claimedBy,
    'claimedAt': claimedAt?.toIso8601String(),
  };
}

/// A service offered by the campus health centre.
class HealthService {
  const HealthService({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.hours,
    this.fee = 0,
    this.phone = '',
    this.walkIn = true,
  });

  final String id;
  final String name;
  final String description;
  final String location;
  final String hours;

  /// ₹0 means the service is free for enrolled students.
  final int fee;
  final String phone;
  final bool walkIn;

  String get feeLabel => fee == 0 ? 'Free' : '₹$fee';

  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    final String q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        location.toLowerCase().contains(q);
  }
}

/// Lifecycle of a health-centre appointment.
enum HealthAppointmentStatus {
  scheduled('Scheduled', 'scheduled'),
  completed('Completed', 'completed'),
  cancelled('Cancelled', 'cancelled');

  const HealthAppointmentStatus(this.label, this.apiValue);
  final String label;
  final String apiValue;

  static HealthAppointmentStatus fromApi(String value) =>
      HealthAppointmentStatus.values.firstWhere(
        (HealthAppointmentStatus s) => s.apiValue == value,
        orElse: () => HealthAppointmentStatus.scheduled,
      );
}

/// A slot booked at the campus health centre.
class HealthAppointment {
  const HealthAppointment({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.patientName,
    required this.studentId,
    required this.scheduledFor,
    required this.reason,
    required this.createdAt,
    this.status = HealthAppointmentStatus.scheduled,
    this.note = '',
  });

  final String id;
  final String serviceId;
  final String serviceName;
  final String patientName;
  final String studentId;
  final DateTime scheduledFor;
  final String reason;
  final DateTime createdAt;
  final HealthAppointmentStatus status;

  /// Health-centre remark, filled in after the visit.
  final String note;

  bool get canCancel => status == HealthAppointmentStatus.scheduled;
  bool ownedBy(String studentId) =>
      studentId.isNotEmpty && this.studentId == studentId;

  HealthAppointment copyWith({HealthAppointmentStatus? status, String? note}) =>
      HealthAppointment(
        id: id,
        serviceId: serviceId,
        serviceName: serviceName,
        patientName: patientName,
        studentId: studentId,
        scheduledFor: scheduledFor,
        reason: reason,
        createdAt: createdAt,
        status: status ?? this.status,
        note: note ?? this.note,
      );

  factory HealthAppointment.fromJson(Map<String, Object?> json) =>
      HealthAppointment(
        id: json['id'] as String? ?? '',
        serviceId: json['serviceId'] as String? ?? '',
        serviceName: json['serviceName'] as String? ?? '',
        patientName: json['patientName'] as String? ?? '',
        studentId: json['studentId'] as String? ?? '',
        scheduledFor: DateTime.parse(json['scheduledFor'] as String),
        reason: json['reason'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: HealthAppointmentStatus.fromApi(
          json['status'] as String? ?? 'scheduled',
        ),
        note: json['note'] as String? ?? '',
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'serviceId': serviceId,
    'serviceName': serviceName,
    'patientName': patientName,
    'studentId': studentId,
    'scheduledFor': scheduledFor.toIso8601String(),
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
    'status': status.apiValue,
    'note': note,
  };
}
