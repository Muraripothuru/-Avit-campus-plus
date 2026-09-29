import '../../core/constants/app_constants.dart';
import '../../core/security/audit_log.dart';
import '../../core/security/otp_service.dart';
import '../../core/security/password_hasher.dart';
import '../../core/security/rate_limiter.dart';
import '../../core/security/signed_tokens.dart';
import '../../core/utils/app_exception.dart';
import '../../models/user.dart';
import '../datasources/api_client.dart';
import '../datasources/demo_catalog.dart';
import '../datasources/token_manager.dart';
import 'dart:convert';

/// Result of an authentication attempt.
class AuthResult {
  const AuthResult({required this.user, required this.tokens});
  final AppUser user;
  final SessionTokens tokens;
}

/// Credential flow contract. Two implementations exist:
///  * [RemoteAuthRepository] — real REST API (production)
///  * [DemoAuthRepository]    — local, clearly-labelled development mode
abstract class AuthRepository {
  bool get isRemote;
  Future<AuthResult> login({
    required String identifier,
    required String password,
  });
  Future<void> requestOtp(String destination);
  Future<void> verifyOtp(String destination, String code);
  Future<AuthResult> completeSignup({
    required String fullName,
    required String studentId,
    required String email,
    required String phone,
    required String programme,
    required int semester,
    required String password,
  });
  Future<void> requestPasswordReset(String identifier);
  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  });
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<bool> refresh(String refreshToken);
  Future<List<UserSession>> sessions();
  Future<void> revokeSession(String sessionId);
  Future<void> revokeAllSessions();
  Future<void> logout({bool everywhere = false});
}

