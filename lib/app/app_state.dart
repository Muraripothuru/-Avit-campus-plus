import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/security/audit_log.dart';
import '../core/security/secure_store.dart';
import '../core/services/biometric_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/permission_service.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/formatters.dart';
import '../models/user.dart';
import '../../data/datasources/api_client.dart';
import '../../data/datasources/demo_catalog.dart';
import '../../data/datasources/local_store.dart';
import '../../data/datasources/token_manager.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/campus_repository.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/gate_pass_repository.dart';
import '../../data/repositories/staff_repository.dart';
import '../../data/repositories/visitor_pass_repository.dart';

/// Composition root: every service and repository in one place.
///
/// Built once in `main()` and handed to the widget tree through `AppScope`.
/// Swapping `API_BASE_URL` switches every repository from the local demo
/// implementation to the REST implementation — no UI changes required.
class AppDependencies {
  AppDependencies._({
    required this.store,
    required this.tokens,
    required this.audit,
    required this.connectivity,
    required this.permissions,
    required this.biometrics,
    required this.localStore,
    required this.auth,
    required this.content,
    required this.activities,
    required this.campus,
    required this.gatePasses,
    required this.visitorPasses,
    required this.security,
    required this.warden,
    required this.admin,
    required this.isRemote,
  });

  final SecureStore store;
  final TokenManager tokens;
  final AuditLog audit;
  final ConnectivityService connectivity;
  final PermissionService permissions;
  final BiometricService biometrics;
  final LocalStore localStore;

  final AuthRepository auth;
  final ContentRepository content;
  final ActivityRepository activities;
  final CampusRepository campus;
  final GatePassRepository gatePasses;
  final VisitorPassRepository visitorPasses;
  final SecurityRepository security;
  final WardenRepository warden;
  final AdminRepository admin;

  final bool isRemote;

  /// True when no API base URL was supplied — the app runs against clearly
  /// labelled development data.
  bool get isDemoMode => !isRemote;

  /// [secureStore] lets tests inject an in-memory store instead of the
  /// platform Keystore/Keychain channel.
  factory AppDependencies({bool? forceRemote, SecureStore? secureStore}) {
    final SecureStore store = secureStore ?? PlatformSecureStore();
    final TokenManager tokens = TokenManager(store: store);
    final AuditLog audit = AuditLog();
    final ConnectivityService connectivity = ConnectivityService();
    final PermissionService permissions = PermissionService();
    final BiometricService biometrics = BiometricService();
    final LocalStore localStore = LocalStore();

    final bool remote = forceRemote ?? AppConfig.hasLiveBackend;

    final ApiClient? api = remote
        ? ApiClient(baseUrl: AppConfig.apiBaseUrl, tokenManager: tokens)
        : null;

    late final AuthRepository auth;
    late final ContentRepository content;
    late final ActivityRepository activities;
    late final CampusRepository campus;
    late final GatePassRepository gatePasses;
    late final VisitorPassRepository visitorPasses;
    late final SecurityRepository security;
    late final WardenRepository warden;
    late final AdminRepository admin;

    if (remote && api != null) {
      auth = RemoteAuthRepository(api: api, tokens: tokens, audit: audit);
      content = RemoteContentRepository(api);
      activities = RemoteActivityRepository(api);
      campus = RemoteCampusRepository(api: api, audit: audit);
      gatePasses = RemoteGatePassRepository(api: api, audit: audit);
      visitorPasses = RemoteVisitorPassRepository(api: api, audit: audit);
      security = RemoteSecurityRepository(api: api, audit: audit);
      warden = RemoteWardenRepository(api);
      admin = RemoteAdminRepository(api: api, audit: audit);
    } else {
      auth = DemoAuthRepository(tokens: tokens, audit: audit);
      content = DemoContentRepository(localStore);
      activities = DemoActivityRepository(localStore);
      campus = DemoCampusRepository(
        store: localStore,
        audit: audit,
        studentNameOf: () => DemoCatalog.student.fullName,
      );
      final DemoGatePassRepository demoGate = DemoGatePassRepository(
        store: localStore,
        audit: audit,
        studentIdOf: () => DemoCatalog.student.studentId ?? '',
      );
      gatePasses = demoGate;
      final DemoVisitorPassRepository demoVisitor = DemoVisitorPassRepository(
        store: localStore,
        audit: audit,
      );
      visitorPasses = demoVisitor;
      security = DemoSecurityRepository(
        store: localStore,
        audit: audit,
        gateRepository: demoGate,
        visitorRepository: demoVisitor,
      );
      warden = DemoWardenRepository(localStore);
      admin = DemoAdminRepository(
        store: localStore,
        audit: audit,
        isRemote: false,
      );
    }

    // The refresh delegate keeps HTTP concerns inside the repository.
    if (auth is RemoteAuthRepository) {
      tokens.onRefresh = auth.refresh;
    } else if (auth is DemoAuthRepository) {
      tokens.onRefresh = auth.refresh;
    }

    return AppDependencies._(
      store: store,
      tokens: tokens,
      audit: audit,
      connectivity: connectivity,
      permissions: permissions,
      biometrics: biometrics,
      localStore: localStore,
      auth: auth,
      content: content,
      activities: activities,
      campus: campus,
      gatePasses: gatePasses,
      visitorPasses: visitorPasses,
      security: security,
      warden: warden,
      admin: admin,
      isRemote: remote,
    );
  }
}

