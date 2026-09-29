import 'dart:math';

import '../utils/app_exception.dart';

/// One-time-passcode generation + verification with attempt limits.
class OtpChallenge {
  OtpChallenge({
    required this.destination,
    required this.code,
    required this.expiresAt,
    this.maxAttempts = 5,
  });

  final String destination;
  final String code;
  final DateTime expiresAt;
  final int maxAttempts;
  int attempts = 0;
  bool consumed = false;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class OtpService {
  OtpService({this.ttl = const Duration(minutes: 5), Random? rng})
    : _rng = rng ?? Random.secure();

  final Duration ttl;
  final Random _rng;

  OtpChallenge issue(String destination) {
    final String code = (100000 + _rng.nextInt(900000)).toString();
    return OtpChallenge(
      destination: destination,
      code: code,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  /// Returns `true` when the code matches and was not already used.
  /// Throws [AppException] on lockout so the caller can show a friendly state.
  bool verify(OtpChallenge challenge, String attempt) {
    if (challenge.consumed) {
      throw const AppException(
        'This code was already used. Request a new one.',
        kind: 'validation',
      );
    }
    if (challenge.isExpired) {
      throw const AppException(
        'This code has expired. Request a new one.',
        kind: 'validation',
      );
    }
    if (challenge.attempts >= challenge.maxAttempts) {
      throw AppException(
        'Too many incorrect attempts. Request a new code.',
        kind: 'locked',
      );
    }
    challenge.attempts++;
    if (!_constantTimeEquals(challenge.code, attempt.trim())) return false;
    challenge.consumed = true;
    return true;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
