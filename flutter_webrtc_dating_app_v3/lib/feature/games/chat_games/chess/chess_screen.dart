// lib/feature/games/chat_games/chess/chess_screen.dart
//
// Live chess with a match: 30 seconds per move; when time runs out the turn
// passes (or, in check, the game is lost on time).

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../models/user_model.dart';
import '../../../../widgets/app_states.dart';
import '../../ludo/audio.dart';
import '../chat_game.dart';
import '../chat_game_service.dart';
import '../ui/game_fx.dart';
import '../ui/game_motion.dart';
import '../ui/game_ui.dart';
import '../ui/player_info.dart';
import '../widgets/turn_clock.dart';
import 'chess_board.dart';
import 'chess_engine.dart';
import 'chess_game.dart';
import 'chess_service.dart';

class ChessScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherName;
  final UserModel? otherUser;

  const ChessScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherName,
    this.otherUser,
  });

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen>
    with TurnClockTicker, MyProfile {
  static const GameTheme _theme = GameTheme.chess;

  final ChessService _service = ChessService.instance;
  late Stream<ChessGame?> _game = _service.watch(widget.conversationId);
  bool _busy = false;

  // The replay only changes when the move list does; the clock rebuilds the
  // screen every second.
  String? _replayKey;
  ChessReplay? _replay;
  int _heardMoves = -1;
  bool _heardEnd = false;

  ChessReplay _replayOf(ChessGame g) {
    final key = '${g.gameId}|${g.moves.length}|${g.resignedBy}';
    if (key != _replayKey || _replay == null) {
      _replayKey = key;
      _replay = g.replay;
    }
    return _replay!;
  }

  /// Move sound on every new move, win/lose sound once at the end.
  void _sounds(ChessGame g, ChessReplay r) {
    if (_heardMoves >= 0 && g.moves.length > _heardMoves) Audio.playMove();
    _heardMoves = g.moves.length;
    if (r.isOver && !_heardEnd && r.whiteWon != null) {
      _heardEnd = true;
      final iWon = r.whiteWon! == g.isWhite(myUid);
      iWon ? Audio.playWin() : Audio.playLose();
    } else if (!r.isOver) {
      _heardEnd = false;
    }
  }

  Future<void> _run(Future<void> Function() action, String failMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on ChatGameException catch (e) {
      _snack(e.message);
    } catch (_) {
      Haptics.error();
      _snack(failMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _start() => _run(() async {
    await _service.start(
      convId: widget.conversationId,
      otherUserId: widget.otherUserId,
    );
    // The first listen may have been denied before the chat existed.
    if (mounted) {
      setState(() => _game = _service.watch(widget.conversationId));
    }
  }, "Couldn't start the game. Check your connection and try again.");

  Future<void> _join() => _run(
    () => _service.join(widget.conversationId),
    "Couldn't join the game. Try again.",
  );

  Future<void> _move(ChessMove m) {
    Haptics.selection();
    return _run(
      () => _service.move(
        convId: widget.conversationId,
        otherUserId: widget.otherUserId,
        move: m,
      ),
      "Couldn't send your move. Try again.",
    );
  }

  Future<void> _timeout() => _service.timeout(
    convId: widget.conversationId,
    otherUserId: widget.otherUserId,
  );

  Future<void> _resign({required bool started}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: Text(
          started ? 'Resign this game?' : 'Cancel this invite?',
          style: const TextStyle(color: AppColors.white),
        ),
        content: Text(
          started
              ? '${widget.otherName} wins if you resign.'
              : 'You can start a new game any time.',
          style: const TextStyle(color: AppColors.lavender),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              started ? 'Resign' : 'Cancel invite',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => _service.resign(
        convId: widget.conversationId,
        otherUserId: widget.otherUserId,
        postResult: started,
      ),
      "Couldn't end the game. Try again.",
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChessGame?>(
      stream: _game,
      builder: (context, snap) {
        final game = snap.data;
        final waiting = snap.connectionState == ConnectionState.waiting;
        final replay = game == null ? null : _replayOf(game);
        final running =
            game != null &&
            game.isPlaying &&
            game.bothJoined &&
            replay != null &&
            !replay.isOver &&
            replay.illegalAt == null;
        updateClock(running ? game.deadline : null, _timeout);
        if (game != null && replay != null) _sounds(game, replay);

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: gameAppBar(
            context,
            title: ChessGame.title,
            actions: [
              if (running)
                IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  tooltip: 'Resign',
                  onPressed: _busy ? null : () => _resign(started: true),
                ),
            ],
          ),
          body: GameBackdrop(
            theme: _theme,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: waiting
                      ? const Center(child: CircularProgressIndicator())
                      : _body(game, replay),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(ChessGame? game, ChessReplay? replay) {
    if (game == null || replay == null || game.status == 'cancelled') {
      return GameIntro(
        theme: _theme,
        title: 'Chess with ${widget.otherName}',
        subtitle: 'Classic chess, played live in your chat.',
        steps: const [
          HowToStep('🎲', 'Colours are picked at random. White moves first.'),
          HowToStep('👆', 'Tap a piece, then a glowing square to move it.'),
          HowToStep(
            '⏱️',
            '${TurnClock.seconds} seconds per move, or your turn passes.',
          ),
          HowToStep('👑', 'Checkmate wins. Stalemate and repetition draw.'),
        ],
        busy: _busy,
        onStart: _start,
      );
    }
    if (game.isPlaying && !game.bothJoined && game.moves.isEmpty) {
      final waitingForOther = game.joined.contains(myUid);
      return JoinPanel(
        theme: _theme,
        title: 'a game of chess',
        otherName: widget.otherName,
        waitingForOther: waitingForOther,
        busy: _busy,
        onJoin: _join,
        onCancel: waitingForOther
            ? () => _resign(started: false)
            : () => Navigator.of(context).maybePop(),
      );
    }

    final iAmWhite = game.isWhite(myUid);
    final over = !game.isPlaying || replay.isOver;
    final myTurn =
        !over &&
        replay.illegalAt == null &&
        game.turn == myUid &&
        replay.position.whiteToMove == iAmWhite;
    final seconds = clockSecondsLeft;
    final iWon = replay.whiteWon != null && replay.whiteWon == iAmWhite;

    return WinCelebration(
      won: over && iWon,
      theme: _theme,
      child: TurnBanner(
        turnKey: game.moves.length,
        show: myTurn,
        theme: _theme,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VersusBar(
                theme: _theme,
                left: VersusSide(
                  name: 'You',
                  imageUrl: avatarUrlOf(me),
                  subtitle: iAmWhite ? 'White' : 'Black',
                  active: myTurn,
                  secondsLeft: seconds,
                ),
                right: VersusSide(
                  name: widget.otherName,
                  imageUrl: avatarUrlOf(widget.otherUser),
                  subtitle: iAmWhite ? 'Black' : 'White',
                  active: !over && !myTurn,
                  secondsLeft: seconds,
                ),
              ),
              const SizedBox(height: 16),
              ChessBoard(
                position: replay.position,
                flipped: !iAmWhite,
                interactive: myTurn && !_busy,
                lastMove: replay.lastMove,
                onMove: _move,
              ),
              const SizedBox(height: 16),
              if (replay.illegalAt != null)
                const AppBanner(
                  tone: AppBannerTone.warning,
                  message:
                      "This game has an invalid move and can't continue. "
                      'Resign to start a new one.',
                )
              else if (over)
                _Over(
                  text: _outcome(game, replay),
                  won: iWon,
                  busy: _busy,
                  onPlayAgain: _start,
                )
              else
                _StatusPill(
                  key: ValueKey(game.moves.length),
                  text: _status(replay, myTurn),
                  highlight: myTurn,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _status(ChessReplay replay, bool myTurn) {
    final check = Chess.inCheck(replay.position);
    final passed = replay.lastWasPass
        ? (myTurn
              ? '⏱️ ${widget.otherName} ran out of time. '
              : '⏱️ You ran out of time. ')
        : '';
    if (myTurn) return '$passed${check ? 'Check! ' : ''}Your move';
    return '$passed${check ? 'Check! ' : ''}${widget.otherName} is thinking…';
  }

  String _outcome(ChessGame game, ChessReplay replay) {
    final end = replay.end;
    if (end == null) return 'Game ended.';
    final whiteWon = replay.whiteWon;
    final winner = whiteWon == null
        ? null
        : (whiteWon ? game.white : game.black);
    return ChessGame.outcomeFor(
      viewer: myUid,
      otherName: widget.otherName,
      end: end,
      winner: winner,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final bool highlight;

  const _StatusPill({super.key, required this.text, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final pill = GlassPanel(
      radius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      borderColor: highlight ? GameTheme.chess.a.withOpacity(0.7) : null,
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return pill;
    return pill.animate().fadeIn(duration: 250.ms).slideY(begin: 0.3, end: 0);
  }
}

class _Over extends StatelessWidget {
  final String text;
  final bool won;
  final bool busy;
  final VoidCallback onPlayAgain;

  const _Over({
    required this.text,
    required this.won,
    required this.busy,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      borderColor: GameTheme.chess.a.withOpacity(0.6),
      child: Column(
        children: [
          ResultHero(
            theme: GameTheme.chess,
            emoji: won ? '🏆' : '🤝',
            title: text,
            celebrate: won,
          ),
          const SizedBox(height: 18),
          enterFx(
            context,
            GameButton(
              label: 'Play again',
              icon: Icons.refresh,
              theme: GameTheme.chess,
              loading: busy,
              onPressed: busy ? null : onPlayAgain,
            ),
            delay: 500.ms,
          ),
        ],
      ),
    );
  }
}
