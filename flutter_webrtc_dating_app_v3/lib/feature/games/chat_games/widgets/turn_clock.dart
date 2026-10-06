// lib/feature/games/chat_games/widgets/turn_clock.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../services/presence_watch.dart';
import '../chat_game.dart';
import '../ui/game_ui.dart';

/// Ticks once a second while a 30 s clock runs. The expiry action runs only
/// on the phone whose clock it is ([updateClock] isMineOverdue: my move or
/// my pick is missing), so a player who left stops moving the game on. When
/// only the other player is overdue and the clock is
/// [TurnClock.staleSeconds] old, the stale action ends the game as left.
/// The server checks the time again, so a phone with a fast clock just gets
/// denied and retries a little later.
///
/// A tick doesn't rebuild the screen: wrap only the widgets that show the
/// time in [clockBuilder].
mixin TurnClockTicker<T extends StatefulWidget> on State<T> {
  static const Duration _grace = Duration(seconds: 1);
  static const Duration _retryAfter = Duration(seconds: 3);
  static const Duration _staleAfterDeadline = Duration(
    seconds: TurnClock.staleSeconds - TurnClock.seconds,
  );

  Timer? _ticker;
  final ValueNotifier<int> _clockTick = ValueNotifier<int>(0);
  DateTime? _deadline;
  bool _mineOverdue = true;
  Future<void> Function()? _onExpired;
  Future<void> Function()? _onStale;
  bool _expiring = false;
  DateTime _nextTry = DateTime.fromMillisecondsSinceEpoch(0);

  /// Seconds left on the running clock; null if no clock is running.
  int? get clockSecondsLeft => TurnClock.secondsLeft(_deadline, DateTime.now());

  /// While only the other player is past the deadline: seconds until the
  /// game can be ended as left by them. Null otherwise.
  int? get staleSecondsLeft {
    final deadline = _deadline;
    final now = DateTime.now();
    if (deadline == null || _mineOverdue || now.isBefore(deadline)) {
      return null;
    }
    return TurnClock.secondsLeft(deadline.add(_staleAfterDeadline), now);
  }

  /// Call from build with the current deadline (null = no clock).
  /// [isMineOverdue]: the running clock is waiting for me, so I time it out.
  void updateClock(
    DateTime? deadline,
    Future<void> Function() onExpired, {
    required bool isMineOverdue,
    Future<void> Function()? onStale,
  }) {
    _deadline = deadline;
    _mineOverdue = isMineOverdue;
    _onExpired = onExpired;
    _onStale = onStale;
  }

  /// Rebuilds [builder] with [clockSecondsLeft] on every tick.
  Widget clockBuilder(Widget Function(int? secondsLeft) builder) {
    return ValueListenableBuilder<int>(
      valueListenable: _clockTick,
      builder: (context, _, __) => builder(clockSecondsLeft),
    );
  }

  /// "Bob isn't responding… 0:24" / "Bob went offline" while a clock runs;
  /// empty while the other player is fine.
  Widget awayBanner({required String otherUserId, required String otherName}) {
    return clockBuilder(
      (_) => OpponentAwayBanner(
        otherUserId: otherUserId,
        otherName: otherName,
        running: _deadline != null,
        staleSecondsLeft: staleSecondsLeft,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final deadline = _deadline;
    if (!mounted || deadline == null) return;
    _clockTick.value++;
    final now = DateTime.now();
    final due = _mineOverdue ? deadline : deadline.add(_staleAfterDeadline);
    if (_expiring || now.isBefore(due.add(_grace)) || now.isBefore(_nextTry)) {
      return;
    }
    final action = _mineOverdue ? _onExpired : _onStale;
    if (action == null) return;
    _expiring = true;
    _nextTry = now.add(_retryAfter);
    action().catchError((Object _) {}).whenComplete(() => _expiring = false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clockTick.dispose();
    super.dispose();
  }
}

/// Warns that the other player isn't playing: offline (RTDB presence explicitly offline, a UI
/// hint only) or past the deadline, with the time until the game ends.
class OpponentAwayBanner extends StatefulWidget {
  final String otherUserId;
  final String otherName;

  /// A turn / round clock is running.
  final bool running;

  /// Set while only the other player is overdue (see
  /// [TurnClockTicker.staleSecondsLeft]).
  final int? staleSecondsLeft;

  const OpponentAwayBanner({
    super.key,
    required this.otherUserId,
    required this.otherName,
    required this.running,
    required this.staleSecondsLeft,
  });

  @override
  State<OpponentAwayBanner> createState() => _OpponentAwayBannerState();
}

class _OpponentAwayBannerState extends State<OpponentAwayBanner> {
  StreamSubscription<bool>? _presence;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    if (widget.otherUserId.isEmpty) return;
    _presence = PresenceWatch.instance.watchGone(widget.otherUserId).listen((
      gone,
    ) {
      if (mounted && _offline != gone) setState(() => _offline = gone);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _presence?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.staleSecondsLeft;
    if (!widget.running || (left == null && !_offline)) {
      return const SizedBox.shrink();
    }
    final name = widget.otherName;
    final String text;
    if (left == null) {
      text = '$name went offline. Waiting for them to come back…';
    } else {
      final time = '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
      text = _offline
          ? '$name went offline… $time'
          : "$name isn't responding… $time";
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        liveRegion: true,
        child: GlassPanel(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          borderColor: AppColors.warning.withValues(alpha: 0.7),
          child: Row(
            children: [
              Icon(
                _offline ? Icons.wifi_off_rounded : Icons.hourglass_bottom,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
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

/// "⏱️ 0:18", red in the last 10 seconds.
class ClockChip extends StatelessWidget {
  final int seconds;

  /// Whose clock it is, e.g. "Your turn" or "Bob".
  final String? label;

  const ClockChip({super.key, required this.seconds, this.label});

  @override
  Widget build(BuildContext context) {
    final low = seconds <= 10;
    final text = '0:${seconds.toString().padLeft(2, '0')}';
    return Semantics(
      label: '${label == null ? '' : '$label, '}$seconds seconds left',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (low ? AppColors.error : AppColors.brandPurpleLight)
              .withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: low ? AppColors.error : AppColors.brandPurpleLight,
          ),
        ),
        child: Text(
          '⏱️ ${label == null ? '' : '$label · '}$text',
          style: TextStyle(
            color: low ? AppColors.error : AppColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Shown while the second player hasn't joined yet.
class JoinPanel extends StatelessWidget {
  final GameTheme theme;
  final String title;
  final String otherName;

  /// True on the inviter's phone: waiting for the other player.
  final bool waitingForOther;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onCancel;

  /// A random-match room has no chat to accept the invite in.
  final bool inRoom;

  const JoinPanel({
    super.key,
    required this.theme,
    required this.title,
    required this.otherName,
    required this.waitingForOther,
    required this.busy,
    required this.onJoin,
    required this.onCancel,
    this.inRoom = false,
  });

  @override
  Widget build(BuildContext context) {
    final orb = GameOrb(theme: theme);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
      child: Column(
        children: [
          if (waitingForOther && !MediaQuery.disableAnimationsOf(context))
            RepaintBoundary(
              child: RepaintBoundary(child: orb)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(
                    end: 1.06,
                    duration: 900.ms,
                    curve: Curves.easeInOut,
                  ),
            )
          else
            orb,
          const SizedBox(height: 26),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              waitingForOther
                  ? 'Waiting for $otherName…'
                  : '$otherName invited you to $title',
              textAlign: TextAlign.center,
              style: GameText.display,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            waitingForOther
                ? (inRoom
                      ? 'The game starts when $otherName joins.'
                      : 'The game starts when $otherName accepts the invite '
                            'in your chat.')
                : 'Every turn has ${TurnClock.seconds} seconds. If time runs '
                      'out, the turn passes. Ready?',
            textAlign: TextAlign.center,
            style: GameText.body,
          ),
          const SizedBox(height: 18),
          GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${TurnClock.seconds}s per turn · live game',
                  style: GameText.caption.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (!waitingForOther)
            GameButton(
              label: 'Join game',
              icon: Icons.play_arrow_rounded,
              theme: theme,
              loading: busy,
              onPressed: busy ? null : onJoin,
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: busy ? null : onCancel,
            child: Text(
              waitingForOther ? 'Cancel invite' : 'Not now',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
