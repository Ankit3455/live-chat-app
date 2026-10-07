// lib/feature/games/game_identity.dart
//
// The name and picture Ludo and Carrom show for the current user: the
// profile username from users/{me}, never the sign-in email.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/user_model.dart';
import 'chat_games/ui/player_info.dart';

class GameIdentity {
  const GameIdentity({required this.name, this.avatar});

  final String name;
  final String? avatar;

  // Firestore rules cap these fields (displayName/senderName 100, avatar 2048).
  static const int _maxName = 100;
  static const int _maxAvatar = 2048;

  static String? _uid;
  static Future<GameIdentity>? _pending;
  static GameIdentity? _loaded;

  /// Mine, loaded once per signed-in uid. A failed load is retried on the
  /// next call; until then the auth fallback is returned.
  static Future<GameIdentity> mine() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.uid != _uid || _pending == null) {
      _uid = user?.uid;
      _loaded = null;
      _pending = _load(user);
    }
    return _pending!;
  }

  /// Mine if already loaded for the signed-in uid, else null.
  static GameIdentity? get current {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == _uid ? _loaded : null;
  }

  static Future<GameIdentity> _load(User? user) async {
    if (user == null) return const GameIdentity(name: 'Player');
    Map<String, dynamic>? data;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      data = snap.data();
    } catch (e) {
      debugPrint('Game identity not loaded: $e');
      if (_uid == user.uid) _pending = null;
    }
    final profile = data == null ? null : UserModel.fromMap(data, uid: user.uid);
    final username = data?['username'];
    final identity = GameIdentity(
      name: _pickName(username is String ? username : null, user.displayName),
      avatar: _pickAvatar(avatarUrlOf(profile)) ?? _pickAvatar(user.photoURL),
    );
    if (data != null && _uid == user.uid) _loaded = identity;
    return identity;
  }

  /// Username, else the auth name; anything that looks like an email is
  /// skipped.
  static String _pickName(String? username, String? authName) {
    for (final raw in [username, authName]) {
      final name = raw?.trim() ?? '';
      if (name.isNotEmpty && !name.contains('@')) return _clamp(name);
    }
    return 'Player';
  }

  static String? _pickAvatar(String? url) {
    final u = url?.trim() ?? '';
    return u.isEmpty || u.length > _maxAvatar ? null : u;
  }

  static String _clamp(String name) =>
      name.length > _maxName ? name.substring(0, _maxName) : name;

  /// A player name read from a match/queue/leaderboard doc. Old docs (and
  /// old app versions) may hold an email: only the part before '@' is shown.
  static String shown(Object? raw, String fallback) {
    var name = raw?.toString().trim() ?? '';
    final at = name.indexOf('@');
    if (at >= 0) name = name.substring(0, at).trim();
    return name.isEmpty ? fallback : _clamp(name);
  }
}
