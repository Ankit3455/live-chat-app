// lib/feature/games/chat_games/thumb_war/thumb_war.dart
//
// Thumb War: each clash both players pick a move in secret and stop a grip
// meter (power 0..100). Pounce beats Feint, Feint beats Guard, Guard beats
// Pounce; the same move goes to the stronger grip. The winner hits for
// 15..35. Not picking in time = pinned for 25. 100 HP per round, first to
// 2 rounds wins. Pure Dart.

enum ThumbMove {
  pounce('⚡', 'Pounce'),
  guard('🛡️', 'Guard'),
  feint('🌀', 'Feint');

  const ThumbMove(this.emoji, this.label);

  final String emoji;
  final String label;

  /// The move this one beats.
  ThumbMove get beats {
    switch (this) {
      case ThumbMove.pounce:
        return ThumbMove.feint;
      case ThumbMove.feint:
        return ThumbMove.guard;
      case ThumbMove.guard:
        return ThumbMove.pounce;
    }
  }

  static ThumbMove? byName(Object? name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

class ThumbPick {
  final ThumbMove move;

  /// Grip meter, 0..100 (100 = stopped dead centre).
  final int power;

  const ThumbPick(this.move, this.power);

  /// Stored form: {'m': 'pounce', 'p': 72}.
  Map<String, Object> toMap() => {'m': move.name, 'p': power};

  static ThumbPick? parse(Object? raw) {
    if (raw is! Map || raw.length != 2) return null;
    final move = ThumbMove.byName(raw['m']);
    final power = raw['p'];
    if (move == null || power is! int || power < 0 || power > 100) return null;
    return ThumbPick(move, power);
  }
}

class ThumbClash {
  /// Picks by player index; null = timed out.
  final List<ThumbPick?> picks;

  /// Player index that landed the hit, or null (no damage).
  final int? winner;
  final int damage;

  /// Set when this clash knocked the loser out and ended the round.
  final bool endedRound;

  const ThumbClash(this.picks, this.winner, this.damage, this.endedRound);

  bool get sameMove =>
      picks[0] != null && picks[1] != null && picks[0]!.move == picks[1]!.move;

  bool get timeout => picks[0] == null || picks[1] == null;
}

class ThumbWar {
  ThumbWar._();

  static const int maxHp = 100;
  static const int roundsToWin = 2;
  static const int pinDamage = 25;

  static const List<String> accessories = ['👑', '🎩', '🧢', '🎀', '🕶️', '🤠'];

  /// FNV-1a so both phones agree.
  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final u in s.codeUnits) {
      h = ((h ^ u) * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// A fixed accessory per player, never the same for both.
  static List<String> accessoriesFor(List<String> players) {
    final a = _hash(players[0]) % accessories.length;
    var b = _hash(players[1]) % accessories.length;
    if (b == a) b = (b + 1) % accessories.length;
    return [accessories[a], accessories[b]];
  }

  /// Resolves one clash: (winner index or null, damage).
  static (int?, int) resolve(ThumbPick? a, ThumbPick? b) {
    if (a == null && b == null) return (null, 0);
    if (a == null) return (1, pinDamage);
    if (b == null) return (0, pinDamage);
    if (a.move != b.move) {
      final w = a.move.beats == b.move ? 0 : 1;
      final power = w == 0 ? a.power : b.power;
      return (w, 15 + power ~/ 5);
    }
    if (a.power == b.power) return (null, 0);
    final w = a.power > b.power ? 0 : 1;
    return (w, 10 + (a.power - b.power).abs() ~/ 5);
  }
}

class ThumbReplay {
  final List<String> players;
  final List<ThumbClash> clashes;
  final List<int> hp;
  final List<int> rounds;
  final int? winner;
  final bool byResignation;

  const ThumbReplay({
    required this.players,
    required this.clashes,
    required this.hp,
    required this.rounds,
    required this.winner,
    required this.byResignation,
  });

  bool get isOver => winner != null;
  int get round => rounds[0] + rounds[1] + 1;
  ThumbClash? get lastClash => clashes.isEmpty ? null : clashes.last;
  int indexOf(String uid) => players.indexOf(uid);

  /// [history] entries are {uid: pick}; a missing or invalid pick = timed out.
  static ThumbReplay of(
    List<String> players,
    List<Map<String, Object>> history, {
    String? resignedBy,
  }) {
    final hp = [ThumbWar.maxHp, ThumbWar.maxHp];
    final rounds = [0, 0];
    final clashes = <ThumbClash>[];
    int? winner;

    for (final entry in history) {
      if (winner != null) break;
      final picks = [
        ThumbPick.parse(entry[players[0]]),
        ThumbPick.parse(entry[players[1]]),
      ];
      final (w, damage) = ThumbWar.resolve(picks[0], picks[1]);
      var ended = false;
      if (w != null) {
        final loser = 1 - w;
        hp[loser] = (hp[loser] - damage).clamp(0, ThumbWar.maxHp);
        if (hp[loser] == 0) {
          ended = true;
          rounds[w]++;
          hp[0] = ThumbWar.maxHp;
          hp[1] = ThumbWar.maxHp;
          if (rounds[w] >= ThumbWar.roundsToWin) winner = w;
        }
      }
      clashes.add(ThumbClash(picks, w, w == null ? 0 : damage, ended));
    }

    var resigned = false;
    if (winner == null && resignedBy != null && players.contains(resignedBy)) {
      winner = 1 - players.indexOf(resignedBy);
      resigned = true;
    }
    return ThumbReplay(
      players: players,
      clashes: clashes,
      hp: hp,
      rounds: rounds,
      winner: winner,
      byResignation: resigned,
    );
  }
}
