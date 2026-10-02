// // lib/feature/games/ludo/services/ludo_game_service.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';
//
// class LudoGameService {
//   final FirebaseFirestore _fs = FirebaseFirestore.instance;
//
//   CollectionReference<Map<String, dynamic>> get _matches =>
//       _fs.collection('ludo_matches');
//   CollectionReference<Map<String, dynamic>> get _queue =>
//       _fs.collection('ludo_queue');
//
//   // ============================================================
//   // QUEUE OPERATIONS
//   // ============================================================
//
//   Future<DocumentReference<Map<String, dynamic>>> enqueue(
//       String uid,
//       String displayName,
//       String? avatar,
//       ) async {
//     final doc = _queue.doc();
//     await doc.set({
//       'uid': uid,
//       'displayName': displayName,
//       'avatar': avatar ?? '',
//       'createdAt': FieldValue.serverTimestamp(),
//     });
//     return doc;
//   }
//
//   Future<void> dequeue(String docId) async {
//     try {
//       await _queue.doc(docId).delete();
//     } catch (_) {}
//   }
//
//   Future<List<DocumentSnapshot<Map<String, dynamic>>>> findQueueOpponents(
//       String uid,
//       int count,
//       ) async {
//     final qSnap = await _queue
//         .orderBy('createdAt')
//         .limit(count + 5)
//         .get();
//
//     final opponents = <DocumentSnapshot<Map<String, dynamic>>>[];
//
//     for (final doc in qSnap.docs) {
//       final docUid = doc.data()['uid']?.toString() ?? '';
//       if (docUid.isNotEmpty && docUid != uid) {
//         opponents.add(doc);
//         if (opponents.length >= count) break;
//       }
//     }
//
//     return opponents;
//   }
//
//   // ============================================================
//   // MATCH CREATION
//   // ============================================================
//
//   Future<DocumentReference<Map<String, dynamic>>> createMatchFromQueue2Players({
//     required DocumentReference<Map<String, dynamic>> opponentRef,
//     required String opponentUid,
//     required String opponentName,
//     required String opponentAvatar,
//     required String hostUid,
//     required String hostName,
//     required String hostAvatar,
//   }) async {
//     final matchRef = _matches.doc();
//
//     await _fs.runTransaction((tx) async {
//       final oppSnap = await tx.get(opponentRef);
//       if (!oppSnap.exists) throw Exception('Opponent left queue');
//
//       tx.set(matchRef, {
//         'players': {
//           hostUid: {
//             'displayName': hostName,
//             'avatar': hostAvatar,
//             'color': 'green',
//             'status': 'active',
//             'leftAt': null,
//             'joinedAt': FieldValue.serverTimestamp(),
//           },
//           opponentUid: {
//             'displayName': opponentName,
//             'avatar': opponentAvatar,
//             'color': 'yellow',
//             'status': 'active',
//             'leftAt': null,
//             'joinedAt': FieldValue.serverTimestamp(),
//           },
//         },
//         'activeColors': ['green', 'yellow'],
//         'activePlayers': 2,
//         'state': 'playing',
//         'host': hostUid,
//         'maxPlayers': 2,
//         'turnColor': 'green',
//         'turnStartedAt': FieldValue.serverTimestamp(),
//         'createdAt': FieldValue.serverTimestamp(),
//         'updatedAt': FieldValue.serverTimestamp(),
//         'pawnSteps': {
//           'green': [-1, -1, -1, -1],
//           'yellow': [-1, -1, -1, -1],
//         },
//         'dice': 1,
//         'winners': [],
//         'isPublic': false,
//         'finishReason': null,
//         'forfeitDeadline': null,
//       });
//     });
//
//     return matchRef;
//   }
//
//   // ============================================================
//   // PLAYER LEAVE HANDLING
//   // ============================================================
//
//   /// Call when player leaves the game
//   Future<void> playerLeft({
//     required String matchId,
//     required String odId,
//   }) async {
//     try {
//       final matchRef = _matches.doc(matchId);
//
//       await _fs.runTransaction((tx) async {
//         final snap = await tx.get(matchRef);
//         if (!snap.exists) return;
//
//         final data = snap.data()!;
//         final state = data['state']?.toString() ?? '';
//
//         // Don't process if already finished
//         if (state == 'finished' || state == 'abandoned') return;
//
//         final players = Map<String, dynamic>.from(data['players'] ?? {});
//         final activeColors = List<String>.from(data['activeColors'] ?? []);
//         final maxPlayers = data['maxPlayers'] ?? 2;
//
//         // Check if player exists
//         if (!players.containsKey(odId)) return;
//
//         final leavingPlayer = Map<String, dynamic>.from(players[odId]);
//         final leavingColor = leavingPlayer['color']?.toString() ?? '';
//
//         // Mark player as left
//         leavingPlayer['status'] = 'left';
//         leavingPlayer['leftAt'] = FieldValue.serverTimestamp();
//         players[odId] = leavingPlayer;
//
//         // Remove from active colors
//         activeColors.remove(leavingColor);
//
//         // Remove pawns from board
//         final pawnSteps = Map<String, dynamic>.from(data['pawnSteps'] ?? {});
//         pawnSteps.remove(leavingColor);
//
//         // Count active players
//         int activePlayers = 0;
//         players.forEach((uid, info) {
//           if (info is Map && info['status'] == 'active') {
//             activePlayers++;
//           }
//         });
//
//         // Determine game outcome
//         Map<String, dynamic> updates = {
//           'players': players,
//           'activeColors': activeColors,
//           'activePlayers': activePlayers,
//           'pawnSteps': pawnSteps,
//           'updatedAt': FieldValue.serverTimestamp(),
//         };
//
//         if (activePlayers <= 1) {
//           // Only 1 or 0 players left
//           if (activePlayers == 1) {
//             // Find the remaining player - they win!
//             String? winnerColor;
//             players.forEach((uid, info) {
//               if (info is Map && info['status'] == 'active') {
//                 winnerColor = info['color']?.toString();
//               }
//             });
//
//             if (winnerColor != null) {
//               updates['winners'] = [winnerColor];
//             }
//           }
//
//           updates['state'] = 'finished';
//           updates['finishReason'] = 'forfeit';
//           updates['forfeitDeadline'] = null;
//         } else if (maxPlayers == 2) {
//           // 2 player game - set forfeit deadline (5 min)
//           updates['forfeitDeadline'] = Timestamp.fromDate(
//             DateTime.now().add(const Duration(minutes: 5)),
//           );
//         } else {
//           // 4 player game with 2+ players remaining - continue
//           // Just skip the left player's turns
//           final currentTurn = data['turnColor']?.toString() ?? '';
//           if (currentTurn == leavingColor) {
//             // If it was leaving player's turn, move to next
//             updates['turnColor'] = _getNextActiveColor(currentTurn, activeColors);
//             updates['turnStartedAt'] = FieldValue.serverTimestamp();
//           }
//         }
//
//         tx.update(matchRef, updates);
//       });
//
//       debugPrint('✅ Player left handled: $odId');
//     } catch (e) {
//       debugPrint('❌ playerLeft error: $e');
//     }
//   }
//
//   /// Player reconnects within forfeit deadline
//   Future<bool> playerReconnect({
//     required String matchId,
//     required String odId,
//   }) async {
//     try {
//       final matchRef = _matches.doc(matchId);
//
//       return await _fs.runTransaction((tx) async {
//         final snap = await tx.get(matchRef);
//         if (!snap.exists) return false;
//
//         final data = snap.data()!;
//         final state = data['state']?.toString() ?? '';
//
//         if (state == 'finished' || state == 'abandoned') return false;
//
//         final players = Map<String, dynamic>.from(data['players'] ?? {});
//
//         if (!players.containsKey(odId)) return false;
//
//         final player = Map<String, dynamic>.from(players[odId]);
//
//         // Check if within forfeit deadline
//         final forfeitDeadline = data['forfeitDeadline'] as Timestamp?;
//         if (forfeitDeadline != null) {
//           if (DateTime.now().isAfter(forfeitDeadline.toDate())) {
//             // Too late - game already forfeited
//             return false;
//           }
//         }
//
//         // Reconnect player
//         final playerColor = player['color']?.toString() ?? '';
//         player['status'] = 'active';
//         player['leftAt'] = null;
//         players[odId] = player;
//
//         // Add back to active colors
//         final activeColors = List<String>.from(data['activeColors'] ?? []);
//         if (!activeColors.contains(playerColor)) {
//           activeColors.add(playerColor);
//         }
//
//         // Restore pawns (all at home)
//         final pawnSteps = Map<String, dynamic>.from(data['pawnSteps'] ?? {});
//         pawnSteps[playerColor] = [-1, -1, -1, -1];
//
//         tx.update(matchRef, {
//           'players': players,
//           'activeColors': activeColors,
//           'activePlayers': activeColors.length,
//           'pawnSteps': pawnSteps,
//           'forfeitDeadline': null,
//           'updatedAt': FieldValue.serverTimestamp(),
//         });
//
//         return true;
//       });
//     } catch (e) {
//       debugPrint('❌ playerReconnect error: $e');
//       return false;
//     }
//   }
//
//   /// Check and handle forfeit deadline
//   Future<void> checkForfeitDeadline(String matchId) async {
//     try {
//       final snap = await _matches.doc(matchId).get();
//       if (!snap.exists) return;
//
//       final data = snap.data()!;
//       final forfeitDeadline = data['forfeitDeadline'] as Timestamp?;
//
//       if (forfeitDeadline == null) return;
//
//       if (DateTime.now().isAfter(forfeitDeadline.toDate())) {
//         // Deadline passed - forfeit the game
//         final activeColors = List<String>.from(data['activeColors'] ?? []);
//
//         if (activeColors.isNotEmpty) {
//           await _matches.doc(matchId).update({
//             'state': 'finished',
//             'finishReason': 'forfeit',
//             'winners': [activeColors.first], // Remaining player wins
//             'forfeitDeadline': null,
//             'updatedAt': FieldValue.serverTimestamp(),
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint('❌ checkForfeitDeadline error: $e');
//     }
//   }
//
//   // ============================================================
//   // CLEANUP OLD MATCHES
//   // ============================================================
//
//   /// Clean matches older than 12 hours
//   Future<int> cleanupOldMatches() async {
//     try {
//       final cutoff = DateTime.now().subtract(const Duration(hours: 12));
//
//       final oldMatches = await _matches
//           .where('state', whereIn: ['finished', 'abandoned'])
//           .where('updatedAt', isLessThan: Timestamp.fromDate(cutoff))
//           .limit(50)
//           .get();
//
//       int deleted = 0;
//       for (final doc in oldMatches.docs) {
//         await doc.reference.delete();
//         deleted++;
//       }
//
//       debugPrint('✅ Cleaned $deleted old matches');
//       return deleted;
//     } catch (e) {
//       debugPrint('❌ cleanupOldMatches error: $e');
//       return 0;
//     }
//   }
//
//   /// Delete a specific match
//   Future<void> deleteMatch(String matchId) async {
//     try {
//       await _matches.doc(matchId).delete();
//       debugPrint('✅ Match deleted: $matchId');
//     } catch (e) {
//       debugPrint('❌ deleteMatch error: $e');
//     }
//   }
//
//   // ============================================================
//   // WATCH STREAMS
//   // ============================================================
//
//   Stream<DocumentSnapshot<Map<String, dynamic>>> watchMatchDoc(String matchId) {
//     return _matches.doc(matchId).snapshots();
//   }
//
//   // ============================================================
//   // HELPERS
//   // ============================================================
//
//   String _getNextActiveColor(String current, List<String> activeColors) {
//     if (activeColors.isEmpty) return current;
//
//     final order = ['green', 'yellow', 'blue', 'red'];
//     int currentIdx = order.indexOf(current);
//
//     for (int i = 1; i <= 4; i++) {
//       final nextColor = order[(currentIdx + i) % 4];
//       if (activeColors.contains(nextColor)) {
//         return nextColor;
//       }
//     }
//
//     return activeColors.first;
//   }
// }


