// lib/feature/games/chat_games/thumb_war/thumb_screen.dart
//
// Thumb War with a match: each clash pick Pounce / Guard / Feint, then stop
// the grip gauge. 30 seconds per clash; no pick in time = pinned.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../ludo/audio.dart';
import '../chat_game.dart';
import '../chat_game_service.dart';
import '../duel/duel_game.dart';
import '../duel/duel_service.dart';
import '../ui/game_fx.dart';
import '../ui/game_motion.dart';
import '../ui/game_ui.dart';
import '../widgets/room_mode.dart';
import '../widgets/turn_clock.dart';
import 'thumb_rules.dart';
import 'thumb_war.dart';
import 'thumb_widgets.dart';

class ThumbScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherName;

  /// Random-match room: this player made the room and starts the first game.
  final bool startOnOpen;

  const ThumbScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherName,
    this.startOnOpen = false,
  });

  @override
  State<ThumbScreen> createState() => _ThumbScreenState();
}

class _ThumbScreenState extends State<ThumbScreen> with TurnClockTicker, RoomMode {
  static const GameTheme _theme = GameTheme.thumb;

  final DuelService _service = DuelService(ThumbRules.instance);
  late Stream<DuelGame?> _game = _service.watch(widget.conversationId);

  @override
  String get spaceId => widget.conversationId;
  bool _busy = false;

  /// Move chosen for this clash, before the grip gauge is stopped.
  ThumbMove? _move;
  int _seenClashes = -1;
  bool _heardEnd = false;

  /// Per player index: bumps when they land / take a hit (drives animations).
  final List<int> _strikeKeys = [0, 0];
  final List<int> _hitKeys = [0, 0];
  int _lastDamage = 0;

  String? _replayKey;
  ThumbReplay? _replay;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  ThumbReplay _replayOf(DuelGame g) {
    final key = '${g.gameId}|${g.history.length}|${g.resignedBy}';
    if (key != _replayKey || _replay == null) {
      _replayKey = key;
      _replay = ThumbRules.replayOf(g);
    }
    return _replay!;
  }

