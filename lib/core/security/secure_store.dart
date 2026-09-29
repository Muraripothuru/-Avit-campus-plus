import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A tiny abstraction so tests and demo runs never depend on platform channels.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
  Future<bool> containsKey(String key);
}

/// Keys used with [SecureStore].
abstract final class SecureKeys {
  static const String accessToken = 'avit.access.token';
  static const String refreshToken = 'avit.refresh.token';
  static const String sessionId = 'avit.session.id';
  static const String biometricConsent = 'avit.biometric.consent';
  static const String lastUserId = 'avit.last.user.id';
  static const String pendingSignup = 'avit.pending.signup';
  static const String pendingOtpPurpose = 'avit.pending.otp.purpose';
}

/// Android Keystore / iOS Keychain backed storage.
///
/// Sensitive material (tokens, session ids) must NEVER go into
/// SharedPreferences — this is the only sanctioned path.
class PlatformSecureStore implements SecureStore {
  PlatformSecureStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  /// Every operation is bounded: a hung platform channel must never stall
  /// startup, sign-in or token refresh.
  static const Duration opTimeout = Duration(seconds: 3);

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key).timeout(opTimeout);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value).timeout(opTimeout);
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key).timeout(opTimeout);
    } catch (_) {}
  }

  @override
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll().timeout(opTimeout);
    } catch (_) {}
  }

  @override
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key).timeout(opTimeout);
    } catch (_) {
      return false;
    }
  }
}

/// In-memory implementation for unit tests / widget tests.
class InMemorySecureStore implements SecureStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> deleteAll() async => _data.clear();

  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);
}
