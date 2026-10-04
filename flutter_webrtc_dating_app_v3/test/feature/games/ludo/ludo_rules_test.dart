import 'package:availchat/feature/games/ludo/constants.dart';
import 'package:availchat/feature/games/ludo/ludo_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// Shared Ludo rules: DEST-039 (turns skip colours not playing), DEST-136.
void main() {
  final last = LudoRules.lastStep('green');

  bool isSafe(List<double> p) =>
      LudoPath.safeArea.any((s) => s[0] == p[0] && s[1] == p[1]);

  int indexOf(String color, List<double> pos) => LudoRules.pathFor(
    color,
  ).indexWhere((p) => p[0] == pos[0] && p[1] == pos[1]);

  test('every colour has a path of the same length', () {
    for (final c in LudoRules.colorOrder) {
      expect(LudoRules.lastStep(c), last, reason: c);
    }
  });

  test('a home pawn needs a 6 to enter', () {
    expect(LudoRules.targetStep(-1, 6, last), 0);
    for (var d = 1; d <= 5; d++) {
      expect(LudoRules.targetStep(-1, d, last), isNull);
    }
  });

  test('moves cannot overshoot the finish and dice must be 1..6', () {
    expect(LudoRules.targetStep(last - 3, 3, last), last);
    expect(LudoRules.targetStep(last - 3, 4, last), isNull);
    expect(LudoRules.targetStep(last, 1, last), isNull);
    expect(LudoRules.targetStep(5, 0, last), isNull);
    expect(LudoRules.targetStep(5, 7, last), isNull);
  });

  test('legalPawns lists only movable pawns', () {
    expect(LudoRules.legalPawns([-1, -1, 10, last], 3, last), [2]);
    expect(LudoRules.legalPawns([-1, -1, 10, last], 6, last), [0, 1, 2]);
    expect(LudoRules.legalPawns([-1, -1, -1, -1], 5, last), isEmpty);
  });

  test('a player finishes only with all four pawns home', () {
    expect(LudoRules.hasFinished([last, last, last, last], last), isTrue);
    expect(LudoRules.hasFinished([last, last, last, last - 1], last), isFalse);
    expect(LudoRules.hasFinished([last, last, last], last), isFalse);
  });

  test('parseSteps tolerates bad data', () {
    expect(LudoRules.parseSteps(null), [-1, -1, -1, -1]);
    expect(LudoRules.parseSteps([1, 2.0, 'x']), [1, 2, -1, -1]);
    expect(LudoRules.parseSteps([1, 2, 3, 4, 5]), [1, 2, 3, 4]);
  });

  test('nextColor skips colours that are not playing', () {
    expect(LudoRules.nextColor('green', ['green', 'blue']), 'blue');
    expect(LudoRules.nextColor('blue', ['green', 'blue']), 'green');
    expect(LudoRules.nextColor('red', LudoRules.colorOrder), 'green');
    expect(LudoRules.nextColor('green', ['green']), 'green');
    expect(LudoRules.nextColor('green', const <String>[]), isNull);
  });

  test('two players get opposite corners', () {
    expect(LudoRules.colorsFor(2), ['green', 'blue']);
    expect(LudoRules.colorsFor(4), LudoRules.colorOrder);
  });

  test('landing on an opponent captures it, except on safe squares', () {
    final greenPath = LudoRules.pathFor('green');

    final open = List.generate(greenPath.length - 1, (i) => i).firstWhere(
      (i) => !isSafe(greenPath[i]) && indexOf('blue', greenPath[i]) > 0,
    );
    final blueAtOpen = indexOf('blue', greenPath[open]);
    final hit = LudoRules.captures(
      color: 'green',
      step: open,
      pawnSteps: {
        'blue': [blueAtOpen, -1, -1, -1],
      },
      victimColors: ['green', 'blue'],
    );
    expect(hit, {
      'blue': [0],
    });

    final safe = List.generate(greenPath.length - 1, (i) => i).firstWhere(
      (i) => isSafe(greenPath[i]) && indexOf('blue', greenPath[i]) >= 0,
    );
    final none = LudoRules.captures(
      color: 'green',
      step: safe,
      pawnSteps: {
        'blue': [indexOf('blue', greenPath[safe]), -1, -1, -1],
      },
      victimColors: ['blue'],
    );
    expect(none, isEmpty);
  });
}
