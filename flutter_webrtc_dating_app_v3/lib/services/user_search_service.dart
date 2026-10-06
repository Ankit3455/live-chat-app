import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:availchat/core/utils/auth_validators.dart';
import 'package:availchat/models/public_profile.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/services/safety_service.dart';

/// Username search over discoverable profiles. Same visibility rules as the
/// discovery feed (18+, discoverable, not me, not blocked) but ignores the
/// feed's filters, so any available user can be found by name.
class UserSearchService {
  UserSearchService({required this.myUid});

  static const int limit = 20;

  final String myUid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Prefix match on `username`. Firestore ranges are case-sensitive, so the
  /// typed text, lowercase, Capitalized and Title Case forms are all tried.
  Future<List<UserModel>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final hidden = await SafetyService.instance.watchHiddenUserIds().first;
    final found = <String, UserModel>{};
    final results = await Future.wait(_variants(q).map(_prefix));
    for (final docs in results) {
      for (final doc in docs) {
        final user = _parse(doc);
        final uid = user?.uid;
        if (user == null || uid == null || found.containsKey(uid)) continue;
        if (uid == myUid || hidden.contains(uid)) continue;
        if (!user.discoveryEnabled) continue;
        final age = user.age;
        if (age == null || age < AgePolicy.minAge) continue;
        found[uid] = user;
      }
    }
    final list = found.values.toList()
      ..sort((a, b) =>
          a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    return list.take(limit).toList();
  }

  Set<String> _variants(String q) {
    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    final lower = q.toLowerCase();
    return {
      q,
      lower,
      cap(lower),
      lower.split(' ').map(cap).join(' '),
    };
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _prefix(String p) async {
    // Feed currently reads sanitised `users` docs (legacyUsersRead); fall back
    // to public_profiles if that read is denied.
    for (final col in const ['users', PublicProfile.collection]) {
      try {
        final snap = await _db
            .collection(col)
            .where('username', isGreaterThanOrEqualTo: p)
            .where('username', isLessThan: '$p\uf8ff')
            .limit(limit)
            .get();
        return snap.docs;
      } catch (e) {
        if (kDebugMode) debugPrint('User search on $col failed: $e');
      }
    }
    return const [];
  }

  UserModel? _parse(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    try {
      return UserModel.fromMap(PublicProfile.fromUserData(doc.id, data),
          uid: doc.id);
    } catch (e) {
      if (kDebugMode) debugPrint('Skipping profile ${doc.id}: $e');
      return null;
    }
  }
}
