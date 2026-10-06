// lib/feature/games/chat_games/duel/duel_game.dart
//
// Two-player duels played shot by shot (Tennis Duel, Thumb War): both pick
// in secret, the second pick (or the 30 s timeout) moves the shot onto the
// history, and both phones replay the history to get the score. State lives
// in conversations/{convId}/games/{name}. Pure Dart.

import '../chat_game.dart';
import '../chat_game_logic.dart';

/// What makes one duel different from another.
abstract class DuelRules {
  /// Doc id under conversations/{convId}/games and metadata.game.
  String get name;
  String get emoji;
  String get title;
  String get tagline;

  /// Matches the rules' cap on stored shots.
  int get maxShots => 400;

  /// A valid stored pick, or null if [raw] isn't one.
  Object? parsePick(Object? raw);

  bool isOver(DuelGame game);

  ChatGameMessage invite();

  /// The result card for a finished game.
  ChatGameMessage result(DuelGame game);

  /// Result line on the chat card, as seen by [viewer].
  String resultLine(
    Map<String, dynamic> meta, {
    required String viewer,
    required String otherName,
  });
}

class DuelGame {
  final String gameId;
  final List<String> players;
  final String createdBy;

  /// 'playing', 'over' or 'cancelled'.
  final String status;

  /// Picks for the shot in play: {uid: pick}.
  final Map<String, Object> picks;

  /// Finished shots: {uid: pick}, a missing uid = timed out.
  final List<Map<String, Object>> history;

  /// Who resigned; a player who left (leftBy) counts as resigned.
  final String? resignedBy;

  /// Who left the game (or was away too long).
  final String? leftBy;
  final List<String> joined;

  /// When the current shot's 30 seconds started; null until both joined.
  final DateTime? turnStartedAt;

  const DuelGame({
    required this.gameId,
    required this.players,
    required this.createdBy,
    required this.status,
    required this.picks,
    required this.history,
    this.resignedBy,
    this.leftBy,
    this.joined = const [],
    this.turnStartedAt,
  });

  bool get isPlaying => status == 'playing';
  bool get bothJoined => players.every(joined.contains);

  DateTime? get deadline =>
      turnStartedAt?.add(const Duration(seconds: TurnClock.seconds));

  String otherOf(String uid) => uid == players[0] ? players[1] : players[0];

  DuelGame copyWith({
    String? status,
    Map<String, Object>? picks,
    List<Map<String, Object>>? history,
    String? resignedBy,
    String? leftBy,
  }) => DuelGame(
    gameId: gameId,
    players: players,
    createdBy: createdBy,
    status: status ?? this.status,
    picks: picks ?? this.picks,
    history: history ?? this.history,
    resignedBy: resignedBy ?? this.resignedBy,
    leftBy: leftBy ?? this.leftBy,
    joined: joined,
    turnStartedAt: turnStartedAt,
  );

  /// [data] with timestamps already converted to DateTime; invalid picks
  /// are dropped (they count as timed out).
  static DuelGame? fromMap(DuelRules rules, Map<String, dynamic>? data) {
    if (data == null) return null;
    final players = (data['players'] as List?)?.whereType<String>().toList();
    if (players == null || players.length != 2) return null;
    Map<String, Object> picksOf(Object? raw) => {
      if (raw is Map)
        for (final e in raw.entries)
          if (e.key is String && rules.parsePick(e.value) != null)
            e.key as String: rules.parsePick(e.value)!,
    };
    return DuelGame(
      gameId: (data['gameId'] as String?) ?? '',
      players: players,
      createdBy: (data['createdBy'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'playing',
      picks: picksOf(data['picks']),
      history: [
        for (final e in (data['history'] as List?) ?? const []) picksOf(e),
      ],
      resignedBy: data['resignedBy'] as String? ?? data['leftBy'] as String?,
      leftBy: data['leftBy'] as String?,
      joined: ((data['joined'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      turnStartedAt: data['turnStartedAt'] as DateTime?,
    );
  }
}
