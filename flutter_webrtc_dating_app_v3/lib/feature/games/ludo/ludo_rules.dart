// lib/feature/games/ludo/ludo_rules.dart
import 'constants.dart';

/// Pure Ludo rules shared by the provider (UI hints) and the service
/// (transactional writes), so both sides agree on what is legal.
class LudoRules {
  LudoRules._();

  /// Clockwise turn order on the board.
  static const List<String> colorOrder = ['green', 'yellow', 'blue', 'red'];
  static const int pawnCount = 4;

  static List<List<double>> pathFor(String color) {
    switch (color) {
      case 'yellow':
        return LudoPath.yellowPath;
      case 'blue':
        return LudoPath.bluePath;
      case 'red':
        return LudoPath.redPath;
      case 'green':
      default:
        return LudoPath.greenPath;
    }
  }

  static int lastStep(String color) => pathFor(color).length - 1;

  /// Colours for a new match: opposite corners for 2 players.
  static List<String> colorsFor(int playerCount) =>
      playerCount <= 2 ? const ['green', 'blue'] : colorOrder;

  /// Target step for a pawn, or null if the move is illegal
  /// (home pawn without a 6, finished pawn, or overshooting the finish).
  static int? targetStep(int from, int dice, int lastStep) {
    if (dice < 1 || dice > 6) return null;
    if (from < 0) return dice == 6 ? 0 : null;
    final to = from + dice;
    return to <= lastStep ? to : null;
  }

  static List<int> legalPawns(List<int> steps, int dice, int lastStep) => [
        for (int i = 0; i < steps.length; i++)
          if (targetStep(steps[i], dice, lastStep) != null) i,
      ];

  static bool hasFinished(List<int> steps, int lastStep) =>
      steps.length == pawnCount && steps.every((s) => s == lastStep);

  static List<int> parseSteps(dynamic raw) {
    final steps = List<int>.filled(pawnCount, -1);
    if (raw is List) {
      for (int i = 0; i < raw.length && i < pawnCount; i++) {
        final v = raw[i];
        if (v is num) steps[i] = v.toInt();
      }
    }
    return steps;
  }

  /// Next colour after [current] in clockwise order among [eligible],
  /// or null if nobody is eligible.
  static String? nextColor(String current, Iterable<String> eligible) {
    final set = eligible.toSet();
    if (set.isEmpty) return null;
    final idx = colorOrder.indexOf(current);
    for (int i = 1; i <= colorOrder.length; i++) {
      final c = colorOrder[(idx + i) % colorOrder.length];
      if (set.contains(c)) return c;
    }
    return null;
  }

  static bool _isSafe(List<double> pos) =>
      LudoPath.safeArea.any((s) => s[0] == pos[0] && s[1] == pos[1]);

  /// Pawns captured when [color] lands on [step]: colour -> pawn indices.
  static Map<String, List<int>> captures({
    required String color,
    required int step,
    required Map<String, List<int>> pawnSteps,
    required Iterable<String> victimColors,
  }) {
    final result = <String, List<int>>{};
    final path = pathFor(color);
    if (step < 0 || step >= path.length - 1) return result;
    final pos = path[step];
    if (_isSafe(pos)) return result;

    for (final victim in victimColors) {
      if (victim == color) continue;
      final steps = pawnSteps[victim];
      if (steps == null) continue;
      final vPath = pathFor(victim);
      for (int i = 0; i < steps.length; i++) {
        final s = steps[i];
        if (s < 0 || s >= vPath.length - 1) continue;
        final vPos = vPath[s];
        if (vPos[0] == pos[0] && vPos[1] == pos[1]) {
          (result[victim] ??= []).add(i);
        }
      }
    }
    return result;
  }
}
