// lib/feature/games/chat_games/chess/chess_board.dart

import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import 'chess_engine.dart';

/// Tap a piece, then a highlighted square. [flipped] puts black at the
/// bottom. Calls [onMove] with a legal move (promotion chosen in a dialog).
class ChessBoard extends StatefulWidget {
  final ChessPosition position;
  final bool flipped;

  /// Only the side to move can be picked up, and only when true.
  final bool interactive;
  final ChessMove? lastMove;
  final ValueChanged<ChessMove> onMove;

  const ChessBoard({
    super.key,
    required this.position,
    required this.flipped,
    required this.interactive,
    required this.onMove,
    this.lastMove,
  });

  static const Color _light = Color(0xFFF3EAFF);
  static const Color _dark = Color(0xFF9A7BD9);

  static const Map<String, String> _names = {
    'k': 'king',
    'q': 'queen',
    'r': 'rook',
    'b': 'bishop',
    'n': 'knight',
    'p': 'pawn',
  };

  static String pieceName(String piece) =>
      '${Chess.isWhite(piece) ? 'white' : 'black'} '
      '${_names[piece.toLowerCase()]}';

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard>
    with SingleTickerProviderStateMixin {
  int? _selected;

  /// Slides the piece of the latest move from its old square to the new one.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  ChessMove? _sliding;

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved = oldWidget.position.toFen() != widget.position.toFen();
    if (moved || !widget.interactive) _selected = null;
    final last = widget.lastMove;
    if (moved && last != null && last != oldWidget.lastMove) {
      _sliding = last;
      if (MediaQuery.disableAnimationsOf(context)) {
        _slide.value = 1;
      } else {
        _slide.forward(from: 0);
      }
    }
  }

  /// Top-left of [sq] inside the board, in squares.
  Offset _cell(int sq) {
    final file = sq % 8;
    final rank = sq ~/ 8;
    return widget.flipped
        ? Offset((7 - file).toDouble(), rank.toDouble())
        : Offset(file.toDouble(), (7 - rank).toDouble());
  }

  List<ChessMove> get _legal =>
      widget.interactive ? Chess.legalMoves(widget.position) : const [];

  Future<void> _tap(int sq) async {
    if (!widget.interactive) return;
    final legal = _legal;
    final piece = widget.position.board[sq];
    final ownPiece =
        piece != null && Chess.isWhite(piece) == widget.position.whiteToMove;

    final from = _selected;
    if (from != null) {
      final options = legal.where((m) => m.from == from && m.to == sq).toList();
      if (options.isNotEmpty) {
        setState(() => _selected = null);
        if (options.length == 1) {
          widget.onMove(options.first);
          return;
        }
        final promo = await _askPromotion();
        if (promo == null || !mounted) return;
        widget.onMove(options.firstWhere((m) => m.promotion == promo));
        return;
      }
    }
    setState(() {
      _selected = ownPiece && legal.any((m) => m.from == sq) && sq != from
          ? sq
          : null;
    });
  }

