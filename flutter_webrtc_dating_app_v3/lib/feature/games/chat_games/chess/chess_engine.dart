// lib/feature/games/chat_games/chess/chess_engine.dart
//
// A small, complete chess rules engine: legal moves (castling, en passant,
// promotion), check, checkmate, stalemate and automatic draws (insufficient
// material, 50-move rule, threefold repetition). Verified with perft tests.
// Squares are 0..63 with a1 = 0, h1 = 7, a8 = 56. Pieces are FEN letters,
// upper case = white. Pure Dart so it can be unit tested.

class ChessMove {
  final int from;
  final int to;

  /// Lower-case 'q', 'r', 'b' or 'n' when a pawn promotes.
  final String? promotion;

  const ChessMove(this.from, this.to, [this.promotion]);

  static const String _files = 'abcdefgh';

  static String squareName(int sq) => '${_files[sq % 8]}${sq ~/ 8 + 1}';

  static int? parseSquare(String s) {
    if (s.length != 2) return null;
    final f = _files.indexOf(s[0]);
    final r = int.tryParse(s[1]);
    if (f < 0 || r == null || r < 1 || r > 8) return null;
    return (r - 1) * 8 + f;
  }

  /// Written when a player's time runs out: the turn passes.
  static const String pass = '0000';

  /// e.g. "e2e4", "e7e8q".
  String get uci => '${squareName(from)}${squareName(to)}${promotion ?? ''}';

  static final RegExp uciPattern = RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$');

  static ChessMove? parse(String uci) {
    if (!uciPattern.hasMatch(uci)) return null;
    final from = parseSquare(uci.substring(0, 2))!;
    final to = parseSquare(uci.substring(2, 4))!;
    return ChessMove(from, to, uci.length == 5 ? uci[4] : null);
  }

  @override
  bool operator ==(Object other) =>
      other is ChessMove &&
      other.from == from &&
      other.to == to &&
      other.promotion == promotion;

  @override
  int get hashCode => Object.hash(from, to, promotion);

  @override
  String toString() => uci;
}

class ChessPosition {
  /// 64 squares, null = empty.
  final List<String?> board;
  final bool whiteToMove;

  /// Subset of "KQkq".
  final String castling;
  final int? epSquare;
  final int halfmove;
  final int fullmove;

  const ChessPosition({
    required this.board,
    required this.whiteToMove,
    required this.castling,
    required this.epSquare,
    required this.halfmove,
    required this.fullmove,
  });

  static const String startFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  static ChessPosition initial() => fromFen(startFen);

  static ChessPosition fromFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    final board = List<String?>.filled(64, null);
    final rows = parts[0].split('/');
    for (var i = 0; i < 8; i++) {
      final rank = 7 - i;
      var file = 0;
      for (final ch in rows[i].split('')) {
        final n = int.tryParse(ch);
        if (n != null) {
          file += n;
        } else {
          board[rank * 8 + file] = ch;
          file++;
        }
      }
    }
    return ChessPosition(
      board: board,
      whiteToMove: parts.length < 2 || parts[1] == 'w',
      castling: parts.length < 3 || parts[2] == '-' ? '' : parts[2],
      epSquare: parts.length < 4 || parts[3] == '-'
          ? null
          : ChessMove.parseSquare(parts[3]),
      halfmove: parts.length < 5 ? 0 : int.tryParse(parts[4]) ?? 0,
      fullmove: parts.length < 6 ? 1 : int.tryParse(parts[5]) ?? 1,
    );
  }

  String toFen() => '$repetitionKey $halfmove $fullmove';

  /// Placement, side, castling and en passant: equal keys = same position
  /// for the repetition rule.
  String get repetitionKey {
    final rows = <String>[];
    for (var rank = 7; rank >= 0; rank--) {
      var row = '';
      var empty = 0;
      for (var file = 0; file < 8; file++) {
        final p = board[rank * 8 + file];
        if (p == null) {
          empty++;
        } else {
          if (empty > 0) row += '$empty';
          empty = 0;
          row += p;
        }
      }
      if (empty > 0) row += '$empty';
      rows.add(row);
    }
    final ep = epSquare == null ? '-' : ChessMove.squareName(epSquare!);
    return '${rows.join('/')} ${whiteToMove ? 'w' : 'b'} '
        '${castling.isEmpty ? '-' : castling} $ep';
  }
}

