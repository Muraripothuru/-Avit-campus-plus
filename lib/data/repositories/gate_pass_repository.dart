import '../../core/security/audit_log.dart';
import '../../core/security/qr_token_service.dart';
import '../../core/utils/app_exception.dart';
import '../../models/pass.dart';
import '../datasources/api_client.dart';
import '../datasources/local_store.dart';

/// Gate pass lifecycle: create → review → QR → use.
abstract class GatePassRepository {
  Future<List<GatePass>> myPasses(String studentId);
  Future<List<GatePass>> pendingReview();
  Future<GatePass> create({
    required String studentId,
    required String studentName,
    required String reason,
    required String destination,
    required DateTime outAt,
    required DateTime inBy,
  });
  Future<GatePass> decide({
    required String passId,
    required bool approve,
    required String reviewer,
    String comment = '',
  });
  Future<GatePass> markUsed({required String passId, required String guard});
  Future<ScanResult> verifyQr(String rawQr);
}

class DemoGatePassRepository implements GatePassRepository {
  DemoGatePassRepository({
    required this.store,
    required this.audit,
    required this.studentIdOf,
  });

  final LocalStore store;
  final AuditLog audit;
  final String Function() studentIdOf;

  @override
  Future<List<GatePass>> myPasses(String studentId) async {
    await _delay();
    return store.gatePassesFor(studentId);
  }

  @override
  Future<List<GatePass>> pendingReview() async {
    await _delay();
    return store.gatePasses
        .where((GatePass p) => p.status == PassStatus.pending)
        .toList();
  }

  @override
  Future<GatePass> create({
    required String studentId,
    required String studentName,
    required String reason,
    required String destination,
    required DateTime outAt,
    required DateTime inBy,
  }) async {
    await _delay();
    if (inBy.isBefore(outAt)) {
      throw const AppException(
        'Return time must be after exit time',
        kind: 'validation',
      );
    }
    final bool overlaps = store.gatePasses.any(
      (GatePass p) =>
          p.studentId == studentId &&
          !p.status.isTerminal &&
          p.outAt.isBefore(inBy) &&
          p.inBy.isAfter(outAt),
    );
    if (overlaps) {
      throw const AppException(
        'You already have an active pass for those dates',
        kind: 'validation',
      );
    }
    final GatePass pass = GatePass(
      id: 'gp_${DateTime.now().millisecondsSinceEpoch}',
      studentId: studentId,
      studentName: studentName,
      reason: reason,
      destination: destination,
      outAt: outAt,
      inBy: inBy,
      createdAt: DateTime.now(),
    );
    store.gatePasses.insert(0, pass);
    audit.record(
      AuditAction.gatePassCreated,
      actorId: studentId,
      role: 'student',
      detail: pass.id,
    );
    return pass;
  }

  @override
  Future<GatePass> decide({
    required String passId,
    required bool approve,
    required String reviewer,
    String comment = '',
  }) async {
    await _delay();
    final int index = store.gatePasses.indexWhere((GatePass p) => p.id == passId);
    if (index < 0) throw AppException.notFound;
    final GatePass existing = store.gatePasses[index];
    if (existing.status != PassStatus.pending) {
      throw const AppException(
        'This request has already been reviewed',
        kind: 'validation',
      );
    }
    final GatePass updated = existing.copyWith(
      status: approve ? PassStatus.approved : PassStatus.rejected,
      reviewerComment: comment,
      reviewedBy: reviewer,
      reviewedAt: DateTime.now(),
      qrToken: approve
          ? QrTokenService.issue(
              type: 'gate',
              requestId: existing.id,
              holderId: existing.studentId,
              expiresAt: existing.inBy,
              destination: existing.destination,
            )
          : null,
    );
    store.gatePasses[index] = updated;
    audit.record(
      approve ? AuditAction.gatePassApproved : AuditAction.gatePassRejected,
      actorId: reviewer,
      role: 'warden',
      detail: updated.id,
    );
    return updated;
  }

  @override
  Future<GatePass> markUsed({
    required String passId,
    required String guard,
  }) async {
    await _delay();
    final int index = store.gatePasses.indexWhere((GatePass p) => p.id == passId);
    if (index < 0) throw AppException.notFound;
    final GatePass updated = store.gatePasses[index].copyWith(
      status: PassStatus.used,
      usedAt: DateTime.now(),
      reviewedBy: guard,
    );
    store.gatePasses[index] = updated;
    audit.record(
      AuditAction.gatePassUsed,
      actorId: guard,
      role: 'security',
      detail: updated.id,
    );
    return updated;
  }

  @override
  Future<ScanResult> verifyQr(String rawQr) async {
    await _delay();
    return _verifyGeneric(
      rawQr,
      // Approved *and* already-used passes are both resolvable so a second
      // scan reports ALREADY USED instead of an unrecognised code.
      store.gatePasses
          .where(
            (GatePass p) =>
                p.status == PassStatus.approved ||
                p.status == PassStatus.used,
          )
          .map(
            (GatePass p) => (
              id: p.id,
              holder: p.studentName,
              expiresAt: p.inBy,
              used: p.usedAt != null,
            ),
          )
          .toList(),
      'gate',
      onUse: (String id) => markUsed(passId: id, guard: 'system'),
    );
  }

  static Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 260));
}

