import 'package:availchat/feature/games/chat_games/chess/chess_engine.dart';
import 'package:flutter_test/flutter_test.dart';

// Perft node counts from the Chess Programming Wiki "Perft Results" page.
void main() {
  void perft(String name, String fen, List<int> expected) {
    test('perft: $name', () {
      final p = ChessPosition.fromFen(fen);
      for (var d = 1; d <= expected.length; d++) {
        expect(Chess.perft(p, d), expected[d - 1], reason: '$name depth $d');
      }
    });
  }

  perft('start position', ChessPosition.startFen, [20, 400, 8902]);
  perft(
    'kiwipete (castling, en passant, promotions, pins)',
    'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
    [48, 2039, 97862],
  );
  perft(
    'position 3 (en passant discovered checks)',
    '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1',
    [14, 191, 2812, 43238],
  );
  perft(
    'position 4 (promotion with castling rights)',
    'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1',
    [6, 264, 9467],
  );
  perft(
    'position 5',
    'rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8',
    [44, 1486, 62379],
  );

  test('FEN round trip', () {
    const fens = [
      ChessPosition.startFen,
      'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
      '8/8/8/8/8/8/8/K6k b - - 12 40',
    ];
    for (final f in fens) {
      expect(ChessPosition.fromFen(f).toFen(), f);
    }
  });

  test("fool's mate is checkmate, black wins", () {
    final r = ChessReplay.of(['f2f3', 'e7e5', 'g2g4', 'd8h4']);
    expect(r.end, ChessEnd.checkmate);
    expect(r.whiteWon, isFalse);
    expect(r.illegalAt, isNull);
  });

  test('an illegal move is caught and later moves ignored', () {
    final r = ChessReplay.of(['e2e4', 'e7e5', 'e1e3', 'd7d6']);
    expect(r.illegalAt, 2);
    expect(r.moves.length, 2);
    expect(ChessReplay.of(['e2e9']).illegalAt, 0);
    expect(ChessReplay.of(['e7e5']).illegalAt, 0, reason: 'black cannot start');
  });

  test('no moves are accepted after checkmate', () {
    final r = ChessReplay.of(['f2f3', 'e7e5', 'g2g4', 'd8h4', 'a2a3']);
    expect(r.end, ChessEnd.checkmate);
    expect(r.illegalAt, 4);
  });

  test('threefold repetition is a draw', () {
    final r = ChessReplay.of([
      'g1f3', 'g8f6', 'f3g1', 'f6g8', //
      'g1f3', 'g8f6', 'f3g1', 'f6g8',
    ]);
    expect(r.end, ChessEnd.repetition);
    expect(r.whiteWon, isNull);
  });

  test('stalemate and insufficient material are draws', () {
    final stale = ChessPosition.fromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
    expect(Chess.legalMoves(stale), isEmpty);
    expect(Chess.inCheck(stale), isFalse);
    expect(
      Chess.insufficientMaterial(
        ChessPosition.fromFen('8/8/8/8/8/8/8/K6k w - - 0 1').board,
      ),
      isTrue,
    );
    expect(
      Chess.insufficientMaterial(
        ChessPosition.fromFen('8/8/8/8/8/8/8/KN5k w - - 0 1').board,
      ),
      isTrue,
    );
    expect(
      Chess.insufficientMaterial(
        ChessPosition.fromFen('8/8/8/8/8/8/8/KR5k w - - 0 1').board,
      ),
      isFalse,
    );
  });

  test('castling moves the rook and clears the rights', () {
    var p = ChessPosition.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
    p = Chess.apply(p, ChessMove.parse('e1g1')!);
    expect(p.board[ChessMove.parseSquare('f1')!], 'R');
    expect(p.board[ChessMove.parseSquare('h1')!], isNull);
    expect(p.castling, 'kq');
  });

  test('en passant removes the passed pawn', () {
    var p = ChessPosition.fromFen('4k3/3p4/8/4P3/8/8/8/4K3 b - - 0 1');
    p = Chess.apply(p, ChessMove.parse('d7d5')!);
    expect(p.epSquare, ChessMove.parseSquare('d6'));
    final ep = ChessMove.parse('e5d6')!;
    expect(Chess.isLegal(p, ep), isTrue);
    p = Chess.apply(p, ep);
    expect(p.board[ChessMove.parseSquare('d5')!], isNull);
    expect(p.board[ChessMove.parseSquare('d6')!], 'P');
  });

  test('resignation ends the game for the other side', () {
    final r = ChessReplay.of(['e2e4'], resignedByWhite: false);
    expect(r.end, ChessEnd.resignation);
    expect(r.whiteWon, isTrue);
  });

  test('a timed-out turn passes to the other side', () {
    final r = ChessReplay.of(['e2e4', '0000', 'd2d4']);
    expect(r.illegalAt, isNull);
    expect(r.lastWasPass, isFalse);
    expect(r.position.whiteToMove, isFalse);
    expect(r.moves[1], isNull);
    expect(ChessReplay.of(['e2e4', '0000']).lastWasPass, isTrue);
  });

  test('timing out while in check loses the game', () {
    // 1.e4 f6 2.Qh5+ and black runs out of time in check.
    final r = ChessReplay.of(['e2e4', 'f7f6', 'd1h5', '0000']);
    expect(r.end, ChessEnd.timeout);
    expect(r.whiteWon, isTrue);
    expect(
      ChessReplay.of(['e2e4', 'f7f6', 'd1h5', '0000', 'a7a6']).illegalAt,
      4,
    );
  });
}
