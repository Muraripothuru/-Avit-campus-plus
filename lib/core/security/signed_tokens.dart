import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../utils/app_exception.dart';

/// Stateless, signed token helpers (HMAC-SHA256).
///
/// Tokens are `base64Url(payload).base64Url(hmac)`. The server owns the
/// signing secret; the client only decodes/verifies tokens it has been issued
/// so it can show expiry states without leaking anything it cannot already see.
abstract final class SignedTokens {
  static String encode(Map<String, Object?> payload, String secret) {
    final String body = base64Url.encode(utf8.encode(jsonEncode(payload)));
    final String sig = _sign(body, secret);
    return '$body.$sig';
  }

  static Map<String, Object?>? tryDecode(String token, String secret) {
    final List<String> parts = token.split('.');
    if (parts.length != 2) return null;
    if (!constantTimeEqual(parts[1], _sign(parts[0], secret))) return null;
    try {
      final Object? decoded = jsonDecode(
        utf8.decode(base64Url.decode(parts[0])),
      );
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Returns the payload or throws a typed auth error.
  static Map<String, Object?> decode(String token, String secret) {
    final Map<String, Object?>? payload = tryDecode(token, secret);
    if (payload == null) {
      throw const AppException('Session token is invalid', kind: 'auth');
    }
    return payload;
  }

  static bool isExpired(Map<String, Object?> payload, {DateTime? now}) {
    final Object? exp = payload['exp'];
    if (exp is! int) return true;
    final DateTime timestamp = now ?? DateTime.now();
    return timestamp.isAfter(DateTime.fromMillisecondsSinceEpoch(exp * 1000));
  }

  static String newId([int bytes = 16]) {
    final Random rng = Random.secure();
    final List<int> data = List<int>.generate(bytes, (_) => rng.nextInt(256));
    return base64Url.encode(data).replaceAll('=', '');
  }

  static String _sign(String body, String secret) {
    final Hmac hmac = Hmac(sha256, utf8.encode(secret));
    return base64Url.encode(hmac.convert(utf8.encode(body)).bytes);
  }

  static bool constantTimeEqual(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
