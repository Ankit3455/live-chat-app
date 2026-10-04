import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/auth_validators.dart';
import '../models/public_profile.dart';

/// Mirrors the signed-in user's `users/{uid}` into `public_profiles/{uid}`
/// from the client (replaces the mirrorPublicProfile Function). Started and
/// stopped by SessionService. Failures are logged only.
class PublicProfileSync {
  PublicProfileSync._();
  static final PublicProfileSync instance = PublicProfileSync._();

  static const Duration _debounce = Duration(seconds: 1);
  static const Duration _flushTimeout = Duration(seconds: 4);

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _timer;
  String? _uid;
  String? _lastWritten;

  void start(String uid) {
    if (_uid == uid && _sub != null) return;
    stop();
    _uid = uid;
    _sub = _db
        .collection('users')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snap) => _onSnapshot(uid, snap),
          onError: (Object e) => _log('listen', e),
        );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    unawaited(_sub?.cancel());
    _sub = null;
    _uid = null;
    _lastWritten = null;
  }

  /// Writes the current profile now (e.g. offline state on sign-out), then
  /// stops. Must run while still signed in.
  Future<void> flushAndStop() async {
    final uid = _uid;
    _timer?.cancel();
    _timer = null;
    if (uid != null) {
      try {
        final snap = await _db
            .collection('users')
            .doc(uid)
            .get()
            .timeout(_flushTimeout);
        final data = snap.data();
        if (data != null) await _write(uid, data).timeout(_flushTimeout);
      } catch (e) {
        _log('flush', e);
      }
    }
    stop();
  }

  void _onSnapshot(String uid, DocumentSnapshot<Map<String, dynamic>> snap) {
    // Wait for server-confirmed data so pending server timestamps are set.
    if (snap.metadata.hasPendingWrites || snap.metadata.isFromCache) return;
    final data = snap.data();
    if (data == null) return;
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(_write(uid, data)));
  }

  Future<void> _write(String uid, Map<String, dynamic> data) async {
    if (_uid != uid) return;
    final public = PublicProfile.fromUserData(uid, data);
    public['uid'] = uid;
    if (public['online'] is! bool) public['online'] = false;
    _fitRules(public, data);

    final key = _canonical(public);
    if (key == _lastWritten) return;
    _lastWritten = key;
    try {
      await _db.collection(PublicProfile.collection).doc(uid).set({
        ...public,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (_lastWritten == key) _lastWritten = null;
      _log('write', e);
    }
  }

  // Limits of publicProfileOk in firestore.rules.
  static const int _maxAge = 120;
  static const int _maxUrl = 2048;
  static const Map<String, int> _textCaps = {
    'username': 100,
    'bio': 1000,
    'profession': 150,
    'education': 150,
    'location': 100,
    'idealDate': 500,
    'hereFor': 200,
    'gender': 50,
  };
  static const List<String> _urlKeys = [
    'profileImage',
    'avatar',
    'voiceIntroUrl',
  ];
  static const Map<String, int> _listCaps = {
    'interests': 30,
    'hereFor': 30,
    'habits': 30,
    'pets': 30,
    'musicGenres': 30,
    'movieGenres': 30,
    'tvGenres': 30,
    'preferredSigns': 12,
  };

  /// Makes [p] pass the public_profiles rules: legacy oversized text and lists
  /// are trimmed, oversized URLs dropped, an age outside 18..120 is dropped
  /// (discovery then off), and lastSeen is a Timestamp not in the future.
  static void _fitRules(Map<String, dynamic> p, Map<String, dynamic> data) {
    _textCaps.forEach((key, max) {
      final v = p[key];
      if (v is String && v.length > max) p[key] = _truncate(v, max);
    });
    for (final key in _urlKeys) {
      final v = p[key];
      if (v is String && v.length > _maxUrl) p.remove(key);
    }
    _listCaps.forEach((key, max) {
      final v = p[key];
      if (v is List && v.length > max) p[key] = v.sublist(0, max);
    });
    final avatarProps = p['avatarProperties'];
    final avatarUrl = avatarProps is Map ? avatarProps['avatarImageUrl'] : null;
    if (avatarUrl is String && avatarUrl.length > _maxUrl) {
      p.remove('avatarProperties');
    }

    final age = p['age'];
    if (age is! int || age < AgePolicy.minAge || age > _maxAge) {
      p.remove('age');
      p['discoveryEnabled'] = false;
    }

    // The feed orders by lastSeen; a doc without it would never be listed.
    Object? lastSeen = p['lastSeen'];
    if (lastSeen is! Timestamp) {
      final createdAt = data['createdAt'];
      lastSeen = createdAt is Timestamp ? createdAt : Timestamp(0, 0);
    }
    p['lastSeen'] = lastSeen.toDate().isAfter(DateTime.now())
        ? FieldValue.serverTimestamp()
        : lastSeen;
  }

  // Cuts to [max] UTF-16 units without splitting a surrogate pair.
  static String _truncate(String s, int max) {
    var end = max;
    final last = s.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end--;
    return s.substring(0, end);
  }

  static String _canonical(Object? value) =>
      jsonEncode(_normalise(value), toEncodable: (v) => v.toString());

  static Object? _normalise(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _normalise(v[k])};
    }
    if (v is List) return v.map(_normalise).toList();
    if (v is Timestamp) return 'ts:${v.seconds}.${v.nanoseconds}';
    if (v is GeoPoint) return 'geo:${v.latitude},${v.longitude}';
    if (v is DateTime) return 'dt:${v.microsecondsSinceEpoch}';
    if (v is DocumentReference) return 'ref:${v.path}';
    return v;
  }

  static void _log(String step, Object e) {
    if (!kDebugMode) return;
    final code = e is FirebaseException ? e.code : e.runtimeType;
    debugPrint('PublicProfileSync $step failed: $code');
  }
}
