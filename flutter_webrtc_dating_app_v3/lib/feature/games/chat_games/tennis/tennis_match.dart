// lib/feature/games/chat_games/tennis/tennis_match.dart
//
// Tennis Duel: a guessing game with real tennis scoring. On every shot the
// hitter picks where to aim (L / C / R) and the receiver, at the same time,
// picks where to run. Same zone = returned, roles swap and the rally goes
// on; different zone = point to the hitter. A player who runs out of time
// loses the point. 15-30-40, deuce and advantage; first to 2 games wins.
//
// Zones are stored from players[0]'s side of the court; players[1] sees the
// court turned around, so their screen-left is 'R'. Pure Dart.

enum TennisShotResult {
  /// Same zone: the receiver got it back.
  returned,

  /// Different zone: point to the hitter.
  winner,

  /// The hitter ran out of time: point to the receiver.
  fault,

  /// The receiver ran out of time: point to the hitter.
  noReturn,
}

class TennisShot {
  final int hitter;
  final String? aim;
  final String? guess;
  final TennisShotResult result;

  const TennisShot(this.hitter, this.aim, this.guess, this.result);

  int get receiver => 1 - hitter;

  /// Index of the player who won the point, or null if the rally goes on.
  int? get pointTo {
    switch (result) {
      case TennisShotResult.returned:
        return null;
      case TennisShotResult.winner:
      case TennisShotResult.noReturn:
        return hitter;
      case TennisShotResult.fault:
        return receiver;
    }
  }
}

class TennisMatch {
  TennisMatch._();

  static const List<String> zones = ['L', 'C', 'R'];
  static const int gamesToWin = 2;

  /// Matches the rules' cap on stored shots.
  static const int maxShots = 400;

  static bool isZone(Object? v) => zones.contains(v);

  /// Screen zone -> stored zone ([playerIndex] 1 sees the court turned).
  static String toCourt(String screenZone, int playerIndex) =>
      playerIndex == 0 ? screenZone : _mirror(screenZone);

  /// Stored zone -> zone as seen on [playerIndex]'s screen.
  static String toScreen(String courtZone, int playerIndex) =>
      playerIndex == 0 ? courtZone : _mirror(courtZone);

  static String _mirror(String z) => z == 'L' ? 'R' : (z == 'R' ? 'L' : z);

  static String zoneName(String screenZone) =>
      screenZone == 'L' ? 'left' : (screenZone == 'R' ? 'right' : 'middle');
}

class TennisReplay {
  final List<String> players;
  final List<TennisShot> shots;

  /// Games won, by player index.
  final List<int> games;

  /// Points in the current game, by player index.
  final List<int> points;
  final int server;

  /// Who hits the next shot.
  final int hitter;

  /// Set when the match is over (2 games, or a resignation).
  final int? winner;
  final bool byResignation;

  /// Final points of every finished game, e.g. [[4, 2], [1, 4]].
  final List<List<int>> finishedGames;

  const TennisReplay({
    required this.players,
    required this.shots,
    required this.games,
    required this.points,
    required this.server,
    required this.hitter,
    required this.winner,
    required this.byResignation,
    required this.finishedGames,
  });

  bool get isOver => winner != null;
  int get receiver => 1 - hitter;
  TennisShot? get lastShot => shots.isEmpty ? null : shots.last;

  int indexOf(String uid) => players.indexOf(uid);

  /// [history] entries are {uid: storedZone}; a missing uid = timed out.
  static TennisReplay of(
    List<String> players,
    List<Map<String, String>> history, {
    String? resignedBy,
  }) {
    final games = [0, 0];
    final points = [0, 0];
    final shots = <TennisShot>[];
    final finished = <List<int>>[];
    var server = 0;
    var hitter = 0;
    int? winner;

    for (final entry in history) {
      if (winner != null) break;
      final aim = entry[players[hitter]];
      final guess = entry[players[1 - hitter]];
      final TennisShotResult result;
      if (!TennisMatch.isZone(aim)) {
        result = TennisShotResult.fault;
      } else if (!TennisMatch.isZone(guess)) {
        result = TennisShotResult.noReturn;
      } else if (aim == guess) {
        result = TennisShotResult.returned;
      } else {
        result = TennisShotResult.winner;
      }
      final shot = TennisShot(
        hitter,
        TennisMatch.isZone(aim) ? aim : null,
        TennisMatch.isZone(guess) ? guess : null,
        result,
      );
      shots.add(shot);

      final pointTo = shot.pointTo;
      if (pointTo == null) {
        hitter = 1 - hitter;
        continue;
      }
      points[pointTo]++;
      final p = points[pointTo];
      final o = points[1 - pointTo];
      if (p >= 4 && p - o >= 2) {
        finished.add(List.of(points));
        games[pointTo]++;
        points[0] = 0;
        points[1] = 0;
        if (games[pointTo] >= TennisMatch.gamesToWin) {
          winner = pointTo;
          break;
        }
        server = 1 - server;
      }
      hitter = server;
    }

    var resigned = false;
    if (winner == null && resignedBy != null && players.contains(resignedBy)) {
      winner = 1 - players.indexOf(resignedBy);
      resigned = true;
    }

    return TennisReplay(
      players: players,
      shots: shots,
      games: games,
      points: points,
      server: server,
      hitter: hitter,
      winner: winner,
      byResignation: resigned,
      finishedGames: finished,
    );
  }

  /// "15", "40", "Deuce", "Ad" style call for the current game, from
  /// [viewer]'s side: (mine, theirs).
  (String, String) pointCall(int viewer) {
    final me = points[viewer];
    final them = points[1 - viewer];
    if (me >= 3 && them >= 3) {
      if (me == them) return ('Deuce', 'Deuce');
      return me > them ? ('Ad', '40') : ('40', 'Ad');
    }
    const calls = ['0', '15', '30', '40'];
    return (calls[me.clamp(0, 3)], calls[them.clamp(0, 3)]);
  }
}
