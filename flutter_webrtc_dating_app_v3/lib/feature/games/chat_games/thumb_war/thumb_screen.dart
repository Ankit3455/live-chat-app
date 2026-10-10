// lib/feature/games/chat_games/thumb_war/thumb_screen.dart
//
// Thumb War with a match, played live: hold anywhere to press. The invite,
// join, give up and result card work like the other duels; the fight runs
// through thumb_live.dart and each finished round is stored as one shot.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../ludo/audio.dart';
import '../chat_game_service.dart';
import '../duel/duel_game.dart';
import '../duel/duel_service.dart';
import '../ui/game_fx.dart';
import '../ui/game_motion.dart';
import '../ui/game_ui.dart';
import '../widgets/game_leave.dart';
import '../widgets/room_mode.dart';
import '../widgets/turn_clock.dart';
import 'thumb_live.dart';
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

class _ThumbScreenState extends State<ThumbScreen> with RoomMode, GameLeave {
  static const GameTheme _theme = GameTheme.thumb;

  final DuelService _service = DuelService(ThumbRules.instance);
  late Stream<DuelGame?> _game = _service.watch(widget.conversationId);

  @override
  String get spaceId => widget.conversationId;
  bool _busy = false;
  bool _heardEnd = false;

  /// The live fight for the running game, and the game it belongs to.
  ThumbLiveMatch? _match;
  String? _matchGameId;
  DuelGame? _latest;

  bool _sendingRound = false;
  Timer? _roundFallback;
  DateTime _nextLeftClaim = DateTime.fromMillisecondsSinceEpoch(0);

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// The live fight for [g], made once per game.
  ThumbLiveMatch _matchFor(DuelGame g) {
    final current = _match;
    if (current != null && _matchGameId == g.gameId) return current;
    _closeMatch();
    final match = ThumbLiveMatch.online(
      gameId: g.gameId,
      players: g.players,
      me: _myUid,
    );
    match
      ..onDown = Audio.playThumbDown
      ..onPin = (_) {
        Audio.playThumbHit();
        Haptics.hit();
      }
      ..onFightCall = Audio.playGong
      ..onRoundOver = (_) {
        Audio.playKo();
        Haptics.warning();
        _sendRounds();
      }
      ..addListener(_onLive);
    _match = match;
    _matchGameId = g.gameId;
    unawaited(match.start());
    return match;
  }

  void _closeMatch() {
    _roundFallback?.cancel();
    _match?.removeListener(_onLive);
    _match?.dispose();
    _match = null;
    _matchGameId = null;
  }

  /// Every live update: store finished rounds, and end the game as left
  /// when the other phone has gone quiet.
  void _onLive() {
    final match = _match;
    if (match == null) return;
    _sendRounds();
    final now = DateTime.now();
    if (match.otherGone && now.isAfter(_nextLeftClaim)) {
      _nextLeftClaim = now.add(const Duration(seconds: 5));
      unawaited(
        _service
            .claimLeft(
              convId: widget.conversationId,
              otherUserId: widget.otherUserId,
            )
            .catchError((Object _) {}),
      );
    }
  }

  /// Stores the next finished round (the winner as both phones saw it). If
  /// the other phone doesn't store its side, the shot is closed with mine.
  void _sendRounds() {
    final game = _latest;
    final match = _match;
    if (game == null || match == null || _sendingRound) return;
    if (!game.isPlaying || game.picks.containsKey(_myUid)) return;
    final done = match.fight.roundWinners;
    final n = game.history.length;
    if (done.length <= n) return;
    _sendingRound = true;
    _service
        .pick(
          convId: widget.conversationId,
          otherUserId: widget.otherUserId,
          pick: done[n],
        )
        .catchError((Object _) {})
        .whenComplete(() {
      _sendingRound = false;
      _roundFallback?.cancel();
      // Retried until the shot closes; the server allows it 30 s after the
      // last round was stored.
      _roundFallback = Timer.periodic(const Duration(seconds: 6), (t) {
        final latest = _latest;
        if (latest == null ||
            !latest.isPlaying ||
            !latest.picks.containsKey(_myUid)) {
          t.cancel();
          return;
        }
        unawaited(
          _service
              .timeout(
                convId: widget.conversationId,
                otherUserId: widget.otherUserId,
              )
              .catchError((Object _) {}),
        );
      });
    });
  }

