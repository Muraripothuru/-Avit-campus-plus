import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../utils/app_exception.dart';
import 'signed_tokens.dart';

/// QR payloads for gate passes / visitor passes / event tickets.
///
/// A QR value is never a predictable sequential id. It is a signed bundle:
///
/// ```text
/// AVITQR1.<base64url(payload)>.<base64url(hmac)>
/// ```
///
/// The payload carries a unique request id, a single-use nonce, an expiry and
/// the document type. Verification therefore needs no lookup for integrity;
/// a server still performs the one-time-use and status checks.
abstract final class QrTokenService {
  static const String prefix = 'AVITQR1';

  /// Demo secret. In production override with `--dart-define=QR_SIGNING_KEY`.
  static const String signingKey = String.fromEnvironment(
    'QR_SIGNING_KEY',
    defaultValue: 'avit-campus-plus-demo-qr-key-rotate-in-prod',
  );

  static String issue({
    required String type, // gate | visitor | event
    required String requestId,
    required String holderId,
    required DateTime expiresAt,
    String? destination,
  }) {
    final String nonce = SignedTokens.newId(12);
    final Map<String, Object?> payload = <String, Object?>{
      'v': 1,
      't': type,
      'rid': requestId,
      'h': holderId,
      'n': nonce,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
    };
    if (destination != null) payload['d'] = destination;
    final String body = base64Url.encode(utf8.encode(jsonEncode(payload)));
    return '$prefix.$body.${_sign(body)}';
  }

  static QrPayload parse(String raw) {
    final String value = raw.trim();
    final List<String> parts = value.split('.');
    if (parts.length != 3 || parts[0] != prefix) {
      throw const AppException('Not a valid AVIT pass code', kind: 'qr');
    }
    if (!SignedTokens.constantTimeEqual(parts[2], _sign(parts[1]))) {
      throw const AppException('Pass code signature is invalid', kind: 'qr');
    }
    try {
      final Object? decoded = jsonDecode(
        utf8.decode(base64Url.decode(parts[1])),
      );
      if (decoded is! Map<String, Object?>) {
        throw const AppException('Pass code is malformed', kind: 'qr');
      }
      return QrPayload.fromJson(decoded);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Pass code is malformed', kind: 'qr');
    }
  }

  static String _sign(String body) {
    final Hmac hmac = Hmac(sha256, utf8.encode(signingKey));
    return base64Url.encode(hmac.convert(utf8.encode(body)).bytes);
  }
}

/// Outcome of validating a scanned pass.
enum QrValidationStatus { valid, invalid, expired, used, revoked }

class QrPayload {
  const QrPayload({
    required this.type,
    required this.requestId,
    required this.holderId,
    required this.nonce,
    required this.issuedAt,
    required this.expiresAt,
    this.destination,
  });

  final String type;
  final String requestId;
  final String holderId;
  final String nonce;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String? destination;

  factory QrPayload.fromJson(Map<String, Object?> json) {
    return QrPayload(
      type: json['t'] as String? ?? '',
      requestId: json['rid'] as String? ?? '',
      holderId: json['h'] as String? ?? '',
      nonce: json['n'] as String? ?? '',
      issuedAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['iat'] as int?) ?? 0) * 1000,
      ),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['exp'] as int?) ?? 0) * 1000,
      ),
      destination: json['d'] as String?,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Cryptographic checks only — status checks (used/revoked) happen
  /// server-side because they require server state.
  QrValidationStatus verifyIntegrity() {
    if (type.isEmpty || requestId.isEmpty) return QrValidationStatus.invalid;
    if (isExpired) return QrValidationStatus.expired;
    return QrValidationStatus.valid;
  }
}
