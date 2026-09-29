import '../../core/security/audit_log.dart';
import '../../core/security/qr_token_service.dart';
import '../../core/utils/app_exception.dart';
import '../../models/pass.dart';
import '../datasources/api_client.dart';
import '../datasources/local_store.dart';

/// Visitor pass lifecycle (student request → review → QR → gate use).
abstract class VisitorPassRepository {
  Future<List<VisitorPass>> myPasses(String studentId);
  Future<List<VisitorPass>> pendingReview();
  Future<VisitorPass> create({
    required String hostStudentId,
    required String hostStudentName,
    required String visitorName,
    required String visitorPhone,
    required String idType,
    required DateTime visitDate,
    required String purpose,
  });
  Future<VisitorPass> decide({
    required String passId,
    required bool approve,
    required String reviewer,
    String comment = '',
  });
  Future<VisitorPass> markUsed({required String passId, required String guard});
  Future<ScanResult> verifyQr(String rawQr);
}

class DemoVisitorPassRepository implements VisitorPassRepository {
  DemoVisitorPassRepository({required this.store, required this.audit});

  final LocalStore store;
  final AuditLog audit;

  static Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 240));

  @override
  Future<List<VisitorPass>> myPasses(String studentId) async {
    await _delay();
    return store.visitorPassesFor(studentId);
  }

  @override
  Future<List<VisitorPass>> pendingReview() async {
    await _delay();
    return store.visitorPasses
        .where((VisitorPass p) => p.status == PassStatus.pending)
        .toList();
  }

  @override
  Future<VisitorPass> create({
    required String hostStudentId,
    required String hostStudentName,
    required String visitorName,
    required String visitorPhone,
    required String idType,
    required DateTime visitDate,
    required String purpose,
  }) async {
    await _delay();
    final bool tooSoon = visitDate.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    if (tooSoon) {
      throw const AppException(
        'Visit date cannot be in the past',
        kind: 'validation',
      );
    }
    final VisitorPass pass = VisitorPass(
      id: 'vp_${DateTime.now().millisecondsSinceEpoch}',
      hostStudentId: hostStudentId,
      hostStudentName: hostStudentName,
      visitorName: visitorName,
      visitorPhone: visitorPhone,
      idType: idType,
      visitDate: visitDate,
      purpose: purpose,
      createdAt: DateTime.now(),
    );
    store.visitorPasses.insert(0, pass);
    audit.record(
      AuditAction.visitorRequested,
      actorId: hostStudentId,
      role: 'student',
      detail: pass.id,
    );
    return pass;
  }

  @override
  Future<VisitorPass> decide({
    required String passId,
    required bool approve,
    required String reviewer,
    String comment = '',
  }) async {
    await _delay();
    final int index = store.visitorPasses
        .indexWhere((VisitorPass p) => p.id == passId);
    if (index < 0) throw AppException.notFound;
    final VisitorPass existing = store.visitorPasses[index];
    if (existing.status != PassStatus.pending) {
      throw const AppException(
        'This request has already been reviewed',
        kind: 'validation',
      );
    }
    final VisitorPass updated = existing.copyWith(
      status: approve ? PassStatus.approved : PassStatus.rejected,
      reviewerComment: comment,
      reviewedBy: reviewer,
      qrToken: approve
          ? QrTokenService.issue(
              type: 'visitor',
              requestId: existing.id,
              holderId: existing.hostStudentId,
              expiresAt: DateTime(
                existing.visitDate.year,
                existing.visitDate.month,
                existing.visitDate.day,
                23,
                59,
              ),
            )
          : null,
    );
    store.visitorPasses[index] = updated;
    audit.record(
      approve ? AuditAction.visitorApproved : AuditAction.visitorRejected,
      actorId: reviewer,
      role: 'warden',
      detail: updated.id,
    );
    return updated;
  }

  @override
  Future<VisitorPass> markUsed({
    required String passId,
    required String guard,
  }) async {
    await _delay();
    final int index = store.visitorPasses
        .indexWhere((VisitorPass p) => p.id == passId);
    if (index < 0) throw AppException.notFound;
    final VisitorPass updated = store.visitorPasses[index].copyWith(
      status: PassStatus.used,
      usedAt: DateTime.now(),
      reviewedBy: guard,
    );
    store.visitorPasses[index] = updated;
    return updated;
  }

  @override
  Future<ScanResult> verifyQr(String rawQr) async {
    await _delay();
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
    if (payload.type != 'visitor') {
      return const ScanResult(
        status: QrScanStatus.invalid,
        message: 'This code is not a visitor pass',
        title: 'INVALID',
      );
    }
    final int index = store.visitorPasses
        .indexWhere((VisitorPass p) => p.id == payload.requestId);
    if (index < 0) {
      return const ScanResult(
        status: QrScanStatus.invalid,
        message: 'No visitor pass matches this code',
        title: 'INVALID',
      );
    }
    final VisitorPass pass = store.visitorPasses[index];
    if (pass.status == PassStatus.used) {
      return ScanResult(
        status: QrScanStatus.used,
        message: 'This pass was already used',
        title: 'ALREADY USED',
        holderName: pass.visitorName,
      );
    }
    if (pass.status != PassStatus.approved) {
      return ScanResult(
        status: QrScanStatus.revoked,
        message: 'This pass is ${pass.status.label.toLowerCase()}',
        title: 'REVOKED',
        holderName: pass.visitorName,
      );
    }
    if (payload.isExpired) {
      return ScanResult(
        status: QrScanStatus.expired,
        message: 'This pass expired on ${payload.expiresAt}',
        title: 'EXPIRED',
      );
    }
    store.visitorPasses[index] = pass.copyWith(
      status: PassStatus.used,
      usedAt: DateTime.now(),
    );
    return ScanResult(
      status: QrScanStatus.valid,
      message: 'Visitor entry allowed',
      title: 'VALID',
      holderName: pass.visitorName,
    );
  }
}

