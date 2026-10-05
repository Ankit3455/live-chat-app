// lib/feature/games/chat_games/ui/game_ui.dart
//
// Shared look for chat games: a themed glowing backdrop, glass panels,
// gradient buttons, player badges with a 30 s ring, the versus bar and the
// intro hero. Everything respects reduced motion.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../widgets/motion.dart';
import '../chat_game.dart';

/// Colours for one game.
class GameTheme {
  final Color a;
  final Color b;
  final String emoji;

  const GameTheme(this.a, this.b, this.emoji);

  LinearGradient get gradient => LinearGradient(
    colors: [a, b],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const GameTheme date = GameTheme(
    Color(0xFFFF5F9E),
    Color(0xFF9B5CFF),
    '💌',
  );
  static const GameTheme rate = GameTheme(
    Color(0xFFFFB547),
    Color(0xFFFF5F9E),
    '🔢',
  );
  static const GameTheme flags = GameTheme(
    Color(0xFFFF5A5F),
    Color(0xFF2BD98C),
    '🚩',
  );
  static const GameTheme telepathy = GameTheme(
    Color(0xFF5B6CFF),
    Color(0xFF22D3EE),
    '🧠',
  );
  static const GameTheme chess = GameTheme(
    Color(0xFF8B5CF6),
    Color(0xFF3B1F7A),
    '♟️',
  );
  static const GameTheme tennis = GameTheme(
    Color(0xFFB8F35A),
    Color(0xFF10B981),
    '🎾',
  );
  static const GameTheme thumb = GameTheme(
    Color(0xFFFF8A3D),
    Color(0xFFFF4F9A),
    '👍',
  );

  static GameTheme of(String game) {
    switch (game) {
      case 'date':
        return date;
      case 'rate':
        return rate;
      case 'flags':
        return flags;
      case 'telepathy':
        return telepathy;
      case 'chess':
        return chess;
      case 'tennis':
        return tennis;
      case 'thumb':
        return thumb;
    }
    return date;
  }
}

class GameText {
  GameText._();

  static const TextStyle display = TextStyle(
    color: Colors.white,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.15,
  );

  static const TextStyle title = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );

  static const TextStyle body = TextStyle(
    color: Color(0xFFD9D1EE),
    fontSize: 15,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    color: Color(0xFFB4A9CF),
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
}

/// True when the platform asks for reduced motion.
bool calmMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Dark base, two soft drifting glows in the game's colours and small
/// bokeh particles floating up.
class GameBackdrop extends StatefulWidget {
  final GameTheme theme;
  final Widget child;

  const GameBackdrop({super.key, required this.theme, required this.child});

