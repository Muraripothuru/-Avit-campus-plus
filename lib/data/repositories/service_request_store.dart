import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/firebase_bridge.dart';

/// Persistence for campus service requests.
///
/// Docx section 19: submissions live in the Firestore `service_requests`
/// collection whose document id is the SR reference (section 20). The demo
/// implementation reproduces the same reference format in memory so tests
/// and offline runs behave identically.
abstract class ServiceRequestStore {
  /// Saves the request and returns its SR reference. [reference] forces a
  /// specific reference so a mirrored submission keeps one identity in
  /// both the local and the cloud store.
  Future<String> submit(Map<String, Object?> data, {String? reference});

  /// Most recent requests for the signed-in student, newest first.
  Future<List<Map<String, String>>> recent({int limit = 20});

  /// Every request across all students, newest first — the admin
  /// operations view.
  Future<List<Map<String, String>>> all({int limit = 100});

  /// Moves one request to [status] ('Submitted', 'In progress',
  /// 'Resolved'); unknown references are ignored.
  Future<void> updateStatus(String reference, String status);

  /// Uploads a real attachment and returns its download URL, or null when
  /// the backend is unavailable (attachments are optional).
  Future<String?> uploadAttachment({
    required String reference,
    required String fileName,
    required Uint8List bytes,
  });
}

/// Optional persistence for [DemoServiceRequestStore].
///
/// The demo store stays in memory when this is null; supplying a
/// shared_preferences backed implementation makes submissions survive an
/// app restart so the records screen keeps its history.
abstract class ServiceRequestPersistence {
  /// Restored records (newest first), or null when nothing was saved yet.
  Future<List<Map<String, String>>?> read();

  /// Replaces the persisted record list.
  Future<void> write(List<Map<String, String>> records);
}

/// [ServiceRequestPersistence] backed by SharedPreferences (demo mode).
class PrefsServiceRequestPersistence implements ServiceRequestPersistence {
  PrefsServiceRequestPersistence(this._prefs);

  static const String storageKey = 'avit.service.request.records';

  final SharedPreferences _prefs;

  /// Opens the preference store, or returns null when the platform channel
  /// is unavailable (widget tests) so callers fall back to memory.
  static Future<PrefsServiceRequestPersistence?> tryCreate() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      return PrefsServiceRequestPersistence(prefs);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Map<String, String>>?> read() async {
    final String? raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) return null;
      return <Map<String, String>>[
        for (final Object? item in decoded)
          if (item is Map<Object?, Object?>)
            <String, String>{
              for (final MapEntry<Object?, Object?> e in item.entries)
                if (e.key is String && e.value != null)
                  '${e.key}': '${e.value}',
            },
      ];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(List<Map<String, String>> records) async {
    try {
      await _prefs.setString(storageKey, jsonEncode(records));
    } catch (_) {
      // Losing a demo write must never break the submit flow.
    }
  }
}

/// Resolves SharedPreferences once, lazily and failure-safe: every call
/// degrades to a no-op when the platform channel is missing, so the store
/// simply keeps its records in memory.
class LazyPrefsServiceRequestPersistence implements ServiceRequestPersistence {
  LazyPrefsServiceRequestPersistence()
    : _future = PrefsServiceRequestPersistence.tryCreate();

  final Future<PrefsServiceRequestPersistence?> _future;

  @override
  Future<List<Map<String, String>>?> read() async =>
      (await _future)?.read();

  @override
  Future<void> write(List<Map<String, String>> records) async =>
      (await _future)?.write(records);
}

/// Session store used when Firebase is not initialised.
///
/// Keeps every submission for the whole session (newest first) so the
/// requests list still shows a student's previous records after they
/// navigate away from the service request screen and come back — and,
/// when a [ServiceRequestPersistence] is supplied, across app restarts.
class DemoServiceRequestStore implements ServiceRequestStore {
  DemoServiceRequestStore({Random? random, this.persistence})
    : _random = random ?? Random();

  final Random _random;
  final ServiceRequestPersistence? persistence;

  List<Map<String, String>> _records = <Map<String, String>>[];
  Future<void>? _hydrated;

  Future<void> _ensureLoaded() => _hydrated ??= _load();

  Future<void> _load() async {
    if (persistence == null) return;
    try {
      final List<Map<String, String>>? restored = await persistence!.read();
      if (restored != null) _records = restored;
    } catch (_) {
      // Corrupt or unavailable storage — start from an empty session list.
    }
  }

  Future<void> _persist() async {
    if (persistence == null) return;
    try {
      await persistence!.write(_records);
    } catch (_) {
      // Persistence is best-effort; the in-memory copy already succeeded.
    }
  }

