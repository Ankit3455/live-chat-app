// lib/feature/games/chat_games/match_invite_service.dart
//
// Ludo and Carrom invited from a chat. The invite lives at
// conversations/{convId}/games/{ludo|carrom} (same Accept / Decline card as
// the chat games); accepting creates a private ludo_matches / carrom_matches
// doc for exactly the two players in the same write and stores its id there.
// firestore.rules (matchInvite*) checks every write.

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../ludo/services/ludo_game_service.dart';
import 'chat_game_invites.dart';
import 'chat_game_logic.dart';
import 'chat_game_service.dart';
import 'game_space.dart';

class MatchInviteService {
  MatchInviteService._();
  static final MatchInviteService instance = MatchInviteService._();

  static const String ludo = 'ludo';
  static const String carrom = 'carrom';

  static bool handles(String name) => name == ludo || name == carrom;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ChatGameService _games = ChatGameService.instance;

  String get _me => FirebaseAuth.instance.currentUser?.uid ?? '';

  static ChatGameMessage invite(String name) => ChatGameMessage(
        name == ludo
            ? "🎲 Let's play Ludo! First to bring all 4 pawns home wins."
            : "🎯 Let's play Carrom! Pocket your coins before I do.",
        {'game': name, 'stage': ChatGameLogic.inviteStage},
      );

  CollectionReference<Map<String, dynamic>> _matches(String name) =>
      _db.collection(name == ludo ? 'ludo_matches' : 'carrom_matches');

  /// Creates the invite and posts its card. False if one is already open
  /// (callers close an invite whose match has ended first).
  Future<bool> send({
    required String name,
    required String convId,
    required String otherUserId,
  }) async {
    final me = _me;
    final random = Random.secure();
    final gameId = List.generate(
      20,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    final card = ChatGameLogic.withGameId(invite(name), gameId);
    final (:participants, :invited) = await _games.prepareConversation(
      convId: convId,
      otherUserId: otherUserId,
      invite: card,
    );
    final ref = GameSpace.game(convId, name);
    final created = await _db.runTransaction<bool>((tx) async {
      final current = GameRoomState.fromMap((await tx.get(ref)).data());
      if (current != null && current.isOpen) return false;
      final now = FieldValue.serverTimestamp();
      tx.set(ref, {
        'gameId': gameId,
        'players': participants,
        'createdBy': me,
        'status': 'playing',
        'joined': [me],
        'matchId': null,
        'createdAt': now,
        'updatedAt': now,
      });
      return true;
    });
    if (created && !invited) {
      await _games.sendGameMessage(convId, otherUserId, card);
    }
    return created;
  }

  /// Accepts the invite: creates the private match (I host it) and stores
  /// its id on the invite in one batch. Returns the match id.
  Future<String> accept({
    required String name,
    required String convId,
    required String inviterUid,
    required String inviterName,
    required String inviterAvatar,
  }) async {
    final me = _me;
    final inviteRef = GameSpace.game(convId, name);
    final state = GameRoomState.fromMap((await inviteRef.get()).data());
    if (state == null || !state.isPending || state.joined.contains(me)) {
      throw const ChatGameException('This invite has ended.');
    }
    final mine = (await _db.collection('users').doc(me).get()).data() ?? {};
    final myName = (mine['username'] as String?)?.trim() ?? '';
    final myAvatar = _avatarOf(mine);

    final matchRef = _matches(name).doc();
    final Map<String, dynamic> data;
    if (name == ludo) {
      data = LudoGameService().privateMatchData(
        hostUid: me,
        hostName: myName.isEmpty ? 'Player' : myName,
        hostAvatar: myAvatar,
        guestUid: inviterUid,
        guestName: inviterName,
        guestAvatar: inviterAvatar,
      );
    } else {
      data = {
        'players': {
          me: {'displayName': myName, 'avatar': myAvatar},
          inviterUid: {'displayName': inviterName, 'avatar': inviterAvatar},
        },
        'playerUids': [me, inviterUid],
        'status': 'ready',
        'private': true,
        'host': me,
        'turn': me,
        'joined': <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
        'boardState': null,
        'lastMove': null,
        'scores': {me: 0, inviterUid: 0},
        'moveSeq': 0,
        'turnSeq': 0,
      };
    }
    final batch = _db.batch()
      ..set(matchRef, data)
      ..update(inviteRef, {
        'joined': [...state.joined, me],
        'matchId': matchRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    await batch.commit();
    return matchRef.id;
  }

  /// Declines (receiver), cancels (sender) or retires a finished invite.
  Future<void> close(String name, String convId) async {
    await GameSpace.game(convId, name).update({
      'status': 'over',
      'resignedBy': _me,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// The private match is finished, cancelled or gone.
  Future<bool> matchEnded(String name, String matchId) async {
    try {
      final d = (await _matches(name).doc(matchId).get()).data();
      if (d == null) return true;
      return name == ludo
          ? ['finished', 'abandoned'].contains(d['state'])
          : ['finished', 'cancelled'].contains(d['status']);
    } catch (_) {
      return false;
    }
  }

  static String _avatarOf(Map<String, dynamic> user) {
    final photo = user['profileImage'];
    if (photo is String && photo.isNotEmpty) return photo;
    final props = user['avatarProperties'];
    final generated = props is Map ? props['avatarImageUrl'] : null;
    return generated is String ? generated : '';
  }
}
