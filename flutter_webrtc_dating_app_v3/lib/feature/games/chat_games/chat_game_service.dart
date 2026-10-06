// lib/feature/games/chat_games/chat_game_service.dart
//
// Firestore side of chat games: conversations/{convId}/games/{kind}, or
// game_rooms/{roomId}/games/{kind} for a random match (see GameSpace).
// firestore.rules (match /games/{name}) checks every write.

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../models/chat_message_model.dart';
import '../../../services/chat_service.dart';
import '../../../services/notification/onesignal_sender.dart';
import 'chat_game.dart';
import 'chat_game_logic.dart';
import 'game_space.dart';

class ChatGameException implements Exception {
  final String message;
  const ChatGameException(this.message);

  @override
  String toString() => message;
}

class ChatGameService {
  ChatGameService._();
  static final ChatGameService instance = ChatGameService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ChatService _chat = ChatService();

  String get _me => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> _game(
    String convId,
    ChatGameKind kind,
  ) => GameSpace.game(convId, kind.name);

  /// Null while there is no game. A read error (e.g. the chat has no
  /// messages yet, so the rules can't see it) also gives null and ends the
  /// stream; call watch again after [start].
  Stream<ChatGame?> watch(String convId, ChatGameKind kind) {
    return _game(convId, kind)
        .snapshots()
        .map((s) => ChatGame.fromMap(kind, withDates(s.data())))
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (Object e, StackTrace _, EventSink<ChatGame?> sink) {
              _log('watch', e);
              sink.add(null);
            },
          ),
        );
  }

  /// Starts a new game and invites the other player, or does nothing if one
  /// is already running. Returns whether a game was created.
  Future<bool> start({
    required String convId,
    required String otherUserId,
    required ChatGameKind kind,
  }) async {
    final me = _me;
    final random = Random.secure();
    final gameId = List.generate(
      20,
      (_) => _idChars[random.nextInt(_idChars.length)],
    ).join();
    final invite = ChatGameLogic.withGameId(ChatGameLogic.invite(kind), gameId);
    final (:participants, :invited) = await prepareConversation(
      convId: convId,
      otherUserId: otherUserId,
      invite: invite,
    );

    final ref = _game(convId, kind);
    final created = await _db.runTransaction<bool>((tx) async {
      final current = ChatGame.fromMap(
        kind,
        withDates((await tx.get(ref)).data()),
      );
      // Both tapped Start at once: join the game that already exists.
      if (current != null && current.isActive) return false;
      // A new game never repeats the questions of the one it replaces.
      final deck = ChatGameLogic.buildDeck(
        kind,
        random: random,
        exclude: ChatGameLogic.deckIds(current),
      );
      final now = FieldValue.serverTimestamp();
      tx.set(ref, {
        'gameId': gameId,
        'players': participants,
        'createdBy': me,
        'status': 'playing',
        'round': 0,
        'deck': {
          for (var r = 0; r < deck.length; r++) ChatGame.roundKey(r): deck[r],
        },
        'picks': <String, dynamic>{},
        // The other player's join starts the first round's clock.
        'joined': [me],
        'roundStartedAt': null,
        'createdAt': now,
        'updatedAt': now,
      });
      return true;
    });

    if (created && !invited) {
      await sendGameMessage(convId, otherUserId, invite);
    }
    return created;
  }

  /// The game rules read the conversation, so it has to exist before a game
  /// doc is written; if it doesn't, [invite] is sent first, which creates it.
  /// A random-match room always exists and gets no invite.
  /// Returns the stored participants and whether the invite went out.
  Future<({List<String> participants, bool invited})> prepareConversation({
    required String convId,
    required String otherUserId,
    required ChatGameMessage invite,
  }) async {
    if (_me.isEmpty || convId.isEmpty) {
      throw const ChatGameException('You are not logged in.');
    }
    final parent = GameSpace.parent(convId);
    var convSnap = await parent.get();
    var invited = false;
    if (!convSnap.exists && !GameSpace.isRoom(convId)) {
      await sendGameMessage(convId, otherUserId, invite);
      invited = true;
      convSnap = await parent.get();
    }
    final participants = (convSnap.data()?['participants'] as List?)
        ?.whereType<String>()
        .toList();
    if (participants == null || participants.length != 2) {
      throw const ChatGameException('This chat is not available.');
    }
    return (participants: participants, invited: invited);
  }

  /// Saves my pick for the current round. The pick that completes the last
  /// round also posts the result card in the chat.
  Future<void> pick({
    required String convId,
    required String otherUserId,
    required ChatGameKind kind,
    required Object value,
  }) async {
    final me = _me;
    final ref = _game(convId, kind);
    final finished = await _db.runTransaction<ChatGame?>((tx) async {
      final snap = await tx.get(ref);
      final game = ChatGame.fromMap(kind, withDates(snap.data()));
      if (game == null || !game.isActive) {
        throw const ChatGameException('This game has ended.');
      }
      if (!game.bothJoined) {
        throw const ChatGameException('Waiting for your match to join.');
      }
      final r = game.round;
      if (game.picksFor(r).containsKey(me)) return null;
      if (!ChatGameLogic.isValidPick(game, value)) {
        throw const ChatGameException("That pick isn't part of this round.");
      }
      final completes = game.picksFor(r).length == 1;
      tx.update(ref, {
        'picks.${ChatGame.roundKey(r)}.$me': value,
        if (completes) 'round': r + 1,
        if (completes) 'roundStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!completes || r + 1 < game.rounds) return null;
      final picks = [...game.picks];
      picks[r] = {...game.picksFor(r), me: value};
      return ChatGame(
        kind: kind,
        gameId: game.gameId,
        players: game.players,
        createdBy: game.createdBy,
        cancelled: false,
        round: r + 1,
        deck: game.deck,
        picks: picks,
      );
    });

    if (finished != null) {
      try {
        await sendGameMessage(
          convId,
          otherUserId,
          ChatGameLogic.result(finished),
        );
      } catch (e) {
        // The game itself is saved; only the chat card is missing.
        _log('sendResult', e);
      }
    }
  }

  /// Joins a game the other player started; this starts the clock.
  Future<void> join(String convId, ChatGameKind kind) async {
    final me = _me;
    final ref = _game(convId, kind);
    await _db.runTransaction<void>((tx) async {
      final game = ChatGame.fromMap(
        kind,
        withDates((await tx.get(ref)).data()),
      );
      if (game == null || !game.isActive || game.joined.contains(me)) return;
      tx.update(ref, {
        'joined': [...game.joined, me],
        'roundStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Ends a round whose 30 seconds are up; missing picks are skipped. Either
  /// phone may call it; the rules check the time on the server. Does nothing
  /// if the round already moved on.
  Future<void> timeout({
    required String convId,
    required String otherUserId,
    required ChatGameKind kind,
  }) async {
    final ref = _game(convId, kind);
    final finished = await _db.runTransaction<ChatGame?>((tx) async {
      final game = ChatGame.fromMap(
        kind,
        withDates((await tx.get(ref)).data()),
      );
      final deadline = game?.deadline;
      if (game == null || !game.isActive || deadline == null) return null;
      if (DateTime.now().isBefore(deadline)) return null;
      final next = game.round + 1;
      tx.update(ref, {
        'round': next,
        'roundStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (next < game.rounds) return null;
      return ChatGame(
        kind: kind,
        gameId: game.gameId,
        players: game.players,
        createdBy: game.createdBy,
        cancelled: false,
        round: next,
        deck: game.deck,
        picks: game.picks,
        joined: game.joined,
      );
    });
    if (finished != null) {
      try {
        await sendGameMessage(
          convId,
          otherUserId,
          ChatGameLogic.result(finished),
        );
      } catch (e) {
        _log('sendResult', e);
      }
    }
  }

  /// Firestore Timestamps -> DateTime, so the pure game models can read them.
  static Map<String, dynamic>? withDates(Map<String, dynamic>? data) {
    if (data == null) return null;
    return {
      for (final e in data.entries)
        e.key: e.value is Timestamp ? (e.value as Timestamp).toDate() : e.value,
    };
  }

  /// Ends the game for both. [left]: I'm leaving it (leftBy = me), so the
  /// other player sees that I left.
  Future<void> cancel(
    String convId,
    ChatGameKind kind, {
    bool left = false,
  }) async {
    await _game(convId, kind).update({
      'status': 'cancelled',
      if (left) 'leftBy': _me,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// The other player hasn't picked for [TurnClock.staleSeconds]: ends the
  /// game as left by them. The rules check the time on the server.
  Future<void> claimLeft(String convId, ChatGameKind kind) async {
    final me = _me;
    final ref = _game(convId, kind);
    await _db.runTransaction<void>((tx) async {
      final game = ChatGame.fromMap(
        kind,
        withDates((await tx.get(ref)).data()),
      );
      final started = game?.roundStartedAt;
      if (game == null || !game.isActive || !game.bothJoined) return;
      if (started == null || !isStale(started)) return;
      final other = game.otherOf(me);
      if (game.picksFor(game.round).containsKey(other)) return;
      tx.update(ref, {
        'status': 'cancelled',
        'leftBy': other,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// A clock that started at [started] is old enough to claim a left player.
  static bool isStale(DateTime started) => DateTime.now().isAfter(
    started.add(const Duration(seconds: TurnClock.staleSeconds)),
  );

  /// Sends a plain text message (e.g. "Should we actually go?"). Rooms have
  /// no chat.
  Future<void> sendText(String convId, String otherUserId, String text) async {
    if (GameSpace.isRoom(convId)) return;
    final id = await _chat.sendMessage(
      conversationId: convId,
      receiverId: otherUserId,
      message: text,
    );
    _notify(convId, id);
  }

  /// Posts a game card (invite or result) in the chat and pushes it. Games
  /// in a random-match room have no chat, so nothing is sent.
  Future<void> sendGameMessage(
    String convId,
    String otherUserId,
    ChatGameMessage message,
  ) async {
    if (GameSpace.isRoom(convId)) return;
    final id = await _chat.sendMessage(
      conversationId: convId,
      receiverId: otherUserId,
      type: MessageType.game,
      message: message.text,
      metadata: message.metadata,
    );
    _notify(convId, id);
  }

  void _notify(String convId, String? messageId) {
    if (messageId == null) return;
    unawaited(
      OneSignalSender.sendChatNotification(
        conversationId: convId,
        messageId: messageId,
      ),
    );
  }

  static const String _idChars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  void _log(String where, Object e) {
    if (kDebugMode) debugPrint('ChatGameService.$where failed: $e');
  }
}
