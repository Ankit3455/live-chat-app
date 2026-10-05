import 'package:availchat/feature/games/chat_games/chat_game_logic.dart';
import 'package:availchat/feature/games/chat_games/duel/duel_game.dart';
import 'package:availchat/feature/games/chat_games/thumb_war/thumb_rules.dart';
import 'package:availchat/feature/games/chat_games/thumb_war/thumb_war.dart';
import 'package:flutter_test/flutter_test.dart';

const players = ['alice', 'bob'];

Map<String, Object> clash(ThumbPick? a, ThumbPick? b) => {
  if (a != null) 'alice': a.toMap(),
  if (b != null) 'bob': b.toMap(),
};

ThumbPick p(ThumbMove m, int power) => ThumbPick(m, power);

void main() {
  test('pounce beats feint, feint beats guard, guard beats pounce', () {
    expect(ThumbMove.pounce.beats, ThumbMove.feint);
    expect(ThumbMove.feint.beats, ThumbMove.guard);
    expect(ThumbMove.guard.beats, ThumbMove.pounce);
    expect(
      ThumbWar.resolve(p(ThumbMove.guard, 0), p(ThumbMove.pounce, 100)),
      (0, 15),
      reason: 'the right move wins even with a weak grip',
    );
    expect(ThumbWar.resolve(p(ThumbMove.feint, 100), p(ThumbMove.guard, 50)), (
      0,
      35,
    ));
  });

  test('the same move goes to the stronger grip; equal grips do nothing', () {
    expect(ThumbWar.resolve(p(ThumbMove.pounce, 40), p(ThumbMove.pounce, 90)), (
      1,
      20,
    ));
    expect(ThumbWar.resolve(p(ThumbMove.guard, 60), p(ThumbMove.guard, 60)), (
      null,
      0,
    ));
  });

  test('not picking in time gets you pinned', () {
    expect(ThumbWar.resolve(null, p(ThumbMove.feint, 10)), (
      1,
      ThumbWar.pinDamage,
    ));
    expect(ThumbWar.resolve(p(ThumbMove.feint, 10), null), (
      0,
      ThumbWar.pinDamage,
    ));
    expect(ThumbWar.resolve(null, null), (null, 0));
  });

  test('a knockout wins the round and resets health', () {
    final hit = clash(p(ThumbMove.feint, 100), p(ThumbMove.guard, 0)); // 35
    final r = ThumbReplay.of(players, [hit, hit]);
    expect(r.hp, [100, 30]);
    final ko = ThumbReplay.of(players, [hit, hit, hit]);
    expect(ko.rounds, [1, 0]);
    expect(ko.hp, [100, 100]);
    expect(ko.lastClash!.endedRound, isTrue);
    expect(ko.round, 2);
  });

  test('two rounds win the war; later clashes are ignored', () {
    final hit = clash(p(ThumbMove.feint, 100), p(ThumbMove.guard, 0));
    final r = ThumbReplay.of(players, List.filled(7, hit));
    expect(r.rounds, [2, 0]);
    expect(r.winner, 0);
    expect(r.clashes.length, 6);
  });

  test('giving up hands the war to the other player', () {
    final r = ThumbReplay.of(players, const [], resignedBy: 'bob');
    expect(r.winner, 0);
    expect(r.byResignation, isTrue);
  });

  test('picks must be a known move and a power from 0 to 100', () {
    expect(ThumbPick.parse({'m': 'pounce', 'p': 50})!.move, ThumbMove.pounce);
    expect(ThumbPick.parse({'m': 'kick', 'p': 50}), isNull);
    expect(ThumbPick.parse({'m': 'pounce', 'p': 101}), isNull);
    expect(ThumbPick.parse({'m': 'pounce', 'p': 5.5}), isNull);
    expect(ThumbPick.parse({'m': 'pounce', 'p': 5, 'x': 1}), isNull);
    expect(ThumbRules.instance.parsePick('L'), isNull);
  });

  test('each player gets a different accessory, the same on both phones', () {
    final a = ThumbWar.accessoriesFor(players);
    expect(a.length, 2);
    expect(a[0], isNot(a[1]));
    expect(ThumbWar.accessoriesFor(players), a);
  });

  test('result card and line', () {
    final hit = clash(p(ThumbMove.feint, 100), p(ThumbMove.guard, 0));
    final g = DuelGame(
      gameId: 'g',
      players: players,
      createdBy: 'alice',
      status: 'over',
      picks: const {},
      history: List.filled(6, hit),
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