  /// A new clash arrived: forget the chosen move, animate the hit, play sounds.
  void _onClashes(ThumbReplay r) {
    final count = r.clashes.length;
    if (count == _seenClashes) return;
    final first = _seenClashes < 0;
    _seenClashes = count;
    _move = null;
    if (first) return;
    final last = r.lastClash;
    final w = last?.winner;
    if (last != null && w != null) {
      _strikeKeys[w]++;
      _hitKeys[1 - w]++;
      _lastDamage = last.damage;
      Haptics.medium();
    }
    Audio.playMove();
    final me = r.indexOf(_myUid);
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
  }, "Couldn't start the Thumb War. Check your connection and try again.");

  Future<void> _join() => _run(
    () => _service.join(widget.conversationId),
    "Couldn't join. Try again.",
  );

  Future<void> _grip(int power) {
    final move = _move;
    if (move == null) return Future.value();
    Haptics.medium();
    return _run(
      () => _service.pick(
        convId: widget.conversationId,
        otherUserId: widget.otherUserId,
        pick: ThumbPick(move, power).toMap(),
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
          started ? 'Give up this Thumb War?' : 'Cancel this invite?',
          style: const TextStyle(color: AppColors.white),
        ),
        content: Text(
          started
              ? '${widget.otherName} wins if you give up.'
              : 'You can start a new one any time.',
          style: const TextStyle(color: AppColors.lavender),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep fighting'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              started ? 'Give up' : 'Cancel invite',
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
        if (!waiting) {
          roomStep(
            hasGame: game != null,
            bothJoined: game?.bothJoined ?? false,
            needsMyJoin:
                game != null &&
                game.isPlaying &&
                !game.joined.contains(_myUid) &&
                game.createdBy != _myUid,
            startOnOpen: widget.startOnOpen,
            start: _start,
            join: _join,
          );
        }
        if (replay != null) _onClashes(replay);

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: gameAppBar(
            context,
            title: ThumbRules.displayTitle,
            actions: [
              if (running)
                IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  tooltip: 'Give up',
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

  Widget _body(DuelGame? game, ThumbReplay? replay) {
    if (roomSettingUp &&
        (game == null || (game.isPlaying && !game.bothJoined))) {
      return RoomWaiting(theme: _theme, otherName: widget.otherName);
    }
    if (game == null || replay == null || game.status == 'cancelled') {
      return GameIntro(
        theme: _theme,
        title: 'Thumb War with ${widget.otherName}',
        subtitle: 'One, two, three, four… I declare a Thumb War!',
        steps: const [
          HowToStep(
            '⚡',
            'Pounce beats Feint. Feint beats Guard. Guard beats '
                'Pounce.',
          ),
          HowToStep('🎯', 'Stop the grip gauge in the green for a harder hit.'),
          HowToStep(
            '⏱️',
            '${TurnClock.seconds} seconds per clash, or you get '
                'pinned.',
          ),
          HowToStep('❤️', 'Knock them to 0 HP. First to 2 rounds wins.'),
        ],
        buttonLabel: "Let's fight",
        busy: _busy,
        onStart: _start,
      );
    }
    if (game.isPlaying && !game.bothJoined && game.history.isEmpty) {
      final waitingForOther = game.joined.contains(_myUid);
      return JoinPanel(
        theme: _theme,
        title: 'a Thumb War',
        otherName: widget.otherName,
        waitingForOther: waitingForOther,
        busy: _busy,
        onJoin: _join,
        onCancel: waitingForOther
            ? () => _resign(started: false)
            : () => Navigator.of(context).maybePop(),
        inRoom: inRoom,
      );
    }

    final me = replay.indexOf(_myUid);
    if (me < 0) return const SizedBox.shrink();
    final them = 1 - me;
    final over = !game.isPlaying || replay.isOver;
    final myPick = ThumbPick.parse(game.picks[_myUid]);
    final last = replay.lastClash;
    final looks = ThumbWar.accessoriesFor(replay.players);
    final iWon = replay.winner == me;
    // Built here so a clock tick rebuilding the arena reuses them as is.
    final topFighter = ThumbFighter(
      name: widget.otherName,
      accessory: looks[them],
      hp: replay.hp[them],
      roundsWon: replay.rounds[them],
      top: true,
      color: const Color(0xFF8B7BFF),
      strikeKey: _strikeKeys[them],
      hitKey: _hitKeys[them],
      lastDamage: _lastDamage,
    );
    final bottomFighter = ThumbFighter(
      name: 'You',
      accessory: looks[me],
      hp: replay.hp[me],
      roundsWon: replay.rounds[me],
      top: false,
      color: _theme.b,
      strikeKey: _strikeKeys[me],
      hitKey: _hitKeys[me],
      lastDamage: _lastDamage,
    );

    return WinCelebration(
      won: over && iWon,
      theme: _theme,
      child: TurnBanner(
        turnKey: replay.clashes.length,
        show: !over && myPick == null,
        text: 'Fight!',
        theme: _theme,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              clockBuilder(
                (seconds) => _Arena(
                  round: replay.round,
                  over: over,
                  secondsLeft: seconds,
                  top: topFighter,
                  bottom: bottomFighter,
                ),
              ),
              const SizedBox(height: 14),
              RevealToast(
                key: ValueKey('clash${replay.clashes.length}'),
                theme: _theme,
                text: last == null
                    ? 'Round ${replay.round}. One, two, three, four… fight!'
                    : _describe(last, me),
              ),
              const SizedBox(height: 18),
              if (over)
                _Over(
                  text: _outcome(replay, me),
                  won: iWon,
                  busy: _busy,
                  onPlayAgain: _start,
                  extra: inRoom
                      ? SayHiButton(
                          theme: _theme,
                          otherUserId: widget.otherUserId,
                          otherName: widget.otherName,
                          secondary: true,
                        )
                      : null,
                )
              else if (myPick != null)
                GlassPanel(
                  radius: 30,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Text(
                    'Locked in: ${myPick.move.emoji} ${myPick.move.label} · '
                    'grip ${myPick.power}\nWaiting for ${widget.otherName}…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                )
              else
                _picker(replay),
            ],
          ),
        ),
      ),
    );
  }

  Widget _picker(ThumbReplay replay) {
    final move = _move;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          move == null ? 'Pick your move' : 'Now stop the gauge in the green!',
          textAlign: TextAlign.center,
          style: GameText.title,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final m in ThumbMove.values) ...[
              if (m != ThumbMove.values.first) const SizedBox(width: 10),
              Expanded(
                child: MoveCard(
                  move: m,
                  theme: _theme,
                  selected: move == m,
                  dimmed: move != null && move != m,
                  onTap: _busy ? null : () => setState(() => _move = m),
                ),
              ),
            ],
          ],
        ),
        if (move != null) ...[
          const SizedBox(height: 18),
          enterFx(
            context,
            GripGauge(
              key: ValueKey('grip-${replay.clashes.length}'),
              enabled: !_busy,
              theme: _theme,
              onStop: _grip,
            ),
          ),
        ],
      ],
    );
  }

  /// "Your ⚡ Pounce beat Bob's 🌀 Feint! -27 HP" for the last clash.
  String _describe(ThumbClash c, int me) {
    final mine = c.picks[me];
    final theirs = c.picks[1 - me];
    final other = widget.otherName;
    String tail() => c.endedRound
        ? (c.winner == me ? ' Round to you! 👑' : ' Round to $other.')
        : '';
    if (c.timeout) {
      if (mine == null && theirs == null) {
        return '⏱️ Nobody moved. Shake it out!';
      }
      return mine == null
          ? '⏱️ Too slow! $other pinned you. -${c.damage} HP${tail()}'
          : '⏱️ $other froze. You pinned them! -${c.damage} HP${tail()}';
    }
    final a = '${mine!.move.emoji} ${mine.move.label}';
    final b = '${theirs!.move.emoji} ${theirs.move.label}';
    if (c.winner == null) return "Your $a met $other's $b. Dead even!";
    if (c.sameMove) {
      return c.winner == me
          ? 'Both went $a. Your grip ${mine.power} beat ${theirs.power}! '
                '-${c.damage} HP${tail()}'
          : "Both went $a. $other's grip ${theirs.power} beat ${mine.power}. "
                '-${c.damage} HP${tail()}';
    }
    return c.winner == me
        ? "Your $a beat $other's $b! -${c.damage} HP${tail()}"
        : "$other's $b beat your $a. -${c.damage} HP${tail()}";
  }

  String _outcome(ThumbReplay r, int me) {
    final w = r.winner;
    if (w == null) return 'Thumb War ended.';
    if (r.byResignation) {
      return w == me ? '${widget.otherName} gave up!' : 'You gave up.';
    }
    return w == me ? 'Thumb War champion!' : '${widget.otherName} wins!';
  }
}

