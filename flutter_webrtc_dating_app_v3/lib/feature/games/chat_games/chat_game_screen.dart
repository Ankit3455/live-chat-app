// lib/feature/games/chat_games/chat_game_screen.dart
//
// One screen for the round games (Build Our Date, Rate It, Red Flag Green
// Flag, Telepathy): intro, rounds (versus bar, flip reveal of the last round,
// the game's picker) and the result. The parts that differ per game come
// from ChatGameView.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../models/user_model.dart';
import '../ludo/audio.dart';
import 'build_our_date/date_cards.dart';
import 'chat_game.dart';
import 'chat_game_service.dart';
import 'chat_game_views.dart';
import 'ui/game_fx.dart';
import 'ui/game_motion.dart';
import 'ui/game_ui.dart';
import 'ui/player_info.dart';
import 'widgets/premium_pickers.dart';
import 'widgets/room_mode.dart';
import 'widgets/turn_clock.dart';

class ChatGameScreen extends StatefulWidget {
  final ChatGameKind kind;
  final String conversationId;
  final String otherUserId;
  final String otherName;
  final UserModel? otherUser;

  /// Random-match room: this player made the room and starts the first game.
  final bool startOnOpen;

  const ChatGameScreen({
    super.key,
    required this.kind,
    required this.conversationId,
    required this.otherUserId,
    required this.otherName,
    this.otherUser,
    this.startOnOpen = false,
  });

  @override
  State<ChatGameScreen> createState() => _ChatGameScreenState();
}

