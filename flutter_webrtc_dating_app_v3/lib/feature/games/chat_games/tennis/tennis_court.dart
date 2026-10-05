// lib/feature/games/chat_games/tennis/tennis_court.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../ui/game_ui.dart';
import 'tennis_match.dart';

/// Top-down grass court: the opponent's half on top, mine at the bottom. The
/// half I act on (top to aim, bottom to run) has 3 tappable lanes. When
/// [shotKey] changes, the last shot plays: the ball flies in an arc to where
/// it landed and the receiver runs to where they guessed.
class TennisCourt extends StatefulWidget {
  /// True if I hit this shot (I aim at the top half).
  final bool hitting;
  final bool canPick;

  /// My locked-in zone for this shot, as seen on my screen.
  final String? myPick;

  /// Last shot, already turned to my screen.
  final String? lastLanding;
  final String? lastReceiver;
  final bool lastOnMyHalf;

  /// Bumps with every finished shot (history length).
  final int shotKey;
  final ValueChanged<String> onPick;

  const TennisCourt({
    super.key,
    required this.hitting,
    required this.canPick,
    required this.myPick,
    required this.onPick,
    required this.shotKey,
    this.lastLanding,
    this.lastReceiver,
    this.lastOnMyHalf = false,
  });

  @override
  State<TennisCourt> createState() => _TennisCourtState();
}

