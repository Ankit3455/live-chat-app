// lib/feature/games/chat_games/thumb_war/thumb_war.dart
//
// Thumb War, played live: one button per player, 60 ticks a second.
//  - Press while both are up: your thumb goes down (taunt). Their stamina
//    drains, yours refills.
//  - Press while they're down: you pin them. Every tick they lose HP and you
//    lose stamina. Run dry mid-pin and it flips: you're the one down, and
//    they're back to full stamina.
//  - Let go: back to neutral, both refill.
// 100 HP per round, first to 2 rounds wins. Each finished round is one
// history entry {uid: winner index}. Pure Dart.

import 'dart:math';

/// Who is doing what. L = players[0], R = players[1].
enum FightState {
  idle,
  downL,
  downR,
  pinL,
  pinR,
  winL,
  winR;

  static FightState byName(Object? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return idle;
  }

  /// The player whose thumb is down (taunting), or null.
  int? get down => this == downL ? 0 : (this == downR ? 1 : null);

  /// The player pinning the other, or null.
  int? get pinner => this == pinL ? 0 : (this == pinR ? 1 : null);

  /// The round winner, or null.
  int? get winner => this == winL ? 0 : (this == winR ? 1 : null);
}

/// What a round looks like right now: 'intro' (ROUND n / FIGHT!), 'fight',
/// 'ko' (round just ended) or 'over' (match decided).
enum FightPhase {
  intro,
  fight,
  ko,
  over;

  static FightPhase byName(Object? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return intro;
  }
}

class ThumbWar {
  ThumbWar._();

  static const double maxHp = 100;
  static const double maxStamina = 100;

  /// HP the pinned player loses per tick.
  static const double attack = 1.45;

  /// Stamina the pinner spends per tick.
  static const double pinCost = 3;

  /// Stamina the taunted player loses / the taunter gains per tick.
  static const double tauntDrain = 0.5;
  static const double tauntGain = 1;

  /// Stamina both regain per tick while both thumbs are up.
  static const double idleGain = 0.5;

  static const int roundsToWin = 2;
  static const int ticksPerSecond = 60;

  /// Intro ("ROUND n" then "FIGHT!") and KO pauses, in ticks.
  static const int introTicks = 114;
  static const int fightCallTick = 66;
  static const int koTicks = 132;

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
}

/// The fight simulation. The host phone runs [step] 60 times a second and
/// shares [toMap]; the other phone only shows it.
class ThumbFight {
  FightState state = FightState.idle;
  FightPhase phase = FightPhase.intro;
  final List<double> hp = [ThumbWar.maxHp, ThumbWar.maxHp];
  final List<double> stamina = [ThumbWar.maxStamina, ThumbWar.maxStamina];

  /// Round winners so far (player indexes), in order.
  final List<int> roundWinners = [];

  /// Ticks spent in the current phase.
  int phaseTicks = 0;

  /// Counts every pin that starts, so a pin is heard once on both phones.
  int pins = 0;

  /// Button held, per player; [step] reacts to presses and releases.
  final List<bool> input = [false, false];
  final List<bool> _held = [false, false];

  ThumbFight();

  int roundsOf(int p) => roundWinners.where((w) => w == p).length;
  int get round => roundWinners.length + 1;
  bool get isFinalRound => roundsOf(0) == 1 && roundsOf(1) == 1;
  int? get matchWinner {
    for (final p in const [0, 1]) {
      if (roundsOf(p) >= ThumbWar.roundsToWin) return p;
    }
    return null;
  }

  /// One tick of game logic.
  void step() {
    phaseTicks++;
    switch (phase) {
      case FightPhase.intro:
        _held.setAll(0, input);
        if (phaseTicks >= ThumbWar.introTicks) _enter(FightPhase.fight);
        return;
      case FightPhase.ko:
        if (phaseTicks >= ThumbWar.koTicks) _nextRound();
        return;
      case FightPhase.over:
        return;
      case FightPhase.fight:
        break;
    }

    for (final p in const [0, 1]) {
      final pressed = input[p] && !_held[p];
      final released = !input[p] && _held[p];
      if (pressed && hp[p] > 0) {
        if (state == FightState.idle) {
          state = p == 0 ? FightState.downL : FightState.downR;
        } else if (state.down == 1 - p) {
          state = p == 0 ? FightState.pinL : FightState.pinR;
          pins++;
        }
      }
      if (released && (state.down == p || state.pinner == p)) {
        state = FightState.idle;
      }
    }
    _held.setAll(0, input);

    final down = state.down;
    final pinner = state.pinner;
    if (state == FightState.idle) {
      for (final p in const [0, 1]) {
        stamina[p] += ThumbWar.idleGain;
      }
    } else if (down != null) {
      stamina[1 - down] -= ThumbWar.tauntDrain;
      stamina[down] += ThumbWar.tauntGain;
    } else if (pinner != null) {
      final other = 1 - pinner;
      if (stamina[pinner] > 0) {
        stamina[pinner] -= ThumbWar.pinCost;
        hp[other] -= ThumbWar.attack;
      } else {
        // Ran dry: the pinner is now the one down, the other at full stamina.
        state = pinner == 0 ? FightState.downL : FightState.downR;
        stamina[other] = ThumbWar.maxStamina;
      }
    }
    for (final p in const [0, 1]) {
      stamina[p] = stamina[p].clamp(0, ThumbWar.maxStamina).toDouble();
    }

    for (final p in const [0, 1]) {
      if (hp[p] <= 0) {
        hp[p] = 0;
        final w = 1 - p;
        roundWinners.add(w);
        state = w == 0 ? FightState.winL : FightState.winR;
        _enter(matchWinner == null ? FightPhase.ko : FightPhase.over);
        return;
      }
    }
  }

