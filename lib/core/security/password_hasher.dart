import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Password hashing helpers.
///
/// The client never transmits a usable credential hash: it only computes a
/// PBKDF2 digest when the app runs in **offline demo mode** against the local
/// mock data source. In live mode the password goes over TLS to the API,
/// which performs the authoritative hash/compare (never trust the client).
abstract final class PasswordHasher {
  static const int iterations = 120000;
  static const int saltBytes = 16;
  static const int keyLength = 32;

  static final Random _rng = Random.secure();

  static String randomSalt([int bytes = saltBytes]) {
    final Uint8List salt = Uint8List(bytes);
    for (int i = 0; i < bytes; i++) {
      salt[i] = _rng.nextInt(256);
    }
    return base64Encode(salt);
  }

  static String hash(String password, String saltB64) {
    final Uint8List passwordBytes = Uint8List.fromList(
      utf8.encode(password),
    );
    final Uint8List saltBytesList = base64Decode(saltB64);
    final Uint8List derived = _pbkdf2(
      passwordBytes,
      saltBytesList,
      iterations,
      keyLength,
    );
    return base64Encode(derived);
  }

  static bool verify(String password, String saltB64, String expectedHash) {
    final String computed = hash(password, saltB64);
    return constantTimeEquals(
      utf8.encode(computed),
      utf8.encode(expectedHash),
    );
  }

  /// Comparison that does not short-circuit (timing-attack resistant).
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Uint8List _pbkdf2(
    Uint8List password,
    Uint8List salt,
    int iterations,
    int keyLength,
  ) {
    final int hLen = 32; // SHA-256
    final int blockCount = (keyLength / hLen).ceil();
    final Uint8List out = Uint8List(blockCount * hLen);

    for (int i = 1; i <= blockCount; i++) {
      final Uint8List block = Uint8List.fromList(
        salt + _intToBytes(i),
      );
      List<int> u = Hmac(sha256, password).convert(block).bytes;
      final Uint8List t = Uint8List.fromList(u);
      for (int iter = 1; iter < iterations; iter++) {
        u = Hmac(sha256, password).convert(u).bytes;
        for (int k = 0; k < t.length; k++) {
          t[k] ^= u[k];
        }
      }
      out.setRange((i - 1) * hLen, i * hLen, t);
    }
    return Uint8List.sublistView(out, 0, keyLength);
  }

  static Uint8List _intToBytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }
}
