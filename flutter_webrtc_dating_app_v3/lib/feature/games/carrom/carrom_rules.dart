// Pure Carrom rules (DECISIONS.md DEST-006). No Flutter/Firebase imports so it
// can be unit tested and later reused by a server-side validator.
import 'dart:math' as math;

/// Playing surface in centimetres (ICF 74 cm square), origin top-left. The
/// physics, rendering and sync all use these units.
const double kBoardSize = 74.0;

/// Pocket circle (Ø4.45 cm) touching both rails.
const double kPocketRadius = 2.225;
const double kCoinRadius = 1.59;
const double kQueenRadius = 1.59;
const double kStrikerRadius = 2.065;

/// Baselines: 47 cm long, outer line 10.15 cm from the rail, 3.18 cm wide.
const double kBaselineLength = 47.0;
const double kBaselineOuter = 10.15;
const double kBaselineWidth = 3.18;

/// Distance of the striker's centre line from its own rail.
const double kBaselineInset = kBaselineOuter + kBaselineWidth / 2;
const double kBaselineMinX =
    kBoardSize / 2 - (kBaselineLength / 2 - kBaselineWidth / 2);
const double kBaselineMaxX =
    kBoardSize / 2 + (kBaselineLength / 2 - kBaselineWidth / 2);

const int kCoinsPerColour = 9;
const int kQueenPoints = 3;

const String kQueenId = 'q';
const String kWhite = 'white';
const String kBlack = 'black';

/// Marks a boardState stored in centimetres (older boards used 40 units).
const String kBoardUnits = 'cm';

const String kFoulStriker = 'striker_pocketed';
const String kFoulOwnLast = 'own_last_before_queen';
const String kFoulOpponentLast = 'opponent_last_coin';

double baselineY({required bool hostSide}) =>
    hostSide ? kBoardSize - kBaselineInset : kBaselineInset;

const List<CarromPos> kPockets = [
  CarromPos(kPocketRadius, kPocketRadius),
  CarromPos(kBoardSize - kPocketRadius, kPocketRadius),
  CarromPos(kPocketRadius, kBoardSize - kPocketRadius),
  CarromPos(kBoardSize - kPocketRadius, kBoardSize - kPocketRadius),
];

const CarromPos kBoardCentre = CarromPos(kBoardSize / 2, kBoardSize / 2);

String? colourOfCoin(String id) {
  if (id.startsWith('w')) return kWhite;
  if (id.startsWith('b')) return kBlack;
  return null;
}

double radiusOfCoin(String id) => id == kQueenId ? kQueenRadius : kCoinRadius;

class CarromPos {
  final double x;
  final double y;
  const CarromPos(this.x, this.y);

  double distanceTo(CarromPos o) {
    final dx = x - o.x;
    final dy = y - o.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  Map<String, double> toMap() => {'x': x, 'y': y};

  static CarromPos fromMap(dynamic m) {
    final map = Map<String, dynamic>.from(m as Map);
    return CarromPos(
      ((map['x'] ?? 0) as num).toDouble(),
      ((map['y'] ?? 0) as num).toDouble(),
    );
  }
}

/// Synced board state. Stored in `carrom_matches/{id}.boardState`.
class CarromState {
  /// Coins still on the board.
  final Map<String, CarromPos> coins;

  /// Penalty coins a player owes but had none pocketed to return yet. Paid
  /// automatically as soon as they have one. Each counts -1 point meanwhile.
  final Map<String, int> due;

  /// Uid that pocketed the queen and still has to cover it on the next shot.
  final String? queenPendingBy;

  /// Uid that covered the queen (gets [kQueenPoints]).
  final String? queenCoveredBy;

  const CarromState({
    required this.coins,
    this.due = const {},
    this.queenPendingBy,
    this.queenCoveredBy,
  });

  /// Standard rosette: queen in the centre, a touching ring of 6 and a ring of
  /// 12 around it, colours alternating. Built from multiples of 30° with sqrt
  /// only (no sin/cos) so every platform gets bit-identical positions, which
  /// shot replays depend on.
  factory CarromState.initial() {
    const c = kBoardCentre;
    const gap = 0.02;
    const inner = 2 * kCoinRadius + gap;
    const outer = 2 * inner;
    final h = math.sqrt(3) / 2;
    // cos/sin of 90° + k·30°.
    final unit = <List<double>>[
      [0, 1], [-0.5, h], [-h, 0.5], [-1, 0], [-h, -0.5], [-0.5, -h], //
      [0, -1], [0.5, -h], [h, -0.5], [1, 0], [h, 0.5], [0.5, h],
    ];
    final coins = <String, CarromPos>{kQueenId: c};
    var w = 0;
    var b = 0;
    void ring(int count, double radius) {
      for (int i = 0; i < count; i++) {
        final u = unit[i * (12 ~/ count)];
        final p = CarromPos(c.x + u[0] * radius, c.y + u[1] * radius);
        if (i.isEven) {
          coins['w${w++}'] = p;
        } else {
          coins['b${b++}'] = p;
        }
      }
    }

    ring(6, inner);
    ring(12, outer);
    return CarromState(coins: coins);
  }

