import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Client-side part of the old scheduledCleanup Function: removes the
/// signed-in user's own stale call inbox entries and expired queue docs.
/// Never throws.
class StaleCleanup {
  StaleCleanup._();

  static const Duration _inboxMaxAge = Duration(minutes: 2);
  static const Duration _legacyQueueMaxAge = Duration(hours: 2);
  static const Duration _timeout = Duration(seconds: 10);
  static const List<String> _queues = ['ludo_queue', 'carrom_queue'];

  static Future<void> run(String uid) async {
    await Future.wait([
      _step('incoming_calls', () => _sweepInbox(uid)),
      for (final q in _queues) _step(q, () => _sweepQueue(q, uid)),
    ]);
  }

  static Future<void> _sweepInbox(String uid) async {
    final db = FirebaseDatabase.instance;
    final ref = db.ref('incoming_calls/$uid');
    final snap = await ref.get().timeout(_timeout);
    if (!snap.exists) return;
    final now = DateTime.now().millisecondsSinceEpoch + await _serverOffset(db);
    final updates = <String, Object?>{};
    for (final call in snap.children) {
      final value = call.value;
      final ts = value is Map ? value['timestamp'] : null;
      if (ts is num && now - ts < _inboxMaxAge.inMilliseconds) continue;
      final key = call.key;
      if (key != null) updates[key] = null;
    }
    if (updates.isNotEmpty) await ref.update(updates).timeout(_timeout);
  }

  static Future<int> _serverOffset(FirebaseDatabase db) async {
    try {
      final event = await db
          .ref('.info/serverTimeOffset')
          .onValue
          .first
          .timeout(const Duration(seconds: 3));
      final v = event.snapshot.value;
      return v is num ? v.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _sweepQueue(String collection, String uid) async {
    final ref = FirebaseFirestore.instance.collection(collection).doc(uid);
    final snap = await ref.get().timeout(_timeout);
    final data = snap.data();
    if (data == null) return;
    final now = DateTime.now();
    final expiresAt = data['expiresAt'];
    final createdAt = data['createdAt'];
    final expired = expiresAt is Timestamp
        ? expiresAt.toDate().isBefore(now)
        : createdAt is Timestamp &&
              now.difference(createdAt.toDate()) > _legacyQueueMaxAge;
    if (expired) await ref.delete().timeout(_timeout);
  }

  static Future<void> _step(String name, Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (kDebugMode) {
        final code = e is FirebaseException ? e.code : e.runtimeType;
        debugPrint('StaleCleanup $name failed: $code');
      }
    }
  }
}
