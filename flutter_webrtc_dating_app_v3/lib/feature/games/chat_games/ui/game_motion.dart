// lib/feature/games/chat_games/ui/game_motion.dart
//
// Premium moments shared by the games: the "Your turn" flash, the result
// hero with spinning rays, reveal toasts, floating damage numbers and a
// pulsing glow. All fall back to static widgets with reduced motion.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'game_ui.dart';

/// Flashes a big "Your turn!" badge over [child] each time [turnKey]
/// changes while [show] is true.
class TurnBanner extends StatefulWidget {
  final Object turnKey;
  final bool show;
  final String text;
  final GameTheme theme;
  final Widget child;

  const TurnBanner({
    super.key,
    required this.turnKey,
    required this.show,
    required this.theme,
    required this.child,
    this.text = 'Your turn!',
  });

  @override
  State<TurnBanner> createState() => _TurnBannerState();
}

class _TurnBannerState extends State<TurnBanner> {
  int _flash = 0;

  @override
  void didUpdateWidget(covariant TurnBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show &&
        (oldWidget.turnKey != widget.turnKey || !oldWidget.show)) {
      _flash++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_flash > 0 && !calmMotion(context))
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child:
                    Container(
                          key: ValueKey(_flash),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: widget.theme.gradient,
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: widget.theme.a.withOpacity(0.6),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                          child: Text(
                            widget.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                        .animate()
                        .scaleXY(
                          begin: 0.3,
                          end: 1,
                          duration: 380.ms,
                          curve: Curves.elasticOut,
                        )
                        .fadeIn(duration: 150.ms)
                        .then(delay: 650.ms)
                        .fadeOut(duration: 300.ms)
                        .scaleXY(end: 1.15, duration: 300.ms),
              ),
            ),
          ),
      ],
    );
  }
}

/// Big result moment: an emoji (trophy, heart…) over slowly spinning rays,
/// a title, a subtitle and optional extra content.
class ResultHero extends StatelessWidget {
  final GameTheme theme;
  final String emoji;
  final String title;
  final String? subtitle;
  final bool celebrate;

  const ResultHero({
    super.key,
    required this.theme,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.celebrate = true,
  });

  @override
  Widget build(BuildContext context) {
    final calm = calmMotion(context);
    // The rays are painted once into their own layer and only rotated per
    // frame; the outer boundaries keep the loops from repainting the card.
    Widget rays = RepaintBoundary(
      child: SizedBox(
        width: 190,
        height: 190,
        child: CustomPaint(painter: _RaysPainter(theme, celebrate)),
      ),
    );
    if (!calm) {
      rays = RepaintBoundary(
        child: rays
            .animate(onPlay: (c) => c.repeat())
            .rotate(duration: 18.seconds, begin: 0, end: 1),
      );
    }
    Widget icon = Text(emoji, style: const TextStyle(fontSize: 72));
    if (!calm) {
      icon = RepaintBoundary(
        child: RepaintBoundary(child: icon)
            .animate()
            .scaleXY(
              begin: 0.2,
              end: 1,
              duration: 700.ms,
              curve: Curves.elasticOut,
            )
            .then()
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(
              begin: -3,
              end: 3,
              duration: 1500.ms,
              curve: Curves.easeInOut,
            ),
      );
    }
    return Column(
      children: [
        SizedBox(
          width: 190,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [rays, icon],
          ),
        ),
        enterFx(
          context,
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GameText.display.copyWith(fontSize: 26),
            ),
          ),
          delay: 250.ms,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          enterFx(
            context,
            ShaderMask(
              shaderCallback: (r) => theme.gradient.createShader(r),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            delay: 380.ms,
          ),
        ],
      ],
    );
  }
}

class _RaysPainter extends CustomPainter {
  final GameTheme theme;
  final bool bright;

  _RaysPainter(this.theme, this.bright);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    const rays = 14;
    for (var i = 0; i < rays; i++) {
      final a = i * math.pi * 2 / rays;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - 0.09), c.dy + r * math.sin(a - 0.09))
        ..lineTo(c.dx + r * math.cos(a + 0.09), c.dy + r * math.sin(a + 0.09))
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: [
              (i.isEven ? theme.a : theme.b).withOpacity(bright ? 0.55 : 0.22),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) =>
      old.theme != theme || old.bright != bright;
}

/// A glass pill that drops in for a round's result; re-runs when [key]
/// changes.
class RevealToast extends StatelessWidget {
  final String text;
  final GameTheme theme;

  const RevealToast({super.key, required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    final pill = GlassPanel(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderColor: theme.a.withOpacity(0.55),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ),
    );
    if (calmMotion(context)) return pill;
    return pill
        .animate()
        .fadeIn(duration: 250.ms)
        .slideY(
          begin: -0.4,
          end: 0,
          duration: 420.ms,
          curve: Curves.easeOutBack,
        );
  }
}

/// "-27" that floats up and fades; give it a new key per hit.
class FloatingNumber extends StatelessWidget {
  final String text;
  final Color color;

  const FloatingNumber({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 30,
        fontWeight: FontWeight.w900,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
      ),
    );
    if (calmMotion(context)) return label;
    return label
        .animate()
        .scaleXY(
          begin: 0.5,
          end: 1.2,
          duration: 220.ms,
          curve: Curves.easeOutBack,
        )
        .moveY(begin: 0, end: -46, duration: 900.ms, curve: Curves.easeOut)
        .fadeOut(delay: 500.ms, duration: 400.ms);
  }
}

/// Soft pulsing halo behind [child] while [active].
class PulseGlow extends StatelessWidget {
  final Widget child;
  final Color color;
  final bool active;
  final double radius;

  const PulseGlow({
    super.key,
    required this.child,
    required this.color,
    this.active = true,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    final halo = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: color.withOpacity(0.55), blurRadius: 22)],
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: calmMotion(context)
              ? halo
              : RepaintBoundary(
                  child: RepaintBoundary(child: halo)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fade(begin: 0.35, end: 1, duration: 900.ms),
                ),
        ),
        child,
      ],
    );
  }
}