/// Session + user-facing application state.
///
/// A single `ChangeNotifier` the widget tree listens to. Screens still use
/// `setState` for their own local UI state (tab index, favourites, counters)
/// as required by the assignment brief.
class AppState extends ChangeNotifier {
  AppState(this.deps);

  final AppDependencies deps;

  AppUser? _user;
  bool _initialising = true;
  bool _busy = false;
  String? _lastError;
  ThemeMode _themeMode = ThemeMode.system;
  bool _biometricOptIn = false;
  int _reminderCount = 0;
  final Set<String> _favouriteEvents = <String>{};
  final Set<String> _followedClubs = <String>{};

  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get initialising => _initialising;
  bool get busy => _busy;
  String? get lastError => _lastError;
  ThemeMode get themeMode => _themeMode;
  bool get biometricOptIn => _biometricOptIn;
  int get reminderCount => _reminderCount;
  Set<String> get favouriteEvents => Set<String>.unmodifiable(_favouriteEvents);
  Set<String> get followedClubs => Set<String>.unmodifiable(_followedClubs);
  bool get isDemo => deps.isDemoMode;
  String get greeting => Formatters.greeting(DateTime.now());

  String get displayName => _user?.fullName ?? 'Student';
  String get displayId => _user?.displayId ?? '';
  String get programme => _user?.programme ?? '';
  String get semesterLabel => _user?.semester == null
      ? ''
      : 'Semester ${_user!.semester}';

  Future<void> bootstrap() async {
    _initialising = true;
    notifyListeners();
    try {
      final String? lastId = await deps.tokens.lastUserId();
      final bool hasSession = await deps.store.containsKey(SecureKeys.accessToken);
      if (hasSession && lastId != null) {
        _user = _demoUserFor(lastId) ?? _user;
      }
    } catch (_) {
      // Never block startup on storage errors.
    }
    _initialising = false;
    notifyListeners();
  }

  AppUser? _demoUserFor(String id) {
    for (final (UserRole _, AppUser user, String _) in DemoCatalog.accounts) {
      if (user.id == id) return user;
    }
    return null;
  }

  Future<bool> signIn({
    required String identifier,
    required String password,
  }) async {
    return (await _run<bool>(() async {
      final AuthResult result = await deps.auth.login(
        identifier: identifier,
        password: password,
      );
      _user = result.user;
      await deps.store.write(SecureKeys.lastUserId, result.user.id);
      return true;
    })) ?? false;
  }

  Future<bool> signUp({
    required String fullName,
    required String studentId,
    required String email,
    required String phone,
    required String programme,
    required int semester,
    required String password,
  }) async {
    return (await _run<bool>(() async {
      final AuthResult result = await deps.auth.completeSignup(
        fullName: fullName,
        studentId: studentId,
        email: email,
        phone: phone,
        programme: programme,
        semester: semester,
        password: password,
      );
      _user = result.user;
      await deps.store.write(SecureKeys.lastUserId, result.user.id);
      return true;
    })) ?? false;
  }

  Future<bool> signOut({bool everywhere = false}) async {
    await deps.auth.logout(everywhere: everywhere);
    _user = null;
    _busy = false;
    _lastError = null;
    notifyListeners();
    return true;
  }

  Future<void> loadSessionUser() async {
    // In live mode the profile comes from /me; in demo mode we restore from
    // the demo catalogue keyed by the stored user id.
    final String? id = await deps.tokens.lastUserId();
    if (id == null) return;
    final AppUser? found = _demoUserFor(id);
    if (found != null) {
      _user = found;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(AppUser updated) async {
    return (await _run<bool>(() async {
      _user = updated;
      return true;
    })) ?? false;
  }

  Future<bool> setBiometric(bool enabled) async {
    if (enabled) {
      final bool ok = await deps.biometrics.authenticate(
        reason: 'Enable biometric sign-in',
      );
      if (!ok) return false;
    }
    _biometricOptIn = enabled;
    await deps.store.write(
      SecureKeys.biometricConsent,
      enabled ? '1' : '0',
    );
    _user = _user?.copyWith(biometricEnabled: enabled);
    notifyListeners();
    return true;
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggleEventFavourite(String eventId) {
    // Demonstrates setState-style local state via the shared notifier.
    if (!_favouriteEvents.add(eventId)) _favouriteEvents.remove(eventId);
    notifyListeners();
  }

  void toggleClubFollow(String clubId) {
    if (!_followedClubs.add(clubId)) _followedClubs.remove(clubId);
    notifyListeners();
  }

  void addReminder() {
    _reminderCount++;
    notifyListeners();
  }

  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final T result = await action();
      return result;
    } on AppException catch (e) {
      _lastError = e.userMessage;
      if (e.kind == 'auth') _user = null;
      return null;
    } catch (_) {
      _lastError = 'Something went wrong. Please try again.';
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Injects an error message (used by screens that handle errors themselves).
  void setError(String message) {
    _lastError = message;
    notifyListeners();
  }
}
