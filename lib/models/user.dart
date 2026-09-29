/// Role-based access control.
///
/// The client uses [UserRole] to decide which UI to render. Authoritative
/// enforcement happens on the API: a token's `role` claim is validated
/// server-side on every request, never trusted from a client field.
enum UserRole {
  student('Student', 'student'),
  security('Security', 'security'),
  warden('Warden', 'warden'),
  admin('Administrator', 'admin');

  const UserRole(this.label, this.apiValue);
  final String label;
  final String apiValue;

  static UserRole fromApi(String value) => UserRole.values.firstWhere(
    (UserRole r) => r.apiValue == value,
    orElse: () => UserRole.student,
  );
}

/// Core identity shared by every account.
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.studentId,
    this.phone = '',
    this.programme = '',
    this.department = '',
    this.semester,
    this.year,
    this.hostel,
    this.emergencyContact = '',
    this.avatarUrl,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.biometricEnabled = false,
    this.strongPassword = true,
    this.profileVisibility = 'campus',
    this.locationConsent = false,
    this.emergencyLocationSharing = false,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String? studentId;
  final String phone;
  final String programme;
  final String department;
  final int? semester;
  final int? year;
  final String? hostel;
  final String emergencyContact;
  final String? avatarUrl;
  final bool emailVerified;
  final bool phoneVerified;
  final bool biometricEnabled;
  final bool strongPassword;
  final String profileVisibility;
  final bool locationConsent;
  final bool emergencyLocationSharing;
  final DateTime? createdAt;

  bool get isStudent => role == UserRole.student;
  bool get canManagePasses =>
      role == UserRole.warden || role == UserRole.admin;
  bool get canVerifyPasses =>
      role == UserRole.security || role == UserRole.admin;

  String get displayId => studentId ?? email;
  String get programmeShort =>
      programme.isEmpty ? '—' : programme.replaceAll('B.Tech ', 'B.Tech ');

  AppUser copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? programme,
    String? department,
    int? semester,
    int? year,
    String? hostel,
    String? emergencyContact,
    String? avatarUrl,
    bool? emailVerified,
    bool? phoneVerified,
    bool? biometricEnabled,
    String? profileVisibility,
    bool? locationConsent,
    bool? emergencyLocationSharing,
  }) {
    return AppUser(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role,
      studentId: studentId,
      phone: phone ?? this.phone,
      programme: programme ?? this.programme,
      department: department ?? this.department,
      semester: semester ?? this.semester,
      year: year ?? this.year,
      hostel: hostel ?? this.hostel,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      strongPassword: strongPassword,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      locationConsent: locationConsent ?? this.locationConsent,
      emergencyLocationSharing:
          emergencyLocationSharing ?? this.emergencyLocationSharing,
      createdAt: createdAt,
    );
  }

  factory AppUser.fromJson(Map<String, Object?> json) => AppUser(
    id: json['id'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: UserRole.fromApi(json['role'] as String? ?? 'student'),
    studentId: json['studentId'] as String?,
    phone: json['phone'] as String? ?? '',
    programme: json['programme'] as String? ?? '',
    department: json['department'] as String? ?? '',
    semester: (json['semester'] as num?)?.toInt(),
    year: (json['year'] as num?)?.toInt(),
    hostel: json['hostel'] as String?,
    emergencyContact: json['emergencyContact'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    emailVerified: json['emailVerified'] as bool? ?? false,
    phoneVerified: json['phoneVerified'] as bool? ?? false,
    biometricEnabled: json['biometricEnabled'] as bool? ?? false,
    profileVisibility: json['profileVisibility'] as String? ?? 'campus',
    locationConsent: json['locationConsent'] as bool? ?? false,
    emergencyLocationSharing:
        json['emergencyLocationSharing'] as bool? ?? false,
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.tryParse(json['createdAt'] as String),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'fullName': fullName,
    'email': email,
    'role': role.apiValue,
    'studentId': studentId,
    'phone': phone,
    'programme': programme,
    'department': department,
    'semester': semester,
    'year': year,
    'hostel': hostel,
    'emergencyContact': emergencyContact,
    'avatarUrl': avatarUrl,
    'emailVerified': emailVerified,
    'phoneVerified': phoneVerified,
    'biometricEnabled': biometricEnabled,
    'profileVisibility': profileVisibility,
    'locationConsent': locationConsent,
    'emergencyLocationSharing': emergencyLocationSharing,
    'createdAt': createdAt?.toIso8601String(),
  };
}

/// A device session the user can inspect and revoke.
class UserSession {
  const UserSession({
    required this.id,
    required this.device,
    required this.lastActive,
    this.current = false,
    this.locationLabel = 'Approximate location only',
  });

  final String id;
  final String device;
  final DateTime lastActive;
  final bool current;
  final String locationLabel;

  factory UserSession.fromJson(Map<String, Object?> json) => UserSession(
    id: json['id'] as String? ?? '',
    device: json['device'] as String? ?? 'Unknown device',
    lastActive: DateTime.parse(json['lastActive'] as String),
    current: json['current'] as bool? ?? false,
    locationLabel:
        json['locationLabel'] as String? ?? 'Approximate location only',
  );
}