enum ChessEnd {
  checkmate,
  stalemate,
  insufficientMaterial,
  fiftyMoves,
  repetition,
  resignation,

  /// Time ran out while in check, so the turn could not pass.
  timeout,
}

class Chess {
  Chess._();

  static bool isWhite(String p) => p.toUpperCase() == p;

  static int _file(int sq) => sq % 8;
  static int _rank(int sq) => sq ~/ 8;

  static int? _offset(int sq, int df, int dr) {
    final f = _file(sq) + df;
    final r = _rank(sq) + dr;
    if (f < 0 || f > 7 || r < 0 || r > 7) return null;
    return r * 8 + f;
  }

  static const List<List<int>> _knight = [
    [1, 2],
    [2, 1],
    [2, -1],
    [1, -2],
    [-1, -2],
    [-2, -1],
    [-2, 1],
    [-1, 2],
  ];
  static const List<List<int>> _kingDirs = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
    [1, 1],
    [1, -1],
    [-1, 1],
    [-1, -1],
  ];
  static const List<List<int>> _rookDirs = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];
  static const List<List<int>> _bishopDirs = [
    [1, 1],
    [1, -1],
    [-1, 1],
    [-1, -1],
  ];

  /// True if [sq] is attacked by the side [byWhite].
  static bool isAttacked(List<String?> board, int sq, bool byWhite) {
    // Pawns: a white pawn attacks up, so look one rank down from [sq].
    final pawnDr = byWhite ? -1 : 1;
    for (final df in const [-1, 1]) {
      final s = _offset(sq, df, pawnDr);
      if (s != null && board[s] == (byWhite ? 'P' : 'p')) return true;
    }
    for (final d in _knight) {
      final s = _offset(sq, d[0], d[1]);
      if (s != null && board[s] == (byWhite ? 'N' : 'n')) return true;
    }
    for (final d in _kingDirs) {
      final s = _offset(sq, d[0], d[1]);
      if (s != null && board[s] == (byWhite ? 'K' : 'k')) return true;
    }
    bool slide(List<List<int>> dirs, String a, String b) {
      for (final d in dirs) {
        var s = _offset(sq, d[0], d[1]);
        while (s != null) {
          final p = board[s];
          if (p != null) {
            if (p == a || p == b) return true;
            break;
          }
          s = _offset(s, d[0], d[1]);
        }
      }
      return false;
    }

    return slide(_rookDirs, byWhite ? 'R' : 'r', byWhite ? 'Q' : 'q') ||
        slide(_bishopDirs, byWhite ? 'B' : 'b', byWhite ? 'Q' : 'q');
  }

  static int? kingSquare(List<String?> board, bool white) {
    final k = white ? 'K' : 'k';
    for (var i = 0; i < 64; i++) {
      if (board[i] == k) return i;
    }
    return null;
  }

  static bool inCheck(ChessPosition p) {
    final k = kingSquare(p.board, p.whiteToMove);
    return k != null && isAttacked(p.board, k, !p.whiteToMove);
  }

  static List<ChessMove> _pseudoMoves(ChessPosition p) {
    final moves = <ChessMove>[];
    final white = p.whiteToMove;
    final b = p.board;

    bool own(String? q) => q != null && isWhite(q) == white;
    bool enemy(String? q) => q != null && isWhite(q) != white;

    for (var sq = 0; sq < 64; sq++) {
      final piece = b[sq];
      if (piece == null || isWhite(piece) != white) continue;
      switch (piece.toLowerCase()) {
        case 'p':
          final dir = white ? 1 : -1;
          final startRank = white ? 1 : 6;
          final lastRank = white ? 7 : 0;
          void addPawn(int to) {
            if (_rank(to) == lastRank) {
              for (final promo in const ['q', 'r', 'b', 'n']) {
                moves.add(ChessMove(sq, to, promo));
              }
            } else {
              moves.add(ChessMove(sq, to));
            }
          }

          final one = _offset(sq, 0, dir);
          if (one != null && b[one] == null) {
            addPawn(one);
            final two = _offset(sq, 0, 2 * dir);
            if (_rank(sq) == startRank && two != null && b[two] == null) {
              moves.add(ChessMove(sq, two));
            }
          }
          for (final df in const [-1, 1]) {
            final t = _offset(sq, df, dir);
            if (t == null) continue;
            if (enemy(b[t])) {
              addPawn(t);
            } else if (t == p.epSquare) {
              moves.add(ChessMove(sq, t));
            }
          }
          break;
        case 'n':
          for (final d in _knight) {
            final t = _offset(sq, d[0], d[1]);
            if (t != null && !own(b[t])) moves.add(ChessMove(sq, t));
          }
          break;
        case 'k':
          for (final d in _kingDirs) {
            final t = _offset(sq, d[0], d[1]);
            if (t != null && !own(b[t])) moves.add(ChessMove(sq, t));
          }
          _addCastling(p, sq, moves);
          break;
        default:
          final lower = piece.toLowerCase();
          final dirs = lower == 'r'
              ? _rookDirs
              : lower == 'b'
              ? _bishopDirs
              : [..._rookDirs, ..._bishopDirs];
          for (final d in dirs) {
            var t = _offset(sq, d[0], d[1]);
            while (t != null) {
              if (own(b[t])) break;
              moves.add(ChessMove(sq, t));
              if (b[t] != null) break;
              t = _offset(t, d[0], d[1]);
            }
          }
      }
    }
    return moves;
  }

  static void _addCastling(ChessPosition p, int kingSq, List<ChessMove> out) {
    final white = p.whiteToMove;
    final home = white ? 4 : 60;
    if (kingSq != home) return;
    final b = p.board;
    final enemyWhite = !white;
    bool safe(int s) => !isAttacked(b, s, enemyWhite);
    final rook = white ? 'R' : 'r';
    if (p.castling.contains(white ? 'K' : 'k') &&
        b[home + 3] == rook &&
        b[home + 1] == null &&
        b[home + 2] == null &&
        safe(home) &&
        safe(home + 1) &&
        safe(home + 2)) {
      out.add(ChessMove(home, home + 2));
    }
    if (p.castling.contains(white ? 'Q' : 'q') &&
        b[home - 4] == rook &&
        b[home - 1] == null &&
        b[home - 2] == null &&
        b[home - 3] == null &&
        safe(home) &&
        safe(home - 1) &&
        safe(home - 2)) {
      out.add(ChessMove(home, home - 2));
    }
  }

  /// Plays [m] without checking legality.
  static ChessPosition apply(ChessPosition p, ChessMove m) {
    final b = List<String?>.of(p.board);
    final piece = b[m.from]!;
    final white = isWhite(piece);
    final lower = piece.toLowerCase();
    final captured = b[m.to];
    var castling = p.castling;
    int? ep;

    b[m.to] = m.promotion == null
        ? piece
        : (white ? m.promotion!.toUpperCase() : m.promotion!);
    b[m.from] = null;

    var isCapture = captured != null;
    if (lower == 'p') {
      if (m.to == p.epSquare && captured == null) {
        b[m.to + (white ? -8 : 8)] = null;
        isCapture = true;
      }
      if ((m.to - m.from).abs() == 16) ep = (m.from + m.to) ~/ 2;
    }
    if (lower == 'k') {
      if (m.to - m.from == 2) {
        b[m.from + 1] = b[m.from + 3];
        b[m.from + 3] = null;
      } else if (m.from - m.to == 2) {
        b[m.from - 1] = b[m.from - 4];
        b[m.from - 4] = null;
      }
      castling = castling.replaceAll(
        white ? RegExp('[KQ]') : RegExp('[kq]'),
        '',
      );
    }
    String drop(String rights, int sq) {
      switch (sq) {
        case 0:
          return rights.replaceAll('Q', '');
        case 7:
          return rights.replaceAll('K', '');
        case 56:
          return rights.replaceAll('q', '');
        case 63:
          return rights.replaceAll('k', '');
      }
      return rights;
    }

    castling = drop(drop(castling, m.from), m.to);

    return ChessPosition(
      board: b,
      whiteToMove: !p.whiteToMove,
      castling: castling,
      epSquare: ep,
      halfmove: lower == 'p' || isCapture ? 0 : p.halfmove + 1,
      fullmove: p.whiteToMove ? p.fullmove : p.fullmove + 1,
    );
  }

  /// The same position with the other side to move (a timed-out turn).
  static ChessPosition passTurn(ChessPosition p) => ChessPosition(
    board: p.board,
    whiteToMove: !p.whiteToMove,
    castling: p.castling,
    epSquare: null,
    halfmove: p.halfmove + 1,
    fullmove: p.whiteToMove ? p.fullmove : p.fullmove + 1,
  );

  static List<ChessMove> legalMoves(ChessPosition p) {
    return [
      for (final m in _pseudoMoves(p))
        if (!_leavesKingInCheck(p, m)) m,
    ];
  }

  static bool _leavesKingInCheck(ChessPosition p, ChessMove m) {
    final next = apply(p, m);
    final k = kingSquare(next.board, p.whiteToMove);
    return k == null || isAttacked(next.board, k, !p.whiteToMove);
  }

  static bool isLegal(ChessPosition p, ChessMove m) =>
      legalMoves(p).contains(m);

  static bool insufficientMaterial(List<String?> board) {
    final others = <String>[];
    final bishopColors = <int>{};
    for (var sq = 0; sq < 64; sq++) {
      final q = board[sq];
      if (q == null || q.toLowerCase() == 'k') continue;
      others.add(q.toLowerCase());
      if (q.toLowerCase() == 'b') bishopColors.add((_file(sq) + _rank(sq)) % 2);
    }
    if (others.isEmpty) return true;
    if (others.length == 1 && (others[0] == 'b' || others[0] == 'n')) {
      return true;
    }
    // Only bishops, all on the same colour.
    return others.every((q) => q == 'b') && bishopColors.length == 1;
  }

  /// Node count for move-generator tests.
  static int perft(ChessPosition p, int depth) {
    if (depth == 0) return 1;
    final moves = legalMoves(p);
    if (depth == 1) return moves.length;
    var n = 0;
    for (final m in moves) {
      n += perft(apply(p, m), depth - 1);
    }
    return n;
  }
}

