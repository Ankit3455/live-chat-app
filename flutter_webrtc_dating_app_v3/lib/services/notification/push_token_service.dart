import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushTokenService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _messaging = FirebaseMessaging.instance;

  /// Call this after login / app start
  static Future<void> syncToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('🔕 PushTokenService: No user logged in');
        return;
      }

      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('🔕 PushTokenService: Token is null');
        return;
      }

      await _db.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastPushTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ PushTokenService: Token synced');
    } catch (e) {
      debugPrint('❌ PushTokenService error: $e');
    }
  }

  /// Optional: call this on logout
  static Future<void> removeToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      await _db.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });

      debugPrint('✅ PushTokenService: Token removed');
    } catch (e) {
      debugPrint('❌ Remove token failed: $e');
    }
  }
}
