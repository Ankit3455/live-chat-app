// lib/feature/games/chat_games/chess/chess_service.dart
//
// Firestore side of chess: {space}/games/chess (see GameSpace).
// firestore.rules (match /games/chess) checks turn order and move format;
// legality is checked here and again by the other phone's replay.

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../chat_game_logic.dart';
import '../chat_game_service.dart';
import '../game_space.dart';
import 'chess_engine.dart';
import 'chess_game.dart';

class ChessService {
  ChessService._();
  static final ChessService instance = ChessService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ChatGameService _games = ChatGameService.instance;

  String get _me => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> _doc(String convId) =>
      GameSpace.game(convId, ChessGame.gameName);

  /// Null while there is no game. A read error (the chat has no messages
  /// yet) also gives null and ends the stream; call watch again after start.
  Stream<ChessGame?> watch(String convId) {
    return _doc(convId)
        .snapshots()
        .map((s) => ChessGame.fromMap(ChatGameService.withDates(s.data())))
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (Object e, StackTrace _, EventSink<ChessGame?> sink) {
              _log('watch', e);
              sink.add(null);
            },
          ),
        );
  }

  /// Starts a new game with random colours and invites the other player, or
  /// does nothing if one is already running. Returns whether one was created.
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
    final invite = ChatGameLogic.withGameId(ChessGame.invite(), gameId);
    final (:participants, :invited) = await _games.prepareConversation(
      convId: convId,
      otherUserId: otherUserId,
      invite: invite,
    );
    final players = List.of(participants)..shuffle(random);

    final ref = _doc(convId);
    final created = await _db.runTransaction<bool>((tx) async {
      final current = ChessGame.fromMap(
        ChatGameService.withDates((await tx.get(ref)).data()),
      );
      if (current != null && current.isPlaying) return false;
      final now = FieldValue.serverTimestamp();
      tx.set(ref, {
        'gameId': gameId,
        'players': players,
        'createdBy': me,
        'status': 'playing',
        'moves': <String>[],
        // The other player's join starts white's clock.
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

  /// Plays [move] if it's my turn and legal. A move that ends the game also
  /// posts the result in the chat.
  Future<void> move({
    required String convId,
    required String otherUserId,
    required ChessMove move,
  }) async {
    final me = _me;
    final ref = _doc(convId);
    final ended = await _db.runTransaction<ChessGame?>((tx) async {
      final game = ChessGame.fromMap(
        ChatGameService.withDates((await tx.get(ref)).data()),
      );
      if (game == null || !game.isPlaying) {
        throw const ChatGameException('This game has ended.');
      }
      if (!game.bothJoined) {
        throw const ChatGameException('Waiting for your match to join.');
      }
      final before = game.replay;
      if (before.illegalAt != null || before.isOver) {
        throw const ChatGameException("This game can't continue.");
      }
      if (game.turn != me) {
        throw const ChatGameException("It's not your turn.");
      }
      if (!Chess.isLegal(before.position, move)) {
        throw const ChatGameException("That move isn't allowed.");
      }
      if (game.moves.length >= ChessGame.maxMoves) {
        throw const ChatGameException('This game is too long to continue.');
      }
      return _append(tx, ref, game, move.uci);
    });

    if (ended != null) await _postResult(convId, otherUserId, ended);
  }

  /// Joins a game the other player started; this starts white's clock.
  Future<void> join(String convId) async {
    final me = _me;
    final ref = _doc(convId);
    await _db.runTransaction<void>((tx) async {
      final game = ChessGame.fromMap(
        ChatGameService.withDates((await tx.get(ref)).data()),
      );
      if (game == null || !game.isPlaying || game.joined.contains(me)) return;
      tx.update(ref, {
        'joined': [...game.joined, me],
        'turnStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// The player to move ran out of time: the turn passes (or, in check, the
  /// game is lost on time). Either phone may call it; the rules check the
  /// time on the server. Does nothing if the turn already moved on.
  Future<void> timeout({
    required String convId,
    required String otherUserId,
  }) async {
    final ref = _doc(convId);
    final ended = await _db.runTransaction<ChessGame?>((tx) async {
      final game = ChessGame.fromMap(
        ChatGameService.withDates((await tx.get(ref)).data()),
      );
      final deadline = game?.deadline;
      if (game == null || !game.isPlaying || deadline == null) return null;
      if (DateTime.now().isBefore(deadline)) return null;
      final before = game.replay;
      if (before.illegalAt != null || before.isOver) return null;
      if (game.moves.length >= ChessGame.maxMoves) return null;
      return _append(tx, ref, game, ChessMove.pass);
    });
    if (ended != null) await _postResult(convId, otherUserId, ended);
  }

  /// Writes one more entry (a move or a pass) and restarts the clock.
  /// Returns the finished game if this entry ended it.
  ChessGame? _append(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
    ChessGame game,
    String entry,
  ) {
    final moves = [...game.moves, entry];
    final after = ChessReplay.of(moves);
    tx.update(ref, {
      'moves': moves,
      'turnStartedAt': FieldValue.serverTimestamp(),
      if (after.isOver) 'status': 'over',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!after.isOver) return null;
    return ChessGame(
      gameId: game.gameId,
      players: game.players,
      createdBy: game.createdBy,
      status: 'over',
      moves: moves,
      resignedBy: null,
      joined: game.joined,
    );
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
    await _db.runTransaction<void>((tx) async {
      final game = ChessGame.fromMap(
        ChatGameService.withDates((await tx.get(_doc(convId))).data()),
      );
      if (game == null || !game.isPlaying) {
        throw const ChatGameException('This game has ended.');
      }
      tx.update(_doc(convId), {
        'status': 'over',
        'resignedBy': me,
        if (left) 'leftBy': me,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    if (!postResult) return;
    await _send(
      convId,
      otherUserId,
      ChessGame.result(ChessEnd.resignation, otherUserId, left: left),
    );
  }

  /// The other player hasn't moved for [TurnClock.staleSeconds]: they left,
  /// so I win. The rules check the time on the server.
  Future<void> claimLeft({
    required String convId,
    required String otherUserId,
  }) async {
    final me = _me;
    final ref = _doc(convId);
    final claimed = await _db.runTransaction<bool>((tx) async {
      final game = ChessGame.fromMap(
        ChatGameService.withDates((await tx.get(ref)).data()),
      );
      final started = game?.turnStartedAt;
      if (game == null || !game.isPlaying || !game.bothJoined) return false;
      if (started == null || !ChatGameService.isStale(started)) return false;
      if (game.turn == me) return false;
      tx.update(ref, {
        'status': 'over',
        'leftBy': game.otherOf(me),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (!claimed) return;
    await _send(
      convId,
      otherUserId,
      ChessGame.result(ChessEnd.resignation, me, left: true),
    );
  }

  Future<void> _postResult(
    String convId,
    String otherUserId,
    ChessGame game,
  ) async {
    final replay = game.replay;
    final end = replay.end;
    if (end == null) return;
    final whiteWon = replay.whiteWon;
    final winner = whiteWon == null
        ? null
        : (whiteWon ? game.white : game.black);
    await _send(convId, otherUserId, ChessGame.result(end, winner));
  }

  Future<void> _send(
    String convId,
    String otherUserId,
    ChatGameMessage message,
  ) async {
    try {
      await _games.sendGameMessage(convId, otherUserId, message);
    } catch (e) {
      // The game itself is saved; only the chat card is missing.
      _log('sendResult', e);
    }
  }

  void _log(String where, Object e) {
    if (kDebugMode) debugPrint('ChessService.$where failed: $e');
  }
}