  Future<String?> _askPromotion() {
    final white = widget.position.whiteToMove;
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text(
          'Promote to',
          style: TextStyle(color: AppColors.white),
        ),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final p in const ['q', 'r', 'b', 'n'])
                Semantics(
                  button: true,
                  label: ChessBoard.pieceName(white ? p.toUpperCase() : p),
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, p),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _Piece(
                        piece: white ? p.toUpperCase() : p,
                        size: 44,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.position;
    final legal = _selected == null ? const <ChessMove>[] : _legal;
    final targets = {
      for (final m in legal)
        if (m.from == _selected) m.to,
    };
    final checkSq = Chess.inCheck(pos)
        ? Chess.kingSquare(pos.board, pos.whiteToMove)
        : null;
    final last = widget.lastMove;

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = (box.maxWidth - 12) / 8;
          return Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFFB794FF), Color(0xFF5B2FB0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Column(
                    children: [
                      for (var row = 0; row < 8; row++)
                        Row(
                          children: [
                            for (var col = 0; col < 8; col++)
                              _square(
                                widget.flipped
                                    ? row * 8 + (7 - col)
                                    : (7 - row) * 8 + col,
                                size,
                                targets: targets,
                                checkSq: checkSq,
                                last: last,
                                showFile: row == 7,
                                showRank: col == 0,
                              ),
                          ],
                        ),
                    ],
                  ),
                  _slidingPiece(size),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _slidingPiece(double size) {
    final m = _sliding;
    final piece = m == null ? null : widget.position.board[m.to];
    if (m == null || piece == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, _) {
        if (_slide.value >= 1) return const SizedBox.shrink();
        final t = Curves.easeOutCubic.transform(_slide.value);
        final p = Offset.lerp(_cell(m.from), _cell(m.to), t)! * size;
        return Positioned(
          left: p.dx,
          top: p.dy,
          width: size,
          height: size,
          child: IgnorePointer(
            child: Center(
              child: Transform.scale(
                scale: 1 + 0.18 * (1 - (2 * t - 1).abs()),
                child: _Piece(piece: piece, size: size),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _square(
    int sq,
    double size, {
    required Set<int> targets,
    required int? checkSq,
    required ChessMove? last,
    required bool showFile,
    required bool showRank,
  }) {
    final piece = widget.position.board[sq];
    final light = (sq % 8 + sq ~/ 8) % 2 == 1;
    final base = light ? ChessBoard._light : ChessBoard._dark;
    final isTarget = targets.contains(sq);
    final name = ChessMove.squareName(sq);

    Color? overlay;
    if (sq == _selected) {
      overlay = AppColors.brandPink.withOpacity(0.55);
    } else if (sq == checkSq) {
      overlay = AppColors.error.withOpacity(0.6);
    } else if (last != null && (sq == last.from || sq == last.to)) {
      overlay = AppColors.gold.withOpacity(0.4);
    }
    final labelColor = light ? ChessBoard._dark : ChessBoard._light;

    return Semantics(
      button: widget.interactive,
      selected: sq == _selected,
      label:
          '$name${piece == null ? '' : ', ${ChessBoard.pieceName(piece)}'}'
          '${isTarget ? ', can move here' : ''}',
      excludeSemantics: true,
      onTap: widget.interactive ? () => _tap(sq) : null,
      child: GestureDetector(
        onTap: () => _tap(sq),
        child: Container(
          width: size,
          height: size,
          color: base,
          child: Stack(
            children: [
              if (overlay != null)
                Positioned.fill(
                  child:
                      sq == checkSq && !MediaQuery.disableAnimationsOf(context)
                      ? ColoredBox(color: overlay)
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .fade(begin: 0.45, end: 1, duration: 600.ms)
                      : ColoredBox(color: overlay),
                ),
              if (showFile)
                Positioned(
                  right: 2,
                  bottom: 0,
                  child: Text(
                    name[0],
                    style: TextStyle(color: labelColor, fontSize: size * 0.2),
                  ),
                ),
              if (showRank)
                Positioned(
                  left: 2,
                  top: 0,
                  child: Text(
                    name[1],
                    style: TextStyle(color: labelColor, fontSize: size * 0.2),
                  ),
                ),
              if (piece != null)
                AnimatedBuilder(
                  animation: _slide,
                  builder: (context, child) => Opacity(
                    opacity: _sliding?.to == sq && _slide.value < 1 ? 0 : 1,
                    child: child,
                  ),
                  child: Center(
                    child: AnimatedScale(
                      scale: sq == _selected ? 1.14 : 1,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutBack,
                      child: Container(
                        decoration: sq == _selected
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              )
                            : null,
                        child: _Piece(piece: piece, size: size),
                      ),
                    ),
                  ),
                ),
              if (isTarget)
                Center(
                  child: Container(
                    width: piece == null ? size * 0.3 : size * 0.9,
                    height: piece == null ? size * 0.3 : size * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: piece == null
                          ? Colors.black.withOpacity(0.25)
                          : null,
                      border: piece == null
                          ? null
                          : Border.all(
                              color: Colors.black.withOpacity(0.35),
                              width: size * 0.07,
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Piece extends StatelessWidget {
  final String piece;
  final double size;

  const _Piece({required this.piece, required this.size});

  @override
  Widget build(BuildContext context) {
    final s = size * 0.9;
    switch (piece) {
      case 'K':
        return WhiteKing(size: s);
      case 'Q':
        return WhiteQueen(size: s);
      case 'R':
        return WhiteRook(size: s);
      case 'B':
        return WhiteBishop(size: s);
      case 'N':
        return WhiteKnight(size: s);
      case 'P':
        return WhitePawn(size: s);
      case 'k':
        return BlackKing(size: s);
      case 'q':
        return BlackQueen(size: s);
      case 'r':
        return BlackRook(size: s);
      case 'b':
        return BlackBishop(size: s);
      case 'n':
        return BlackKnight(size: s);
      default:
        return BlackPawn(size: s);
    }
  }
}
