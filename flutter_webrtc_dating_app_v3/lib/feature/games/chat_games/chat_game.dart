// lib/feature/games/chat_games/chat_game.dart
//
// Chat games: two matched users play a few rounds inside their chat. Each
// round both pick in secret, then the picks are revealed. State lives in
// conversations/{convId}/games/{kind}; firestore.rules checks every write.
// No Flutter or Firebase imports, so it can be unit tested on its own.

enum ChatGameKind {
  date('💌', 'Build Our Date', 'Plan a pretend date together, card by card.'),
  rate('🔢', 'Rate It', 'Rate 5 things from 1 to 10 and compare tastes.'),
  flags('🚩', 'Red Flag, Green Flag', 'Vote on 5 dating habits: red or green?'),
  telepathy(
    '🧠',
    'Telepathy',
    'Pick the emojis your match will pick. Sync minds!',
  );

  const ChatGameKind(this.emoji, this.title, this.tagline);

  final String emoji;
  final String title;
  final String tagline;

  static ChatGameKind? byName(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// Every turn (chess) or round (the other games) lasts this long; then the
/// turn passes. firestore.rules uses the same 30 seconds.
class TurnClock {
  TurnClock._();

  static const int seconds = 30;

  /// After this long without the overdue player acting, the other player
  /// may end the game as left (firestore.rules gameStale).
  static const int staleSeconds = 60;

  /// Seconds left before [deadline], never negative; null if no clock.
  static int? secondsLeft(DateTime? deadline, DateTime now) {
    if (deadline == null) return null;
    final left = deadline.difference(now).inMilliseconds;
    return left <= 0 ? 0 : (left / 1000).ceil();
  }
}

class ChatGame {
  /// Every chat game has this many rounds (the rules expect r0..r4).
  static const int roundCount = 5;

  final ChatGameKind kind;
  final String gameId;
  final List<String> players;
  final String createdBy;
  final bool cancelled;
  final int round;

  /// deck[r] = what round r is about: 4 card ids (date), 1 item id
  /// (rate, flags) or a prompt id + 9 emojis (telepathy).
  final List<List<String>> deck;

  /// picks[r] = {uid: value}. A card id (date), 1..10 (rate),
  /// 'red' / 'green' (flags) or a list of 3 emojis (telepathy).
  final List<Map<String, Object>> picks;

  /// Players who opened the game. Rounds start once both joined.
  final List<String> joined;

  /// When the current round's 30 seconds started; null until both joined.
  final DateTime? roundStartedAt;

  /// Who left (or was away too long); set when that ended the game.
  final String? leftBy;

  const ChatGame({
    required this.kind,
    required this.gameId,
    required this.players,
    required this.createdBy,
    required this.cancelled,
    required this.round,
    required this.deck,
    required this.picks,
    this.joined = const [],
    this.roundStartedAt,
    this.leftBy,
  });

  bool get bothJoined => players.every(joined.contains);

  /// When the current round times out; null while the clock isn't running.
  DateTime? get deadline =>
      roundStartedAt?.add(const Duration(seconds: TurnClock.seconds));

  bool get isDone => !cancelled && round >= roundCount;
  bool get isActive => !cancelled && round < roundCount;

  Map<String, Object> picksFor(int r) =>
      r >= 0 && r < picks.length ? picks[r] : const {};

  Object? pickOf(int r, String uid) => picksFor(r)[uid];

  bool bothPicked(int r) => players.every(picksFor(r).containsKey);

  /// The other player's uid.
  String otherOf(String uid) => players.firstWhere(
    (p) => p != uid,
    orElse: () => players.isEmpty ? '' : players.last,
  );

  static String roundKey(int round) => 'r$round';

  /// [data] with timestamps already converted to DateTime.
  static ChatGame? fromMap(ChatGameKind kind, Map<String, dynamic>? data) {
    if (data == null) return null;
    final players = (data['players'] as List?)?.whereType<String>().toList();
    final deckMap = data['deck'];
    if (players == null || players.length != 2 || deckMap is! Map) return null;
    final rawPicks = data['picks'] is Map ? data['picks'] as Map : const {};
    return ChatGame(
      kind: kind,
      gameId: (data['gameId'] as String?) ?? '',
      players: players,
      createdBy: (data['createdBy'] as String?) ?? '',
      cancelled: data['status'] == 'cancelled',
      round: (data['round'] as num?)?.toInt() ?? 0,
      deck: [
        for (var r = 0; r < roundCount; r++)
          ((deckMap[roundKey(r)] as List?) ?? const [])
              .whereType<String>()
              .toList(),
      ],
      picks: [
        for (var r = 0; r < roundCount; r++)
          {
            for (final e
                in ((rawPicks[roundKey(r)] as Map?) ?? const {}).entries)
              if (e.key is String && (e.value is String || e.value is int))
                e.key as String: e.value as Object
              else if (e.key is String && e.value is List)
                e.key as String: (e.value as List).whereType<String>().toList(),
          },
      ],
      joined: ((data['joined'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      roundStartedAt: data['roundStartedAt'] as DateTime?,
      leftBy: data['leftBy'] as String?,
    );
  }
}
