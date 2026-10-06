// lib/feature/games/chat_games/duel/duel_service.dart
//
// Firestore side of duels: {space}/games/{rules.name} (see GameSpace).
// firestore.rules (match /games/{duel}) checks own picks, pick values and
// the 30 s clock; the score comes from replaying the history.

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../chat_game_logic.dart';
import '../chat_game_service.dart';
import '../game_space.dart';
import 'duel_game.dart';

class DuelService {
  DuelService(this.rules);

  final DuelRules rules;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ChatGameService _games = ChatGameService.instance;

  String get _me => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> _doc(String convId) =>
      GameSpace.game(convId, rules.name);

  DuelGame? _read(DocumentSnapshot<Map<String, dynamic>> s) =>
      DuelGame.fromMap(rules, ChatGameService.withDates(s.data()));

  /// Null while there is no game. A read error (the chat has no messages
  /// yet) also gives null and ends the stream; call watch again after start.
  Stream<DuelGame?> watch(String convId) {
    return _doc(convId)
        .snapshots()
        .map(_read)
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (Object e, StackTrace _, EventSink<DuelGame?> sink) {
              _log('watch', e);
              sink.add(null);
            },
          ),
        );
  }

  /// Starts a new game (random player order: players[0] goes first) and
  /// invites the other player, or does nothing if one is already running.
  /// Returns whether one was created.
  Future<bool> start({
    required String convId,
    required String otherUserId,
  }) async {
    final me = _me;
    final random = Random.secure();
    final gameId = List.generate(
      20,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    final invite = ChatGameLogic.withGameId(rules.invite(), gameId);
    final (:participants, :invited) = await _games.prepareConversation(
      convId: convId,
      otherUserId: otherUserId,
      invite: invite,
    );
    final players = List.of(participants)..shuffle(random);

    final ref = _doc(convId);
    final created = await _db.runTransaction<bool>((tx) async {
      final current = _read(await tx.get(ref));
      if (current != null && current.isPlaying) return false;
      final now = FieldValue.serverTimestamp();
      tx.set(ref, {
        'gameId': gameId,
        'players': players,
        'createdBy': me,
        'status': 'playing',
        'picks': <String, dynamic>{},
        'history': <dynamic>[],
        // The other player's join starts the first shot's clock.
        'joined': [me],
        'turnStartedAt': null,
        'createdAt': now,
        'updatedAt': now,
      });
      return true;
    });

    if (created && !invited) {
      await _games.sendGameMessage(convId, otherUserId, invite);
    }
    return created;
  }

  Future<void> join(String convId) async {
    final me = _me;
    final ref = _doc(convId);
    await _db.runTransaction<void>((tx) async {
      final game = _read(await tx.get(ref));
      if (game == null || !game.isPlaying || game.joined.contains(me)) return;
      tx.update(ref, {
        'joined': [...game.joined, me],
        'turnStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Locks in my [pick] (stored form) for this shot. The second pick
  /// finishes the shot and starts the next clock.
  Future<void> pick({
    required String convId,
    required String otherUserId,
    required Object pick,
  }) async {
    final me = _me;
    final ref = _doc(convId);
    final ended = await _db.runTransaction<DuelGame?>((tx) async {
      final game = _read(await tx.get(ref));
      if (game == null || !game.isPlaying) {
        throw const ChatGameException('This game has ended.');
      }
      if (!game.bothJoined) {
        throw const ChatGameException('Waiting for your match to join.');
      }
      if (rules.isOver(game) || game.picks.containsKey(me)) return null;
      if (!game.players.contains(me) || rules.parsePick(pick) == null) {
        throw const ChatGameException("That move isn't allowed.");
      }
      final picks = {...game.picks, me: pick};
      if (picks.length < 2) {
        tx.update(ref, {
          'picks': picks,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return null;
      }
      return _finishShot(tx, ref, game, picks);
    });
    if (ended != null) await _postResult(convId, otherUserId, ended);
  }

  /// The shot's 30 seconds are up: it's played with whatever picks there
  /// are. Either phone may call it; the rules check the time on the server.
  Future<void> timeout({
    required String convId,
    required String otherUserId,
  }) async {
    final ref = _doc(convId);
    final ended = await _db.runTransaction<DuelGame?>((tx) async {
      final game = _read(await tx.get(ref));
      final deadline = game?.deadline;
      if (game == null || !game.isPlaying || deadline == null) return null;
      if (DateTime.now().isBefore(deadline) || rules.isOver(game)) return null;
      return _finishShot(tx, ref, game, game.picks);
    });
    if (ended != null) await _postResult(convId, otherUserId, ended);
  }

  /// Moves [picks] onto the history and restarts the clock. Returns the
  /// game if this shot ended it.
  DuelGame? _finishShot(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
    DuelGame game,
    Map<String, Object> picks,
  ) {
    if (game.history.length >= rules.maxShots) {
      throw const ChatGameException('This game is too long to continue.');
    }
    final after = game.copyWith(history: [...game.history, picks], picks: {});
    final over = rules.isOver(after);
    tx.update(ref, {
      'history': after.history,
      'picks': <String, dynamic>{},
      'turnStartedAt': FieldValue.serverTimestamp(),
      if (over) 'status': 'over',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return over ? after.copyWith(status: 'over') : null;
  }

  /// Resigns (or cancels an invite nobody joined: [postResult] false skips
  /// the result card). [left]: resigning by leaving the game.
  Future<void> resign({
    required String convId,
    required String otherUserId,
    bool postResult = true,
    bool left = false,
  }) async {
    final me = _me;
    final ref = _doc(convId);
    final ended = await _db.runTransaction<DuelGame>((tx) async {
      final game = _read(await tx.get(ref));
      if (game == null || !game.isPlaying) {
        throw const ChatGameException('This game has ended.');
      }
      tx.update(ref, {
        'status': 'over',
        'resignedBy': me,
        if (left) 'leftBy': me,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return game.copyWith(
        status: 'over',
        resignedBy: me,
        leftBy: left ? me : null,
      );
    });
    if (postResult) await _postResult(convId, otherUserId, ended);
  }

  /// The other player hasn't picked for [TurnClock.staleSeconds]: they left,
  /// so I win. The rules check the time on the server.
  Future<void> claimLeft({
    required String convId,
    required String otherUserId,
  }) async {
    final me = _me;
    final ref = _doc(convId);
    final ended = await _db.runTransaction<DuelGame?>((tx) async {
      final game = _read(await tx.get(ref));
      final started = game?.turnStartedAt;
      if (game == null || !game.isPlaying || !game.bothJoined) return null;
      if (started == null || !ChatGameService.isStale(started)) return null;
      final other = game.otherOf(me);
      if (game.picks.containsKey(other)) return null;
      tx.update(ref, {
        'status': 'over',
        'leftBy': other,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return game.copyWith(status: 'over', resignedBy: other, leftBy: other);
    });
    if (ended != null) await _postResult(convId, otherUserId, ended);
  }

  Future<void> _postResult(
    String convId,
    String otherUserId,
    DuelGame game,
  ) async {
    try {
      await _games.sendGameMessage(convId, otherUserId, rules.result(game));
    } catch (e) {
      // The game itself is saved; only the chat card is missing.
      _log('sendResult', e);
    }
  }

  void _log(String where, Object e) {
    if (kDebugMode) debugPrint('DuelService(${rules.name}).$where failed: $e');
  }
}
