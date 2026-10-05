// lib/feature/games/chat_games/tennis/tennis_screen.dart
//
// Tennis Duel with a match: 30 seconds per shot; whoever runs out of time
// loses the point.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../models/user_model.dart';
import '../../ludo/audio.dart';
import '../chat_game_service.dart';
import '../duel/duel_game.dart';
import '../duel/duel_service.dart';
import '../ui/game_fx.dart';
import '../ui/game_motion.dart';
import '../ui/game_ui.dart';
import '../ui/player_info.dart';
import '../widgets/turn_clock.dart';
import 'tennis_court.dart';
import 'tennis_game.dart';
import 'tennis_match.dart';

class TennisScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherName;
  final UserModel? otherUser;

  const TennisScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherName,
    this.otherUser,
  });

  @override
  State<TennisScreen> createState() => _TennisScreenState();
}

class _TennisScreenState extends State<TennisScreen>
    with TurnClockTicker, MyProfile {
  static const GameTheme _theme = GameTheme.tennis;

  final DuelService _service = DuelService(TennisRules.instance);
  late Stream<DuelGame?> _game = _service.watch(widget.conversationId);
  bool _busy = false;

  /// My index in players (0 or 1), set on every build.
  int _myIndex = 0;
  int _heardShots = -1;
  bool _heardEnd = false;

  String? _replayKey;
  TennisReplay? _replay;

  // Replay only when the history changes, not on every rebuild.
  TennisReplay _replayOf(DuelGame g) {
    final key = '${g.gameId}|${g.history.length}|${g.resignedBy}';
    if (key != _replayKey || _replay == null) {
      _replayKey = key;
      _replay = TennisRules.replayOf(g);
    }
    return _replay!;
  }

  void _sounds(TennisReplay r) {
    if (_heardShots >= 0 && r.shots.length > _heardShots) Audio.playMove();
    _heardShots = r.shots.length;
    final me = r.indexOf(myUid);
    if (r.isOver && !_heardEnd && me >= 0) {
      _heardEnd = true;
      r.winner == me ? Audio.playWin() : Audio.playLose();
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
      setState(() {
        _game = _service.watch(widget.conversationId);
        _heardEnd = false;
      });
    }
  }, "Couldn't start the match. Check your connection and try again.");

  Future<void> _join() => _run(
    () => _service.join(widget.conversationId),
    "Couldn't join the match. Try again.",
  );

  Future<void> _pick(String zone) {
    Haptics.selection();
    return _run(
      () => _service.pick(
        convId: widget.conversationId,
        otherUserId: widget.otherUserId,
        pick: TennisMatch.toCourt(zone, _myIndex),
      ),
      "Couldn't send your shot. Try again.",
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
          started ? 'Resign this match?' : 'Cancel this invite?',
          style: const TextStyle(color: AppColors.white),
        ),
        content: Text(
          started
              ? '${widget.otherName} wins if you resign.'
              : 'You can start a new match any time.',
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
      "Couldn't end the match. Try again.",
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DuelGame?>(
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
            !replay.isOver;
        updateClock(running ? game.deadline : null, _timeout);
        if (replay != null) _sounds(replay);

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: gameAppBar(
            context,
            title: 'Tennis Duel',
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
                  constraints: const BoxConstraints(maxWidth: 520),
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

  Widget _body(DuelGame? game, TennisReplay? replay) {
    if (game == null || replay == null || game.status == 'cancelled') {
      return GameIntro(
        theme: _theme,
        title: 'Tennis Duel with ${widget.otherName}',
        subtitle: 'A mind game with real tennis scoring.',
        steps: const [
          HowToStep(
            '🎯',
            'The hitter picks where to aim: left, middle or right.',
          ),
          HowToStep(
            '👟',
            'The other player guesses where to run, at the same '
                'time.',
          ),
          HowToStep(
            '🔁',
            'Guess right and the rally goes on. Wrong? Point to '
                'the hitter.',
          ),
          HowToStep('🏆', '15, 30, 40, deuce. First to 2 games wins.'),
        ],
        busy: _busy,
        onStart: _start,
      );
    }
    if (game.isPlaying && !game.bothJoined && game.history.isEmpty) {
      final waitingForOther = game.joined.contains(myUid);
      return JoinPanel(
        theme: _theme,
        title: 'a Tennis Duel',
        otherName: widget.otherName,
        waitingForOther: waitingForOther,
        busy: _busy,
        onJoin: _join,
        onCancel: waitingForOther
            ? () => _resign(started: false)
            : () => Navigator.of(context).maybePop(),
      );
    }

    final me = replay.indexOf(myUid);
    if (me < 0) return const SizedBox.shrink();
    _myIndex = me;
    final over = !game.isPlaying || replay.isOver;
    final hitting = replay.hitter == me;
    final myCourtPick = game.picks[myUid] as String?;
    final myPick = myCourtPick == null
        ? null
        : TennisMatch.toScreen(myCourtPick, me);
    final canPick = !over && myPick == null && !_busy;
    final last = replay.lastShot;
    final iWon = replay.winner == me;

    return WinCelebration(
      won: over && iWon,
      theme: _theme,
      child: TurnBanner(
        turnKey: replay.shots.length,
        show: !over && myPick == null,
        text: hitting ? 'Your shot!' : 'Read it!',
        theme: _theme,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              clockBuilder(
                (seconds) => _Scoreboard(
                  replay: replay,
                  me: me,
                  otherName: widget.otherName,
                  myAvatar: avatarUrlOf(this.me),
                  otherAvatar: avatarUrlOf(widget.otherUser),
                  secondsLeft: over ? null : seconds,
                ),
              ),
              const SizedBox(height: 12),
              if (last != null) ...[
                RevealToast(
                  key: ValueKey('shot${replay.shots.length}'),
                  theme: _theme,
                  text: _describe(last, me),
                ),
                const SizedBox(height: 12),
              ],
              TennisCourt(
                hitting: hitting,
                canPick: canPick,
                myPick: myPick,
                onPick: _pick,
                shotKey: replay.shots.length,
                lastLanding: last?.aim == null
                    ? null
                    : TennisMatch.toScreen(last!.aim!, me),
                lastReceiver: last?.guess == null
                    ? null
                    : TennisMatch.toScreen(last!.guess!, me),
                lastOnMyHalf: last != null && last.receiver == me,
              ),
              const SizedBox(height: 14),
              if (over)
                _Over(
                  text: _outcome(replay, me),
                  won: iWon,
                  busy: _busy,
                  onPlayAgain: _start,
                )
              else
                GlassPanel(
                  radius: 30,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  borderColor: myPick == null
                      ? _theme.a.withOpacity(0.6)
                      : null,
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      myPick != null
                          ? 'Locked in. Waiting for ${widget.otherName}…'
                          : hitting
                          ? 'You hit. Tap where to aim 🎯'
                          : '${widget.otherName} hits. Tap where to run 👟',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
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

  /// "🎾 Bob aimed left, you ran left: great return!" for the last shot.
  String _describe(TennisShot s, int me) {
    final iHit = s.hitter == me;
    final hitterName = iHit ? 'You' : widget.otherName;
    final receiverName = iHit ? widget.otherName : 'you';
    String side(String? z) =>
        z == null ? '' : TennisMatch.zoneName(TennisMatch.toScreen(z, me));
    switch (s.result) {
      case TennisShotResult.returned:
        return '🎾 $hitterName aimed ${side(s.aim)}, $receiverName got there. '
            'Great return!';
      case TennisShotResult.winner:
        return '🎾 $hitterName aimed ${side(s.aim)}, $receiverName went '
            '${side(s.guess)}. Point ${iHit ? 'you' : widget.otherName}!';
      case TennisShotResult.fault:
        return iHit
            ? "⏱️ You didn't hit in time. Point ${widget.otherName}."
            : "⏱️ ${widget.otherName} didn't hit in time. Point you!";
      case TennisShotResult.noReturn:
        return iHit
            ? "⏱️ ${widget.otherName} didn't move in time. Point you!"
            : "⏱️ You didn't move in time. Point ${widget.otherName}.";
    }
  }

  String _outcome(TennisReplay r, int me) {
    final w = r.winner;
    if (w == null) return 'Match ended.';
    final score = '${r.games[w]}–${r.games[1 - w]}';
    if (r.byResignation) {
      return w == me ? '${widget.otherName} resigned!' : 'You resigned.';
    }
    return w == me
        ? 'Game, set, match! $score'
        : '${widget.otherName} wins $score';
  }
}

/// LED-style scoreboard: avatar, name, games and the point call per player,
/// a ball next to the server and the shot clock.
class _Scoreboard extends StatelessWidget {
  final TennisReplay replay;
  final int me;
  final String otherName;
  final String? myAvatar;
  final String? otherAvatar;
  final int? secondsLeft;

  const _Scoreboard({
    required this.replay,
    required this.me,
    required this.otherName,
    required this.myAvatar,
    required this.otherAvatar,
    required this.secondsLeft,
  });

  @override
  Widget build(BuildContext context) {
    final (mine, theirs) = replay.pointCall(me);
    final seconds = secondsLeft;
    Widget row(String name, String? avatar, int idx, String call) {
      final serving = replay.server == idx && !replay.isOver;
      return Semantics(
        label:
            '$name: ${replay.games[idx]} games, $call'
            '${serving ? ', serving' : ''}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              PlayerBadge(
                name: name,
                imageUrl: avatar,
                theme: GameTheme.tennis,
                size: 36,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                width: 22,
                child: serving
                    ? const Text('🎾', style: TextStyle(fontSize: 15))
                    : null,
              ),
              _Led(text: '${replay.games[idx]}', width: 40),
              const SizedBox(width: 8),
              _Led(text: call, width: 74, accent: true),
            ],
          ),
        ),
      );
    }

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Text('MATCH', style: GameText.caption),
              const Spacer(),
              if (seconds != null)
                Text(
                  '⏱️ 0:${seconds.toString().padLeft(2, '0')}',
                  style: GameText.caption.copyWith(
                    color: seconds <= 10 ? AppColors.error : Colors.white,
                  ),
                ),
              const SizedBox(width: 14),
              const SizedBox(
                width: 40,
                child: Text(
                  'GAMES',
                  textAlign: TextAlign.center,
                  style: GameText.caption,
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 74,
                child: Text(
                  'POINTS',
                  textAlign: TextAlign.center,
                  style: GameText.caption,
                ),
              ),
            ],
          ),
          row(otherName, otherAvatar, 1 - me, theirs),
          row('You', myAvatar, me, mine),
        ],
      ),
    );
  }
}

/// A glowing digital readout.
class _Led extends StatelessWidget {
  final String text;
  final double width;
  final bool accent;

  const _Led({required this.text, required this.width, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final color = accent ? const Color(0xFFD9FF6B) : const Color(0xFFFFD166);
    return Container(
      width: width,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF06140D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()],
          shadows: [Shadow(color: color, blurRadius: 10)],
        ),
      ),
    );
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
      borderColor: GameTheme.tennis.a.withOpacity(0.6),
      child: Column(
        children: [
          ResultHero(
            theme: GameTheme.tennis,
            emoji: won ? '🏆' : '🎾',
            title: text,
            celebrate: won,
          ),
          const SizedBox(height: 18),
          enterFx(
            context,
            GameButton(
              label: 'Play again',
              icon: Icons.refresh,
              theme: GameTheme.tennis,
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
