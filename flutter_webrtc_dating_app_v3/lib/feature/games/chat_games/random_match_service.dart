// lib/feature/games/chat_games/random_match_service.dart
//
// Games tab: play a chat game with whoever else is looking for the same
// game right now. Each searcher keeps one entry in game_queue/{uid}; a
// searcher claims another's live entry in a transaction that also creates
// the game_rooms doc and removes its own entry. The claimed player sees
// roomId appear on its entry. firestore.rules (game_queue, game_rooms) check
// both sides of the claim.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../services/safety_service.dart';
import 'game_space.dart';

/// A random opponent was found. [iMadeIt]: this player claimed the other's
/// entry, made the room and starts the first game.
class RandomMatch {
  final String spaceId;
  final String otherUid;
  final bool iMadeIt;

  const RandomMatch({
    required this.spaceId,
    required this.otherUid,
    required this.iMadeIt,
  });
}

class RandomMatchService {
  RandomMatchService._();
  static final RandomMatchService instance = RandomMatchService._();

  static const Duration searchTime = Duration(seconds: 60);
  static const Duration _entryTtl = Duration(seconds: 90);
  static const Duration _recheckEvery = Duration(seconds: 3);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _me => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _queue =>
      _db.collection('game_queue');

  /// Searches for up to [searchTime]. Null when nobody was found or
  /// [cancelled] turned true.
  Future<RandomMatch?> find({
    required String game,
    required String displayName,
    required String avatar,
    required bool Function() cancelled,
  }) async {
    final me = _me;
    if (me.isEmpty) return null;
    final myRef = _queue.doc(me);
    final deadline = DateTime.now().add(searchTime);

    // Overwrites a stale entry (and an old claim) from a previous search.
    await myRef.set({
      'uid': me,
      'game': game,
      'displayName': displayName,
      'avatar': avatar,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(_entryTtl)),
    });

    final claimed = Completer<RandomMatch>();
    final sub = myRef.snapshots().listen((snap) {
      final d = snap.data();
      final roomId = d?['roomId'];
      final by = d?['claimedBy'];
      if (roomId is String && by is String && !claimed.isCompleted) {
        claimed.complete(
          RandomMatch(
            spaceId: GameSpace.room(roomId),
            otherUid: by,
            iMadeIt: false,
          ),
        );
      }
    }, onError: (Object e) => _log('watchEntry', e));

    try {
      while (!claimed.isCompleted &&
          !cancelled() &&
          DateTime.now().isBefore(deadline)) {
        final mine = await _tryClaim(game, myRef);
        if (mine != null) return mine;
        await Future.any([claimed.future, Future.delayed(_recheckEvery)]);
      }
      if (claimed.isCompleted) return await claimed.future;
      return null;
    } finally {
      await sub.cancel();
      // A claim deletes the claimer's entry; the claimed one tidies its own.
      unawaited(myRef.delete().catchError((Object e) => _log('leave', e)));
    }
  }

  Future<RandomMatch?> _tryClaim(
    String game,
    DocumentReference<Map<String, dynamic>> myRef,
  ) async {
    final me = _me;
    final hidden = SafetyService.instance.hiddenUserIdsNow;
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
    try {
      docs = (await _queue.where('game', isEqualTo: game).limit(25).get()).docs;
    } catch (e) {
      _log('list', e);
      return null;
    }
    final now = DateTime.now();
    final candidates = docs.where((d) {
      final data = d.data();
      final expires = data['expiresAt'];
      return d.id != me &&
          data['roomId'] == null &&
          expires is Timestamp &&
          expires.toDate().isAfter(now.add(const Duration(seconds: 2))) &&
          !hidden.contains(d.id);
    }).toList()
      ..sort((a, b) {
        final ta = a.data()['createdAt'];
        final tb = b.data()['createdAt'];
        if (ta is! Timestamp || tb is! Timestamp) return 0;
        return ta.compareTo(tb);
      });

    for (final cand in candidates) {
      final roomRef = _db.collection('game_rooms').doc();
      try {
        final made = await _db.runTransaction<bool>((tx) async {
          final mine = await tx.get(myRef);
          if (!mine.exists || mine.data()?['roomId'] != null) return false;
          final other = await tx.get(cand.reference);
          final d = other.data();
          final expires = d?['expiresAt'];
          if (d == null ||
              d['roomId'] != null ||
              d['game'] != game ||
              expires is! Timestamp ||
              !expires.toDate().isAfter(DateTime.now())) {
            return false;
          }
          tx.set(roomRef, {
            'participants': [me, cand.id],
            'game': game,
            'createdBy': me,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.update(cand.reference, {'roomId': roomRef.id, 'claimedBy': me});
          tx.delete(myRef);
          return true;
        });
        if (made) {
          return RandomMatch(
            spaceId: GameSpace.room(roomRef.id),
            otherUid: cand.id,
            iMadeIt: true,
          );
        }
      } catch (e) {
        // Someone else claimed them (or me) first; try the next one.
        _log('claim', e);
      }
    }
    return null;
  }

  void _log(String where, Object e) {
    if (kDebugMode) debugPrint('RandomMatchService.$where failed: $e');
  }
}