  @override
  State<GameBackdrop> createState() => _GameBackdropState();
}

class _GameBackdropState extends State<GameBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF0B0716)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  return CustomPaint(painter: _GlowPainter(t, _c.value));
                },
              ),
            ),
          ),
          // Keeps the content's repaints off the backdrop and the app bar.
          RepaintBoundary(child: widget.child),
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final GameTheme theme;

  /// 0..1, looping.
  final double t;

  _GlowPainter(this.theme, this.t);

  static final List<List<double>> _particles = List.generate(22, (i) {
    final r = math.Random(i * 7919);
    // x, start y, speed, radius, alpha
    return [
      r.nextDouble(),
      r.nextDouble(),
      0.4 + r.nextDouble() * 0.9,
      1.2 + r.nextDouble() * 2.8,
      0.15 + r.nextDouble() * 0.35,
    ];
  });

  void _glow(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(0.42), color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final v = (math.sin(t * math.pi * 2) + 1) / 2;
    _glow(
      canvas,
      Offset(w * (0.1 + 0.15 * v), h * (0.12 + 0.05 * v)),
      w * 0.85,
      theme.a,
    );
    _glow(
      canvas,
      Offset(w * (0.95 - 0.15 * v), h * (0.78 - 0.06 * v)),
      w * 0.9,
      theme.b,
    );
    final dot = Paint();
    for (final p in _particles) {
      final y = (p[1] - t * p[2]) % 1.0;
      final x = p[0] + math.sin((t + p[1]) * math.pi * 2) * 0.02;
      final fade = math.sin(y * math.pi);
      dot.color = Colors.white.withOpacity(p[4] * fade);
      canvas.drawCircle(Offset(x * w, y * h), p[3], dot);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.t != t || old.theme != theme;
}

/// Frosted glass card.
///
/// No BackdropFilter: the only thing behind these cards is the soft
/// [GameBackdrop] glow, which looks the same unblurred, and a blur over an
/// animated backdrop would be re-run for every card on every frame.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: borderColor ?? Colors.white.withOpacity(0.12),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Big gradient call-to-action with a soft glow and a press bounce.
class GameButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final GameTheme theme;
  final VoidCallback? onPressed;
  final bool loading;

  /// Outline style for secondary actions.
  final bool secondary;

  const GameButton({
    super.key,
    required this.label,
    required this.theme,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          )
        else if (icon != null)
          Icon(icon, color: Colors.white, size: 22),
        if (loading || icon != null) const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: PressScale(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled || loading ? 1 : 0.45,
          child: GestureDetector(
            onTap: enabled ? onPressed : null,
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(29),
                gradient: secondary ? null : theme.gradient,
                color: secondary ? Colors.white.withOpacity(0.06) : null,
                border: secondary
                    ? Border.all(color: Colors.white.withOpacity(0.22))
                    : null,
                boxShadow: secondary || !enabled
                    ? null
                    : [
                        BoxShadow(
                          color: theme.a.withOpacity(0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
              ),
              child: secondary || !enabled || calmMotion(context)
                  ? content
                  : RepaintBoundary(
                      child: content
                          .animate(onPlay: (c) => c.repeat())
                          .shimmer(
                            delay: 1800.ms,
                            duration: 1100.ms,
                            color: Colors.white.withOpacity(0.55),
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round avatar with an optional 30 s countdown ring and active glow.
class PlayerBadge extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final GameTheme theme;
  final double size;

  /// Seconds left on this player's clock; null = no ring.
  final int? secondsLeft;
  final bool active;

  const PlayerBadge({
    super.key,
    required this.name,
    required this.theme,
    this.imageUrl,
    this.size = 56,
    this.secondsLeft,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(gradient: theme.gradient),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final seconds = secondsLeft;
    final low = seconds != null && seconds <= 10;
    final ringColor = low ? AppColors.error : theme.a;
    return SizedBox(
      width: size + 12,
      height: size + 12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (active)
            Container(
              width: size + 12,
              height: size + 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: ringColor.withOpacity(0.55), blurRadius: 18),
                ],
              ),
            ),
          if (seconds != null)
            // The ring animates most of every second; repaint only it.
            RepaintBoundary(
              child: SizedBox(
                width: size + 10,
                height: size + 10,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: seconds / TurnClock.seconds),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 900),
                  builder: (context, v, _) =>
                      CustomPaint(painter: _RingPainter(v, ringColor)),
                ),
              ),
            ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? Colors.white : Colors.white24,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: url == null || !url.startsWith('http')
                  ? fallback
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      // Decode at badge size, not the full upload.
                      cacheWidth:
                          (size * MediaQuery.devicePixelRatioOf(context))
                              .round(),
                      errorBuilder: (_, __, ___) => fallback,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;

  _RingPainter(this.fraction, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white.withOpacity(0.12);
    canvas.drawArc(rect.deflate(2), 0, math.pi * 2, false, track);
    canvas.drawArc(
      rect.deflate(2),
      -math.pi / 2,
      math.pi * 2 * fraction.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// One player in the versus bar.
class VersusSide {
  final String name;
  final String? imageUrl;
  final String? subtitle;
  final bool active;
  final int? secondsLeft;

  const VersusSide({
    required this.name,
    this.imageUrl,
    this.subtitle,
    this.active = false,
    this.secondsLeft,
  });
}

/// "You  [score]  Bob" with avatars; the active side glows and shows its
/// 30 s ring.
class VersusBar extends StatelessWidget {
  final VersusSide left;
  final VersusSide right;
  final GameTheme theme;
  final Widget? center;

  const VersusBar({
    super.key,
    required this.left,
    required this.right,
    required this.theme,
    this.center,
  });

  Widget _side(BuildContext context, VersusSide s, CrossAxisAlignment align) {
    final seconds = s.active ? s.secondsLeft : null;
    return Expanded(
      child: enterFx(
        context,
        Column(
          crossAxisAlignment: align,
          children: [
            PlayerBadge(
              name: s.name,
              imageUrl: s.imageUrl,
              theme: theme,
              active: s.active,
              secondsLeft: seconds,
            ),
            const SizedBox(height: 6),
            Text(
              s.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(s.active ? 1 : 0.75),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (s.subtitle != null || seconds != null)
              Text(
                [
                  if (s.subtitle != null) s.subtitle!,
                  if (seconds != null)
                    '0:${seconds.toString().padLeft(2, '0')}',
                ].join(' · '),
                style: GameText.caption.copyWith(
                  color: seconds != null && seconds <= 10
                      ? AppColors.error
                      : GameText.caption.color,
                ),
              ),
          ],
        ),
        from: Offset(align == CrossAxisAlignment.start ? -0.3 : 0.3, 0),
      ),
    );
  }

  Widget _vs(BuildContext context) {
    final vs = ShaderMask(
      shaderCallback: (r) => theme.gradient.createShader(r),
      child: const Text(
        'VS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
    if (calmMotion(context)) return vs;
    return RepaintBoundary(
      child: RepaintBoundary(child: vs)
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 0.92,
            end: 1.08,
            duration: 1200.ms,
            curve: Curves.easeInOut,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Semantics(
        container: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _side(context, left, CrossAxisAlignment.start),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: center ?? _vs(context),
            ),
            _side(context, right, CrossAxisAlignment.end),
          ],
        ),
      ),
    );
  }
}

/// Glowing emoji orb with a spinning gradient ring, used on intro and join
/// screens.
class GameOrb extends StatelessWidget {
  final GameTheme theme;
  final double size;

  const GameOrb({super.key, required this.theme, this.size = 132});

  @override
  Widget build(BuildContext context) {
    final calm = calmMotion(context);
    Widget emoji = Text(theme.emoji, style: TextStyle(fontSize: size * 0.44));
    // Looping parts get their own layers: the inner boundary paints once,
    // the outer one keeps the per-frame transform away from the orb.
    if (!calm) {
      emoji = RepaintBoundary(
        child: RepaintBoundary(child: emoji)
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(
              begin: -3,
              end: 4,
              duration: 1600.ms,
              curve: Curves.easeInOut,
            ),
      );
    }
    Widget ring = RepaintBoundary(
      child: SizedBox(
        width: size + 22,
        height: size + 22,
        child: CustomPaint(painter: _SweepRingPainter(theme)),
      ),
    );
    if (!calm) {
      ring = RepaintBoundary(
        child: ring
            .animate(onPlay: (c) => c.repeat())
            .rotate(duration: 6.seconds, begin: 0, end: 1),
      );
    }
    return SizedBox(
      width: size + 40,
      height: size + 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.a.withOpacity(0.6),
                  blurRadius: 56,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
          ring,
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [theme.a, theme.b],
                center: const Alignment(-0.3, -0.4),
                radius: 1.1,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: emoji,
          ),
        ],
      ),
    );
  }
}

class _SweepRingPainter extends CustomPainter {
  final GameTheme theme;

  _SweepRingPainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [
            theme.a.withOpacity(0),
            theme.a,
            Colors.white,
            theme.b,
            theme.b.withOpacity(0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SweepRingPainter old) => old.theme != theme;
}

/// One "how to play" line.
class HowToStep {
  final String emoji;
  final String text;

  const HowToStep(this.emoji, this.text);
}

/// Fades and slides [child] in after [delay]; plain child with reduced
/// motion.
Widget enterFx(
  BuildContext context,
  Widget child, {
  Duration delay = Duration.zero,
  Offset from = const Offset(0, 0.25),
}) {
  if (calmMotion(context)) return child;
  return child
      .animate(delay: delay)
      .fadeIn(duration: 380.ms, curve: Curves.easeOut)
      .slide(
        begin: from,
        end: Offset.zero,
        duration: 420.ms,
        curve: Curves.easeOutCubic,
      );
}

/// Intro: orb, title, short how-to steps and a big start button, each
/// arriving a moment after the last.
class GameIntro extends StatelessWidget {
  final GameTheme theme;
  final String title;
  final String subtitle;
  final List<HowToStep> steps;
  final String buttonLabel;
  final bool busy;
  final VoidCallback onStart;

  const GameIntro({
    super.key,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.busy,
    required this.onStart,
    this.buttonLabel = "Let's play",
  });

  @override
  Widget build(BuildContext context) {
    final calm = calmMotion(context);
    Widget orb = GameOrb(theme: theme);
    if (!calm) {
      orb = orb
          .animate()
          .scaleXY(
            begin: 0.4,
            end: 1,
            duration: 650.ms,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: 300.ms);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        children: [
          orb,
          const SizedBox(height: 14),
          enterFx(
            context,
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GameText.display,
              ),
            ),
            delay: 150.ms,
          ),
          const SizedBox(height: 8),
          enterFx(
            context,
            Text(subtitle, textAlign: TextAlign.center, style: GameText.body),
            delay: 230.ms,
          ),
          const SizedBox(height: 22),
          enterFx(
            context,
            GlassPanel(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HOW TO PLAY', style: GameText.caption),
                  const SizedBox(height: 10),
                  for (var i = 0; i < steps.length; i++)
                    enterFx(
                      context,
                      _StepRow(step: steps[i], theme: theme),
                      delay: (420 + i * 110).ms,
                      from: const Offset(0.15, 0),
                    ),
                ],
              ),
            ),
            delay: 320.ms,
          ),
          const SizedBox(height: 24),
          enterFx(
            context,
            GameButton(
              label: buttonLabel,
              icon: Icons.play_arrow_rounded,
              theme: theme,
              loading: busy,
              onPressed: busy ? null : onStart,
            ),
            delay: (480 + steps.length * 110).ms,
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final HowToStep step;
  final GameTheme theme;

  const _StepRow({required this.step, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.a.withOpacity(0.35), theme.b.withOpacity(0.2)],
              ),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(step.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                step.text,
                style: GameText.body.copyWith(
                  color: Colors.white,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Transparent app bar over the backdrop.
PreferredSizeWidget gameAppBar(
  BuildContext context, {
  required String title,
  List<Widget> actions = const [],
}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    foregroundColor: Colors.white,
    title: Text(title, style: GameText.title),
    actions: actions,
  );
}
