import 'package:availchat/feature/games/chat_games/chat_game_logic.dart';
import 'package:availchat/feature/games/chat_games/duel/duel_game.dart';
import 'package:availchat/feature/games/chat_games/tennis/tennis_game.dart';
import 'package:availchat/feature/games/chat_games/tennis/tennis_match.dart';
import 'package:flutter_test/flutter_test.dart';

const players = ['alice', 'bob']; // alice serves first

/// One shot where alice and bob picked [a] and [b] (null = timed out).
Map<String, String> shot(String? a, String? b) => {
  if (a != null) 'alice': a,
  if (b != null) 'bob': b,
};

/// A point won outright by whoever is hitting (aim differs from the guess).
Map<String, String> ace() => shot('L', 'R');

void main() {
  test('a missed guess is a point for the hitter', () {
    final r = TennisReplay.of(players, [ace()]);
    expect(r.shots.single.result, TennisShotResult.winner);
    expect(r.points, [1, 0]);
    expect(r.hitter, 0, reason: 'next point starts with the server again');
  });

  test('a return swaps hitter and receiver', () {
    final r = TennisReplay.of(players, [shot('C', 'C')]);
    expect(r.shots.single.result, TennisShotResult.returned);
    expect(r.hitter, 1);
    // bob now hits right, alice guessed middle: point to bob.
    final r2 = TennisReplay.of(players, [shot('C', 'C'), shot('C', 'R')]);
    expect(r2.points, [0, 1]);
    expect(r2.hitter, 0);
  });

  test('four straight points win the game and the serve changes', () {
    final r = TennisReplay.of(players, List.filled(4, ace()));
    expect(r.games, [1, 0]);
    expect(r.points, [0, 0]);
    expect(r.server, 1);
    expect(r.hitter, 1);
    expect(r.finishedGames, [
      [4, 0],
    ]);
  });

  test('deuce and advantage', () {
    // alice serves: point to alice = ace, point to bob = alice faults.
    final aliceWins = ace();
    final bobWins = shot(null, 'C');
    final r = TennisReplay.of(players, [
      aliceWins, aliceWins, aliceWins, //
      bobWins, bobWins, bobWins,
    ]);
    expect(r.pointCall(0), ('Deuce', 'Deuce'));
    final adv = TennisReplay.of(players, [
      aliceWins,
      aliceWins,
      aliceWins,
      bobWins,
      bobWins,
      bobWins,
      bobWins,
    ]);
    expect(adv.pointCall(0), ('40', 'Ad'));
    expect(adv.pointCall(1), ('Ad', '40'));
    expect(adv.games, [0, 0]);
    final back = TennisReplay.of(players, [
      aliceWins,
      aliceWins,
      aliceWins,
      bobWins,
      bobWins,
      bobWins,
      bobWins,
      aliceWins,
    ]);
    expect(back.pointCall(0), ('Deuce', 'Deuce'));
  });

  test('running out of time loses the point', () {
    expect(
      TennisReplay.of(players, [shot(null, 'L')]).shots.single.result,
      TennisShotResult.fault,
    );
    expect(TennisReplay.of(players, [shot(null, 'L')]).points, [0, 1]);
    expect(
      TennisReplay.of(players, [shot('L', null)]).shots.single.result,
      TennisShotResult.noReturn,
    );
    expect(TennisReplay.of(players, [shot('L', null)]).points, [1, 0]);
    expect(
      TennisReplay.of(players, [shot(null, null)]).points,
      [0, 1],
      reason: 'the hitter has to play first',
    );
  });

  test('two games win the match; later shots are ignored', () {
    // Game 1: alice serves and wins 4 aces. Game 2: bob serves; alice wins
    // every point because bob times out each time.
    final bobFaults = shot('C', null);
    final r = TennisReplay.of(players, [
      ...List.filled(4, ace()),
      ...List.filled(4, bobFaults),
      ace(),
    ]);
    expect(r.games, [2, 0]);
    expect(r.winner, 0);
    expect(r.isOver, isTrue);
    expect(r.shots.length, 8);
  });

  test('resigning hands the match to the other player', () {
    final r = TennisReplay.of(players, [ace()], resignedBy: 'alice');
    expect(r.winner, 1);
    expect(r.byResignation, isTrue);
  });

  test("player 2 sees the court turned around", () {
    expect(TennisMatch.toCourt('L', 0), 'L');
    expect(TennisMatch.toCourt('L', 1), 'R');
    expect(TennisMatch.toCourt('C', 1), 'C');
    for (final z in TennisMatch.zones) {
      expect(TennisMatch.toScreen(TennisMatch.toCourt(z, 1), 1), z);
    }
  });

  test('duel docs keep only valid zones', () {
    final g = DuelGame.fromMap(TennisRules.instance, {
      'players': players,
      'status': 'playing',
      'picks': {'alice': 'L', 'bob': 'X'},
      'history': [
        {'alice': 'L', 'bob': 'L'},
        {'alice': 7},
      ],
      'joined': players,
      'turnStartedAt': DateTime(2026, 1, 1, 12),
    })!;
    expect(g.picks, {'alice': 'L'});
    expect(g.history, [
      {'alice': 'L', 'bob': 'L'},
      <String, Object>{},
    ]);
    expect(g.bothJoined, isTrue);
    expect(g.deadline, DateTime(2026, 1, 1, 12, 0, 30));
    // Shot 1 returned (bob hits next); shot 2 bob didn't hit: point alice.
    expect(
      TennisRules.replayOf(g).shots.first.result,
      TennisShotResult.returned,
    );
    expect(TennisRules.replayOf(g).points, [1, 0]);
    expect(TennisRules.instance.isOver(g), isFalse);
  });

  test('result message names the winner and the score', () {
    final r = TennisReplay.of(players, [
      ...List.filled(4, ace()),
      ...List.filled(4, shot('C', null)),
    ]);
    final m = TennisRules.resultFor(r);
    expect(m.metadata['winner'], 'alice');
    expect(m.metadata['score'], '2-0');
    expect(m.metadata['stage'], ChatGameLogic.resultStage);
    expect(
      TennisRules.outcomeFor(
        viewer: 'alice',
        otherName: 'Bob',
        meta: m.metadata,
      ),
      'You won the match! 🏆',
    );
    expect(
      TennisRules.outcomeFor(
        viewer: 'bob',
        otherName: 'Alice',
        meta: m.metadata,
      ),
      'Alice won the match.',
    );
  });
}
