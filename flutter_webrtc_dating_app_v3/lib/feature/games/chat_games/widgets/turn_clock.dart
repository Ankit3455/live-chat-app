// lib/feature/games/chat_games/widgets/turn_clock.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../chat_game.dart';
import '../ui/game_ui.dart';

/// Ticks once a second while a 30 s clock runs, and calls the expiry action
/// once the deadline has passed. The server checks the time again, so a
/// phone with a fast clock just gets denied and retries a little later.
mixin TurnClockTicker<T extends StatefulWidget> on State<T> {
  static const Duration _grace = Duration(seconds: 1);
  static const Duration _retryAfter = Duration(seconds: 3);

  Timer? _ticker;
  DateTime? _deadline;
  Future<void> Function()? _onExpired;
  bool _expiring = false;
  DateTime _nextTry = DateTime.fromMillisecondsSinceEpoch(0);

  /// Seconds left on the running clock; null if no clock is running.
  int? get clockSecondsLeft => TurnClock.secondsLeft(_deadline, DateTime.now());

  /// Call from build with the current deadline (null = no clock).
  void updateClock(DateTime? deadline, Future<void> Function() onExpired) {
    _deadline = deadline;
    _onExpired = onExpired;
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final deadline = _deadline;
    if (!mounted || deadline == null) return;
    setState(() {});
    final now = DateTime.now();
    if (_expiring ||
        now.isBefore(deadline.add(_grace)) ||
        now.isBefore(_nextTry)) {
      return;
    }
    final action = _onExpired;
    if (action == null) return;
    _expiring = true;
    _nextTry = now.add(_retryAfter);
    action().catchError((Object _) {}).whenComplete(() => _expiring = false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
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

  const JoinPanel({
    super.key,
    required this.theme,
    required this.title,
    required this.otherName,
    required this.waitingForOther,
    required this.busy,
    required this.onJoin,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final orb = GameOrb(theme: theme);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
      child: Column(
        children: [
          if (waitingForOther && !MediaQuery.disableAnimationsOf(context))
            orb
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(end: 1.06, duration: 900.ms, curve: Curves.easeInOut)
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
                ? 'The game starts when $otherName accepts the invite in '
                      'your chat.'
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
