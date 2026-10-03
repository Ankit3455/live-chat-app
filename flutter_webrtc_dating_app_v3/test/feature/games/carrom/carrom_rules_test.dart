import 'package:availchat/feature/games/carrom/carrom_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const players = CarromPlayers(whiteUid: 'host', blackUid: 'guest');
  final start = CarromState.initial();
  final allWhite = [for (var i = 0; i < kCoinsPerColour; i++) 'w$i'];

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

  test('initial board has 19 non-overlapping coins', () {
    expect(start.coins.length, 19);
    final ids = start.coins.keys.toList();
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final d = start.coins[ids[i]]!.distanceTo(start.coins[ids[j]]!);
        expect(d, greaterThanOrEqualTo(radiusOfCoin(ids[i]) + radiusOfCoin(ids[j])));
      }
    }
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
    expect(foul.keepsTurn, isFalse);
  });

  test('foul never goes below 0', () {
    final foul = shot(start, [], foul: true);
    expect(foul.scores['host'], 0);
    expect(foul.state.penalties['host'] ?? 0, 0);
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

  test('last own coin returns while the queen is unresolved', () {
    final s = CarromState(coins: without(start, allWhite.sublist(0, 8)));
    final o = shot(s, ['w8']);
    expect(o.winnerUid, isNull);
    expect(o.state.onBoard(kWhite), 1);
  });

  test('timeout returns a pending queen', () {
    final pending = shot(start, ['q']).state;
    final s = resolveTimeout(pending, 'host');
    expect(s.queenPendingBy, isNull);
    expect(s.coins.containsKey(kQueenId), isTrue);
  });

  test('state survives a map round trip', () {
    final s = shot(start, ['q', 'w0']).state;
    final r = CarromState.fromMap(s.toMap());
    expect(r.coins.length, s.coins.length);
    expect(r.queenPendingBy, s.queenPendingBy);
  });
}
