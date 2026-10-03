import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Pushes go through OneSignal (DECISIONS.md DEST-097); the server never reads
/// `users.fcmTokens`. This only cleans up tokens written by older builds.
class PushTokenService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _messaging = FirebaseMessaging.instance;

  @Deprecated('FCM tokens are unused; OneSignal is bound by SessionService')
  static Future<void> syncToken() async {}

  /// Removes this device's legacy FCM token. Called by SessionService.signOut
  /// while the user is still signed in.
  static Future<void> removeToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 3),
      );
      if (token == null) return;

      await _db
          .collection('users')
          .doc(user.uid)
          .set({
            'fcmTokens': FieldValue.arrayRemove([token]),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      if (kDebugMode) debugPrint('Remove FCM token failed: $e');
    }
  }
}