class _TennisCourtState extends State<TennisCourt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant TennisCourt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shotKey != widget.shotKey && widget.lastLanding != null) {
      if (calmMotion(context)) {
        _flight.value = 1;
      } else {
        _flight.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  static double _laneX(String zone) =>
      zone == 'L' ? 1 / 6 : (zone == 'R' ? 5 / 6 : 0.5);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.66,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: GameTheme.tennis.b.withOpacity(0.4),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final h = box.maxHeight;
              return Stack(
                children: [
                  // Static court; the pulsing lanes and the ball repaint
                  // above it without redrawing the stripes and net.
                  const Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(painter: _CourtPainter()),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: h / 2,
                    child: _half(top: true),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: h / 2,
                    child: _half(top: false),
                  ),
                  _lastShot(w, h),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _half({required bool top}) {
    // I aim at the opponent's half (top) and run on mine (bottom).
    final active = widget.hitting == top;
    if (!active) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final zone in TennisMatch.zones) Expanded(child: _lane(zone)),
      ],
    );
  }

  Widget _lane(String zone) {
    final selected = widget.myPick == zone;
    final tappable = widget.canPick;
    final verb = widget.hitting ? 'Aim' : 'Run';
    final icon = widget.hitting ? '🎯' : '👟';
    final name = TennisMatch.zoneName(zone);
    Widget mark = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          selected ? '$verb ✓' : verb,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ],
    );
    if (tappable && !calmMotion(context)) {
      mark = RepaintBoundary(
        child: RepaintBoundary(child: mark)
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(
              begin: 0.94,
              end: 1.06,
              duration: 900.ms,
              curve: Curves.easeInOut,
            ),
      );
    }
    return Semantics(
      button: tappable,
      selected: selected,
      label: '$verb $name',
      excludeSemantics: true,
      onTap: tappable ? () => widget.onPick(zone) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tappable ? () => widget.onPick(zone) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? Colors.white.withOpacity(0.28)
                : Colors.white.withOpacity(tappable ? 0.08 : 0.03),
            border: Border.all(
              color: selected ? Colors.white : Colors.white.withOpacity(0.25),
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Center(
            child: Opacity(
              opacity: tappable || selected ? 1 : 0.5,
              child: mark,
            ),
          ),
        ),
      ),
    );
  }

  /// Ball and runner of the last shot; animated while [_flight] runs.
  Widget _lastShot(double w, double h) {
    final landing = widget.lastLanding;
    if (landing == null) return const SizedBox.shrink();
    final onMine = widget.lastOnMyHalf;
    final runner = widget.lastReceiver;
    // Ball from the hitter's baseline to the middle of the landing lane.
    final start = Offset(w * 0.5, onMine ? h * 0.08 : h * 0.92);
    final end = Offset(w * _laneX(landing), onMine ? h * 0.72 : h * 0.28);
    final runFrom = Offset(w * 0.5, onMine ? h * 0.86 : h * 0.14);
    final runTo = runner == null
        ? runFrom
        : Offset(w * _laneX(runner), onMine ? h * 0.82 : h * 0.18);
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _flight,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_flight.value);
            final ground = Offset.lerp(start, end, t)!;
            final lift = math.sin(t * math.pi);
            final run = Offset.lerp(
              runFrom,
              runTo,
              Curves.easeOut.transform(t),
            )!;
            return Stack(
              children: [
                Positioned(
                  left: run.dx - 16,
                  top: run.dy - 18,
                  child: const Text('🏃', style: TextStyle(fontSize: 30)),
                ),
                // Shadow on the court.
                Positioned(
                  left: ground.dx - 10,
                  top: ground.dy - 4,
                  child: Container(
                    width: 20,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35 - 0.2 * lift),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Positioned(
                  left: ground.dx - 13,
                  top: ground.dy - 13 - lift * 46,
                  child: Transform.scale(
                    scale: 1 + 0.6 * lift,
                    child: const Text('🎾', style: TextStyle(fontSize: 24)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CourtPainter extends CustomPainter {
  const _CourtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Mowing stripes.
    const a = Color(0xFF2F8F57);
    const b = Color(0xFF2A8250);
    const stripes = 10;
    for (var i = 0; i < stripes; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, h * i / stripes, w, h / stripes + 1),
        Paint()..color = i.isEven ? a : b,
      );
    }
    // Soft vignette.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withOpacity(0.28)],
          radius: 0.9,
        ).createShader(Offset.zero & size),
    );

    final line = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final m = w * 0.06;
    final court = Rect.fromLTRB(m, h * 0.04, w - m, h * 0.96);
    canvas.drawRect(court, line); // doubles
    final alley = court.width * 0.12;
    canvas.drawLine(
      Offset(court.left + alley, court.top),
      Offset(court.left + alley, court.bottom),
      line,
    );
    canvas.drawLine(
      Offset(court.right - alley, court.top),
      Offset(court.right - alley, court.bottom),
      line,
    );
    final service = court.height * 0.23;
    final mid = h / 2;
    canvas.drawLine(
      Offset(court.left + alley, mid - service),
      Offset(court.right - alley, mid - service),
      line,
    );
    canvas.drawLine(
      Offset(court.left + alley, mid + service),
      Offset(court.right - alley, mid + service),
      line,
    );
    canvas.drawLine(
      Offset(w / 2, mid - service),
      Offset(w / 2, mid + service),
      line,
    );
    canvas.drawLine(
      Offset(w / 2, court.top),
      Offset(w / 2, court.top + 8),
      line,
    );
    canvas.drawLine(
      Offset(w / 2, court.bottom),
      Offset(w / 2, court.bottom - 8),
      line,
    );

    // Net: shadow, mesh, tape and posts.
    canvas.drawRect(
      Rect.fromLTWH(0, mid + 2, w, 8),
      Paint()..color = Colors.black.withOpacity(0.22),
    );
    final mesh = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1;
    for (double x = 0; x < w; x += 6) {
      canvas.drawLine(Offset(x, mid - 5), Offset(x + 3, mid + 5), mesh);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, mid - 6, w, 3.5),
      Paint()..color = Colors.white,
    );
    final post = Paint()..color = const Color(0xFFE5E7EB);
    canvas.drawCircle(Offset(m * 0.5, mid), 4.5, post);
    canvas.drawCircle(Offset(w - m * 0.5, mid), 4.5, post);
  }

  @override
  bool shouldRepaint(covariant _CourtPainter oldDelegate) => false;
}
