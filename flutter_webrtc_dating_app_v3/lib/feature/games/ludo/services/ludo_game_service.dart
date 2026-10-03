// lib/feature/games/ludo/services/ludo_game_service.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../ludo_rules.dart';

class LudoRollResult {
  final int dice;
  final List<int> legalPawns;
  final bool turnPassed;
  const LudoRollResult(this.dice, this.legalPawns, this.turnPassed);
}

class LudoMoveResult {
  final int toStep;
  final bool captured;
  final bool gameFinished;
  const LudoMoveResult(this.toStep, this.captured, this.gameFinished);
}

class LudoGameService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// How long a backgrounded / disconnected player may stay away.
  static const Duration awayGrace = Duration(seconds: 60);
  static const Duration queueTtl = Duration(minutes: 2);
  static const Duration queueHeartbeatMaxAge = Duration(seconds: 45);
  static const int chatMaxLength = 300;

  CollectionReference<Map<String, dynamic>> get _matches =>
      _fs.collection('ludo_matches');
  CollectionReference<Map<String, dynamic>> get _queue =>
      _fs.collection('ludo_queue');

  // ============================================================
  // QUEUE OPERATIONS
  // ============================================================

  /// One queue entry per user (doc id = uid).
  DocumentReference<Map<String, dynamic>> queueRef(String uid) =>
      _queue.doc(uid);

  Future<DocumentReference<Map<String, dynamic>>> enqueue(
      String uid,
      String displayName,
      String? avatar,
      {int playerCount = 2}
      ) async {
    final doc = queueRef(uid);
    await doc.set({
      'uid': uid,
      'displayName': displayName,
      'avatar': avatar ?? '',
      'playerCount': playerCount,
      'createdAt': FieldValue.serverTimestamp(),
      'heartbeatAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(queueTtl)),
    });
    return doc;
  }

  /// Keeps the queue entry fresh. Returns false if it no longer exists
  /// (claimed by a match or expired).
  Future<bool> heartbeat(String uid) async {
    try {
      await queueRef(uid).update({
        'heartbeatAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(queueTtl)),
      });
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') return false;
      debugPrint('❌ Queue heartbeat error: $e');
      return true;
    }
  }

  Future<bool> isQueued(String uid) async {
    try {
      final snap = await queueRef(uid).get();
      return snap.exists;
    } catch (_) {
      return true;
    }
  }

  Future<void> dequeue(String docId) async {
    try {
      await _queue.doc(docId).delete();
    } catch (_) {}
  }

  static bool _isFreshQueueEntry(Map<String, dynamic> data) {
    final now = DateTime.now();
    final expiresAt = data['expiresAt'];
    final heartbeatAt = data['heartbeatAt'];
    if (expiresAt is! Timestamp || expiresAt.toDate().isBefore(now)) {
      return false;
    }
    if (heartbeatAt is! Timestamp) return false;
    return now.difference(heartbeatAt.toDate()) <= queueHeartbeatMaxAge;
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> findQueueOpponents(
      String uid,
      int count,
      {int playerCount = 2}
      ) async {
    final qSnap = await _queue
        .where('playerCount', isEqualTo: playerCount)
        .orderBy('createdAt')
        .limit(count + 20)
        .get();

    final opponents = <DocumentSnapshot<Map<String, dynamic>>>[];
    final seen = <String>{uid};

    for (final doc in qSnap.docs) {
      final data = doc.data();
      final docUid = data['uid']?.toString() ?? '';
      if (docUid.isEmpty || seen.contains(docUid)) continue;
      if (!_isFreshQueueEntry(data)) continue;
      seen.add(docUid);
      opponents.add(doc);
      if (opponents.length >= count) break;
    }

    return opponents;
  }

  // ============================================================
  // MATCH CREATION (2P and 4P)
  // ============================================================

  /// Atomically claims the host's and every opponent's queue entry and
  /// creates the match. Throws if any entry was already claimed.
  Future<DocumentReference<Map<String, dynamic>>> createMatchFromQueue({
    required DocumentReference<Map<String, dynamic>> hostQueueRef,
    required List<DocumentReference<Map<String, dynamic>>> opponentRefs,
    required List<String> opponentUids,
    required List<String> opponentNames,
    required List<String> opponentAvatars,
    required String hostUid,
    required String hostName,
    required String hostAvatar,
    required int playerCount,
  }) async {
    final matchRef = _matches.doc();
    final colors = LudoRules.colorsFor(playerCount);

    await _fs.runTransaction((tx) async {
      final refs = [hostQueueRef, ...opponentRefs];
      final expectedUids = [hostUid, ...opponentUids];
      for (int i = 0; i < refs.length; i++) {
        final snap = await tx.get(refs[i]);
        final data = snap.data();
        if (data == null ||
            data['uid'] != expectedUids[i] ||
            data['playerCount'] != playerCount ||
            !_isFreshQueueEntry(data)) {
          throw StateError('Queue entry already claimed');
        }
      }

      final uids = expectedUids.take(colors.length).toList();
      final names = [hostName, ...opponentNames];
      final avatars = [hostAvatar, ...opponentAvatars];

      final playersMap = <String, dynamic>{};
      final pawnSteps = <String, List<int>>{};
      final activeColors = <String>[];
      for (int i = 0; i < uids.length; i++) {
        final color = colors[i];
        playersMap[uids[i]] = {
          'displayName': names[i],
          'avatar': avatars[i],
          'color': color,
          'status': 'active',
          'leftAt': null,
          'awaySince': null,
          'joinedAt': FieldValue.serverTimestamp(),
        };
        activeColors.add(color);
        pawnSteps[color] = List<int>.filled(LudoRules.pawnCount, -1);
      }

      for (final ref in refs) {
        tx.delete(ref);
      }

      tx.set(matchRef, {
        'players': playersMap,
        'playerUids': uids,
        'activeColors': activeColors,
        'activePlayers': activeColors.length,
        'maxPlayers': playerCount,
        'state': 'playing',
        'host': hostUid,
        'turnColor': activeColors[Random().nextInt(activeColors.length)],
        'turnSeq': 0,
        'rolled': false,
        'turnStartedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'pawnSteps': pawnSteps,
        'dice': 1,
        'winners': [],
        'isPublic': false,
        'finishReason': null,
        'forfeitDeadline': null,
      });
    });

    return matchRef;
  }

  // ============================================================
  // TURN WRITES (all transactional, guarded by turnColor + turnSeq)
  // ============================================================

  static int turnSeqOf(Map<String, dynamic> data) =>
      (data['turnSeq'] as num?)?.toInt() ?? 0;

  static Map<String, dynamic> _players(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(data['players'] ?? {});

  /// Colours still in the turn order (falls back to non-left players).
  static List<String> activeColorsOf(Map<String, dynamic> data) {
    final raw = data['activeColors'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    final colors = <String>[];
    _players(data).forEach((_, info) {
      if (info is Map && info['status'] != 'left') {
        final c = info['color']?.toString() ?? '';
        if (c.isNotEmpty) colors.add(c);
      }
    });
    return colors;
  }

  static List<String> _winners(Map<String, dynamic> data) =>
      List<String>.from(data['winners'] ?? const []);

  bool _isTurnOf(Map<String, dynamic> data, String color, int expectedSeq) =>
      data['state'] == 'playing' &&
      data['turnColor'] == color &&
      turnSeqOf(data) == expectedSeq;

  Map<String, dynamic> _newTurn(String color, int seq) => {
        'turnColor': color,
        'turnSeq': seq + 1,
        'turnStartedAt': FieldValue.serverTimestamp(),
        'rolled': false,
      };

  Map<String, dynamic> _passTurn(
    Map<String, dynamic> data, {
    List<String>? activeColors,
    List<String>? winners,
  }) {
    final current = data['turnColor']?.toString() ?? 'green';
    final w = winners ?? _winners(data);
    final eligible =
        (activeColors ?? activeColorsOf(data)).where((c) => !w.contains(c));
    return _newTurn(
      LudoRules.nextColor(current, eligible) ?? current,
      turnSeqOf(data),
    );
  }

  /// Ends the match when at most one eligible player remains after a
  /// departure. Remaining players are appended to winners.
  Map<String, dynamic>? _forfeitIfLastStanding(
    Map<String, dynamic> data,
    List<String> activeColors,
  ) {
    final winners = _winners(data);
    final eligible = activeColors.where((c) => !winners.contains(c)).toList();
    if (eligible.length > 1) return null;
    return {
      'winners': [...winners, ...eligible],
      'state': 'finished',
      'finishReason': 'forfeit',
      'forfeitDeadline': null,
      'rolled': false,
      'turnSeq': turnSeqOf(data) + 1,
    };
  }

  /// Stores the roll. Passes the turn when no pawn can move.
  Future<LudoRollResult?> rollDice({
    required String matchId,
    required String color,
    required int expectedSeq,
    required int dice,
  }) async {
    final ref = _matches.doc(matchId);
    try {
      return await _fs.runTransaction<LudoRollResult?>((tx) async {
        final data = (await tx.get(ref)).data();
        if (data == null ||
            !_isTurnOf(data, color, expectedSeq) ||
            data['rolled'] == true) {
          return null;
        }
        final pawnSteps = Map<String, dynamic>.from(data['pawnSteps'] ?? {});
        final steps = LudoRules.parseSteps(pawnSteps[color]);
        final legal =
            LudoRules.legalPawns(steps, dice, LudoRules.lastStep(color));

        final updates = <String, dynamic>{
          'dice': dice,
          'updatedAt': FieldValue.serverTimestamp(),
          if (legal.isEmpty) ..._passTurn(data) else 'rolled': true,
        };
        tx.update(ref, updates);
        return LudoRollResult(dice, legal, legal.isEmpty);
      });
    } catch (e) {
      debugPrint('❌ rollDice error: $e');
      return null;
    }
  }

  /// Applies a pawn move computed from server state. Writes only the
  /// moving colour's pawns plus any captured colour's pawns.
  Future<LudoMoveResult?> commitMove({
    required String matchId,
    required String uid,
    required String color,
    required int expectedSeq,
    required int pawnIndex,
  }) async {
    final ref = _matches.doc(matchId);
    try {
      return await _fs.runTransaction<LudoMoveResult?>((tx) async {
        final data = (await tx.get(ref)).data();
        if (data == null ||
            !_isTurnOf(data, color, expectedSeq) ||
            data['rolled'] != true) {
          return null;
        }
        final dice = (data['dice'] as num?)?.toInt() ?? 0;
        final rawSteps = Map<String, dynamic>.from(data['pawnSteps'] ?? {});
        final allSteps = <String, List<int>>{
          for (final e in rawSteps.entries) e.key: LudoRules.parseSteps(e.value),
        };
        final mine = allSteps[color] ?? LudoRules.parseSteps(null);
        if (pawnIndex < 0 || pawnIndex >= mine.length) return null;

        final last = LudoRules.lastStep(color);
        final to = LudoRules.targetStep(mine[pawnIndex], dice, last);
        if (to == null) return null;
        mine[pawnIndex] = to;
        allSteps[color] = mine;

        final onBoard = <String>[];
        _players(data).forEach((_, info) {
          if (info is Map && info['status'] != 'left') {
            onBoard.add(info['color']?.toString() ?? '');
          }
        });
        final caps = LudoRules.captures(
          color: color,
          step: to,
          pawnSteps: allSteps,
          victimColors: onBoard,
        );

        final updates = <String, dynamic>{
          'pawnSteps.$color': mine,
          'lastMove': {
            'type': color,
            'pawnIndex': pawnIndex,
            'toStep': to,
            'killed': caps.isNotEmpty,
            'byUid': uid,
            'ts': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        };
        caps.forEach((victim, indices) {
          final steps = allSteps[victim]!;
          for (final i in indices) {
            steps[i] = -1;
          }
          updates['pawnSteps.$victim'] = steps;
        });

        final winners = _winners(data);
        if (LudoRules.hasFinished(mine, last) && !winners.contains(color)) {
          winners.add(color);
          updates['winners'] = winners;
        }

        final active = activeColorsOf(data);
        final eligible = active.where((c) => !winners.contains(c)).toList();
        final finished = winners.isNotEmpty && eligible.length <= 1;

        if (finished) {
          updates['state'] = 'finished';
          updates['finishReason'] = 'completed';
          updates['rolled'] = false;
          updates['turnSeq'] = expectedSeq + 1;
        } else if ((dice == 6 || caps.isNotEmpty) &&
            !winners.contains(color)) {
          updates.addAll(_newTurn(color, expectedSeq));
        } else {
          updates.addAll(_passTurn(data, activeColors: active, winners: winners));
        }

        tx.update(ref, updates);
        return LudoMoveResult(to, caps.isNotEmpty, finished);
      });
    } catch (e) {
      debugPrint('❌ commitMove error: $e');
      return null;
    }
  }

  /// Skips the current turn after its deadline. Any participant may call
  /// this; the turnSeq guard makes concurrent calls harmless.
  Future<bool> advanceTurn({
    required String matchId,
    required String expectedColor,
    required int expectedSeq,
  }) async {
    final ref = _matches.doc(matchId);
    try {
      return await _fs.runTransaction<bool>((tx) async {
        final data = (await tx.get(ref)).data();
        if (data == null || !_isTurnOf(data, expectedColor, expectedSeq)) {
          return false;
        }
        tx.update(ref, {
          ..._passTurn(data),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (e) {
      debugPrint('❌ advanceTurn error: $e');
      return false;
    }
  }

  // ============================================================
  // CHAT OPERATIONS
  // ============================================================

  Future<void> sendChatMessage({
    required String matchId,
    required String senderUid,
    required String senderName,
    required String senderColor,
    required String message,
    String? type, // 'text' or 'reaction'
  }) async {
    final text = message.trim();
    if (text.isEmpty) return;
    await _matches.doc(matchId).collection('chat').add({
      'senderUid': senderUid,
      'senderName': senderName,
      'senderColor': senderColor,
      'message': text.length > chatMaxLength
          ? text.substring(0, chatMaxLength)
          : text,
      'type': type ?? 'text',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Latest 100 messages, newest first.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchChat(String matchId) {
    return _matches
        .doc(matchId)
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  // ============================================================
  // PRESENCE: away / reconnect / leave
  // ============================================================

  /// App backgrounded: start the away grace period. Pawns are untouched.
  Future<void> playerAway({
    required String matchId,
    required String odId,
  }) async {
    final ref = _matches.doc(matchId);
    try {
      await _fs.runTransaction((tx) async {
        final data = (await tx.get(ref)).data();
        if (data == null || data['state'] != 'playing') return;
        final info = _players(data)[odId];
        if (info is! Map || info['status'] != 'active') return;
        tx.update(ref, {
          'players.$odId.status': 'away',
          'players.$odId.awaySince': FieldValue.serverTimestamp(),
          'forfeitDeadline':
              Timestamp.fromDate(DateTime.now().add(awayGrace)),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('❌ playerAway error: $e');
    }
  }

  /// Back from away (or skipped): status only, never pawnSteps.
  /// Returns true if the player is active in a running match.
  Future<bool> playerReconnect({
    required String matchId,
    required String odId,
  }) async {
    final ref = _matches.doc(matchId);
    try {
      return await _fs.runTransaction<bool>((tx) async {
        final data = (await tx.get(ref)).data();
        if (data == null || data['state'] != 'playing') return false;
        final players = _players(data);
        final info = players[odId];
        if (info is! Map) return false;
        final status = info['status']?.toString() ?? 'active';
        if (status == 'active') return true;
        if (status != 'away') return false;

        final color = info['color']?.toString() ?? '';
        final active = activeColorsOf(data);
        if (color.isNotEmpty && !active.contains(color)) active.add(color);
        final ordered =
            LudoRules.colorOrder.where((c) => active.contains(c)).toList();

        final othersAway = players.entries.any((e) =>
            e.key != odId && e.value is Map && e.value['status'] == 'away');

        tx.update(ref, {
          'players.$odId.status': 'active',
          'players.$odId.awaySince': null,
          'players.$odId.skipped': false,
          'activeColors': ordered,
          'activePlayers': ordered.length,
          if (!othersAway) 'forfeitDeadline': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (e) {
      debugPrint('❌ playerReconnect error: $e');
      return false;
    }
  }

  /// Away grace expired (observed by another participant). [awaySince] must
  /// match what the caller observed so a reconnect in between wins.
  /// 2 players: forfeit. 4 players: the player is skipped until they return.
  Future<bool> expireAway({
    required String matchId,
    required String odId,
    required Timestamp? awaySince,
  }) async {
    final ref = _matches.doc(matchId);
    try {
      return await _fs.runTransaction<bool>((tx) async {
        final data = (await tx.get(ref)).data();
        if (data == null || data['state'] != 'playing') return false;
        final info = _players(data)[odId];
        if (info is! Map ||
            info['status'] != 'away' ||
            info['skipped'] == true ||
            info['awaySince'] != awaySince) {
          return false;
        }
        final color = info['color']?.toString() ?? '';
        final active = activeColorsOf(data)..remove(color);

        final updates = <String, dynamic>{
          'players.$odId.skipped': true,
          'activeColors': active,
          'activePlayers': active.length,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        final forfeit = _forfeitIfLastStanding(data, active);
        if (forfeit != null) {
          updates.addAll(forfeit);
        } else if (data['turnColor'] == color) {
          updates.addAll(_passTurn(data, activeColors: active));
        }
        tx.update(ref, updates);
        return true;
      });
    } catch (e) {
      debugPrint('❌ expireAway error: $e');
      return false;
    }
  }

  /// Explicit Leave: the player is removed from the turn order for good.
  Future<void> playerLeft({
    required String matchId,
    required String odId,
  }) async {
    final ref = _matches.doc(matchId);
    try {
      await _fs.runTransaction((tx) async {
        final data = (await tx.get(ref)).data();
        if (data == null || data['state'] != 'playing') return;
        final info = _players(data)[odId];
        if (info is! Map || info['status'] == 'left') return;

        final color = info['color']?.toString() ?? '';
        final active = activeColorsOf(data)..remove(color);

        final updates = <String, dynamic>{
          'players.$odId.status': 'left',
          'players.$odId.leftAt': FieldValue.serverTimestamp(),
          'activeColors': active,
          'activePlayers': active.length,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        final forfeit = _forfeitIfLastStanding(data, active);
        if (forfeit != null) {
          updates.addAll(forfeit);
        } else if (data['turnColor'] == color) {
          updates.addAll(_passTurn(data, activeColors: active));
        }
        tx.update(ref, updates);
      });
      debugPrint('✅ Player left handled: $odId');
    } catch (e) {
      debugPrint('❌ playerLeft error: $e');
    }
  }

  // ============================================================
  // WATCH STREAMS
  // ============================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMatchDoc(String matchId) {
    return _matches.doc(matchId).snapshots();
  }

  Query<Map<String, dynamic>> _myPlayingMatches(String uid) => _matches
      .where('playerUids', arrayContains: uid)
      .where('state', isEqualTo: 'playing');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyPlayingMatches(
          String uid) =>
      _myPlayingMatches(uid).snapshots();

  /// A running match this user has not left, for the lobby's resume banner.
  Future<String?> findResumableMatch(String uid) async {
    try {
      final snap = await _myPlayingMatches(uid).get();
      final cutoff = DateTime.now().subtract(const Duration(hours: 3));
      DateTime? best;
      String? bestId;
      for (final doc in snap.docs) {
        final data = doc.data();
        final info = _players(data)[uid];
        if (info is! Map || info['status'] == 'left') continue;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null || createdAt.isBefore(cutoff)) continue;
        if (best == null || createdAt.isAfter(best)) {
          best = createdAt;
          bestId = doc.id;
        }
      }
      return bestId;
    } catch (e) {
      debugPrint('❌ findResumableMatch error: $e');
      return null;
    }
  }
}