/// Shared QR acceptance logic (integrity → expiry → one-time use → status).
Future<ScanResult> _verifyGeneric(
  String rawQr,
  List<({String id, String holder, DateTime expiresAt, bool used})> issued,
  String type, {
  Future<void> Function(String id)? onUse,
}) async {
  final QrPayload payload;
  try {
    payload = QrTokenService.parse(rawQr);
  } on AppException catch (e) {
    return ScanResult(
      status: QrScanStatus.invalid,
      message: e.message,
      title: 'INVALID',
    );
  }

  if (payload.type != type) {
    return const ScanResult(
      status: QrScanStatus.invalid,
      message: 'This code is not a gate pass',
      title: 'INVALID',
    );
  }

  if (payload.isExpired) {
    return ScanResult(
      status: QrScanStatus.expired,
      message: 'This pass expired on ${payload.expiresAt}',
      title: 'EXPIRED',
    );
  }

  final int index = issued.indexWhere(
    (({String id, String holder, DateTime expiresAt, bool used}) r) =>
        r.id == payload.requestId,
  );
  if (index < 0) {
    return const ScanResult(
      status: QrScanStatus.invalid,
      message: 'No active pass matches this code',
      title: 'INVALID',
    );
  }
  if (issued[index].used) {
    return ScanResult(
      status: QrScanStatus.used,
      message: 'This pass was already used',
      title: 'ALREADY USED',
      holderName: issued[index].holder,
    );
  }

  if (onUse != null) await onUse(payload.requestId);
  return ScanResult(
    status: QrScanStatus.valid,
    message: 'Access granted',
    title: 'VALID',
    holderName: issued[index].holder,
  );
}

/// Production implementation: state is decided by the API, the client only
/// renders it. QR integrity is still verified locally for instant feedback.
class RemoteGatePassRepository implements GatePassRepository {
  RemoteGatePassRepository({required this.api, required this.audit});

  final ApiClient api;
  final AuditLog audit;

  static const String _base = '/gate-passes';

  static GatePass _map(Map<String, Object?> json) => GatePass.fromJson(json);

  @override
  Future<List<GatePass>> myPasses(String studentId) async {
    final Map<String, Object?> res = await api.get(
      _base,
      query: <String, String>{'mine': '1'},
    );
    return _list(res, _map);
  }

  @override
  Future<List<GatePass>> pendingReview() async {
    final Map<String, Object?> res = await api.get(
      _base,
      query: <String, String>{'status': 'pending'},
    );
    return _list(res, _map);
  }

  @override
  Future<GatePass> create({
    required String studentId,
    required String studentName,
    required String reason,
    required String destination,
    required DateTime outAt,
    required DateTime inBy,
  }) async {
    final Map<String, Object?> res = await api.post(
      _base,
      body: <String, Object?>{
        'reason': reason,
        'destination': destination,
        'outAt': outAt.toIso8601String(),
        'inBy': inBy.toIso8601String(),
      },
    );
    final GatePass pass = _map(res['item'] as Map<String, Object?>? ?? res);
    audit.record(
      AuditAction.gatePassCreated,
      actorId: studentId,
      role: 'student',
      detail: pass.id,
    );
    return pass;
  }

  @override
  Future<GatePass> decide({
    required String passId,
    required bool approve,
    required String reviewer,
    String comment = '',
  }) async {
    final Map<String, Object?> res = await api.post(
      '$_base/$passId/review',
      body: <String, Object?>{
        'decision': approve ? 'approve' : 'reject',
        'comment': comment,
      },
    );
    audit.record(
      approve ? AuditAction.gatePassApproved : AuditAction.gatePassRejected,
      actorId: reviewer,
      role: 'warden',
      detail: passId,
    );
    return _map(res['item'] as Map<String, Object?>? ?? res);
  }

  @override
  Future<GatePass> markUsed({
    required String passId,
    required String guard,
  }) async {
    final Map<String, Object?> res = await api.post(
      '$_base/$passId/use',
      body: <String, Object?>{'gate': 'Main Gate'},
    );
    audit.record(
      AuditAction.gatePassUsed,
      actorId: guard,
      role: 'security',
      detail: passId,
    );
    return _map(res['item'] as Map<String, Object?>? ?? res);
  }

  @override
  Future<ScanResult> verifyQr(String rawQr) async {
    // Local integrity check first, then the authoritative server decision.
    final QrPayload payload;
    try {
      payload = QrTokenService.parse(rawQr);
    } on AppException catch (e) {
      return ScanResult(
        status: QrScanStatus.invalid,
        message: e.message,
        title: 'INVALID',
      );
    }
    try {
      final Map<String, Object?> res = await api.post(
        '/passes/scan',
        body: <String, Object?>{
          'code': rawQr,
          'type': payload.type,
          'nonce': payload.nonce,
        },
      );
      final String status = res['status'] as String? ?? 'invalid';
      return ScanResult(
        status: switch (status) {
          'valid' => QrScanStatus.valid,
          'expired' => QrScanStatus.expired,
          'used' => QrScanStatus.used,
          'revoked' => QrScanStatus.revoked,
          _ => QrScanStatus.invalid,
        },
        message: res['message'] as String? ?? '',
        title: status.toUpperCase(),
        holderName: res['holderName'] as String? ?? '',
      );
    } catch (_) {
      return const ScanResult(
        status: QrScanStatus.invalid,
        message: 'Unable to verify this pass right now',
        title: 'INVALID',
      );
    }
  }

  static List<T> _list<T>(
    Map<String, Object?> res,
    T Function(Map<String, Object?>) map,
  ) {
    final Object? items = res['items'];
    if (items is! List) return <T>[];
    return items
        .whereType<Map<String, Object?>>()
        .map(map)
        .toList(growable: false);
  }
}
