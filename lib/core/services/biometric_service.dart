import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Facade over device biometrics (fingerprint / face).
///
/// All platform calls are wrapped so unsupported devices, cancelled dialogs
/// and plugin failures degrade to `false` instead of crashing the app.
class BiometricService {
  BiometricService({LocalAuthentication? biometricAuth})
    : _auth = biometricAuth;

  final LocalAuthentication? _auth;
  bool _available = false;
  bool _probed = false;

  Future<bool> isAvailable() async {
    if (_probed) return _available;
    final LocalAuthentication? auth = _auth;
    if (auth == null) {
      _probed = true;
      return false;
    }
    try {
      final bool canCheck = await auth.canCheckBiometrics;
      final bool supported = await auth.isDeviceSupported();
      _available = canCheck || supported;
    } on PlatformException {
      _available = false;
    } catch (_) {
      _available = false;
    }
    _probed = true;
    return _available;
  }

  Future<bool> authenticate({String reason = 'Confirm it is you'}) async {
    final LocalAuthentication? auth = _auth;
    if (auth == null) return false;
    try {
      return await auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
