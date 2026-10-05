// lib/feature/games/chat_games/chat_game_invites.dart
//
// Invite flow shared by every chat game. Picking a game posts an invite card
// in the chat; the game room opens for both players only once the other
// player accepts (joins). Built on each game's own service and the joined
// list in conversations/{convId}/games/{name}.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../models/user_model.dart';
import 'chat_game.dart';
import 'chat_game_service.dart';
import 'chess/chess_game.dart';
import 'chess/chess_service.dart';
import 'duel/duel_service.dart';
import 'match_invite_service.dart';
import 'ui/player_info.dart';
import 'tennis/tennis_game.dart';
import 'thumb_war/thumb_rules.dart';

/// The parts of a game doc the invite flow needs; the same for every game.
class GameRoomState {
  final String gameId;
  final String createdBy;
  final List<String> players;
  final List<String> joined;

  /// Still being played (or still waiting for the other player).
  final bool isOpen;

  /// Who resigned or closed the invite (chess, duels and match invites).
  final String? closedBy;

  /// Ludo / Carrom invite: the private match created on accept.
  final String? matchId;

  const GameRoomState({
    required this.gameId,
    required this.createdBy,
    required this.players,
    required this.joined,
    required this.isOpen,
    this.closedBy,
    this.matchId,
  });

  bool get bothJoined => players.isNotEmpty && players.every(joined.contains);

  /// Invite sent, the other player hasn't accepted yet.
  bool get isPending => isOpen && !bothJoined;

  /// Round games end at round 5 and stay 'playing'; chess and duels set
  /// 'over'; a cancelled round game is 'cancelled'.
  static GameRoomState? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final round = data['round'];
    return GameRoomState(
      gameId: (data['gameId'] as String?) ?? '',
      createdBy: (data['createdBy'] as String?) ?? '',
      players:
          ((data['players'] as List?) ?? const []).whereType<String>().toList(),
      joined:
          ((data['joined'] as List?) ?? const []).whereType<String>().toList(),
      isOpen: data['status'] == 'playing' &&
          (round is! num || round < ChatGame.roundCount),
      closedBy: data['resignedBy'] as String?,
      matchId: data['matchId'] as String?,
    );
  }
}

class ChatGameInvites {
  ChatGameInvites._();

  static String get _me => FirebaseAuth.instance.currentUser?.uid ?? '';

  static DocumentReference<Map<String, dynamic>> _doc(
    String convId,
    String name,
  ) =>
      FirebaseFirestore.instance
          .collection('conversations')
          .doc(convId)
          .collection('games')
          .doc(name);

  static DuelService? _duel(String name) {
    if (name == TennisRules.gameName) return DuelService(TennisRules.instance);
    if (name == ThumbRules.gameName) return DuelService(ThumbRules.instance);
    return null;
  }

  /// Current state of game [name]; null if there is none (or the chat does
  /// not exist yet).
  static Future<GameRoomState?> current(String convId, String name) async {
    try {
      return GameRoomState.fromMap((await _doc(convId, name).get()).data());
    } catch (e) {
      _log('current', e);
      return null;
    }
  }

  /// Creates game [name] and posts the invite card. False if a game of that
  /// kind is already open.
  static Future<bool> send(
    String name, {
    required String convId,
    required String otherUserId,
    UserModel? otherUser,
  }) {
    if (MatchInviteService.handles(name)) {
      return MatchInviteService.instance.send(
        name: name,
        convId: convId,
        otherUserId: otherUserId,
      );
    }
    if (name == ChessGame.gameName) {
      return ChessService.instance.start(
        convId: convId,
        otherUserId: otherUserId,
      );
    }
    final duel = _duel(name);
    if (duel != null) {
      return duel.start(convId: convId, otherUserId: otherUserId);
    }
    return ChatGameService.instance.start(
      convId: convId,
      otherUserId: otherUserId,
      kind: ChatGameKind.byName(name) ?? ChatGameKind.date,
      otherAnswers: {
        'interests': otherUser?.interests ?? const <String>[],
        'habits': otherUser?.habits,
      },
    );
  }

  /// Accepts the invite: joining starts the game's clock. Ludo / Carrom:
  /// creates the private match with [other] (the inviter).
  static Future<void> accept(
    String name,
    String convId, {
    required String otherUserId,
    UserModel? other,
  }) async {
    if (MatchInviteService.handles(name)) {
      await MatchInviteService.instance.accept(
        name: name,
        convId: convId,
        inviterUid: otherUserId,
        inviterName: other?.username.trim() ?? '',
        inviterAvatar: avatarUrlOf(other) ?? '',
      );
      return;
    }
    if (name == ChessGame.gameName) return ChessService.instance.join(convId);
    final duel = _duel(name);
    if (duel != null) return duel.join(convId);
    return ChatGameService.instance.join(
      convId,
      ChatGameKind.byName(name) ?? ChatGameKind.date,
    );
  }

  /// Declines (receiver) or cancels (sender) an invite nobody accepted yet.
  static Future<void> close(
    String name, {
    required String convId,
    required String otherUserId,
  }) {
    if (MatchInviteService.handles(name)) {
      return MatchInviteService.instance.close(name, convId);
    }
    if (name == ChessGame.gameName) {
      return ChessService.instance.resign(
        convId: convId,
        otherUserId: otherUserId,
        postResult: false,
      );
    }
    final duel = _duel(name);
    if (duel != null) {
      return duel.resign(
        convId: convId,
        otherUserId: otherUserId,
        postResult: false,
      );
    }
    return ChatGameService.instance.cancel(
      convId,
      ChatGameKind.byName(name) ?? ChatGameKind.date,
    );
  }

  static void _log(String where, Object e) {
    if (kDebugMode) debugPrint('ChatGameInvites.$where failed: $e');
  }
}

/// Live state of every game in one chat, for the invite cards. Calls
/// [onAccepted] when the other player accepts an invite I sent while this
/// watcher is running.
class GameRoomsWatcher {
  GameRoomsWatcher({required this.convId, required this.onAccepted});

  final String convId;
  final ValueChanged<String> onAccepted;

  /// Game name -> state; a name is present once its first snapshot arrived
  /// (with a null value if there is no game).
  final ValueNotifier<Map<String, GameRoomState?>> rooms = ValueNotifier(
    const {},
  );

  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _subs = {};

  /// Starts listening to [names]; a listen that failed (the chat did not
  /// exist yet) is retried.
  void watch(Iterable<String> names) {
    for (final name in names) {
      if (_subs.containsKey(name)) continue;
      _subs[name] = ChatGameInvites._doc(convId, name).snapshots().listen(
        (snap) => _update(name, GameRoomState.fromMap(snap.data())),
        onError: (Object e) {
          ChatGameInvites._log('watch($name)', e);
          _subs.remove(name);
        },
      );
    }
  }

  void _update(String name, GameRoomState? next) {
    final prev = rooms.value[name];
    rooms.value = {...rooms.value, name: next};
    if (prev != null &&
        next != null &&
        prev.isPending &&
        prev.createdBy == ChatGameInvites._me &&
        next.gameId == prev.gameId &&
        next.isOpen &&
        next.bothJoined) {
      onAccepted(name);
    }
  }

  void dispose() {
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    rooms.dispose();
  }
}
