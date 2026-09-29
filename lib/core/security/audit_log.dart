/// Append-only audit trail for security-sensitive actions.
///
/// In production these entries are written to the backend audit log; the
/// in-memory buffer keeps a local tail so the profile "Login activity" screen
/// can show the user their own recent events. Students never see other
/// users' entries.
enum AuditAction {
  login('Login', true),
  loginFailed('Login failed', true),
  logout('Logout', true),
  logoutAll('Logged out of all devices', true),
  passwordChanged('Password changed', true),
  otpRequested('Verification code requested', true),
  otpVerified('Verification code verified', true),
  accountLocked('Account temporarily locked', true),
  gatePassCreated('Gate pass created', true),
  gatePassApproved('Gate pass approved', true),
  gatePassRejected('Gate pass rejected', true),
  gatePassUsed('Gate pass used at gate', true),
  visitorRequested('Visitor pass requested', true),
  visitorApproved('Visitor pass approved', true),
  visitorRejected('Visitor pass rejected', true),
  qrScanned('Pass QR scanned', true),
  emergencyRaised('Emergency raised', true),
  incidentReported('Incident reported', true),
  roleChanged('User role changed', true),
  announcementPublished('Announcement published', true),
  profileUpdated('Profile updated', false),
  settingsChanged('Settings changed', false),
  sessionRevoked('Session revoked', false);

  const AuditAction(this.label, this.sensitive);

  final String label;
  final bool sensitive;
}

class AuditEntry {
  AuditEntry({
    required this.action,
    required this.actorId,
    required this.role,
    required this.timestamp,
    this.detail = '',
    this.device = '',
  });

  final AuditAction action;
  final String actorId;
  final String role;
  final DateTime timestamp;
  final String detail;
  final String device;

  bool get isSensitive => action.sensitive;
}

/// Local audit sink. Server-side logging is authoritative.
class AuditLog {
  AuditLog({this.capacity = 200});

  final int capacity;
  final List<AuditEntry> _entries = <AuditEntry>[];

  List<AuditEntry> get entries => List.unmodifiable(_entries);

  void record(
    AuditAction action, {
    required String actorId,
    required String role,
    String detail = '',
    String device = '',
  }) {
    _entries.insert(
      0,
      AuditEntry(
        action: action,
        actorId: actorId,
        role: role,
        timestamp: DateTime.now(),
        detail: detail,
        device: device,
      ),
    );
    if (_entries.length > capacity) {
      _entries.removeRange(capacity, _entries.length);
    }
  }

  /// Only the calling user's own history is ever exposed.
  List<AuditEntry> forActor(String actorId) =>
      _entries.where((AuditEntry e) => e.actorId == actorId).toList();

  void clear() => _entries.clear();
}