  void _onGame(DuelGame? game, ThumbReplay? replay) {
    _latest = game;
    final me = replay?.indexOf(_myUid) ?? -1;
    if (replay != null && replay.isOver && !_heardEnd && me >= 0) {
      _heardEnd = true;
      replay.winner == me ? Audio.playWin() : Audio.playLose();
      final match = _match;
      if (match != null && match.isHost) unawaited(match.cleanUp());
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

  Future<void> _leave() => _service.resign(
        convId: widget.conversationId,
        otherUserId: widget.otherUserId,
        left: true,
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
  void dispose() {
    _closeMatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DuelGame?>(
      stream: _game,
      builder: (context, snap) {
        final game = snap.data;
        final waiting = snap.connectionState == ConnectionState.waiting;
        final replay = game == null ? null : ThumbRules.replayOf(game);
        final running = game != null &&
            game.isPlaying &&
            game.bothJoined &&
            replay != null &&
            !replay.isOver;
        _onGame(game, replay);
        updateLeave(
          endsGame: game != null && game.isPlaying && (running || inRoom),
          ask: running,
          leave: _leave,
        );
        if (!waiting) {
          roomStep(
            hasGame: game != null,
            bothJoined: game?.bothJoined ?? false,
            needsMyJoin: game != null &&
                game.isPlaying &&
                !game.joined.contains(_myUid) &&
                game.createdBy != _myUid,
            startOnOpen: widget.startOnOpen,
            start: _start,
            join: _join,
          );
        }

        return leaveScope(
          otherName: widget.otherName,
          leaveMessage: '${widget.otherName} wins if you leave.',
          child: Scaffold(
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
                        : _body(game, replay, running: running),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(DuelGame? game, ThumbReplay? replay, {required bool running}) {
    final leftBy = game?.leftBy;
    if (game != null && !game.isPlaying && leftBy != null && leftBy != _myUid) {
      return LeftPanel(
        theme: _theme,
        otherName: widget.otherName,
        otherUserId: widget.otherUserId,
        competitive: true,
        inRoom: inRoom,
        gameName: ThumbRules.gameName,
        busy: _busy,
        onPlayAgain: _start,
      );
    }
    if (roomSettingUp &&
        (game == null || (game.isPlaying && !game.bothJoined))) {
      return RoomWaiting(
        theme: _theme,
        otherName: widget.otherName,
        otherGone: roomOtherGone,
        gameName: ThumbRules.gameName,
        onLeave: leaveAndPop,
      );
    }
    if (game == null || replay == null || game.status == 'cancelled') {
      return GameIntro(
        theme: _theme,
        title: 'Thumb War with ${widget.otherName}',
        subtitle: 'One, two, three, four… I declare a Thumb War!',
        steps: const [
          HowToStep('👇',
              'Hold anywhere: your thumb goes down and drains their stamina.'),
          HowToStep('💥',
              'Press while their thumb is down to pin it. Every moment pinned costs them HP.'),
          HowToStep('🔋',
              'Pinning burns your stamina. Run dry and they get to pin you.'),
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
    final iWon = replay.winner == me;
    if (!running) {
      _closeMatch();
      return WinCelebration(
        won: iWon,
        theme: _theme,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: _Over(
            text: _outcome(replay, me, left: game.leftBy != null),
            score: '${replay.rounds[me]} – ${replay.rounds[1 - me]}',
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
          ),
        ),
      );
    }

    final match = _matchFor(game);
    final names = [
      for (final uid in game.players) uid == _myUid ? 'You' : widget.otherName,
    ];
    return Column(
      children: [
        Expanded(
          child: ThumbArena(
            match: match,
            names: names,
            hats: ThumbWar.accessoriesFor(game.players),
          ),
        ),
        ListenableBuilder(
          listenable: match,
          builder: (context, _) => match.otherGone
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: OpponentAwayBanner(
                    otherUserId: widget.otherUserId,
                    otherName: widget.otherName,
                    running: true,
                    staleSecondsLeft: null,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 14, top: 4),
          child: Text(
            'Hold anywhere · strike when they are down',
            style: GameText.caption,
          ),
        ),
      ],
    );
  }

  String _outcome(ThumbReplay r, int me, {bool left = false}) {
    final w = r.winner;
    if (w == null) return 'Thumb War ended.';
    if (r.byResignation && left) {
      return w == me ? '${widget.otherName} left the game!' : 'You left.';
    }
    if (r.byResignation) {
      return w == me ? '${widget.otherName} gave up!' : 'You gave up.';
    }
    return w == me ? 'Thumb War champion!' : '${widget.otherName} wins!';
  }
}

class _Over extends StatelessWidget {
  final String text;

  /// Rounds, mine first, e.g. "2 – 1".
  final String score;
  final bool won;
  final bool busy;
  final VoidCallback onPlayAgain;

  /// Shown under the button (e.g. "Say hi" in a random-match room).
  final Widget? extra;

  const _Over({
    required this.text,
    required this.score,
    required this.won,
    required this.busy,
    required this.onPlayAgain,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      borderColor: GameTheme.thumb.a.withValues(alpha: 0.6),
      child: Column(
        children: [
          ResultHero(
            theme: GameTheme.thumb,
            emoji: won ? '👑' : '😵',
            title: text,
            celebrate: won,
          ),
          Text(score, style: GameText.title),
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