  @override
  Future<String> submit(Map<String, Object?> data, {String? reference}) async {
    await _ensureLoaded();
    final int n = _random.nextInt(9000) + 1000;
    final String ref = reference ?? 'SR-${DateTime.now().year}-$n';
    _records.insert(0, <String, String>{
      'ref': ref,
      'subject': '${data['subject'] ?? ''}',
      'category': '${data['category'] ?? ''}',
      'urgency': '${data['urgency'] ?? ''}',
      'name': '${data['studentName'] ?? ''}',
      'studentId': '${data['studentId'] ?? ''}',
      'description': '${data['description'] ?? ''}',
      'status': 'Submitted',
      'preferredDate': '${data['preferredDate'] ?? ''}',
      'createdAt': DateTime.now().toIso8601String(),
    });
    if (_records.length > 100) _records.removeLast();
    await _persist();
    return ref;
  }

  @override
  Future<List<Map<String, String>>> recent({int limit = 20}) async {
    await _ensureLoaded();
    return _records.take(limit).toList();
  }

  @override
  Future<List<Map<String, String>>> all({int limit = 100}) async {
    await _ensureLoaded();
    return _records.take(limit).toList();
  }

  @override
  Future<void> updateStatus(String reference, String status) async {
    await _ensureLoaded();
    final int index = _records.indexWhere(
      (Map<String, String> r) => r['ref'] == reference,
    );
    if (index == -1) return;
    _records[index] = Map<String, String>.from(_records[index])
      ..['status'] = status;
    await _persist();
  }

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
  Future<String> submit(Map<String, Object?> data, {String? reference}) async {
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
    // is still free before writing — unless the caller mirrors a reference
    // the local store already owns.
    final int attempts = reference == null ? 5 : 1;
    for (int attempt = 0; attempt < attempts; attempt++) {
      final String ref = reference ?? _newReference();
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
  Future<List<Map<String, String>>> recent({int limit = 20}) async {
    final FirebaseFirestore? db = FirebaseBridge.db;
    final String? uid = FirebaseBridge.uid;
    if (db == null || uid == null) return const <Map<String, String>>[];
    try {
      final QuerySnapshot<Map<String, Object?>> snap = await db
          .collection('service_requests')
          .where('ownerUid', isEqualTo: uid)
          .get();
      return _takeNewest(snap.docs, limit);
    } catch (_) {
      return const <Map<String, String>>[];
    }
  }

  @override
  Future<List<Map<String, String>>> all({int limit = 100}) async {
    final FirebaseFirestore? db = FirebaseBridge.db;
    if (db == null) return const <Map<String, String>>[];
    try {
      final QuerySnapshot<Map<String, Object?>> snap = await db
          .collection('service_requests')
          .get();
      return _takeNewest(snap.docs, limit);
    } catch (_) {
      return const <Map<String, String>>[];
    }
  }

  @override
  Future<void> updateStatus(String reference, String status) async {
    final FirebaseFirestore? db = FirebaseBridge.db;
    if (db == null) throw StateError('Firebase is not initialised');
    await FirebaseBridge.ensureIdentity();
    await db.collection('service_requests').doc(reference).update(
      <String, Object?>{'status': status},
    );
  }

  List<Map<String, String>> _takeNewest(
    List<QueryDocumentSnapshot<Map<String, Object?>>> docs,
    int limit,
  ) {
    final List<QueryDocumentSnapshot<Map<String, Object?>>> sorted =
        docs.toList()
          ..sort(
            (
              QueryDocumentSnapshot<Map<String, Object?>> a,
              QueryDocumentSnapshot<Map<String, Object?>> b,
            ) => _timestampOf(b).compareTo(_timestampOf(a)),
          );
    return <Map<String, String>>[
      for (final QueryDocumentSnapshot<Map<String, Object?>> d in sorted.take(
        limit,
      ))
        <String, String>{
          'ref': d.id,
          'subject': '${d.data()['subject'] ?? ''}',
          'category': '${d.data()['category'] ?? ''}',
          'urgency': '${d.data()['urgency'] ?? ''}',
          'name': '${d.data()['studentName'] ?? ''}',
          'studentId': '${d.data()['studentId'] ?? ''}',
          'description': '${d.data()['description'] ?? ''}',
          'status': '${d.data()['status'] ?? 'Submitted'}',
          'preferredDate': '${d.data()['preferredDate'] ?? ''}',
          'createdAt': _timestampOf(d).toIso8601String(),
        },
    ];
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
