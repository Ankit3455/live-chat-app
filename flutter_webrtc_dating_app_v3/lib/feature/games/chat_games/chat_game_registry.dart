// lib/feature/games/chat_games/chat_game_registry.dart
//
// Every game that can be played in a chat: what the games sheet lists, which
// screen opens, and the result line on the chat card.

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

  static final List<ChatGameEntry> all = [
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
  }) {
    if (name == ChessGame.gameName) {
      return ChessScreen(
        conversationId: conversationId,
        otherUserId: otherUserId,
        otherName: otherName,
        otherUser: otherUser,
      );
    }
    if (name == TennisRules.gameName) {
      return TennisScreen(
        conversationId: conversationId,
        otherUserId: otherUserId,
        otherName: otherName,
        otherUser: otherUser,
      );
    }
    if (name == ThumbRules.gameName) {
      return ThumbScreen(
        conversationId: conversationId,
        otherUserId: otherUserId,
        otherName: otherName,
      );
    }
    return ChatGameScreen(
      kind: ChatGameKind.byName(name) ?? ChatGameKind.date,
      conversationId: conversationId,
      otherUserId: otherUserId,
      otherName: otherName,
      otherUser: otherUser,
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