/// The ring: spotlight, round badge and the two fighters.
class _Arena extends StatelessWidget {
  final int round;
  final bool over;
  final int? secondsLeft;
  final Widget top;
  final Widget bottom;

  const _Arena({
    required this.round,
    required this.over,
    required this.secondsLeft,
    required this.top,
    required this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final seconds = secondsLeft;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.10),
                      Colors.transparent,
                    ],
                    radius: 0.7,
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              top,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(color: Colors.white.withOpacity(0.15)),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: GameTheme.thumb.gradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        over
                            ? 'FINAL'
                            : 'ROUND $round${seconds == null ? '' : '  ·  0:${seconds.toString().padLeft(2, '0')}'}',
                        style: TextStyle(
                          color: seconds != null && seconds <= 10
                              ? const Color(0xFFFFE0E6)
                              : Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: Colors.white.withOpacity(0.15)),
                    ),
                  ],
                ),
              ),
              bottom,
            ],
          ),
        ],
      ),
    );
  }
}

class _Over extends StatelessWidget {
  final String text;
  final bool won;
  final bool busy;
  final VoidCallback onPlayAgain;

  /// Shown under the button (e.g. "Say hi" in a random-match room).
  final Widget? extra;

  const _Over({
    required this.text,
    required this.won,
    required this.busy,
    required this.onPlayAgain,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      borderColor: GameTheme.thumb.a.withOpacity(0.6),
      child: Column(
        children: [
          ResultHero(
            theme: GameTheme.thumb,
            emoji: won ? '👑' : '😵',
            title: text,
            celebrate: won,
          ),
          const SizedBox(height: 18),
          enterFx(
            context,
            GameButton(
              label: 'Rematch',
              icon: Icons.refresh,
              theme: GameTheme.thumb,
              loading: busy,
              onPressed: busy ? null : onPlayAgain,
            ),
            delay: 500.ms,
          ),
          if (extra != null) ...[const SizedBox(height: 12), extra!],
        ],
      ),
    );
  }
}