/// Production implementation against the AVIT Campus+ REST API.
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required this.api,
    required this.tokens,
    required this.audit,
  });

  final ApiClient api;
  final TokenManager tokens;
  final AuditLog audit;

  @override
  bool get isRemote => true;

  Future<AuthResult> _fromPayload(Map<String, Object?> payload) async {
    final Map<String, Object?>? session =
        payload['session'] as Map<String, Object?>?;
    final Map<String, Object?>? user =
        (payload['user'] as Map<String, Object?>?) ??
        payload['profile'] as Map<String, Object?>?;
    if (session == null || user == null) {
      throw const AppException('Malformed server response', kind: 'server');
    }
    final SessionTokens issued = SessionTokens(
      accessToken: session['accessToken'] as String? ?? '',
      refreshToken: session['refreshToken'] as String? ?? '',
      expiresAt:
          DateTime.tryParse(session['expiresAt'] as String? ?? '') ??
          DateTime.now().add(AppConstants.accessTokenTtl),
      sessionId: session['id'] as String? ?? '',
      userId: user['id'] as String? ?? '',
      role: user['role'] as String? ?? 'student',
    );
    await tokens.save(issued);
    return AuthResult(user: AppUser.fromJson(user), tokens: issued);
  }

  @override
  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    final Map<String, Object?> payload = await api.post(
      '/auth/login',
      body: <String, Object?>{
        'identifier': identifier.trim(),
        'password': password,
        'device': 'mobile',
      },
      authenticated: false,
    );
    final AuthResult result = await _fromPayload(payload);
    audit.record(
      AuditAction.login,
      actorId: result.user.id,
      role: result.user.role.apiValue,
      device: 'mobile',
    );
    return result;
  }

  @override
  Future<void> requestOtp(String destination) =>
      api.post('/auth/otp', body: <String, Object?>{'destination': destination});

  @override
  Future<void> verifyOtp(String destination, String code) => api.post(
    '/auth/otp/verify',
    body: <String, Object?>{'destination': destination, 'code': code},
  );

  @override
  Future<AuthResult> completeSignup({
    required String fullName,
    required String studentId,
    required String email,
    required String phone,
    required String programme,
    required int semester,
    required String password,
  }) async {
    final Map<String, Object?> payload = await api.post(
      '/auth/register',
      body: <String, Object?>{
        'fullName': fullName,
        'studentId': studentId,
        'email': email,
        'phone': phone,
        'programme': programme,
        'semester': semester,
        'password': password,
        'consent': true,
      },
      authenticated: false,
    );
    return _fromPayload(payload);
  }

  @override
  Future<void> requestPasswordReset(String identifier) =>
      api.post('/auth/password/reset-request',
          body: <String, Object?>{'identifier': identifier},
          authenticated: false);

  @override
  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  }) => api.post(
    '/auth/password/reset',
    body: <String, Object?>{
      'identifier': identifier,
      'code': code,
      'password': newPassword,
    },
    authenticated: false,
  );

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await api.post(
      '/auth/password/change',
      body: <String, Object?>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    audit.record(
      AuditAction.passwordChanged,
      actorId: tokens.cached?.userId ?? '',
      role: tokens.cached?.role ?? '',
    );
  }

  @override
  Future<bool> refresh(String refreshToken) async {
    try {
      final Map<String, Object?> payload = await api.post(
        '/auth/refresh',
        body: <String, Object?>{'refreshToken': refreshToken},
        authenticated: false,
      );
      final Map<String, Object?>? session =
          payload['session'] as Map<String, Object?>?;
      if (session == null) return false;
      final SessionTokens current = tokens.cached ??
          SessionTokens(
            accessToken: '',
            refreshToken: refreshToken,
            expiresAt: DateTime.now(),
            sessionId: '',
            userId: '',
            role: 'student',
          );
      await tokens.save(
        SessionTokens(
          accessToken: session['accessToken'] as String? ?? '',
          refreshToken: session['refreshToken'] as String? ?? refreshToken,
          expiresAt:
              DateTime.tryParse(session['expiresAt'] as String? ?? '') ??
              DateTime.now().add(AppConstants.accessTokenTtl),
          sessionId: session['id'] as String? ?? current.sessionId,
          userId: current.userId,
          role: current.role,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<UserSession>> sessions() async {
    final Map<String, Object?> payload = await api.get('/auth/sessions');
    final Object? items = payload['items'];
    if (items is! List) return <UserSession>[];
    return items
        .whereType<Map<String, Object?>>()
        .map(UserSession.fromJson)
        .toList();
  }

  @override
  Future<void> revokeSession(String sessionId) =>
      api.delete('/auth/sessions/$sessionId');

  @override
  Future<void> revokeAllSessions() => api.delete('/auth/sessions');

  @override
  Future<void> logout({bool everywhere = false}) async {
    try {
      await api.post(
        '/auth/logout',
        body: <String, Object?>{'everywhere': everywhere},
      );
    } catch (_) {
      // Session may already be invalid; local cleanup still happens.
    }
    audit.record(
      everywhere ? AuditAction.logoutAll : AuditAction.logout,
      actorId: tokens.cached?.userId ?? '',
      role: tokens.cached?.role ?? '',
    );
    await tokens.clear(forgetUser: everywhere);
  }
}

/// Local development implementation.
///
/// Accounts, OTPs and lockout behave like the real API but everything runs in
/// memory. Clearly labelled "Development mode" in the UI.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository({
    required this.tokens,
    required this.audit,
    OtpService? otp,
    this.tokenSecret = 'avit-demo-signing-secret',
  }) : _otp = otp ?? OtpService();

  final TokenManager tokens;
  final AuditLog audit;
  final OtpService _otp;
  final String tokenSecret;

  final RateLimiter _loginLimiter = RateLimiter(
    maxAttempts: AppConstants.maxLoginAttempts,
    window: AppConstants.loginLockDuration,
  );
  final RateLimiter _otpLimiter = RateLimiter(maxAttempts: 5, window: const Duration(minutes: 10));
  final Map<String, OtpChallenge> _challenges = <String, OtpChallenge>{};

  @override
  bool get isRemote => false;

  AppUser? _findUser(String identifier) {
    final String value = identifier.trim().toLowerCase();
    for (final (UserRole _, AppUser user, String _) in DemoCatalog.accounts) {
      if (user.email.toLowerCase() == value ||
          (user.studentId?.toLowerCase() == value)) {
        return user;
      }
    }
    return null;
  }

  AppUser? _userById(String id) {
    for (final (UserRole _, AppUser user, String _)
        in DemoCatalog.accounts) {
      if (user.id == id) return user;
    }
    return null;
  }

  String? _passwordFor(AppUser user) {
    for (final (UserRole _, AppUser candidate, String password)
        in DemoCatalog.accounts) {
      if (candidate.id == user.id) return password;
    }
    return null;
  }

  @override
  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    _loginLimiter.check(identifier.toLowerCase());

    final AppUser? user = _findUser(identifier);
    final String? expected = user == null ? null : _passwordFor(user);
    final bool ok = user != null &&
        expected != null &&
        PasswordHasher.constantTimeEquals(
          utf8.encode(password),
          utf8.encode(expected),
        );

    if (!ok) {
      _loginLimiter.recordFailure(identifier.toLowerCase());
      audit.record(
        AuditAction.loginFailed,
        actorId: identifier,
        role: 'unknown',
        detail: 'Invalid credentials',
      );
      throw const AppException(
        'Incorrect ID or password',
        kind: 'validation',
      );
    }

    _loginLimiter.reset(identifier.toLowerCase());
    final AuthResult result = await _issue(user);
    audit.record(
      AuditAction.login,
      actorId: result.user.id,
      role: result.user.role.apiValue,
      device: 'mobile',
    );
    return result;
  }

  Future<AuthResult> _issue(AppUser user) async {
    final DateTime now = DateTime.now();
    final String sessionId = SignedTokens.newId(12);
    final String access = SignedTokens.encode(
      <String, Object?>{
        'sub': user.id,
        'role': user.role.apiValue,
        'sid': sessionId,
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': now.add(AppConstants.accessTokenTtl).millisecondsSinceEpoch ~/ 1000,
      },
      tokenSecret,
    );
    final String refresh = SignedTokens.encode(
      <String, Object?>{
        'sub': user.id,
        'sid': sessionId,
        'typ': 'refresh',
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': now.add(AppConstants.refreshTokenTtl).millisecondsSinceEpoch ~/ 1000,
      },
      tokenSecret,
    );
    final SessionTokens session = SessionTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: now.add(AppConstants.accessTokenTtl),
      sessionId: sessionId,
      userId: user.id,
      role: user.role.apiValue,
    );
    await tokens.save(session);
    return AuthResult(user: user, tokens: session);
  }

  @override
  Future<void> requestOtp(String destination) async {
    _otpLimiter.check(destination.toLowerCase());
    final String email = destination.trim().toLowerCase();
    final bool known = _findUser(email) != null;
    if (!known && !email.endsWith('@avit.ac.in')) {
      throw const AppException(
        'No account is associated with that address',
        kind: 'validation',
      );
    }
    final OtpChallenge challenge = _otp.issue(destination.trim());
    _challenges[destination.trim().toLowerCase()] = challenge;
    // In demo mode the code is surfaced to the developer instead of being
    // mailed. It is never written to the audit log.
    _lastIssuedCode = challenge.code;
    audit.record(
      AuditAction.otpRequested,
      actorId: destination,
      role: 'unknown',
      detail: 'OTP issued',
    );
  }

  String? _lastIssuedCode;

  /// Development helper: the code that was just issued (demo mode only).
  String? get debugLastOtp => _lastIssuedCode;

  @override
  Future<void> verifyOtp(String destination, String code) async {
    final OtpChallenge? challenge =
        _challenges[destination.trim().toLowerCase()];
    if (challenge == null) {
      throw const AppException(
        'Request a new code first',
        kind: 'validation',
      );
    }
    final bool ok = _otp.verify(challenge, code);
    if (!ok) {
      throw const AppException('That code is not correct', kind: 'validation');
    }
    audit.record(
      AuditAction.otpVerified,
      actorId: destination,
      role: 'unknown',
    );
  }

  @override
  Future<AuthResult> completeSignup({
    required String fullName,
    required String studentId,
    required String email,
    required String phone,
    required String programme,
    required int semester,
    required String password,
  }) async {
    if (_findUser(email) != null || _findUser(studentId) != null) {
      throw const AppException(
        'An account already exists for this student ID or email',
        kind: 'validation',
      );
    }
    final AppUser user = AppUser(
      id: 'u_${SignedTokens.newId(6)}',
      fullName: fullName,
      email: email,
      role: UserRole.student,
      studentId: studentId,
      phone: phone,
      programme: programme,
      semester: semester,
      emailVerified: true,
      createdAt: DateTime.now(),
    );
    return _issue(user);
  }

  @override
  Future<void> requestPasswordReset(String identifier) async {
    if (_findUser(identifier) == null) {
      // Do not reveal whether an account exists.
      _lastIssuedCode = null;
      return;
    }
    final OtpChallenge challenge = _otp.issue(identifier.trim());
    _challenges[identifier.trim().toLowerCase()] = challenge;
    _lastIssuedCode = challenge.code;
  }

  @override
  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    final OtpChallenge? challenge =
        _challenges[identifier.trim().toLowerCase()];
    if (challenge == null) {
      throw const AppException('Request a new code first', kind: 'validation');
    }
    if (!_otp.verify(challenge, code)) {
      throw const AppException('That code is not correct', kind: 'validation');
    }
    _challenges.remove(identifier.trim().toLowerCase());
    _loginLimiter.reset(identifier.toLowerCase());
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final String? userId = tokens.cached?.userId;
    if (userId == null) throw AppException.unauthorized;
    final AppUser user = _userById(userId) ?? DemoCatalog.student;
    final String? expected = _passwordFor(user);
    if (expected == null || expected != currentPassword) {
      throw const AppException(
        'Your current password is not correct',
        kind: 'validation',
      );
    }
    audit.record(
      AuditAction.passwordChanged,
      actorId: user.id,
      role: user.role.apiValue,
    );
  }

  @override
  Future<bool> refresh(String refreshToken) async {
    final Map<String, Object?>? payload = SignedTokens.tryDecode(
      refreshToken,
      tokenSecret,
    );
    if (payload == null || SignedTokens.isExpired(payload)) return false;
    final String? userId = payload['sub'] as String?;
    if (userId == null) return false;
    final AppUser? user = _userById(userId);
    if (user == null) return false;
    await _issue(user);
    return true;
  }

  @override
  Future<List<UserSession>> sessions() async {
    final String? userId = tokens.cached?.userId;
    return <UserSession>[
      UserSession(
        id: tokens.cached?.sessionId ?? 'current',
        device: 'This device',
        lastActive: DateTime.now(),
        current: true,
      ),
      if (userId != null)
        UserSession(
          id: 'sess_web',
          device: 'Chrome on Windows',
          lastActive: DateTime.now().subtract(const Duration(hours: 6)),
          locationLabel: 'Approximate location only',
        ),
      if (userId != null)
        UserSession(
          id: 'sess_android',
          device: 'Redmi Note 12',
          lastActive: DateTime.now().subtract(const Duration(days: 2)),
          locationLabel: 'Approximate location only',
        ),
    ];
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    if (sessionId == tokens.cached?.sessionId) {
      await tokens.clear();
    }
  }

  @override
  Future<void> revokeAllSessions() => tokens.clear();

  @override
  Future<void> logout({bool everywhere = false}) async {
    audit.record(
      everywhere ? AuditAction.logoutAll : AuditAction.logout,
      actorId: tokens.cached?.userId ?? '',
      role: tokens.cached?.role ?? '',
    );
    await tokens.clear(forgetUser: everywhere);
  }
}