  /// Returns [CarromState.initial] for a missing board. Boards saved before
  /// the centimetre units (no `units`) are rescaled; the legacy `penalties`
  /// field is read as [due].
  factory CarromState.fromMap(Map<String, dynamic>? map) {
    if (map == null || map['coins'] == null) return CarromState.initial();
    final legacy = map['units'] != kBoardUnits;
    final coins = <String, CarromPos>{};
    Map<String, dynamic>.from(map['coins'] as Map).forEach((k, v) {
      final p = CarromPos.fromMap(v);
      coins[k] = legacy ? _fromLegacyUnits(p, radiusOfCoin(k)) : p;
    });
    final due = <String, int>{};
    final rawDue = map['due'] ?? map['penalties'] ?? const {};
    Map<String, dynamic>.from(rawDue as Map).forEach((k, v) {
      due[k] = (v as num).toInt();
    });
    return CarromState(
      coins: coins,
      due: due,
      queenPendingBy: map['queenPendingBy'] as String?,
      queenCoveredBy: map['queenCoveredBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'units': kBoardUnits,
        'coins': coins.map((k, v) => MapEntry(k, v.toMap())),
        'due': due,
        // Same numbers under the old name so older clients still score.
        'penalties': due,
        'queenPendingBy': queenPendingBy,
        'queenCoveredBy': queenCoveredBy,
        'remaining': coins.length,
      };

  int onBoard(String colour) =>
      coins.keys.where((id) => colourOfCoin(id) == colour).length;

  bool get queenResolved => queenCoveredBy != null;

  int scoreFor(String uid, String colour) {
    final pocketed = kCoinsPerColour - onBoard(colour);
    final queen = queenCoveredBy == uid ? kQueenPoints : 0;
    return math.max(0, pocketed + queen - (due[uid] ?? 0));
  }
}

/// Old boards: 40-unit square with a 2.5 frame, 35-unit surface.
CarromPos _fromLegacyUnits(CarromPos p, double r) {
  const scale = kBoardSize / 35.0;
  double conv(double v) =>
      ((v - 2.5) * scale).clamp(r, kBoardSize - r).toDouble();
  return CarromPos(conv(p.x), conv(p.y));
}

class ShotOutcome {
  final CarromState state;
  final bool keepsTurn;

  /// [kFoulStriker], [kFoulOwnLast], [kFoulOpponentLast].
  final List<String> fouls;
  final List<String> returnedToCentre;
  final Map<String, int> scores;
  final String? winnerUid;

  const ShotOutcome({
    required this.state,
    required this.keepsTurn,
    required this.fouls,
    required this.returnedToCentre,
    required this.scores,
    this.winnerUid,
  });

  bool get foul => fouls.isNotEmpty;
}

/// Host plays white, guest plays black.
class CarromPlayers {
  final String whiteUid;
  final String blackUid;
  const CarromPlayers({required this.whiteUid, required this.blackUid});

  String colourOf(String uid) => uid == whiteUid ? kWhite : kBlack;
  String ownerOf(String colour) => colour == kWhite ? whiteUid : blackUid;
  String other(String uid) => uid == whiteUid ? blackUid : whiteUid;

  Map<String, int> scores(CarromState s) => {
        whiteUid: s.scoreFor(whiteUid, kWhite),
        blackUid: s.scoreFor(blackUid, kBlack),
      };
}

/// Applies DEST-006 (with ICF fouls) to the result of one shot.
///
/// [before] is the synced state the shot started from, [coinsAfter] the coins
/// left on the board once everything stopped, [pocketed] the ids that fell in.
///
/// Fouls (striker pocketed, own last coin before the queen is covered, the
/// opponent's last coin): the turn passes, every coin of the shooter pocketed
/// this stroke returns, the opponent's coins return if their last one fell,
/// a queen pocketed or pending this stroke returns, and the shooter pays one
/// penalty coin (or owes it in [CarromState.due]).
ShotOutcome resolveShot({
  required CarromState before,
  required Map<String, CarromPos> coinsAfter,
  required List<String> pocketed,
  required bool strikerPocketed,
  required String shooterUid,
  required CarromPlayers players,
}) {
  final opponentUid = players.other(shooterUid);
  final ownColour = players.colourOf(shooterUid);
  final oppColour = players.colourOf(opponentUid);
  final ownPocketed =
      pocketed.where((id) => colourOfCoin(id) == ownColour).toList();
  final oppPocketed =
      pocketed.where((id) => colourOfCoin(id) == oppColour).toList();
  final queenPocketed = pocketed.contains(kQueenId);

  final coins = Map<String, CarromPos>.from(coinsAfter);
  final due = Map<String, int>.from(before.due);
  String? pending = before.queenPendingBy;
  String? covered = before.queenCoveredBy;
  final returned = <String>[];

  int left(String colour) =>
      coins.keys.where((id) => colourOfCoin(id) == colour).length;

  void returnToCentre(String id) {
    if (coins.containsKey(id)) return;
    coins[id] = freeSpotNearCentre(coins, radiusOfCoin(id));
    returned.add(id);
  }

  final coversNow = covered == null &&
      (queenPocketed || pending == shooterUid) &&
      ownPocketed.isNotEmpty;
  final fouls = <String>[
    if (strikerPocketed) kFoulStriker,
    if (ownPocketed.isNotEmpty &&
        left(ownColour) == 0 &&
        covered == null &&
        !coversNow)
      kFoulOwnLast,
    if (oppPocketed.isNotEmpty && left(oppColour) == 0) kFoulOpponentLast,
  ];

  bool keepsTurn;
  if (fouls.isNotEmpty) {
    keepsTurn = false;
    if (queenPocketed || pending == shooterUid) {
      pending = null;
      returnToCentre(kQueenId);
    }
    ownPocketed.forEach(returnToCentre);
    if (fouls.contains(kFoulOpponentLast)) oppPocketed.forEach(returnToCentre);
    final missing = _missingIds(coins, ownColour);
    if (missing.isNotEmpty) {
      returnToCentre(missing.first);
    } else {
      due[shooterUid] = (due[shooterUid] ?? 0) + 1;
    }
  } else {
    if (pending == shooterUid) {
      pending = null;
      if (ownPocketed.isEmpty) returnToCentre(kQueenId);
    }
    if (coversNow) {
      covered = shooterUid;
    } else if (queenPocketed) {
      pending = shooterUid;
    }
    keepsTurn = ownPocketed.isNotEmpty || queenPocketed;
  }

  // Owed penalty coins come back as soon as the player has one pocketed.
  for (final uid in [shooterUid, opponentUid]) {
    var owed = due[uid] ?? 0;
    while (owed > 0) {
      final missing = _missingIds(coins, players.colourOf(uid));
      if (missing.isEmpty) break;
      returnToCentre(missing.first);
      owed--;
    }
    if (owed > 0) {
      due[uid] = owed;
    } else {
      due.remove(uid);
    }
  }

  final state = CarromState(
    coins: coins,
    due: due,
    queenPendingBy: pending,
    queenCoveredBy: covered,
  );

  // Only the shooter can win on their own stroke; clearing the opponent's
  // last coin is a foul above, never a win for them.
  final winner =
      fouls.isEmpty && state.queenResolved && state.onBoard(ownColour) == 0
          ? shooterUid
          : null;

  return ShotOutcome(
    state: state,
    keepsTurn: winner == null && keepsTurn,
    fouls: fouls,
    returnedToCentre: returned,
    scores: players.scores(state),
    winnerUid: winner,
  );
}

/// A turn ran out: a pending queen goes back to the centre.
CarromState resolveTimeout(CarromState s, String timedOutUid) {
  if (s.queenPendingBy != timedOutUid) return s;
  final coins = Map<String, CarromPos>.from(s.coins);
  coins[kQueenId] = freeSpotNearCentre(coins, kQueenRadius);
  return CarromState(
    coins: coins,
    due: s.due,
    queenCoveredBy: s.queenCoveredBy,
  );
}

List<String> _missingIds(Map<String, CarromPos> coins, String colour) {
  final prefix = colour == kWhite ? 'w' : 'b';
  return [
    for (int i = 0; i < kCoinsPerColour; i++)
      if (!coins.containsKey('$prefix$i')) '$prefix$i',
  ];
}

/// Closest free position to the centre for a returned coin.
CarromPos freeSpotNearCentre(Map<String, CarromPos> coins, double radius) {
  const c = kBoardCentre;
  bool free(CarromPos p) => coins.entries.every(
        (e) => e.value.distanceTo(p) >= radius + radiusOfCoin(e.key) + 0.05,
      );
  if (free(c)) return c;
  for (double ring = 1.0; ring <= 30; ring += 0.8) {
    final steps = math.max(12, (ring * 4).round());
    for (int i = 0; i < steps; i++) {
      final a = i / steps * math.pi * 2;
      final p = CarromPos(c.x + math.cos(a) * ring, c.y + math.sin(a) * ring);
      if (free(p)) return p;
    }
  }
  return c;
}

/// True if a striker centred at [p] overlaps no coin.
bool strikerSpotFree(Map<String, CarromPos> coins, CarromPos p) =>
    coins.entries.every(
      (e) => e.value.distanceTo(p) >= kStrikerRadius + radiusOfCoin(e.key),
    );

/// Nearest free striker spot on a baseline to [x] (centre if null).
CarromPos strikerSpot(
  Map<String, CarromPos> coins, {
  required bool hostSide,
  double? x,
}) {
  final y = baselineY(hostSide: hostSide);
  final start =
      (x ?? kBoardSize / 2).clamp(kBaselineMinX, kBaselineMaxX).toDouble();
  for (double off = 0; off <= kBaselineMaxX - kBaselineMinX; off += 0.25) {
    for (final cx in [start + off, start - off]) {
      if (cx < kBaselineMinX || cx > kBaselineMaxX) continue;
      final p = CarromPos(cx, y);
      if (strikerSpotFree(coins, p)) return p;
    }
  }
  return CarromPos(start, y);
}
