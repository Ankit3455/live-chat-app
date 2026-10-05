import 'package:availchat/feature/games/chat_games/chat_game_logic.dart';
import 'package:availchat/feature/games/chat_games/chess/chess_engine.dart';
import 'package:availchat/feature/games/chat_games/chess/chess_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChessGame game(List<String> moves, {String? resignedBy}) =>
      ChessGame.fromMap({
        'gameId': 'g1',
        'players': ['bob', 'alice'],
        'createdBy': 'alice',
        'status': 'playing',
        'moves': moves,
        'resignedBy': resignedBy,
        'joined': ['alice', 'bob'],
        'turnStartedAt': DateTime(2026, 1, 1, 12),
      })!;

  test('players are [white, black] and turns alternate', () {
    final g = game(const []);
    expect(g.white, 'bob');
    expect(g.isWhite('bob'), isTrue);
    expect(g.turn, 'bob');
    expect(game(const ['e2e4']).turn, 'alice');
    expect(
      game(const ['e2e4', '0000']).turn,
      'bob',
      reason: 'a pass is a turn',
    );
    expect(g.otherOf('bob'), 'alice');
    expect(g.bothJoined, isTrue);
    expect(g.deadline, DateTime(2026, 1, 1, 12, 0, 30));
  });

  test('resignation makes the other player the winner', () {
    final r = game(const ['e2e4'], resignedBy: 'bob').replay;
    expect(r.end, ChessEnd.resignation);
    expect(r.whiteWon, isFalse);
  });

  test('result messages carry the reason and winner', () {
    final m = ChessGame.result(ChessEnd.checkmate, 'alice');
    expect(m.metadata, {
      'game': 'chess',
      'stage': ChatGameLogic.resultStage,
      'reason': 'checkmate',
      'winner': 'alice',
    });
    final draw = ChessGame.result(ChessEnd.stalemate, null);
    expect(draw.metadata.containsKey('winner'), isFalse);
    expect(draw.text, contains('stalemate'));
    expect(ChessGame.invite().metadata['stage'], ChatGameLogic.inviteStage);
  });

  test('outcome lines read right for each player', () {
    String line(String viewer, ChessEnd end, String? winner) =>
        ChessGame.outcomeFor(
          viewer: viewer,
          otherName: 'Bob',
          end: end,
          winner: winner,
        );
    expect(line('alice', ChessEnd.checkmate, 'alice'), 'Checkmate! You win 🎉');
    expect(line('alice', ChessEnd.checkmate, 'bob'), 'Bob wins by checkmate.');
    expect(
      line('alice', ChessEnd.resignation, 'alice'),
      contains('Bob resigned'),
    );
    expect(
      line('alice', ChessEnd.timeout, 'bob'),
      'You ran out of time in check.',
    );
    expect(line('alice', ChessEnd.repetition, null), 'Draw by repetition');
    expect(ChessGame.endByName('timeout'), ChessEnd.timeout);
    expect(ChessGame.endByName('nope'), isNull);
  });
}
