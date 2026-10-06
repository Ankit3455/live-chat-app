// lib/feature/games/chat_games/thumb_war/thumb_rules.dart
//
// Thumb War as a duel (see duel/duel_game.dart). Each pick is
// {'m': move, 'p': power}. Pure Dart.

import '../chat_game_logic.dart';
import '../duel/duel_game.dart';
import 'thumb_war.dart';

class ThumbRules extends DuelRules {
  ThumbRules._();
  static final ThumbRules instance = ThumbRules._();

  static const String gameName = 'thumb';
  static const String emojiIcon = '👍';
  static const String displayTitle = 'Thumb War';

  @override
  String get name => gameName;
  @override
  String get emoji => emojiIcon;
  @override
  String get title => displayTitle;
  @override
  String get tagline => 'Pounce, guard or feint. Grip hard, pin them down.';

  /// Stored as a plain map so Firestore and the rules can read it.
  @override
  Object? parsePick(Object? raw) => ThumbPick.parse(raw)?.toMap();

  static ThumbReplay replayOf(DuelGame g) =>
      ThumbReplay.of(g.players, g.history, resignedBy: g.resignedBy);

  @override
  bool isOver(DuelGame game) => replayOf(game).isOver;

  @override
  ChatGameMessage invite() => const ChatGameMessage(
    "👍 One, two, three, four, I declare a Thumb War!",
    {'game': gameName, 'stage': ChatGameLogic.inviteStage},
  );

  @override
  ChatGameMessage result(DuelGame game) {
    final r = replayOf(game);
    final w = r.winner!;
    final left = game.leftBy != null;
    return ChatGameMessage(
      '👍 Thumb War: ${r.rounds[w]}-${r.rounds[1 - w]}'
      '${_how(r.byResignation, left)}',
      {
        'game': gameName,
        'stage': ChatGameLogic.resultStage,
        'winner': r.players[w],
        // Winner first, e.g. "2-1".
        'score': '${r.rounds[w]}-${r.rounds[1 - w]}',
        if (r.byResignation) 'resigned': true,
        if (left) 'left': true,
      },
    );
  }

  @override
  String resultLine(
    Map<String, dynamic> meta, {
    required String viewer,
    required String otherName,
  }) {
    final winner = meta['winner'] as String?;
    if (winner == null) return 'Thumb War over';
    final iWon = winner == viewer;
    final score = meta['score'] as String?;
    final tail = score == null ? '' : ' ($score)';
    if (meta['left'] == true) {
      return iWon ? '$otherName left the game. You win! 👑' : 'You left.';
    }
    if (meta['resigned'] == true) {
      return iWon ? '$otherName gave up. You win! 👑' : 'You gave up.';
    }
    return iWon
        ? 'You are the Thumb War champion! 👑$tail'
        : '$otherName won the Thumb War.$tail';
  }

  static String _how(bool resigned, bool left) =>
      left ? ' (left the game)' : (resigned ? ' (resigned)' : '');
}
