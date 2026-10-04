// Pure Carrom rules (DECISIONS.md DEST-006). No Flutter/Firebase imports so it
// can be unit tested and later reused by a server-side validator.
import 'dart:math' as math;

/// Fixed logical board, shared by physics, rendering and sync on every device.
const double kBoardSize = 40.0;
const double kBoardMargin = 2.5;
const double kPocketRadius = 2.8;
const double kCoinRadius = 1.0;
const double kQueenRadius = 1.2;
const double kStrikerRadius = 1.6;

/// Distance of each baseline from the inner edge of the playing surface.
const double kBaselineInset = 7.0;
const double kBaselineMinX = kBoardMargin + 4.0;
const double kBaselineMaxX = kBoardSize - kBoardMargin - 4.0;

const int kCoinsPerColour = 9;
const int kQueenPoints = 3;

const String kQueenId = 'q';
const String kWhite = 'white';
const String kBlack = 'black';

double baselineY({required bool hostSide}) => hostSide
    ? kBoardSize - kBoardMargin - kBaselineInset
    : kBoardMargin + kBaselineInset;

const List<CarromPos> kPockets = [
  CarromPos(kBoardMargin, kBoardMargin),
  CarromPos(kBoardSize - kBoardMargin, kBoardMargin),
  CarromPos(kBoardMargin, kBoardSize - kBoardMargin),
  CarromPos(kBoardSize - kBoardMargin, kBoardSize - kBoardMargin),
];

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

  /// Foul points that could not be taken back as a returned coin.
  final Map<String, int> penalties;

  /// Uid that pocketed the queen and still has to cover it on the next shot.
  final String? queenPendingBy;

  /// Uid that covered the queen (gets [kQueenPoints]).
  final String? queenCoveredBy;

  const CarromState({
    required this.coins,
    this.penalties = const {},
    this.queenPendingBy,
    this.queenCoveredBy,
  });

  factory CarromState.initial() {
    const c = CarromPos(kBoardSize / 2, kBoardSize / 2);
    final coins = <String, CarromPos>{kQueenId: c};
    for (int i = 0; i < kCoinsPerColour; i++) {
      final ab = (2 * i) / 18 * math.pi * 2;
      final aw = (2 * i + 1) / 18 * math.pi * 2;
      coins['b$i'] = CarromPos(c.x + math.cos(ab) * 4.3, c.y + math.sin(ab) * 4.3);
      coins['w$i'] = CarromPos(c.x + math.cos(aw) * 5.7, c.y + math.sin(aw) * 5.7);
    }
    return CarromState(coins: coins);
  }

  /// Returns [CarromState.initial] for a missing or legacy board.
  factory CarromState.fromMap(Map<String, dynamic>? map) {
    if (map == null || map['coins'] == null) return CarromState.initial();
    final coins = <String, CarromPos>{};
    Map<String, dynamic>.from(map['coins'] as Map).forEach((k, v) {
      coins[k] = CarromPos.fromMap(v);
    });
    final pen = <String, int>{};
    Map<String, dynamic>.from((map['penalties'] ?? {}) as Map).forEach((k, v) {
      pen[k] = (v as num).toInt();
    });
    return CarromState(
      coins: coins,
      penalties: pen,
      queenPendingBy: map['queenPendingBy'] as String?,
      queenCoveredBy: map['queenCoveredBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'coins': coins.map((k, v) => MapEntry(k, v.toMap())),
        'penalties': penalties,
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
    return math.max(0, pocketed + queen - (penalties[uid] ?? 0));
  }
}

class ShotOutcome {
  final CarromState state;
  final bool keepsTurn;
  final bool foul;
  final List<String> returnedToCentre;
  final Map<String, int> scores;
  final String? winnerUid;

  const ShotOutcome({
    required this.state,
    required this.keepsTurn,
    required this.foul,
    required this.returnedToCentre,
    required this.scores,
    this.winnerUid,
  });
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

/// Applies DEST-006 to the result of one shot.
///
/// [before] is the synced state the shot started from, [coinsAfter] the coins
/// left on the board once everything stopped, [pocketed] the ids that fell in.
ShotOutcome resolveShot({
  required CarromState before,
  required Map<String, CarromPos> coinsAfter,
  required List<String> pocketed,
  required bool strikerPocketed,
  required String shooterUid,
  required CarromPlayers players,
}) {
  final ownColour = players.colourOf(shooterUid);
  final ownPocketed = pocketed.where((id) => colourOfCoin(id) == ownColour);
  final queenPocketed = pocketed.contains(kQueenId);

  final coins = Map<String, CarromPos>.from(coinsAfter);
  final penalties = Map<String, int>.from(before.penalties);
  String? pending = before.queenPendingBy;
  String? covered = before.queenCoveredBy;
  final returned = <String>[];
  bool keepsTurn;

  void returnToCentre(String id) {
    coins[id] = freeSpotNearCentre(coins, radiusOfCoin(id));
    returned.add(id);
  }

  if (strikerPocketed) {
    keepsTurn = false;
    if (queenPocketed || pending == shooterUid) {
      pending = null;
      returnToCentre(kQueenId);
    }
    final ownMissing = _missingIds(coins, ownColour);
    if (ownMissing.isNotEmpty) {
      returnToCentre(ownMissing.first);
    } else {
      final current = CarromState(
        coins: coins,
        penalties: penalties,
        queenCoveredBy: covered,
      ).scoreFor(shooterUid, ownColour);
      if (current > 0) {
        penalties[shooterUid] = (penalties[shooterUid] ?? 0) + 1;
      }
    }
  } else {
    if (pending == shooterUid) {
      pending = null;
      if (ownPocketed.isNotEmpty) {
        covered = shooterUid;
      } else {
        returnToCentre(kQueenId);
      }
    }
    if (queenPocketed) pending = shooterUid;
    keepsTurn = ownPocketed.isNotEmpty || queenPocketed;
  }

  // A colour cannot be cleared while the queen is unresolved.
  if (covered == null) {
    for (final colour in const [kWhite, kBlack]) {
      final left = coins.keys.where((id) => colourOfCoin(id) == colour);
      if (left.isEmpty) {
        final missing = _missingIds(coins, colour);
        if (missing.isNotEmpty) returnToCentre(missing.first);
      }
    }
  }

  final state = CarromState(
    coins: coins,
    penalties: penalties,
    queenPendingBy: pending,
    queenCoveredBy: covered,
  );

  String? winner;
  if (state.queenResolved) {
    bool cleared(String uid) => state.onBoard(players.colourOf(uid)) == 0;
    final opponent = players.other(shooterUid);
    if (cleared(shooterUid)) {
      winner = shooterUid;
    } else if (cleared(opponent)) {
      winner = opponent;
    }
  }

  return ShotOutcome(
    state: state,
    keepsTurn: winner == null && keepsTurn,
    foul: strikerPocketed,
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
    penalties: s.penalties,
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
  const c = CarromPos(kBoardSize / 2, kBoardSize / 2);
  bool free(CarromPos p) => coins.entries.every(
        (e) => e.value.distanceTo(p) >= radius + radiusOfCoin(e.key) + 0.05,
      );
  if (free(c)) return c;
  for (double ring = 1.5; ring <= 12; ring += 1.0) {
    const steps = 16;
    for (int i = 0; i < steps; i++) {
      final a = i / steps * math.pi * 2;
      final p = CarromPos(c.x + math.cos(a) * ring, c.y + math.sin(a) * ring);
      if (free(p)) return p;
    }
  }
  return c;
}
