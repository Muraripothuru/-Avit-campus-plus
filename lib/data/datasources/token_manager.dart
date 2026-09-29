import 'dart:convert';

import '../../core/security/secure_store.dart';
import '../../core/security/signed_tokens.dart';

/// Issued session material.
class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.sessionId,
    required this.userId,
    required this.role,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String sessionId;
  final String userId;
  final String role;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get expiresSoon =>
      DateTime.now().isAfter(
        expiresAt.subtract(const Duration(minutes: 5)),
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'access': accessToken,
    'refresh': refreshToken,
    'exp': expiresAt.toIso8601String(),
    'sid': sessionId,
    'uid': userId,
    'role': role,
  };

  factory SessionTokens.fromJson(Map<String, Object?> json) => SessionTokens(
    accessToken: json['access'] as String? ?? '',
    refreshToken: json['refresh'] as String? ?? '',
    expiresAt:
        DateTime.tryParse(json['exp'] as String? ?? '') ?? DateTime.now(),
    sessionId: json['sid'] as String? ?? '',
    userId: json['uid'] as String? ?? '',
    role: json['role'] as String? ?? 'student',
  );
}

/// Owns token lifecycle: persistence in secure storage, proactive refresh and
/// hard invalidation on logout. Never touches SharedPreferences.
class TokenManager {
  TokenManager({required this.store, this.signingSecret = ''});

  final SecureStore store;
  final String signingSecret;

  SessionTokens? _cached;

  SessionTokens? get cached => _cached;

  Future<String?> get accessToken async {
    final SessionTokens? tokens = await _load();
    if (tokens == null) return null;
    if (tokens.isExpired) {
      final bool ok = await refresh();
      return ok ? _cached?.accessToken : null;
    }
    return tokens.accessToken;
  }

  Future<SessionTokens?> _load() async {
    if (_cached != null) return _cached;
    final String? raw = await store.read(SecureKeys.accessToken);
    if (raw == null) return null;
    try {
      final Map<String, Object?> json =
          jsonDecode(raw) as Map<String, Object?>;
      _cached = SessionTokens.fromJson(json);
    } catch (_) {
      await clear();
      return null;
    }
    return _cached;
  }

  Future<void> save(SessionTokens tokens) async {
    _cached = tokens;
    // Best effort: a storage hiccup must not fail the sign-in itself. The
    // session stays valid in memory for the current run.
    await _tryWrite(SecureKeys.accessToken, jsonEncode(tokens.toJson()));
    await _tryWrite(SecureKeys.refreshToken, tokens.refreshToken);
    await _tryWrite(SecureKeys.sessionId, tokens.sessionId);
    await _tryWrite(SecureKeys.lastUserId, tokens.userId);
  }

  Future<void> _tryWrite(String key, String value) async {
    try {
      await store.write(key, value);
    } catch (_) {}
  }

  Future<void> _tryDelete(String key) async {
    try {
      await store.delete(key);
    } catch (_) {}
  }

  /// Refreshes the access token. Single-flight: concurrent callers await the
  /// same future instead of firing duplicate requests.
  Future<bool>? _inFlight;

  Future<bool> refresh() {
    final Future<bool>? existing = _inFlight;
    if (existing != null) return existing;
    final Future<bool> attempt = _doRefresh().whenComplete(() {
      _inFlight = null;
    });
    _inFlight = attempt;
    return attempt;
  }

  Future<bool> _doRefresh() async {
    final SessionTokens? tokens = await _load();
    if (tokens == null) return false;
    final String refreshToken = await store.read(SecureKeys.refreshToken) ?? '';
    if (refreshToken.isEmpty) return false;

    // A refresh token is itself a signed, expiring credential. If it is no
    // longer valid there is nothing to do but sign the user out.
    if (signingSecret.isNotEmpty) {
      final Map<String, Object?>? payload = SignedTokens.tryDecode(
        refreshToken,
        signingSecret,
      );
      if (payload == null || SignedTokens.isExpired(payload)) {
        await clear();
        return false;
      }
    }

    // Delegated to the auth repository via [onRefresh] to keep HTTP concerns
    // out of this class. Set once during bootstrap.
    final Future<bool> Function(String)? handler = onRefresh;
    if (handler == null) return false;
    try {
      final bool ok = await handler(refreshToken);
      if (!ok) await clear();
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Injected by the auth repository at bootstrap.
  Future<bool> Function(String refreshToken)? onRefresh;

  /// Clears access material but keeps `lastUserId` so biometric login can
  /// offer the same account.
  Future<void> clear({bool forgetUser = false}) async {
    _cached = null;
    await _tryDelete(SecureKeys.accessToken);
    await _tryDelete(SecureKeys.refreshToken);
    await _tryDelete(SecureKeys.sessionId);
    if (forgetUser) await _tryDelete(SecureKeys.lastUserId);
  }

  /// Loads the last signed-in user id (for biometric convenience only).
  Future<String?> lastUserId() => store.read(SecureKeys.lastUserId);
}
