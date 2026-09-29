/// Approval lifecycle shared by gate and visitor passes.
enum PassStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  expired('Expired'),
  used('Used'),
  cancelled('Cancelled');

  const PassStatus(this.label);
  final String label;

  bool get isTerminal =>
      this == PassStatus.rejected ||
      this == PassStatus.expired ||
      this == PassStatus.used ||
      this == PassStatus.cancelled;

  bool get canBeUsed => this == PassStatus.approved;

  static PassStatus fromApi(String value) => PassStatus.values.firstWhere(
    (PassStatus s) => s.name == value,
    orElse: () => PassStatus.pending,
  );
}

/// A student's out-of-campus request.
class GatePass {
  const GatePass({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.reason,
    required this.destination,
    required this.outAt,
    required this.inBy,
    required this.createdAt,
    this.status = PassStatus.pending,
    this.reviewerComment = '',
    this.reviewedBy = '',
    this.reviewedAt,
    this.qrToken,
    this.usedAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String reason;
  final String destination;
  final DateTime outAt;
  final DateTime inBy;
  final DateTime createdAt;
  final PassStatus status;
  final String reviewerComment;
  final String reviewedBy;
  final DateTime? reviewedAt;
  final String? qrToken;
  final DateTime? usedAt;

  bool get isActiveWindow =>
      status == PassStatus.approved &&
      DateTime.now().isBefore(inBy) &&
      DateTime.now().isAfter(outAt.subtract(const Duration(hours: 2)));

  GatePass copyWith({
    PassStatus? status,
    String? reviewerComment,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? qrToken,
    DateTime? usedAt,
  }) => GatePass(
    id: id,
    studentId: studentId,
    studentName: studentName,
    reason: reason,
    destination: destination,
    outAt: outAt,
    inBy: inBy,
    createdAt: createdAt,
    status: status ?? this.status,
    reviewerComment: reviewerComment ?? this.reviewerComment,
    reviewedBy: reviewedBy ?? this.reviewedBy,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    qrToken: qrToken ?? this.qrToken,
    usedAt: usedAt ?? this.usedAt,
  );

  factory GatePass.fromJson(Map<String, Object?> json) => GatePass(
    id: json['id'] as String? ?? '',
    studentId: json['studentId'] as String? ?? '',
    studentName: json['studentName'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
    destination: json['destination'] as String? ?? '',
    outAt: DateTime.parse(json['outAt'] as String),
    inBy: DateTime.parse(json['inBy'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: PassStatus.fromApi(json['status'] as String? ?? 'pending'),
    reviewerComment: json['reviewerComment'] as String? ?? '',
    reviewedBy: json['reviewedBy'] as String? ?? '',
    reviewedAt: json['reviewedAt'] == null
        ? null
        : DateTime.tryParse(json['reviewedAt'] as String),
    qrToken: json['qrToken'] as String?,
    usedAt: json['usedAt'] == null
        ? null
        : DateTime.tryParse(json['usedAt'] as String),
  );
}

/// A visitor the student wants to invite on campus.
class VisitorPass {
  const VisitorPass({
    required this.id,
    required this.hostStudentId,
    required this.hostStudentName,
    required this.visitorName,
    required this.visitorPhone,
    required this.idType,
    required this.visitDate,
    required this.purpose,
    required this.createdAt,
    this.status = PassStatus.pending,
    this.reviewerComment = '',
    this.reviewedBy = '',
    this.qrToken,
    this.usedAt,
  });

  final String id;
  final String hostStudentId;
  final String hostStudentName;
  final String visitorName;
  final String visitorPhone;
  final String idType;
  final DateTime visitDate;
  final String purpose;
  final DateTime createdAt;
  final PassStatus status;
  final String reviewerComment;
  final String reviewedBy;
  final String? qrToken;
  final DateTime? usedAt;

  VisitorPass copyWith({
    PassStatus? status,
    String? reviewerComment,
    String? reviewedBy,
    String? qrToken,
    DateTime? usedAt,
  }) => VisitorPass(
    id: id,
    hostStudentId: hostStudentId,
    hostStudentName: hostStudentName,
    visitorName: visitorName,
    visitorPhone: visitorPhone,
    idType: idType,
    visitDate: visitDate,
    purpose: purpose,
    createdAt: createdAt,
    status: status ?? this.status,
    reviewerComment: reviewerComment ?? this.reviewerComment,
    reviewedBy: reviewedBy ?? this.reviewedBy,
    qrToken: qrToken ?? this.qrToken,
    usedAt: usedAt ?? this.usedAt,
  );

  factory VisitorPass.fromJson(Map<String, Object?> json) => VisitorPass(
    id: json['id'] as String? ?? '',
    hostStudentId: json['hostStudentId'] as String? ?? '',
    hostStudentName: json['hostStudentName'] as String? ?? '',
    visitorName: json['visitorName'] as String? ?? '',
    visitorPhone: json['visitorPhone'] as String? ?? '',
    idType: json['idType'] as String? ?? '',
    visitDate:
        DateTime.tryParse(json['visitDate'] as String? ?? '') ?? DateTime.now(),
    purpose: json['purpose'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    status: PassStatus.fromApi(json['status'] as String? ?? 'pending'),
    reviewerComment: json['reviewerComment'] as String? ?? '',
    reviewedBy: json['reviewedBy'] as String? ?? '',
    qrToken: json['qrToken'] as String?,
    usedAt: json['usedAt'] == null
        ? null
        : DateTime.tryParse(json['usedAt'] as String),
  );
}

/// One entry/exit record on the security log.
class GateMovement {
  const GateMovement({
    required this.id,
    required this.personName,
    required this.personId,
    required this.type, // entry | exit
    required this.time,
    this.method = 'QR',
    this.gate = 'Main Gate',
    this.vehicleNumber,
  });

  final String id;
  final String personName;
  final String personId;
  final String type;
  final DateTime time;
  final String method;
  final String gate;
  final String? vehicleNumber;
}

/// Result of scanning a pass at the gate.
class ScanResult {
  const ScanResult({
    required this.status,
    required this.message,
    this.title = '',
    this.detail = '',
    this.holderName = '',
  });

  final QrScanStatus status;
  final String message;
  final String title;
  final String detail;
  final String holderName;

  bool get isAccepted => status == QrScanStatus.valid;
}

enum QrScanStatus { valid, invalid, expired, used, revoked }

/// Vehicle details for transport verification.
class VehicleRecord {
  const VehicleRecord({
    required this.number,
    required this.owner,
    required this.type,
    this.verified = true,
  });

  final String number;
  final String owner;
  final String type;
  final bool verified;
}
