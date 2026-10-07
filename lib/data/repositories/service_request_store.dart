import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/services/firebase_bridge.dart';

/// Persistence for campus service requests.
///
/// Docx section 19: submissions live in the Firestore `service_requests`
/// collection whose document id is the SR reference (section 20). The demo
/// implementation reproduces the same reference format in memory so tests
/// and offline runs behave identically.
abstract class ServiceRequestStore {
  /// Saves the request and returns its SR reference.
  Future<String> submit(Map<String, Object?> data);

  /// Most recent requests for the signed-in student, newest first.
  Future<List<Map<String, String>>> recent({int limit = 5});

  /// Uploads a real attachment and returns its download URL, or null when
  /// the backend is unavailable (attachments are optional).
  Future<String?> uploadAttachment({
    required String reference,
    required String fileName,
    required Uint8List bytes,
  });
}

/// In-memory store used when Firebase is not initialised.
class DemoServiceRequestStore implements ServiceRequestStore {
  DemoServiceRequestStore({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  Future<String> submit(Map<String, Object?> data) async {
    final int n = _random.nextInt(9000) + 1000;
    return 'SR-${DateTime.now().year}-$n';
  }

  @override
  Future<List<Map<String, String>>> recent({int limit = 5}) async =>
      const <Map<String, String>>[];

  @override
  Future<String?> uploadAttachment({
    required String reference,
    required String fileName,
    required Uint8List bytes,
  }) async => null;
}

/// Firestore-backed store (docx sections 19-24).
class FirebaseServiceRequestStore implements ServiceRequestStore {
  @override
  Future<String> submit(Map<String, Object?> data) async {
    final FirebaseFirestore? db = FirebaseBridge.db;
    if (db == null) {
      throw StateError('Firebase is not initialised');
    }
    await FirebaseBridge.ensureIdentity();
    final String uid = FirebaseBridge.uid ?? '';
    final Object? attachmentBytes = data['attachmentBytes'];
    final Map<String, Object?> payload = Map<String, Object?>.of(data)
      ..remove('attachmentBytes')
      ..['ownerUid'] = uid
      ..['createdAt'] = FieldValue.serverTimestamp();

    // The document id is the SR reference, so allocate one and make sure it
    // is still free before writing.
    for (int attempt = 0; attempt < 5; attempt++) {
      final String ref = _newReference();
      final DocumentReference<Map<String, Object?>> doc = db
          .collection('service_requests')
          .doc(ref);
      final DocumentSnapshot<Map<String, Object?>> existing = await doc.get();
      if (existing.exists) continue;
      await doc.set(payload);
      if (attachmentBytes is Uint8List) {
        final String? url = await uploadAttachment(
          reference: ref,
          fileName: '${data['attachment'] ?? 'attachment'}',
          bytes: attachmentBytes,
        );
        if (url != null) {
          try {
            await doc.update(<String, Object?>{'attachmentUrl': url});
          } catch (_) {
            // The request itself already succeeded.
          }
        }
      }
      return ref;
    }
    throw StateError('Could not allocate a request reference');
  }

  String _newReference() {
    final int n = Random().nextInt(9000) + 1000;
    return 'SR-${DateTime.now().year}-$n';
  }

  @override
  Future<List<Map<String, String>>> recent({int limit = 5}) async {
    final FirebaseFirestore? db = FirebaseBridge.db;
    final String? uid = FirebaseBridge.uid;
    if (db == null || uid == null) return const <Map<String, String>>[];
    try {
      final QuerySnapshot<Map<String, Object?>> snap = await db
          .collection('service_requests')
          .where('ownerUid', isEqualTo: uid)
          .get();
      final List<QueryDocumentSnapshot<Map<String, Object?>>> docs =
          snap.docs.toList()..sort(
            (
              QueryDocumentSnapshot<Map<String, Object?>> a,
              QueryDocumentSnapshot<Map<String, Object?>> b,
            ) => _timestampOf(b).compareTo(_timestampOf(a)),
          );
      return <Map<String, String>>[
        for (final QueryDocumentSnapshot<Map<String, Object?>> d in docs.take(
          limit,
        ))
          <String, String>{
            'ref': d.id,
            'subject': '${d.data()['subject'] ?? ''}',
            'category': '${d.data()['category'] ?? ''}',
            'urgency': '${d.data()['urgency'] ?? ''}',
          },
      ];
    } catch (_) {
      return const <Map<String, String>>[];
    }
  }

  DateTime _timestampOf(DocumentSnapshot<Map<String, Object?>> doc) {
    final Object? value = doc.data()?['createdAt'];
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Future<String?> uploadAttachment({
    required String reference,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final FirebaseStorage? storage = FirebaseBridge.storage;
    if (storage == null) return null;
    try {
      final Reference ref = storage.ref(
        'service-attachments/${FirebaseBridge.uid ?? 'anon'}/$reference/$fileName',
      );
      await ref.putData(bytes);
      return await ref.getDownloadURL();
    } catch (_) {
      return null; // Attachment is optional; the request still submits.
    }
  }
}
