// lib/services/presence_watch.dart
import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Who is online right now, read from RTDB `presence/{uid}/state`.
///
/// RTDB presence is the source of truth: PresenceService registers an
/// onDisconnect, so a killed app still goes offline. The Firestore `online`
/// field is not reliable (on the Spark plan nothing clears it for killed
/// apps, and it flips to false when the app is in the background), so the UI
/// must not use it.
class PresenceWatch {
  PresenceWatch._();
  static final PresenceWatch instance = PresenceWatch._();

  /// Keeps listener count bounded on very long feeds.
  static const int maxWatched = 200;

  /// Uids that are online among the watched ones.
  final ValueNotifier<Set<String>> online = ValueNotifier(const {});

  final Map<String, StreamSubscription<DatabaseEvent>> _subs = {};
  final Set<String> _online = {};

  bool isOnline(String? uid) => uid != null && online.value.contains(uid);

  /// Watches exactly [uids] (first [maxWatched]); stops watching the rest.
  void watch(Iterable<String> uids) {
    final wanted = uids.take(maxWatched).toSet();
    for (final uid in _subs.keys.toList()) {
      if (!wanted.contains(uid)) {
        _subs.remove(uid)?.cancel();
        _online.remove(uid);
      }
    }
    for (final uid in wanted) {
      if (_subs.containsKey(uid)) continue;
      _subs[uid] = FirebaseDatabase.instance
          .ref('presence/$uid/state')
          .onValue
          .listen(
            (event) => _set(uid, event.snapshot.value == 'online'),
            onError: (Object e) {
              if (kDebugMode) debugPrint('PresenceWatch($uid) failed: $e');
            },
          );
    }
    _publish();
  }

  /// Live online state of one user (chat header).
  Stream<bool> watchOne(String uid) => FirebaseDatabase.instance
      .ref('presence/$uid/state')
      .onValue
      .map((e) => e.snapshot.value == 'online')
      .distinct();

  /// True only while [uid]'s presence explicitly says offline (set by its
  /// onDisconnect). A missing node (presence never written) is not "gone",
  /// so it can't make a live player forfeit a game.
  Stream<bool> watchGone(String uid) => FirebaseDatabase.instance
      .ref('presence/$uid/state')
      .onValue
      .map((e) => e.snapshot.value == 'offline')
      .distinct();

  void clear() {
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    _online.clear();
    _publish();
  }

  void _set(String uid, bool isOnline) {
    final changed = isOnline ? _online.add(uid) : _online.remove(uid);
    if (changed) _publish();
  }

  void _publish() {
    if (setEquals(online.value, _online)) return;
    online.value = Set.unmodifiable(_online);
  }
}
