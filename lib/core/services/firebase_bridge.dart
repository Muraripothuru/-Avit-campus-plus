import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../firebase_options.dart';

/// Runtime capability wrapper around Firebase.
///
/// `main()` calls [init] once at startup; widget tests construct
/// `AvitCampusPlus` directly and never touch Firebase, so [ready] stays
/// false there and every call site falls back to the local demo behaviour.
class FirebaseBridge {
  FirebaseBridge._();

  static bool ready = false;

  static Future<void> init() async {
    if (ready) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      ready = true;
    } catch (_) {
      ready = false;
    }
  }

  static FirebaseAuth? get auth => ready ? FirebaseAuth.instance : null;

  static FirebaseFirestore? get db => ready ? FirebaseFirestore.instance : null;

  static FirebaseStorage? get storage =>
      ready ? FirebaseStorage.instance : null;

  static String? get uid => auth?.currentUser?.uid;

  /// Gives the session an identity so security rules can scope data to it.
  ///
  /// Anonymous sign-in keeps submissions working before anyone logs in
  /// (docx section: anonymous authentication); failures are ignored and the
  /// call sites degrade to demo data.
  static Future<void> ensureIdentity() async {
    final FirebaseAuth? a = auth;
    if (a == null) return;
    try {
      if (a.currentUser == null) await a.signInAnonymously();
    } catch (_) {
      // Offline or rules blocked it.
    }
  }

  /// Best-effort email/password sign-in after the demo validator passed, so
  /// demo accounts that Firebase does not know keep the current identity.
  static Future<void> tryEmailSignIn(String email, String password) async {
    final FirebaseAuth? a = auth;
    if (a == null) return;
    try {
      await a.signInWithEmailAndPassword(email: email, password: password);
    } catch (_) {
      // Keep whatever identity we already have.
    }
  }

  /// Creates the matching Firebase account for a new sign-up.
  static Future<String?> tryEmailSignUp(String email, String password) async {
    final FirebaseAuth? a = auth;
    if (a == null) return null;
    try {
      final UserCredential result = await a.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Writes the signed-in profile under `users/{uid}` — rules only allow the
  /// owner to touch their own document.
  static Future<void> syncProfile(Map<String, Object?> fields) async {
    final FirebaseFirestore? database = db;
    final String? id = uid;
    if (database == null || id == null) return;
    try {
      await database
          .collection('users')
          .doc(id)
          .set(fields, SetOptions(merge: true));
    } catch (_) {
      // Profile mirroring is best-effort; the local repository already saved.
    }
  }

  static Future<void> trySignOut() async {
    try {
      await auth?.signOut();
    } catch (_) {
      // Nothing to clean up.
    }
  }
}
