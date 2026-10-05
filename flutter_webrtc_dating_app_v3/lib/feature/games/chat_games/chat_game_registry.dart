// lib/feature/games/chat_games/chat_game_registry.dart
//
// Every 2-player game: what the chat's games sheet and the Games tab list,
// which screen opens, and the result line on the chat card. From a chat a
// game is played with that match (invite card); from the Games tab with a
// random player (RandomMatchScreen, or the Ludo / Carrom lobbies).

import 'package:flutter/widgets.dart';

import '../../../models/user_model.dart';
import 'chat_game.dart';
import 'chat_game_logic.dart';
import 'chat_game_screen.dart';
import 'chess/chess_game.dart';
import 'chess/chess_screen.dart';
import 'duel/duel_game.dart';
import 'tennis/tennis_game.dart';
import 'tennis/tennis_screen.dart';
import 'thumb_war/thumb_rules.dart';
import 'thumb_war/thumb_screen.dart';

class ChatGameEntry {
  /// Doc id under conversations/{convId}/games and metadata.game.
  final String name;
  final String emoji;
  final String title;
  final String tagline;

  const ChatGameEntry(this.name, this.emoji, this.title, this.tagline);
}

class ChatGames {
  ChatGames._();

  static final List<DuelRules> _duels = [
    TennisRules.instance,
    ThumbRules.instance,
  ];

  /// Games that live in a chat / room space ({space}/games/{name}).
  static final List<ChatGameEntry> spaceGames = [
    for (final k in ChatGameKind.values)
      ChatGameEntry(k.name, k.emoji, k.title, k.tagline),
    const ChatGameEntry(
      ChessGame.gameName,
      ChessGame.emoji,
      ChessGame.title,
      ChessGame.tagline,
    ),
    for (final d in _duels) ChatGameEntry(d.name, d.emoji, d.title, d.tagline),
  ];

  /// Ludo and Carrom are their own matches (ludo_matches / carrom_matches):
  /// from a chat they go through MatchInviteService, from the Games tab
  /// through their lobbies.
  static const List<ChatGameEntry> matchGames = [
    ChatGameEntry(
      'ludo',
      '🎲',
      'Ludo',
      'Race your 4 pawns home. The classic board game.',
    ),
    ChatGameEntry(
      'carrom',
      '🎯',
      'Carrom',
      'Flick the striker and pocket your coins first.',
    ),
  ];

  static final List<ChatGameEntry> all = [...matchGames, ...spaceGames];

  static bool isMatchGame(String name) =>
      matchGames.any((g) => g.name == name);

  static ChatGameEntry? byName(Object? name) {
    for (final g in all) {
      if (g.name == name) return g;
    }
    return null;
  }

  static DuelRules? _duel(String name) {
    for (final d in _duels) {
      if (d.name == name) return d;
    }
    return null;
  }

  static Widget screen(
    String name, {
    required String conversationId,
    required String otherUserId,
    required String otherName,
    UserModel? otherUser,
    bool startOnOpen = false,
  }) {
    if (name == ChessGame.gameName) {
      return ChessScreen(
        conversationId: conversationId,
        otherUserId: otherUserId,
        otherName: otherName,
        otherUser: otherUser,
        startOnOpen: startOnOpen,
      );
    }
    if (name == TennisRules.gameName) {
      return TennisScreen(
        conversationId: conversationId,
        otherUserId: otherUserId,
        otherName: otherName,
        otherUser: otherUser,
        startOnOpen: startOnOpen,
      );
    }
    if (name == ThumbRules.gameName) {
      return ThumbScreen(
        conversationId: conversationId,
        otherUserId: otherUserId,
        otherName: otherName,
        startOnOpen: startOnOpen,
      );
    }
    return ChatGameScreen(
      kind: ChatGameKind.byName(name) ?? ChatGameKind.date,
      conversationId: conversationId,
      otherUserId: otherUserId,
      otherName: otherName,
      otherUser: otherUser,
      startOnOpen: startOnOpen,
    );
  }

  /// Result line on a result card, as seen by [viewer]. Empty if unknown.
  static String resultLine(
    String name,
    Map<String, dynamic> meta, {
    required String viewer,
    required String otherName,
  }) {
    if (name == ChessGame.gameName) {
      final end = ChessGame.endByName(meta['reason']);
      if (end == null) return '';
      return ChessGame.outcomeFor(
        viewer: viewer,
        otherName: otherName,
        end: end,
        winner: meta['winner'] as String?,
      );
    }
    final duel = _duel(name);
    if (duel != null) {
      return duel.resultLine(meta, viewer: viewer, otherName: otherName);
    }
    final kind = ChatGameKind.byName(name);
    return kind == null ? '' : ChatGameLogic.resultLine(kind, meta);
  }
}