class _ChatGameScreenState extends State<ChatGameScreen>
    with TurnClockTicker, MyProfile, RoomMode {
  final ChatGameService _service = ChatGameService.instance;
  late Stream<ChatGame?> _game = _watch();

  Set<String> _myTags = const {};
  bool _busy = false;
  int _heardRound = -1;
  bool _heardEnd = false;

  ChatGameKind get _kind => widget.kind;

  @override
  String get spaceId => widget.conversationId;
  GameTheme get _theme => GameTheme.of(_kind.name);

  Stream<ChatGame?> _watch() =>
      _service.watch(widget.conversationId, widget.kind);

  @override
  void onProfileLoaded(UserModel profile) {
    _myTags = DateCards.tagsFrom(
      interests: profile.interests,
      habits: profile.habits,
    );
  }

  void _sounds(ChatGame g) {
    if (_heardRound >= 0 && g.round > _heardRound) Audio.playMove();
    _heardRound = g.round;
    if (g.isDone && !_heardEnd) {
      _heardEnd = true;
      Audio.playWin();
    } else if (!g.isDone) {
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
      kind: _kind,
      otherAnswers: {
        'interests': widget.otherUser?.interests ?? const <String>[],
        'habits': widget.otherUser?.habits,
      },
    );
    // The first listen may have been denied before the chat existed.
    if (mounted) setState(() => _game = _watch());
  }, "Couldn't start the game. Check your connection and try again.");

  Future<void> _pick(Object value) {
    Haptics.selection();
    return _run(
      () => _service.pick(
        convId: widget.conversationId,
        otherUserId: widget.otherUserId,
        kind: _kind,
        value: value,
      ),
      "Couldn't save your pick. Try again.",
    );
  }

  Future<void> _join() => _run(
    () => _service.join(widget.conversationId, _kind),
    "Couldn't join the game. Try again.",
  );

  Future<void> _timeout() => _service.timeout(
    convId: widget.conversationId,
    otherUserId: widget.otherUserId,
    kind: _kind,
  );

  Future<void> _endGame() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text(
          'End this game?',
          style: TextStyle(color: AppColors.white),
        ),
        content: const Text(
          'Your picks so far will be lost.',
          style: TextStyle(color: AppColors.lavender),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'End game',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => _service.cancel(widget.conversationId, _kind),
      "Couldn't end the game. Try again.",
    );
  }

  Future<void> _goForReal() async {
    await _run(
      () => _service.sendText(
        widget.conversationId,
        widget.otherUserId,
        'Should we actually go on this date? 😄',
      ),
      "Couldn't send the message. Try again.",
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatGame?>(
      stream: _game,
      builder: (context, snap) {
        final game = snap.data;
        final waiting = snap.connectionState == ConnectionState.waiting;
        updateClock(
          game != null && game.isActive && game.bothJoined
              ? game.deadline
              : null,
          _timeout,
        );
        if (game != null) _sounds(game);
        if (!waiting) {
          roomStep(
            hasGame: game != null,
            bothJoined: game?.bothJoined ?? false,
            needsMyJoin:
                game != null &&
                game.isActive &&
                !game.joined.contains(myUid) &&
                game.createdBy != myUid,
            startOnOpen: widget.startOnOpen,
            start: _start,
            join: _join,
          );
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: gameAppBar(
            context,
            title: _kind.title,
            actions: [
              if (game != null && game.isActive)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'End this game',
                  onPressed: _busy ? null : _endGame,
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
                      : _body(game),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<HowToStep> get _steps {
    switch (_kind) {
      case ChatGameKind.date:
        return const [
          HowToStep('🃏', '5 rounds: vibe, place, food, activity and time.'),
          HowToStep('🤫', 'You both pick a card in secret.'),
          HowToStep('✨', 'Same card = match! Different? A coin decides.'),
          HowToStep('💌', 'Get a date plan you can actually go on.'),
        ];
      case ChatGameKind.rate:
        return const [
          HowToStep('🔢', 'Rate 5 things from 1 to 10.'),
          HowToStep('🤫', 'You both rate in secret.'),
          HowToStep('📊', 'See how close your tastes are.'),
        ];
      case ChatGameKind.flags:
        return const [
          HowToStep('👈', 'Swipe left for a red flag 🚩'),
          HowToStep('👉', 'Swipe right for a green flag 💚'),
          HowToStep('🤝', 'Compare your votes on 5 dating habits.'),
        ];
      case ChatGameKind.telepathy:
        return const [
          HowToStep('🧠', "You're a team. Each round: a word and 9 emojis."),
          HowToStep('🎯', 'Pick the 3 you think your match will pick.'),
          HowToStep('🤐', 'No talking! Every shared emoji is a point.'),
        ];
    }
  }

  Widget _body(ChatGame? game) {
    if (roomSettingUp && (game == null || (game.isActive && !game.bothJoined))) {
      return RoomWaiting(theme: _theme, otherName: widget.otherName);
    }
    if (game == null || game.cancelled) {
      return GameIntro(
        theme: _theme,
        title: '${_kind.title} with ${widget.otherName}',
        subtitle: game?.cancelled ?? false
            ? 'The last game was ended. Start a new one any time.'
            : _kind.tagline,
        steps: _steps,
        busy: _busy,
        onStart: _start,
      );
    }
    if (game.isActive && !game.bothJoined) {
      final waitingForOther = game.joined.contains(myUid);
      return JoinPanel(
        theme: _theme,
        title: _kind.title,
        otherName: widget.otherName,
        waitingForOther: waitingForOther,
        busy: _busy,
        onJoin: _join,
        onCancel: waitingForOther
            ? _endGame
            : () => Navigator.of(context).maybePop(),
        inRoom: inRoom,
      );
    }
    final view = ChatGameView(
      game: game,
      myUid: myUid,
      otherName: widget.otherName,
      busy: _busy,
      myTags: _myTags,
      onPick: _pick,
    );
    if (game.isDone) return _result(view);
    return _roundView(view);
  }

  Widget _roundView(ChatGameView view) {
    final r = view.round;
    final game = view.game;
    final myPicked = view.myPick != null;
    final otherPicked = game.picksFor(r).containsKey(widget.otherUserId);

    return TurnBanner(
      turnKey: r,
      show: true,
      text: r == ChatGame.roundCount - 1 ? 'Last round!' : 'Round ${r + 1}',
      theme: _theme,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            clockBuilder(
              (seconds) => VersusBar(
                theme: _theme,
                left: VersusSide(
                  name: 'You',
                  imageUrl: avatarUrlOf(me),
                  subtitle: myPicked ? 'Picked ✓' : 'Thinking…',
                  active: !myPicked,
                  secondsLeft: seconds,
                ),
                right: VersusSide(
                  name: widget.otherName,
                  imageUrl: avatarUrlOf(widget.otherUser),
                  subtitle: otherPicked ? 'Picked ✓' : 'Thinking…',
                  active: !otherPicked,
                  secondsLeft: seconds,
                ),
                center: _RoundDots(round: r, theme: _theme),
              ),
            ),
            if (r > 0) ...[const SizedBox(height: 12), _reveal(view, r - 1)],
            const SizedBox(height: 18),
            enterFx(
              context,
              Semantics(
                header: true,
                child: Text(
                  view.question(),
                  textAlign: TextAlign.center,
                  style: GameText.display.copyWith(fontSize: 25),
                ),
              ),
              delay: 100.ms,
            ),
            const SizedBox(height: 6),
            Semantics(
              liveRegion: true,
              child: Text(
                myPicked
                    ? 'Locked in. Waiting for ${widget.otherName}…'
                    : otherPicked
                    ? '${widget.otherName} has picked. Your turn!'
                    : view.hint() ?? 'Pick one. ${widget.otherName} picks too.',
                textAlign: TextAlign.center,
                style: GameText.body,
              ),
            ),
            const SizedBox(height: 18),
            KeyedSubtree(key: ValueKey('picker$r'), child: view.picker()),
          ],
        ),
      ),
    );
  }

  Widget _reveal(ChatGameView view, int r) {
    final (mine, theirs, same) = view.revealPair(r);
    return FlipPair(
      key: ValueKey('reveal$r'),
      theme: _theme,
      mine: mine,
      theirs: theirs,
      otherName: widget.otherName,
      verdict: view.reveal(r),
      same: same,
    );
  }

  Widget _result(ChatGameView view) {
    final goForReal = _kind == ChatGameKind.date && !inRoom ? _goForReal : null;
    return WinCelebration(
      won: true,
      theme: _theme,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          children: [
            ResultHero(
              theme: _theme,
              emoji: _resultEmoji,
              title: view.resultTitle(),
              subtitle: view.resultHeadline(),
            ),
            const SizedBox(height: 16),
            enterFx(
              context,
              GlassPanel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PlayerBadge(
                          name: 'You',
                          imageUrl: avatarUrlOf(me),
                          theme: _theme,
                          size: 48,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('💞', style: TextStyle(fontSize: 26)),
                        ),
                        PlayerBadge(
                          name: widget.otherName,
                          imageUrl: avatarUrlOf(widget.otherUser),
                          theme: _theme,
                          size: 48,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    view.resultBody(),
                  ],
                ),
              ),
              delay: 450.ms,
            ),
            const SizedBox(height: 20),
            if (goForReal != null) ...[
              enterFx(
                context,
                GameButton(
                  label: "Let's do this for real",
                  icon: Icons.favorite_rounded,
                  theme: _theme,
                  loading: _busy,
                  onPressed: _busy ? null : goForReal,
                ),
                delay: 600.ms,
              ),
              const SizedBox(height: 12),
            ],
            if (inRoom) ...[
              SayHiButton(
                theme: _theme,
                otherUserId: widget.otherUserId,
                otherName: widget.otherName,
              ),
              const SizedBox(height: 12),
            ],
            enterFx(
              context,
              GameButton(
                label: 'Play again',
                icon: Icons.refresh_rounded,
                theme: _theme,
                secondary: goForReal != null || inRoom,
                onPressed: _busy ? null : _start,
              ),
              delay: 700.ms,
            ),
          ],
        ),
      ),
    );
  }

  String get _resultEmoji {
    switch (_kind) {
      case ChatGameKind.date:
        return '💌';
      case ChatGameKind.rate:
        return '📊';
      case ChatGameKind.flags:
        return '🚩';
      case ChatGameKind.telepathy:
        return '🧠';
    }
  }
}

/// Five segments; done rounds filled, the current one glowing.
class _RoundDots extends StatelessWidget {
  final int round;
  final GameTheme theme;

  const _RoundDots({required this.round, required this.theme});

  @override
  Widget build(BuildContext context) {
    const total = ChatGame.roundCount;
    return Semantics(
      label: 'Round ${round + 1} of $total',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            '${round + 1}/$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < total; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: i == round ? 16 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: i <= round ? theme.gradient : null,
                    color: i <= round ? null : Colors.white.withOpacity(0.18),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
