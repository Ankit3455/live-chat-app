import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Online/lastSeen for the signed-in user. Started and stopped by
/// SessionService; caches the uid so the offline write on sign-out still
/// targets the right user.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  /// Kept for existing `Provider<PresenceService>` wiring; returns the singleton.
  factory PresenceService() => instance;

  static const Duration _writeTimeout = Duration(seconds: 4);

  String? _uid;
  bool _observing = false;
  StreamSubscription<DatabaseEvent>? _connectedSub;

  String? get uid => _uid;

  /// Legacy entry point; SessionService.start() drives presence now.
  void init() {}

  Future<void> start(String uid) async {
    if (_uid == uid) return;
    if (_uid != null) await stop();
    _uid = uid;

    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }

    _listenConnection(uid);
    await _setOnline(true);
  }

  /// Marks the cached user offline and stops tracking. Must run while the
  /// user is still signed in (rules need auth).
  Future<void> stop({bool markOffline = true}) async {
    final uid = _uid;
    await _connectedSub?.cancel();
    _connectedSub = null;

    if (uid != null) {
      final statusRef = FirebaseDatabase.instance.ref('presence/$uid');
      if (markOffline) {
        await _setOnline(false);
        try {
          await statusRef
              .set({'state': 'offline', 'lastChanged': ServerValue.timestamp})
              .timeout(_writeTimeout);
        } catch (_) {}
      }
      try {
        await statusRef.onDisconnect().cancel().timeout(_writeTimeout);
      } catch (_) {}
    }

    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _uid = null;
  }

  // RTDB `.info/connected` + onDisconnect so a killed app still goes offline.
  // Mirroring presence/{uid} into Firestore is done server-side.
  void _listenConnection(String uid) {
    final statusRef = FirebaseDatabase.instance.ref('presence/$uid');
    _connectedSub = FirebaseDatabase.instance
        .ref('.info/connected')
        .onValue
        .listen(
          (event) async {
            if (event.snapshot.value != true || _uid != uid) return;
            try {
              await statusRef.onDisconnect().set({
                'state': 'offline',
                'lastChanged': ServerValue.timestamp,
              });
              await statusRef.set({
                'state': 'online',
                'lastChanged': ServerValue.timestamp,
              });
            } catch (e) {
              if (kDebugMode) debugPrint('Presence RTDB error: $e');
            }
          },
          onError: (Object e) {
            if (kDebugMode) debugPrint('Presence connection error: $e');
          },
        );
  }

  Future<void> _setOnline(bool online) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      // Offline writes never resolve without a server ack, so bound the wait.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
            'online': online,
            'lastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(_writeTimeout);
    } catch (e) {
      if (kDebugMode) debugPrint('Presence update failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_uid == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _setOnline(false);
        break;
      case AppLifecycleState.inactive:
        // Transient (dialogs, app switcher); ignoring it avoids on/off flapping.
        break;
    }
  }

  void dispose() {
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _connectedSub?.cancel();
    _connectedSub = null;
  }
}
