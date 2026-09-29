/// Emergency request raised by a user.
class EmergencyRequest {
  const EmergencyRequest({
    required this.id,
    required this.type,
    required this.raisedBy,
    required this.raisedAt,
    required this.locationNote,
    this.locationShared = false,
    this.status = EmergencyStatus.dispatched,
    this.notes = '',
    this.responder = '',
  });

  final String id;
  final EmergencyType type;
  final String raisedBy;
  final DateTime raisedAt;
  final String locationNote;
  final bool locationShared;
  final EmergencyStatus status;
  final String notes;
  final String responder;

  EmergencyRequest copyWith({EmergencyStatus? status, String? responder}) =>
      EmergencyRequest(
        id: id,
        type: type,
        raisedBy: raisedBy,
        raisedAt: raisedAt,
        locationNote: locationNote,
        locationShared: locationShared,
        status: status ?? this.status,
        notes: notes,
        responder: responder ?? this.responder,
      );
}

enum EmergencyType {
  security('Campus Security', 'security', 'shield'),
  medical('Medical Emergency', 'medical', 'medical'),
  fire('Fire Emergency', 'fire', 'fire'),
  womenSafety("Women's Safety", 'women', 'safety'),
  hostel('Hostel Emergency', 'hostel', 'hostel'),
  suspicious('Report Suspicious Activity', 'suspicious', 'report');

  const EmergencyType(this.label, this.apiValue, this.icon);
  final String label;
  final String apiValue;
  final String icon;
}

enum EmergencyStatus {
  raised('Request Sent'),
  dispatched('Security Team Notified'),
  assigned('Response Team Assigned'),
  resolved('Resolved');

  const EmergencyStatus(this.label);
  final String label;
}

/// A complaint / service request.
class Complaint {
  const Complaint({
    required this.id,
    required this.category,
    required this.subject,
    required this.description,
    required this.raisedBy,
    required this.createdAt,
    this.status = 'Open',
    this.response = '',
    this.assignedTo = '',
    this.rating,
  });

  final String id;
  final String category;
  final String subject;
  final String description;
  final String raisedBy;
  final DateTime createdAt;
  final String status;
  final String response;
  final String assignedTo;
  final int? rating;

  Complaint copyWith({String? status, String? response, String? ratingless}) =>
      Complaint(
        id: id,
        category: category,
        subject: subject,
        description: description,
        raisedBy: raisedBy,
        createdAt: createdAt,
        status: status ?? this.status,
        response: response ?? this.response,
        assignedTo: assignedTo,
        rating: rating,
      );
}

/// An incident filed by security staff.
class IncidentReport {
  const IncidentReport({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.location,
    required this.reportedBy,
    required this.reportedAt,
    this.status = 'Open',
  });

  final String id;
  final String title;
  final String description;
  final String severity; // low | medium | high
  final String location;
  final String reportedBy;
  final DateTime reportedAt;
  final String status;
}
