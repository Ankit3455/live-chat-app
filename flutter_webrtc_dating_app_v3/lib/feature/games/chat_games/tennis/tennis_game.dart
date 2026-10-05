// lib/feature/games/chat_games/tennis/tennis_game.dart
//
// Tennis Duel as a duel (see duel/duel_game.dart): each pick is a zone
// 'L' / 'C' / 'R' stored from players[0]'s side of the court. Pure Dart.

import '../chat_game_logic.dart';
import '../duel/duel_game.dart';
import 'tennis_match.dart';

class TennisRules extends DuelRules {
  TennisRules._();
  static final TennisRules instance = TennisRules._();

  static const String gameName = 'tennis';
  static const String emojiIcon = '🎾';

  @override
  String get name => gameName;
  @override
  String get emoji => emojiIcon;
  @override
  String get title => 'Tennis Duel';
  @override
  String get tagline => 'Aim, guess, rally. First to 2 games wins.';

  @override
  int get maxShots => TennisMatch.maxShots;

  @override
  Object? parsePick(Object? raw) => TennisMatch.isZone(raw) ? raw : null;

  static TennisReplay replayOf(DuelGame g) => TennisReplay.of(g.players, [
    for (final shot in g.history)
      {
        for (final e in shot.entries)
          if (e.value is String) e.key: e.value as String,
      },
  ], resignedBy: g.resignedBy);

  @override
  bool isOver(DuelGame game) => replayOf(game).isOver;

  @override
  ChatGameMessage invite() => const ChatGameMessage(
    "🎾 Let's play Tennis Duel! Aim, guess, rally.",
    {'game': gameName, 'stage': ChatGameLogic.inviteStage},
  );

  @override
  ChatGameMessage result(DuelGame game) => resultFor(replayOf(game));

  /// Result card for a finished match ([r].winner is set).
  static ChatGameMessage resultFor(TennisReplay r) {
    final w = r.winner!;
    return ChatGameMessage(
      '🎾 Tennis Duel: ${r.games[w]}-${r.games[1 - w]}'
      '${r.byResignation ? ' (resigned)' : ''}',
      {
        'game': gameName,
        'stage': ChatGameLogic.resultStage,
        'winner': r.players[w],
        // Winner first, e.g. "2-1".
        'score': '${r.games[w]}-${r.games[1 - w]}',
        if (r.byResignation) 'resigned': true,
      },
    );
  }

  @override
  String resultLine(
    Map<String, dynamic> meta, {
    required String viewer,
    required String otherName,
  }) {
    final score = meta['score'] as String?;
    final line = outcomeFor(viewer: viewer, otherName: otherName, meta: meta);
    return score == null ? line : '$line ($score)';
  }

  /// "You won the match! 🏆", "Bob won the match." or a resignation line.
  static String outcomeFor({
    required String viewer,
    required String otherName,
    required Map<String, dynamic> meta,
  }) {
    final winner = meta['winner'] as String?;
    if (winner == null) return 'Match over';
    final iWon = winner == viewer;
    if (meta['resigned'] == true) {
      return iWon ? '$otherName resigned. You win! 🏆' : 'You resigned.';
    }
    return iWon ? 'You won the match! 🏆' : '$otherName won the match.';
  }
}