class RemoteVisitorPassRepository implements VisitorPassRepository {
  RemoteVisitorPassRepository({required this.api, required this.audit});

  final ApiClient api;
  final AuditLog audit;
  static const String _base = '/visitor-passes';

  static VisitorPass _map(Map<String, Object?> json) =>
      VisitorPass.fromJson(json);

  static List<VisitorPass> _list(Map<String, Object?> res) {
    final Object? items = res['items'];
    if (items is! List) return <VisitorPass>[];
    return items
        .whereType<Map<String, Object?>>()
        .map(_map)
        .toList(growable: false);
  }

  @override
  Future<List<VisitorPass>> myPasses(String studentId) async =>
      _list(await api.get(_base, query: <String, String>{'mine': '1'}));

  @override
  Future<List<VisitorPass>> pendingReview() async => _list(
    await api.get(_base, query: <String, String>{'status': 'pending'}),
  );

  @override
  Future<VisitorPass> create({
    required String hostStudentId,
    required String hostStudentName,
    required String visitorName,
    required String visitorPhone,
    required String idType,
    required DateTime visitDate,
    required String purpose,
  }) async {
    final Map<String, Object?> res = await api.post(
      _base,
      body: <String, Object?>{
        'visitorName': visitorName,
        'visitorPhone': visitorPhone,
        'idType': idType,
        'visitDate': visitDate.toIso8601String(),
        'purpose': purpose,
      },
    );
    audit.record(
      AuditAction.visitorRequested,
      actorId: hostStudentId,
      role: 'student',
    );
    return _map(res['item'] as Map<String, Object?>? ?? res);
  }

  @override
  Future<VisitorPass> decide({
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
      approve ? AuditAction.visitorApproved : AuditAction.visitorRejected,
      actorId: reviewer,
      role: 'warden',
      detail: passId,
    );
    return _map(res['item'] as Map<String, Object?>? ?? res);
  }

  @override
  Future<VisitorPass> markUsed({
    required String passId,
    required String guard,
  }) async {
    final Map<String, Object?> res = await api.post(
      '$_base/$passId/use',
      body: <String, Object?>{'gate': 'Main Gate'},
    );
    return _map(res['item'] as Map<String, Object?>? ?? res);
  }

  @override
  Future<ScanResult> verifyQr(String rawQr) async {
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
}