// lib/feature/games/ludo/services/ludo_game_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class LudoGameService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _matches =>
      _fs.collection('ludo_matches');
  CollectionReference<Map<String, dynamic>> get _queue =>
      _fs.collection('ludo_queue');

  // ============================================================
  // QUEUE OPERATIONS
  // ============================================================

  Future<DocumentReference<Map<String, dynamic>>> enqueue(
      String uid,
      String displayName,
      String? avatar,
      {int playerCount = 2}
      ) async {
    final doc = _queue.doc();
    await doc.set({
      'uid': uid,
      'displayName': displayName,
      'avatar': avatar ?? '',
      'playerCount': playerCount,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc;
  }

  Future<void> dequeue(String docId) async {
    try {
      await _queue.doc(docId).delete();
    } catch (_) {}
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> findQueueOpponents(
      String uid,
      int count,
      {int playerCount = 2}
      ) async {
    final qSnap = await _queue
        .where('playerCount', isEqualTo: playerCount)
        .orderBy('createdAt')
        .limit(count + 5)
        .get();

    final opponents = <DocumentSnapshot<Map<String, dynamic>>>[];

    for (final doc in qSnap.docs) {
      final docUid = doc.data()['uid']?.toString() ?? '';
      if (docUid.isNotEmpty && docUid != uid) {
        opponents.add(doc);
        if (opponents.length >= count) break;
      }
    }

    return opponents;
  }

  // ============================================================
  // MATCH CREATION (2P and 4P)
  // ============================================================

  Future<DocumentReference<Map<String, dynamic>>> createMatchFromQueue({
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
    final colors = ['green', 'yellow', 'blue', 'red'];

    await _fs.runTransaction((tx) async {
      // Verify opponents exist
      for (final ref in opponentRefs) {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Opponent left queue');
      }

      // Build players map
      final playersMap = <String, dynamic>{
        hostUid: {
          'displayName': hostName,
          'avatar': hostAvatar,
          'color': colors[0], // green
          'status': 'active',
          'leftAt': null,
          'joinedAt': FieldValue.serverTimestamp(),
        },
      };

      final activeColors = <String>[colors[0]];
      final pawnSteps = <String, List<int>>{
        colors[0]: [-1, -1, -1, -1],
      };

      for (int i = 0; i < opponentUids.length && i < 3; i++) {
        final color = colors[i + 1];
        playersMap[opponentUids[i]] = {
          'displayName': opponentNames[i],
          'avatar': opponentAvatars[i],
          'color': color,
          'status': 'active',
          'leftAt': null,
          'joinedAt': FieldValue.serverTimestamp(),
        };
        activeColors.add(color);
        pawnSteps[color] = [-1, -1, -1, -1];
      }

      tx.set(matchRef, {
        'players': playersMap,
        'activeColors': activeColors,
        'activePlayers': playersMap.length,
        'maxPlayers': playerCount,
        'state': 'playing',
        'host': hostUid,
        'turnColor': 'green',
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
    await _matches.doc(matchId).collection('chat').add({
      'senderUid': senderUid,
      'senderName': senderName,
      'senderColor': senderColor,
      'message': message,
      'type': type ?? 'text',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchChat(String matchId) {
    return _matches
        .doc(matchId)
        .collection('chat')
        .orderBy('timestamp', descending: false)
        .limit(100)
        .snapshots();
  }

  // ============================================================
  // PLAYER LEAVE HANDLING
  // ============================================================

  Future<void> playerLeft({
    required String matchId,
    required String odId,
  }) async {
    try {
      final matchRef = _matches.doc(matchId);

      await _fs.runTransaction((tx) async {
        final snap = await tx.get(matchRef);
        if (!snap.exists) return;

        final data = snap.data()!;
        final state = data['state']?.toString() ?? '';

        if (state == 'finished' || state == 'abandoned') return;

        final players = Map<String, dynamic>.from(data['players'] ?? {});
        final activeColors = List<String>.from(data['activeColors'] ?? []);
        final maxPlayers = data['maxPlayers'] ?? 2;

        if (!players.containsKey(odId)) return;

        final leavingPlayer = Map<String, dynamic>.from(players[odId]);
        final leavingColor = leavingPlayer['color']?.toString() ?? '';

        leavingPlayer['status'] = 'left';
        leavingPlayer['leftAt'] = FieldValue.serverTimestamp();
        players[odId] = leavingPlayer;

        activeColors.remove(leavingColor);

        final pawnSteps = Map<String, dynamic>.from(data['pawnSteps'] ?? {});
        pawnSteps.remove(leavingColor);

        int activePlayers = 0;
        players.forEach((uid, info) {
          if (info is Map && info['status'] == 'active') {
            activePlayers++;
          }
        });

        Map<String, dynamic> updates = {
          'players': players,
          'activeColors': activeColors,
          'activePlayers': activePlayers,
          'pawnSteps': pawnSteps,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (activePlayers <= 1) {
          if (activePlayers == 1) {
            String? winnerColor;
            players.forEach((uid, info) {
              if (info is Map && info['status'] == 'active') {
                winnerColor = info['color']?.toString();
              }
            });

            if (winnerColor != null) {
              updates['winners'] = [winnerColor];
              updates['turnStartedAt'] = FieldValue.serverTimestamp();
            }
          }

          updates['state'] = 'finished';
          updates['finishReason'] = 'forfeit';
          updates['forfeitDeadline'] = null;
        } else if (maxPlayers == 2) {
          updates['forfeitDeadline'] = Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 5)),
          );
        } else {
          final currentTurn = data['turnColor']?.toString() ?? '';
          if (currentTurn == leavingColor) {
            updates['turnColor'] = _getNextActiveColor(currentTurn, activeColors);
            updates['turnStartedAt'] = FieldValue.serverTimestamp();
          }
        }

        tx.update(matchRef, updates);
      });

      debugPrint('✅ Player left handled: $odId');
    } catch (e) {
      debugPrint('❌ playerLeft error: $e');
    }
  }

  String _getNextActiveColor(String current, List<String> activeColors) {
    if (activeColors.isEmpty) return current;

    final order = ['green', 'yellow', 'blue', 'red'];
    int currentIdx = order.indexOf(current);

    for (int i = 1; i <= 4; i++) {
      final nextColor = order[(currentIdx + i) % 4];
      if (activeColors.contains(nextColor)) {
        return nextColor;
      }
    }

    return activeColors.first;
  }

  Future<bool> playerReconnect({
    required String matchId,
    required String odId,
  }) async {
    try {
      final matchRef = _matches.doc(matchId);

      return await _fs.runTransaction((tx) async {
        final snap = await tx.get(matchRef);
        if (!snap.exists) return false;

        final data = snap.data()!;
        final state = data['state']?.toString() ?? '';

        if (state == 'finished' || state == 'abandoned') return false;

        final players = Map<String, dynamic>.from(data['players'] ?? {});

        if (!players.containsKey(odId)) return false;

        final player = Map<String, dynamic>.from(players[odId]);

        // Check if within forfeit deadline
        final forfeitDeadline = data['forfeitDeadline'] as Timestamp?;
        if (forfeitDeadline != null) {
          if (DateTime.now().isAfter(forfeitDeadline.toDate())) {
            return false;
          }
        }

        // Reconnect player
        final playerColor = player['color']?.toString() ?? '';
        player['status'] = 'active';
        player['leftAt'] = null;
        players[odId] = player;

        // Add back to active colors
        final activeColors = List<String>.from(data['activeColors'] ?? []);
        if (!activeColors.contains(playerColor)) {
          activeColors.add(playerColor);
        }

        // Restore pawns (all at home)
        final pawnSteps = Map<String, dynamic>.from(data['pawnSteps'] ?? {});
        pawnSteps[playerColor] = [-1, -1, -1, -1];

        tx.update(matchRef, {
          'players': players,
          'activeColors': activeColors,
          'activePlayers': activeColors.length,
          'pawnSteps': pawnSteps,
          'forfeitDeadline': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('❌ playerReconnect error: $e');
      return false;
    }
  }

  // ============================================================
  // WATCH STREAMS
  // ============================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMatchDoc(String matchId) {
    return _matches.doc(matchId).snapshots();
  }
}