/// A game rebuilt from its move list. Both phones replay the stored moves,
/// so a forged or illegal move is caught instead of trusted.
/// [ChessMove.pass] entries are timed-out turns.
class ChessReplay {
  final ChessPosition position;

  /// Played moves; a timed-out turn is null.
  final List<ChessMove?> moves;

  /// Index of the first illegal move, if any (moves after it are ignored).
  final int? illegalAt;
  final ChessEnd? end;

  /// true = white won, false = black won, null = draw or not over.
  final bool? whiteWon;

  const ChessReplay({
    required this.position,
    required this.moves,
    required this.illegalAt,
    required this.end,
    required this.whiteWon,
  });

  bool get isOver => end != null;
  ChessMove? get lastMove => moves.isEmpty ? null : moves.last;

  /// True if the last turn timed out and passed.
  bool get lastWasPass => moves.isNotEmpty && moves.last == null;

  static ChessReplay of(List<String> uci, {bool? resignedByWhite}) {
    var pos = ChessPosition.initial();
    final played = <ChessMove?>[];
    final seen = <String, int>{pos.repetitionKey: 1};
    int? illegalAt;
    ChessEnd? end;
    bool? whiteWon;

    for (var i = 0; i < uci.length; i++) {
      if (uci[i] == ChessMove.pass && end == null) {
        if (Chess.inCheck(pos)) {
          end = ChessEnd.timeout;
          whiteWon = !pos.whiteToMove;
          played.add(null);
          continue;
        }
        pos = Chess.passTurn(pos);
        played.add(null);
        final key = pos.repetitionKey;
        seen[key] = (seen[key] ?? 0) + 1;
        continue;
      }
      final m = ChessMove.parse(uci[i]);
      if (m == null || end != null || !Chess.isLegal(pos, m)) {
        illegalAt = i;
        break;
      }
      pos = Chess.apply(pos, m);
      played.add(m);
      final key = pos.repetitionKey;
      seen[key] = (seen[key] ?? 0) + 1;

      final noMoves = Chess.legalMoves(pos).isEmpty;
      if (noMoves && Chess.inCheck(pos)) {
        end = ChessEnd.checkmate;
        whiteWon = !pos.whiteToMove;
      } else if (noMoves) {
        end = ChessEnd.stalemate;
      } else if (Chess.insufficientMaterial(pos.board)) {
        end = ChessEnd.insufficientMaterial;
      } else if (seen[key]! >= 3) {
        end = ChessEnd.repetition;
      } else if (pos.halfmove >= 100) {
        end = ChessEnd.fiftyMoves;
      }
    }

    if (end == null && resignedByWhite != null) {
      end = ChessEnd.resignation;
      whiteWon = !resignedByWhite;
    }
    return ChessReplay(
      position: pos,
      moves: played,
      illegalAt: illegalAt,
      end: end,
      whiteWon: whiteWon,
    );
  }
}