  void _enter(FightPhase next) {
    phase = next;
    phaseTicks = 0;
  }

  void _nextRound() {
    state = FightState.idle;
    hp.setAll(0, [ThumbWar.maxHp, ThumbWar.maxHp]);
    stamina.setAll(0, [ThumbWar.maxStamina, ThumbWar.maxStamina]);
    _enter(FightPhase.intro);
  }

  /// Shared form, written by the host. Numbers rounded to keep it small.
  Map<String, Object> toMap() => {
        'st': state.name,
        'ph': phase.name,
        't': phaseTicks,
        'hp': [_r(hp[0]), _r(hp[1])],
        'sta': [_r(stamina[0]), _r(stamina[1])],
        'rw': List<int>.of(roundWinners),
        'pins': pins,
      };

  static double _r(double v) => (v * 10).roundToDouble() / 10;

  /// The host's state as read on the other phone; null if malformed.
  static ThumbFight? fromMap(Object? raw) {
    if (raw is! Map) return null;
    List<double>? pair(Object? v) {
      if (v is! List || v.length != 2) return null;
      final a = v[0], b = v[1];
      if (a is! num || b is! num) return null;
      return [a.toDouble(), b.toDouble()];
    }

    final hp = pair(raw['hp']);
    final sta = pair(raw['sta']);
    if (hp == null || sta == null) return null;
    final f = ThumbFight()
      ..state = FightState.byName(raw['st'])
      ..phase = FightPhase.byName(raw['ph'])
      ..phaseTicks = (raw['t'] as num?)?.toInt() ?? 0
      ..pins = (raw['pins'] as num?)?.toInt() ?? 0;
    f.hp.setAll(0, hp);
    f.stamina.setAll(0, sta);
    final rw = raw['rw'];
    if (rw is List) {
      f.roundWinners.addAll(rw.whereType<num>().map((n) => n.toInt()));
    }
    return f;
  }
}

/// A bot for practice: flips its button every 0.2–1.8 s, like the original.
class ThumbBot {
  ThumbBot([Random? random]) : _random = random ?? Random();

  final Random _random;
  int _nextFlip = 0;
  int _tick = 0;

  /// Call once per tick for player [p] of [fight].
  void drive(ThumbFight fight, int p) {
    _tick++;
    if (fight.phase != FightPhase.fight) return;
    if (_tick >= _nextFlip) {
      fight.input[p] = !fight.input[p];
      _nextFlip = _tick + 12 + _random.nextInt(97);
    }
  }
}

/// The match score from the stored history: each entry is one round,
/// {uid: winner index}. players[0] (the host) decides; the other entry is
/// only used if the host's is missing.
class ThumbReplay {
  final List<String> players;
  final List<int> roundWinners;
  final int? winner;
  final bool byResignation;

  const ThumbReplay({
    required this.players,
    required this.roundWinners,
    required this.winner,
    required this.byResignation,
  });

  bool get isOver => winner != null;
  int roundsOf(int p) => roundWinners.where((w) => w == p).length;
  List<int> get rounds => [roundsOf(0), roundsOf(1)];
  int indexOf(String uid) => players.indexOf(uid);

  static ThumbReplay of(
    List<String> players,
    List<Map<String, Object>> history, {
    String? resignedBy,
  }) {
    final winners = <int>[];
    int? winner;
    for (final entry in history) {
      if (winner != null) break;
      final w = entry[players[0]] ?? entry[players[1]];
      if (w is! int || (w != 0 && w != 1)) continue;
      winners.add(w);
      if (winners.where((x) => x == w).length >= ThumbWar.roundsToWin) {
        winner = w;
      }
    }
    var resigned = false;
    if (winner == null && resignedBy != null && players.contains(resignedBy)) {
      winner = 1 - players.indexOf(resignedBy);
      resigned = true;
    }
    return ThumbReplay(
      players: players,
      roundWinners: winners,
      winner: winner,
      byResignation: resigned,
    );
  }
}
