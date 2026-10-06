// lib/feature/games/chat_games/chess/chess_game.dart
//
// Chess in a chat: conversations/{convId}/games/chess. Only the move list is
// stored; both phones rebuild the board from it (ChessReplay), so a forged
// move is caught instead of trusted. Pure Dart.

import '../chat_game.dart';
import '../chat_game_logic.dart';
import 'chess_engine.dart';

class ChessGame {
  static const String gameName = 'chess';
  static const String emoji = '♟️';
  static const String title = 'Chess';
  static const String tagline = 'Classic chess, live: 30 seconds per move.';

  /// Matches the rules' cap on stored moves.
  static const int maxMoves = 600;

  final String gameId;

  /// [white, black].
  final List<String> players;
  final String createdBy;

  /// 'playing', 'over' or 'cancelled'.
  final String status;
  final List<String> moves;

  /// Who resigned; a player who left (leftBy) counts as resigned.
  final String? resignedBy;

  /// Who left the game (or was away too long).
  final String? leftBy;

  /// Players who opened the game. The clock starts once both joined.
  final List<String> joined;

  /// When the current turn's 30 seconds started; null until both joined.
  final DateTime? turnStartedAt;

  const ChessGame({
    required this.gameId,
    required this.players,
    required this.createdBy,
    required this.status,
    required this.moves,
    required this.resignedBy,
    this.leftBy,
    this.joined = const [],
    this.turnStartedAt,
  });

  String get white => players[0];
  String get black => players[1];
  bool isWhite(String uid) => uid == white;
  String otherOf(String uid) => uid == white ? black : white;

  ChessReplay get replay => ChessReplay.of(
    moves,
    resignedByWhite: resignedBy == null ? null : resignedBy == white,
  );

  /// Whose move it is (ignoring whether the game is over).
  String get turn => players[moves.length % 2];

  bool get isPlaying => status == 'playing';

  bool get bothJoined => players.every(joined.contains);

  /// When the current turn times out; null while the clock isn't running.
  DateTime? get deadline =>
      turnStartedAt?.add(const Duration(seconds: TurnClock.seconds));

  /// [data] with timestamps already converted to DateTime.
  static ChessGame? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final players = (data['players'] as List?)?.whereType<String>().toList();
    if (players == null || players.length != 2) return null;
    return ChessGame(
      gameId: (data['gameId'] as String?) ?? '',
      players: players,
      createdBy: (data['createdBy'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'playing',
      moves: ((data['moves'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      resignedBy: data['resignedBy'] as String? ?? data['leftBy'] as String?,
      leftBy: data['leftBy'] as String?,
      joined: ((data['joined'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      turnStartedAt: data['turnStartedAt'] as DateTime?,
    );
  }

  // ---------- chat messages ----------

  static ChatGameMessage invite() => const ChatGameMessage(
    "♟️ Let's play chess! Colours are picked at random.",
    {'game': gameName, 'stage': ChatGameLogic.inviteStage},
  );

  /// [winner] is a uid, or null for a draw. [left]: the loser left.
  static ChatGameMessage result(
    ChessEnd end,
    String? winner, {
    bool left = false,
  }) => ChatGameMessage('♟️ Chess: ${left ? 'left the game' : endText(end)}', {
    'game': gameName,
    'stage': ChatGameLogic.resultStage,
    'reason': end.name,
    if (winner != null) 'winner': winner,
    if (left) 'left': true,
  });

  static String endText(ChessEnd end) {
    switch (end) {
      case ChessEnd.checkmate:
        return 'checkmate!';
      case ChessEnd.resignation:
        return 'resigned';
      case ChessEnd.stalemate:
        return 'draw by stalemate';
      case ChessEnd.insufficientMaterial:
        return 'draw, not enough pieces to mate';
      case ChessEnd.fiftyMoves:
        return 'draw by the 50-move rule';
      case ChessEnd.repetition:
        return 'draw by repetition';
      case ChessEnd.timeout:
        return 'lost on time';
    }
  }

  /// Result line as seen by [viewer]: "You won by checkmate",
  /// "Bob resigned", "Draw by stalemate".
  static String outcomeFor({
    required String viewer,
    required String otherName,
    required ChessEnd end,
    required String? winner,
    bool left = false,
  }) {
    if (winner == null) {
      final t = endText(end);
      return t[0].toUpperCase() + t.substring(1);
    }
    final iWon = winner == viewer;
    if (left) {
      return iWon
          ? '$otherName left the game. You win! 🎉'
          : 'You left the game.';
    }
    if (end == ChessEnd.resignation) {
      return iWon ? '$otherName resigned. You win! 🎉' : 'You resigned.';
    }
    if (end == ChessEnd.timeout) {
      return iWon
          ? '$otherName ran out of time in check. You win! 🎉'
          : 'You ran out of time in check.';
    }
    return iWon ? 'Checkmate! You win 🎉' : '$otherName wins by checkmate.';
  }

  static ChessEnd? endByName(Object? name) {
    for (final e in ChessEnd.values) {
      if (e.name == name) return e;
    }
    return null;
  }
}
