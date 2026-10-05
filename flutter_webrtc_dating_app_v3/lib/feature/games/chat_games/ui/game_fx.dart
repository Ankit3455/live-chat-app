// lib/feature/games/chat_games/ui/game_fx.dart
//
// Win confetti for game result screens.

import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'game_ui.dart';

/// Wraps [child]; when [won] is true a burst of confetti in the game's
/// colours falls from the top once. Skipped with reduced motion.
class WinCelebration extends StatefulWidget {
  final bool won;
  final GameTheme theme;
  final Widget child;

  const WinCelebration({
    super.key,
    required this.won,
    required this.theme,
    required this.child,
  });

  @override
  State<WinCelebration> createState() => _WinCelebrationState();
}

class _WinCelebrationState extends State<WinCelebration> {
  final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 1600),
  );
  bool _played = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePlay();
  }

  @override
  void didUpdateWidget(covariant WinCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybePlay();
  }

  void _maybePlay() {
    if (_played || !widget.won) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _played = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirection: math.pi / 2,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.08,
            numberOfParticles: 18,
            maxBlastForce: 22,
            minBlastForce: 8,
            gravity: 0.25,
            colors: [
              widget.theme.a,
              widget.theme.b,
              Colors.white,
              const Color(0xFFFFD166),
            ],
          ),
        ),
      ],
    );
  }
}
