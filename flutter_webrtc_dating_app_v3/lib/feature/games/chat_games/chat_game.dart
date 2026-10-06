// lib/feature/games/chat_games/chat_game.dart
//
// Chat games: two matched users play a few rounds inside their chat. Each
// round both pick in secret, then the picks are revealed. State lives in
// conversations/{convId}/games/{kind}; firestore.rules checks every write.
// No Flutter or Firebase imports, so it can be unit tested on its own.

enum ChatGameKind {
  date(
    '💌',
    'Build Our Date',
    'Answer 10 date questions in secret and see how well you match.',
    10,
  ),
  rate('🔢', 'Rate It', 'Rate 10 things from 1 to 10 and compare tastes.', 10),
  flags('🚩', 'Red Flag, Green Flag', 'Vote on 5 dating habits: red or green?'),
  telepathy(
    '🧠',
    'Telepathy',
    'Pick the emojis your match will pick. Sync minds!',
  );

  const ChatGameKind(this.emoji, this.title, this.tagline, [this.rounds = 5]);

  final String emoji;
  final String title;
  final String tagline;

  /// Rounds per game; the rules expect deck keys r0..r(rounds - 1).
  final int rounds;

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
  final ChatGameKind kind;
  final String gameId;
  final List<String> players;
  final String createdBy;
  final bool cancelled;
  final int round;

  /// deck[r] = what round r is about: 1 question / item id (date, rate,
  /// flags) or a prompt id + 9 emojis (telepathy).
  final List<List<String>> deck;

  /// picks[r] = {uid: value}. An option index 0..3 (date), 1..10 (rate),
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

  int get rounds => kind.rounds;

  bool get isDone => !cancelled && round >= rounds;
  bool get isActive => !cancelled && round < rounds;

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

  /// [deck] has exactly one entry per round of [kind], each the right size.
  static bool hasCurrentShape(ChatGameKind kind, Map<dynamic, dynamic> deck) {
    if (deck.length != kind.rounds) return false;
    for (var r = 0; r < kind.rounds; r++) {
      final round = deck[roundKey(r)];
      if (round is! List || round.length != deckRoundSize(kind)) return false;
    }
    return true;
  }

  /// Entries per deck round; firestore.rules gameRoundOk checks the same.
  static int deckRoundSize(ChatGameKind kind) =>
      kind == ChatGameKind.telepathy ? 10 : 1;

  /// [data] with timestamps already converted to DateTime.
  static ChatGame? fromMap(ChatGameKind kind, Map<String, dynamic>? data) {
    if (data == null) return null;
    final players = (data['players'] as List?)?.whereType<String>().toList();
    final deckMap = data['deck'];
    if (players == null || players.length != 2 || deckMap is! Map) return null;
    final rawPicks = data['picks'] is Map ? data['picks'] as Map : const {};
    final roundCount = kind.rounds;
    return ChatGame(
      kind: kind,
      gameId: (data['gameId'] as String?) ?? '',
      players: players,
      createdBy: (data['createdBy'] as String?) ?? '',
      // A game saved before its kind changed round count reads as ended.
      cancelled:
          data['status'] == 'cancelled' || !hasCurrentShape(kind, deckMap),
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
