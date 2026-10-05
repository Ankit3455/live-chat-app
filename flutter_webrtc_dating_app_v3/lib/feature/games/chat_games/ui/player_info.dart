// lib/feature/games/chat_games/ui/player_info.dart
//
// Avatars for the versus bar: the current user's profile (loaded once) and
// the best picture URL of a UserModel.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../../../../models/user_model.dart';

/// Photo, then generated avatar, then a legacy http avatar; same order as the
/// chat header.
String? avatarUrlOf(UserModel? u) {
  if (u == null) return null;
  if (u.profileImage.isNotEmpty) return u.profileImage;
  final generated = u.avatarProperties?['avatarImageUrl'];
  if (generated is String && generated.isNotEmpty) return generated;
  final legacy = u.avatarString;
  return legacy != null && legacy.startsWith('http') ? legacy : null;
}

/// Loads users/{me} once; [me] is null until it arrives (or if it fails).
mixin MyProfile<T extends StatefulWidget> on State<T> {
  UserModel? me;

  String get myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final uid = myUid;
    if (uid.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = snap.data();
      if (data == null || !mounted) return;
      setState(() => me = UserModel.fromMap(data, uid: uid));
      onProfileLoaded(me!);
    } catch (_) {
      // Avatars are optional.
    }
  }

  /// Hook for screens that derive more from the profile.
  void onProfileLoaded(UserModel profile) {}
}
