import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/media/avatar_photo.dart';
import '../core/media/gallery_photo_source.dart';
import '../core/security/audit_log.dart';
import '../core/security/secure_store.dart';
import '../core/services/biometric_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/firebase_bridge.dart';
import '../core/services/permission_service.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/formatters.dart';
import '../models/facility_booking.dart';
import '../models/user.dart';
import '../../data/datasources/api_client.dart';
import '../../data/datasources/demo_catalog.dart';
import '../../data/datasources/local_store.dart';
import '../../data/datasources/token_manager.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/campus_repository.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/gate_pass_repository.dart';
import '../../data/repositories/facility_booking_store.dart';
import '../../data/repositories/service_request_store.dart';
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
    required this.photos,
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

  /// Turns a chosen picture into a value the account can store.
  final AvatarPhotoPicker photos;

  final bool isRemote;

  /// True when no API base URL was supplied — the app runs against clearly
  /// labelled development data.
  bool get isDemoMode => !isRemote;

  /// [secureStore] lets tests inject an in-memory store instead of the
  /// platform Keystore/Keychain channel, and [photoPicker] lets them supply a
  /// picture without opening the platform photo picker.
  factory AppDependencies({
    bool? forceRemote,
    SecureStore? secureStore,
    AvatarPhotoPicker? photoPicker,
  }) {
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
      auth = DemoAuthRepository(tokens: tokens, audit: audit, store: store);
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
      photos: photoPicker ?? AvatarPhotoPicker(source: pickFromGalleryPhoto),
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
  AppState(this.deps) {
    // Booking history must be restored before the admin inbox or the
    // booking form consults it, so hydration starts the moment the app
    // boots; screens that need it immediately can await
    // [ensureFacilityBookingsLoaded].
    unawaited(ensureFacilityBookingsLoaded());
  }

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
  String get semesterLabel =>
      _user?.semester == null ? '' : 'Semester ${_user!.semester}';

  Future<void> bootstrap() async {
    _initialising = true;
    notifyListeners();
    try {
      final String? lastId = await deps.tokens.lastUserId();
      final bool hasSession = await deps.store.containsKey(
        SecureKeys.accessToken,
      );
      if (hasSession && lastId != null) {
        _user = await _demoUserFor(lastId) ?? _user;
      } else if (deps.isDemoMode) {
        final AuthResult result = await deps.auth.login(
          identifier: DemoCatalog.student.email,
          password: DemoCredentials.password,
        );
        _user = result.user;
        await deps.store.write(SecureKeys.lastUserId, result.user.id);
      }
    } catch (_) {
      // Never block startup on storage errors.
    }
    _initialising = false;
    notifyListeners();
  }

  Future<AppUser?> _demoUserFor(String id) async {
    final AuthRepository repo = deps.auth;
    if (repo is DemoAuthRepository) {
      // Includes accounts created through sign-up.
      return repo.userById(id);
    }
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
          await _linkFirebaseIdentity(password);
          return true;
        })) ??
        false;
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
          if (FirebaseBridge.ready) {
            // Real accounts land in Firebase Auth; unknown demo credentials
            // simply keep the anonymous identity and the app carries on.
            await FirebaseBridge.tryEmailSignUp(email, password);
            await FirebaseBridge.syncProfile(_profileFields);
          }
          return true;
        })) ??
        false;
  }

  Future<bool> signOut({bool everywhere = false}) async {
    await deps.auth.logout(everywhere: everywhere);
    await FirebaseBridge.trySignOut();
    _user = null;
    _busy = false;
    _lastError = null;
    notifyListeners();
    return true;
  }

  /// Best-effort mirroring of a demo/local session into Firebase email
  /// password auth plus the `users/{uid}` profile document.
  Future<void> _linkFirebaseIdentity(String password) async {
    if (!FirebaseBridge.ready) return;
    final String email = _user?.email ?? '';
    if (!email.contains('@')) return;
    await FirebaseBridge.tryEmailSignIn(email, password);
    await FirebaseBridge.syncProfile(_profileFields);
  }

  Map<String, Object?> get _profileFields => <String, Object?>{
    'fullName': _user?.fullName ?? '',
    'studentId': _user?.studentId ?? '',
    'email': _user?.email ?? '',
    'phone': _user?.phone ?? '',
    'programme': _user?.programme ?? '',
    'semester': _user?.semester,
    'updatedAt': DateTime.now().toIso8601String(),
  };

  Future<void> loadSessionUser() async {
    // In live mode the profile comes from /me; in demo mode we restore from
    // the demo catalogue keyed by the stored user id.
    final String? id = await deps.tokens.lastUserId();
    if (id == null) return;
    final AppUser? found = await _demoUserFor(id);
    if (found != null) {
      _user = found;
      notifyListeners();
    }
  }

  /// Persists the editable profile fields through the auth repository and
  /// republishes the signed-in user so every listening screen updates.
  Future<bool> updateProfile(AppUser updated) async {
    if (_user == null) return false;
    return (await _run<bool>(() async {
          _user = await deps.auth.updateProfile(updated);
          await FirebaseBridge.syncProfile(_profileFields);
          return true;
        })) ??
        false;
  }

  Future<bool> setBiometric(bool enabled) async {
    if (enabled) {
      final bool ok = await deps.biometrics.authenticate(
        reason: 'Enable biometric sign-in',
      );
      if (!ok) return false;
    }
    _biometricOptIn = enabled;
    await deps.store.write(SecureKeys.biometricConsent, enabled ? '1' : '0');
    _user = _user?.copyWith(biometricEnabled: enabled);
    notifyListeners();
    return true;
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  /// Locally saved, unfinished campus service request draft.
  Map<String, Object?>? _serviceRequestDraft;

  Map<String, Object?>? get serviceRequestDraft => _serviceRequestDraft;

  void saveServiceRequestDraft(Map<String, Object?> draft) {
    _serviceRequestDraft = Map<String, Object?>.unmodifiable(draft);
    notifyListeners();
  }

  void clearServiceRequestDraft() {
    if (_serviceRequestDraft == null) return;
    _serviceRequestDraft = null;
    notifyListeners();
  }

  /// Firestore in live mode, the session-scoped demo store otherwise —
  /// tests never initialise Firebase so they keep exercising demo
  /// behaviour. One instance per AppState so submissions survive
  /// navigating away from the service request screen and back; the demo
  /// store additionally persists to shared_preferences so records survive
  /// an app restart too.
  final DemoServiceRequestStore _demoServiceRequests =
      DemoServiceRequestStore(persistence: LazyPrefsServiceRequestPersistence());

  /// Submits a campus service request and returns its SR reference.
  ///
  /// The local store always records the submission first so the admin
  /// inbox and the student's history work even when Firestore drops the
  /// mirrored write (its rules only let an owner read their own
  /// documents). The cloud copy is best-effort, kept under the same
  /// reference.
  Future<String> submitServiceRequest(Map<String, Object?> data) async {
    final String ref = await _demoServiceRequests.submit(data);
    if (FirebaseBridge.ready) {
      try {
        await FirebaseServiceRequestStore().submit(data, reference: ref);
      } catch (_) {
        // Cloud mirror is best-effort; the local copy already succeeded.
      }
    }
    return ref;
  }

  /// Most recent requests for the signed-in student, newest first.
  ///
  /// Local records are always merged with the owner-scoped Firestore
  /// list so submissions that fell back to the demo store (or were made
  /// before the mirror existed) still show up.
  Future<List<Map<String, String>>> recentServiceRequests({
    int limit = 20,
  }) async {
    final List<Map<String, String>> local = await _demoServiceRequests.recent(
      limit: limit,
    );
    final String? studentId = _user?.studentId;
    final List<Map<String, String>> mine = studentId == null ||
            studentId.isEmpty
        ? <Map<String, String>>[]
        : local
              .where((Map<String, String> r) => r['studentId'] == studentId)
              .toList();
    if (!FirebaseBridge.ready) return mine;
    final List<Map<String, String>> owner = await FirebaseServiceRequestStore()
        .recent(limit: limit);
    return _mergeRequestRecords(owner, mine, limit);
  }

  /// Every service request across all students, newest first — the admin
  /// operations view, deliberately unscoped so staff see the whole queue.
  ///
  /// Firestore's owner-only list rules deny this query outright, so the
  /// local mirror is always merged in; without it the admin portal would
  /// look empty no matter what students submitted.
  Future<List<Map<String, String>>> allServiceRequests({
    int limit = 100,
  }) async {
    final List<Map<String, String>> local = await _demoServiceRequests.all(
      limit: limit,
    );
    if (!FirebaseBridge.ready) return local;
    final List<Map<String, String>> cloud = await FirebaseServiceRequestStore()
        .all(limit: limit);
    return _mergeRequestRecords(cloud, local, limit);
  }

  /// Union of the cloud and local records keyed by SR reference — local
  /// wins ties because it carries the latest triage status.
  List<Map<String, String>> _mergeRequestRecords(
    List<Map<String, String>> cloud,
    List<Map<String, String>> local,
    int limit,
  ) {
    final Map<String, Map<String, String>> byRef =
        <String, Map<String, String>>{
          for (final Map<String, String> r in cloud)
            if ((r['ref'] ?? '').isNotEmpty) r['ref']!: r,
        };
    for (final Map<String, String> r in local) {
      final String ref = r['ref'] ?? '';
      if (ref.isNotEmpty) byRef[ref] = r;
    }
    final List<Map<String, String>> merged = byRef.values.toList()
      ..sort(
        (Map<String, String> a, Map<String, String> b) =>
            (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''),
      );
    return merged.take(limit).toList();
  }

  /// Moves one request to a new lifecycle status. The local copy always
  /// takes the change (Firestore owner-only rules reject status patches),
  /// the cloud write is best-effort on top.
  Future<void> setServiceRequestStatus(String reference, String status) async {
    if (FirebaseBridge.ready) {
      try {
        await FirebaseServiceRequestStore().updateStatus(reference, status);
      } catch (_) {
        // Owner-only rules reject status patches; the local copy carries it.
      }
    }
    return _demoServiceRequests.updateStatus(reference, status);
  }

  /// Confirmed facility bookings held by the app-owned state: the list
  /// survives navigating away from the booking screen and back, is
  /// mirrored into shared_preferences so the admin inbox shows bookings
  /// made before a reload, and keeps the booking-lab reset only when
  /// storage itself is unavailable.
  final List<Booking> _facilityBookings = <Booking>[];
  final BookingPersistence _bookingPersistence = LazyPrefsBookingPersistence();
  Future<void>? _bookingsHydrated;

  List<Booking> get facilityBookings =>
      List<Booking>.unmodifiable(_facilityBookings);

  /// Restores persisted bookings exactly once. Screens that must not
  /// miss restored history (the admin inbox, conflict checks) await this
  /// before reading [facilityBookings].
  Future<void> ensureFacilityBookingsLoaded() =>
      _bookingsHydrated ??= _restoreBookings();

  Future<void> _restoreBookings() async {
    try {
      final List<Booking>? restored = await _bookingPersistence.read();
      if (restored == null || restored.isEmpty) return;
      bool changed = false;
      for (final Booking b in restored) {
        final bool known = _facilityBookings.any(
          (Booking x) =>
              x.facilityId == b.facilityId &&
              x.start == b.start &&
              x.end == b.end,
        );
        if (!known) {
          _facilityBookings.add(b);
          changed = true;
        }
      }
      if (changed) notifyListeners();
    } catch (_) {
      // Corrupt or unavailable storage — keep whatever is in memory.
    }
  }

  /// Write-through save that always hydrates first so an early local
  /// change can never overwrite older restored history.
  Future<void> flushFacilityBookings() async {
    await ensureFacilityBookingsLoaded();
    await _bookingPersistence.write(_facilityBookings);
  }

  void addFacilityBooking(Booking booking) {
    _facilityBookings.add(booking);
    notifyListeners();
    unawaited(flushFacilityBookings());
  }

  void cancelFacilityBooking(Booking booking) {
    _facilityBookings.remove(booking);
    notifyListeners();
    unawaited(flushFacilityBookings());
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
