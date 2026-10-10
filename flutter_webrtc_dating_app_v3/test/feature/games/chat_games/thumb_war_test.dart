import 'package:availchat/feature/games/chat_games/chat_game_logic.dart';
import 'package:availchat/feature/games/chat_games/duel/duel_game.dart';
import 'package:availchat/feature/games/chat_games/thumb_war/thumb_rules.dart';
import 'package:availchat/feature/games/chat_games/thumb_war/thumb_war.dart';
import 'package:flutter_test/flutter_test.dart';

const players = ['alice', 'bob'];

/// A fight already past the ROUND / FIGHT! intro.
ThumbFight fighting() {
  final f = ThumbFight();
  for (var i = 0; i < ThumbWar.introTicks; i++) {
    f.step();
  }
  expect(f.phase, FightPhase.fight);
  return f;
}

void press(ThumbFight f, int p, bool down) {
  f.input[p] = down;
  f.step();
}

void main() {
  test('pressing first puts your thumb down and drains their stamina', () {
    final f = fighting();
    press(f, 0, true);
    expect(f.state, FightState.downL);
    for (var i = 0; i < 10; i++) {
      f.step();
    }
    expect(f.stamina[1], lessThan(100));
    expect(f.stamina[0], 100);
    expect(f.hp, [100, 100], reason: 'taunting does no damage');
  });

  test('pressing while they are down pins them: HP for stamina', () {
    final f = fighting();
    press(f, 1, true);
    press(f, 0, true);
    expect(f.state, FightState.pinL);
    expect(f.pins, 1);
    for (var i = 0; i < 9; i++) {
      f.step();
    }
    expect(f.hp[1], closeTo(100 - 10 * ThumbWar.attack, 0.01));
    // The taunt tick before the pin cost half a point.
    expect(f.stamina[0], closeTo(99.5 - 10 * ThumbWar.pinCost, 0.01));
  });

  test('running dry mid-pin flips it: the pinner is down, the other full', () {
    final f = fighting();
    press(f, 1, true);
    press(f, 0, true);
    for (var i = 0; i < 100 && f.state == FightState.pinL; i++) {
      f.step();
    }
    expect(f.state, FightState.downL);
    expect(f.stamina[1], 100);
    expect(f.hp[1], closeTo(100 - 34 * ThumbWar.attack, 0.01));
  });

  test('letting go goes back to neutral and both refill', () {
    final f = fighting();
    press(f, 1, true);
    press(f, 0, true);
    for (var i = 0; i < 5; i++) {
      f.step();
    }
    press(f, 0, false);
    expect(f.state, FightState.idle);
    final before = f.stamina[0];
    f.step();
    expect(f.stamina[0], before + ThumbWar.idleGain);
  });

  test('holding the button is not a new press', () {
    final f = fighting();
    press(f, 0, true);
    press(f, 1, true);
    expect(f.state, FightState.pinR);
    press(f, 1, false);
    expect(f.state, FightState.idle);
    f.step();
    expect(f.state, FightState.idle, reason: 'left is still holding');
  });

  test('a knockout ends the round, then the next round starts fresh', () {
    final f = fighting();
    f.hp[1] = 1;
    press(f, 1, true);
    press(f, 0, true);
    f.step();
    expect(f.roundWinners, [0]);
    expect(f.state, FightState.winL);
    expect(f.phase, FightPhase.ko);
    for (var i = 0; i < ThumbWar.koTicks; i++) {
      f.step();
    }
    expect(f.phase, FightPhase.intro);
    expect(f.hp, [100, 100]);
    expect(f.round, 2);
  });

  test('two rounds win the match', () {
    final f = fighting();
    f.roundWinners.add(1);
    f.hp[1] = 1;
    press(f, 1, true);
    press(f, 0, true);
    f.step();
    expect(f.roundWinners, [1, 0]);
    expect(f.phase, FightPhase.ko);
    expect(f.isFinalRound, isTrue);
  });

  test('the shared form round-trips', () {
    final f = fighting();
    press(f, 1, true);
    press(f, 0, true);
    f.step();
    final back = ThumbFight.fromMap(f.toMap())!;
    expect(back.state, FightState.pinL);
    expect(back.phase, FightPhase.fight);
    expect(back.hp[1], closeTo(f.hp[1], 0.1));
    expect(back.pins, 1);
    expect(ThumbFight.fromMap({'hp': 'x'}), isNull);
  });

  test('a bot match always finishes', () {
    final f = ThumbFight();
    final a = ThumbBot(), b = ThumbBot();
    for (var i = 0; i < 60 * 60 * 10 && f.phase != FightPhase.over; i++) {
      a.drive(f, 0);
      b.drive(f, 1);
      f.step();
    }
    expect(f.phase, FightPhase.over);
    expect(f.matchWinner, isNotNull);
  });

  test('rounds replay from the history; the host decides', () {
    final r = ThumbReplay.of(players, [
      {'alice': 0, 'bob': 0},
      {'alice': 1, 'bob': 0},
      {'bob': 1},
    ]);
    expect(r.roundWinners, [0, 1, 1]);
    expect(r.rounds, [1, 2]);
    expect(r.winner, 1);
  });

  test('giving up hands the war to the other player', () {
    final r = ThumbReplay.of(players, const [], resignedBy: 'bob');
    expect(r.winner, 0);
    expect(r.byResignation, isTrue);
  });

  test('a pick is a player index', () {
    expect(ThumbRules.instance.parsePick(0), 0);
    expect(ThumbRules.instance.parsePick(1), 1);
    expect(ThumbRules.instance.parsePick(2), isNull);
    expect(ThumbRules.instance.parsePick('L'), isNull);
    expect(ThumbRules.instance.parsePick({'m': 'pounce', 'p': 50}), isNull);
  });

  test('each player gets a different accessory, the same on both phones', () {
    final a = ThumbWar.accessoriesFor(players);
    expect(a.length, 2);
    expect(a[0], isNot(a[1]));
    expect(ThumbWar.accessoriesFor(players), a);
  });

  test('result card and line', () {
    const Map<String, Object> round = {'alice': 0, 'bob': 0};
    const g = DuelGame(
      gameId: 'g',
      players: players,
      createdBy: 'alice',
      status: 'over',
      picks: {},
      history: [round, round],
    );
    expect(ThumbRules.instance.isOver(g), isTrue);
    final m = ThumbRules.instance.result(g);
    expect(m.metadata['winner'], 'alice');
    expect(m.metadata['score'], '2-0');
    expect(m.metadata['stage'], ChatGameLogic.resultStage);
    expect(
      ThumbRules.instance.resultLine(
        m.metadata,
        viewer: 'bob',
        otherName: 'Alice',
      ),
      'Alice won the Thumb War. (2-0)',
    );
  });
}
