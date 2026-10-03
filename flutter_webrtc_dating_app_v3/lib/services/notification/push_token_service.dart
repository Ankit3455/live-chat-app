import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Pushes go through OneSignal (DECISIONS.md DEST-097); the server never reads
/// `users.fcmTokens`. This only cleans up tokens written by older builds.
class PushTokenService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  @Deprecated('FCM tokens are unused; OneSignal is bound by SessionService')
  static Future<void> syncToken() async {}

  /// Drops the legacy `fcmTokens` field. Called by SessionService.signOut
  /// while the user is still signed in.
  static Future<void> removeToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _db
          .collection('users')
          .doc(user.uid)
          .update({'fcmTokens': FieldValue.delete()})
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      if (kDebugMode) debugPrint('Remove FCM tokens failed: $e');
    }
  }
}
