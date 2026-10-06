import 'package:availchat/feature/games/carrom/carrom_rules.dart';

import 'carrom_test_shim.dart'
    if (dart.library.ui) 'package:flutter_test/flutter_test.dart';

// Also runs without Flutter: dart run test/feature/games/carrom/carrom_rules_test.dart
void main() {
  const players = CarromPlayers(whiteUid: 'host', blackUid: 'guest');
  final start = CarromState.initial();
  final allWhite = [for (var i = 0; i < kCoinsPerColour; i++) 'w$i'];
  final allBlack = [for (var i = 0; i < kCoinsPerColour; i++) 'b$i'];

  Map<String, CarromPos> without(CarromState s, List<String> ids) =>
      Map.of(s.coins)..removeWhere((k, _) => ids.contains(k));

  ShotOutcome shot(
    CarromState before,
    List<String> pocketed, {
    String shooter = 'host',
    bool foul = false,
  }) =>
      resolveShot(
        before: before,
        coinsAfter: without(before, pocketed),
        pocketed: pocketed,
        strikerPocketed: foul,
        shooterUid: shooter,
        players: players,
      );

  test('initial board is the standard rosette', () {
    expect(start.coins.length, 19);
    expect(start.onBoard(kWhite), kCoinsPerColour);
    expect(start.onBoard(kBlack), kCoinsPerColour);
    expect(start.coins[kQueenId]!.distanceTo(kBoardCentre), closeTo(0, 1e-9));
    final ids = start.coins.keys.toList();
    var touchingQueen = 0;
    for (var i = 0; i < ids.length; i++) {
      final p = start.coins[ids[i]]!;
      expect(p.distanceTo(kBoardCentre), lessThan(8.5 - kCoinRadius));
      if (ids[i] != kQueenId &&
          p.distanceTo(kBoardCentre) < 2 * kCoinRadius + 0.1) {
        touchingQueen++;
      }
      for (var j = i + 1; j < ids.length; j++) {
        final d = p.distanceTo(start.coins[ids[j]]!);
        expect(
          d,
          greaterThanOrEqualTo(radiusOfCoin(ids[i]) + radiusOfCoin(ids[j])),
          reason: '${ids[i]} / ${ids[j]}',
        );
      }
    }
    expect(touchingQueen, 6);
  });

  test('striker spots on the baseline avoid coins', () {
    final coins = {'w0': CarromPos(37, baselineY(hostSide: true))};
    final p = strikerSpot(coins, hostSide: true, x: 37);
    expect(strikerSpotFree(coins, p), isTrue);
    expect(p.y, baselineY(hostSide: true));
    expect(p.x, greaterThanOrEqualTo(kBaselineMinX));
    expect(p.x, lessThanOrEqualTo(kBaselineMaxX));
  });

  test('own coin scores 1 and keeps the turn', () {
    final o = shot(start, ['w0']);
    expect(o.scores['host'], 1);
    expect(o.keepsTurn, isTrue);
  });

  test('opponent coin is credited to its owner and the turn passes', () {
    final o = shot(start, ['w0'], shooter: 'guest');
    expect(o.scores['host'], 1);
    expect(o.scores['guest'], 0);
    expect(o.keepsTurn, isFalse);
  });

  test('queen covered on the next shot scores 3', () {
    final pending = shot(start, ['q']);
    expect(pending.state.queenPendingBy, 'host');
    expect(pending.keepsTurn, isTrue);
    expect(pending.scores['host'], 0);

    final covered = shot(pending.state, ['w1']);
    expect(covered.state.queenCoveredBy, 'host');
    expect(covered.scores['host'], 1 + kQueenPoints);
  });

  test('queen and an own coin in the same stroke cover immediately', () {
    final o = shot(start, ['q', 'w0']);
    expect(o.state.queenCoveredBy, 'host');
    expect(o.state.queenPendingBy, isNull);
    expect(o.scores['host'], 1 + kQueenPoints);
    expect(o.keepsTurn, isTrue);
  });

  test('queen with only an opponent coin stays pending', () {
    final o = shot(start, ['q', 'b0']);
    expect(o.state.queenPendingBy, 'host');
    expect(o.state.queenCoveredBy, isNull);
    expect(o.keepsTurn, isTrue);
  });

  test('queen not covered returns to the centre', () {
    final pending = shot(start, ['q']);
    final miss = shot(pending.state, []);
    expect(miss.state.queenCoveredBy, isNull);
    expect(miss.state.queenPendingBy, isNull);
    expect(miss.state.coins.containsKey(kQueenId), isTrue);
    expect(miss.keepsTurn, isFalse);
  });

  test('foul costs 1 point by returning an own coin', () {
    final two = shot(start, ['w0', 'w1']);
    final foul = shot(two.state, [], foul: true);
    expect(foul.scores['host'], 1);
    expect(foul.returnedToCentre.length, 1);
    expect(foul.fouls, [kFoulStriker]);
    expect(foul.keepsTurn, isFalse);
  });

  test('striker foul returns coins pocketed that stroke plus a penalty', () {
    final one = shot(start, ['w0']);
    final foul = shot(one.state, ['w1', 'w2', 'b0'], foul: true);
    expect(foul.state.onBoard(kWhite), kCoinsPerColour);
    expect(foul.returnedToCentre.toSet(), {'w0', 'w1', 'w2'});
    expect(foul.scores['host'], 0);
    // Opponent coins stay pocketed and count for the opponent.
    expect(foul.scores['guest'], 1);
    expect(foul.state.due['host'] ?? 0, 0);
  });

  test('striker foul with a pocketed queen returns the queen', () {
    final foul = shot(start, ['q', 'w0'], foul: true);
    expect(foul.state.coins.containsKey(kQueenId), isTrue);
    expect(foul.state.queenCoveredBy, isNull);
    expect(foul.state.queenPendingBy, isNull);
    expect(foul.state.coins.containsKey('w0'), isTrue);
  });

  test('a foul with nothing to return is owed and paid later', () {
    final foul = shot(start, [], foul: true);
    expect(foul.scores['host'], 0);
    expect(foul.state.due['host'], 1);

    final paid = shot(foul.state, ['w3']);
    expect(paid.state.coins.containsKey('w3'), isTrue);
    expect(paid.returnedToCentre, ['w3']);
    expect(paid.state.due['host'] ?? 0, 0);
    expect(paid.scores['host'], 0);
    expect(paid.keepsTurn, isTrue);

    final scored = shot(paid.state, ['w4']);
    expect(scored.scores['host'], 1);
  });

  test('an owed coin is paid when the opponent pockets one of yours', () {
    final foul = shot(start, [], foul: true);
    final o = shot(foul.state, ['w5'], shooter: 'guest');
    expect(o.state.coins.containsKey('w5'), isTrue);
    expect(o.state.due['host'] ?? 0, 0);
  });

  test('a striker foul never drops the penalty or goes below 0', () {
    final foul = shot(start, [], foul: true);
    expect(foul.scores['host'], 0);
    final again = shot(foul.state, [], foul: true);
    expect(again.state.due['host'], 2);
    expect(again.scores['host'], 0);
  });

  test('clearing all own coins with the queen covered wins', () {
    final s = CarromState(
      coins: without(start, [kQueenId, ...allWhite.sublist(0, 8)]),
      queenCoveredBy: 'host',
    );
    final o = shot(s, ['w8']);
    expect(o.winnerUid, 'host');
    expect(o.keepsTurn, isFalse);
  });

  test('covering the queen with the last coin wins', () {
    final s = CarromState(
      coins: without(start, [kQueenId, ...allWhite.sublist(0, 8)]),
      queenPendingBy: 'host',
    );
    final o = shot(s, ['w8']);
    expect(o.winnerUid, 'host');
    expect(o.state.queenCoveredBy, 'host');
  });

  test('queen and the last coin in one stroke win', () {
    final s = CarromState(coins: without(start, allWhite.sublist(0, 8)));
    final o = shot(s, [kQueenId, 'w8']);
    expect(o.fouls, isEmpty);
    expect(o.winnerUid, 'host');
  });

  test('own last coin before the queen is covered is a foul', () {
    final s = CarromState(coins: without(start, allWhite.sublist(0, 8)));
    final o = shot(s, ['w8']);
    expect(o.fouls, [kFoulOwnLast]);
    expect(o.winnerUid, isNull);
    expect(o.keepsTurn, isFalse);
    // The last coin and one penalty coin come back.
    expect(o.state.onBoard(kWhite), 2);
  });

  test("pocketing the opponent's last coin is a foul, not their win", () {
    final s = CarromState(
      coins: without(start, [kQueenId, ...allBlack.sublist(0, 8), 'w0']),
      queenCoveredBy: 'guest',
    );
    final o = shot(s, ['b8']);
    expect(o.fouls, [kFoulOpponentLast]);
    expect(o.winnerUid, isNull);
    expect(o.state.coins.containsKey('b8'), isTrue);
    expect(o.state.coins.containsKey('w0'), isTrue);
    expect(o.keepsTurn, isFalse);
  });

  test("the opponent's last coin with the queen open is still a foul", () {
    final s = CarromState(coins: without(start, allBlack.sublist(0, 8)));
    final o = shot(s, ['b8', 'w0']);
    expect(o.fouls, [kFoulOpponentLast]);
    expect(o.state.coins.containsKey('b8'), isTrue);
    expect(o.state.coins.containsKey('w0'), isTrue);
    expect(o.state.due['host'], 1);
  });

  test('timeout returns a pending queen', () {
    final pending = shot(start, ['q']).state;
    final s = resolveTimeout(pending, 'host');
    expect(s.queenPendingBy, isNull);
    expect(s.coins.containsKey(kQueenId), isTrue);
  });

  test('state survives a map round trip', () {
    final s = shot(shot(start, [], foul: true).state, ['q']).state;
    final r = CarromState.fromMap(s.toMap());
    expect(r.coins.length, s.coins.length);
    expect(r.queenPendingBy, s.queenPendingBy);
    expect(r.due, s.due);
    expect(r.coins['w0']!.x, s.coins['w0']!.x);
  });

  test('legacy boards: penalties read as due and units rescaled', () {
    final r = CarromState.fromMap({
      'coins': {
        'q': {'x': 20, 'y': 20},
        'w0': {'x': 2.5, 'y': 37.5},
      },
      'penalties': {'host': 2},
    });
    expect(r.due['host'], 2);
    expect(r.coins['q']!.x, closeTo(kBoardSize / 2, 1e-9));
    expect(r.coins['w0']!.x, closeTo(kCoinRadius, 1e-9));
    expect(r.coins['w0']!.y, closeTo(kBoardSize - kCoinRadius, 1e-9));
    expect(r.scoreFor('host', kWhite), kCoinsPerColour - 1 - 2);
  });
}
