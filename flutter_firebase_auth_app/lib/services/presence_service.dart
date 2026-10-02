import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  bool _attached = false;

  void init() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        print('🟢 User logged in: ${user.uid}'); // ✅ DEBUG
        await _setOnline(true);
      } else {
        print('🔴 User logged out'); // ✅ DEBUG
        await _setOnline(false);
      }
    });

    print('✅ PresenceService initialized'); // ✅ DEBUG
  }

  Future<void> _setOnline(bool online) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        print('⚠️ Cannot update presence - No user logged in'); // ✅ DEBUG
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'online': online,
          'lastSeen': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      print('✅ User $uid is now: ${online ? "ONLINE ✓" : "OFFLINE ✗"}'); // ✅ DEBUG
    } catch (e) {
      print('❌ Error updating presence: $e'); // ✅ DEBUG
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Mark online true when app is foreground, false when background
    switch (state) {
      case AppLifecycleState.resumed:
        print('📱 App RESUMED - Setting ONLINE'); // ✅ DEBUG
        _setOnline(true);
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden: // ✅ FIXED - No more crash!
        print('📱 App PAUSED/HIDDEN - Setting OFFLINE'); // ✅ DEBUG
        _setOnline(false);
        break;
    }
  }

  void dispose() {
    print('🧹 PresenceService disposing...'); // ✅ DEBUG

    // ✅ Set user offline before disposing
    _setOnline(false);

    if (_attached) {
      WidgetsBinding.instance.removeObserver(this);
      _attached = false;
    }
    _authSub?.cancel();
  }
}