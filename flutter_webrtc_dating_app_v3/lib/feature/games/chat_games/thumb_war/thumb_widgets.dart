// lib/feature/games/chat_games/thumb_war/thumb_widgets.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../ui/game_motion.dart';
import '../ui/game_ui.dart';
import 'thumb_war.dart';

/// Semicircle gauge: the needle sweeps across; tap Grip to stop it. Power is
/// 100 in the green middle and 0 at the red ends.
class GripGauge extends StatefulWidget {
  final bool enabled;
  final GameTheme theme;
  final ValueChanged<int> onStop;

  const GripGauge({
    super.key,
    required this.enabled,
    required this.theme,
    required this.onStop,
  });

  static int powerAt(double t) =>
      (100 - ((t - 0.5).abs() * 200)).round().clamp(0, 100);

  @override
  State<GripGauge> createState() => _GripGaugeState();
}

class _GripGaugeState extends State<GripGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  int? _stopped;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: a slower sweep keeps the game playable.
    _c.duration = calmMotion(context)
        ? const Duration(milliseconds: 2400)
        : const Duration(milliseconds: 1100);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _stop() {
    if (!widget.enabled || _stopped != null) return;
    _c.stop();
    final power = GripGauge.powerAt(_c.value);
    setState(() => _stopped = power);
    widget.onStop(power);
  }

  @override
  Widget build(BuildContext context) {
    final stopped = _stopped;
    Widget value = Text(
      stopped == null ? 'GRIP' : '$stopped',
      style: TextStyle(
        color: Colors.white,
        fontSize: stopped == null ? 18 : 34,
        fontWeight: FontWeight.w900,
        letterSpacing: stopped == null ? 3 : 0,
      ),
    );
    if (stopped != null && !calmMotion(context)) {
      value = value.animate().scaleXY(
        begin: 1.8,
        end: 1,
        duration: 420.ms,
        curve: Curves.elasticOut,
      );
    }
    return Column(
      children: [
        Semantics(
          label: stopped == null
              ? 'Grip gauge. Tap Grip when the needle is in the green.'
              : 'Grip $stopped out of 100',
          liveRegion: stopped != null,
          excludeSemantics: true,
          child: SizedBox(
            height: 132,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _GaugePainter(_c.value, widget.theme),
                child: Align(alignment: const Alignment(0, 0.3), child: value),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GameButton(
          label: stopped == null ? 'Grip!' : 'Locked in',
          icon: stopped == null ? Icons.back_hand_rounded : Icons.check_rounded,
          theme: widget.theme,
          onPressed: widget.enabled && stopped == null ? _stop : null,
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double t;
  final GameTheme theme;

  _GaugePainter(this.t, this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width / 2 - 12, size.height - 14);
    final c = Offset(size.width / 2, size.height - 6);
    final rect = Rect.fromCircle(center: c, radius: r);
    // Track with the sweet spot in the middle.
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          startAngle: math.pi,
          endAngle: math.pi * 2,
          colors: [
            Color(0xFFFF4D6D),
            Color(0xFFFFC145),
            Color(0xFF2BD98C),
            Color(0xFFFFC145),
            Color(0xFFFF4D6D),
          ],
        ).createShader(rect),
    );
    // Tick marks.
    final tick = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 2;
    for (var i = 0; i <= 10; i++) {
      final a = math.pi + math.pi * i / 10;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * (r - 18),
        c + Offset(math.cos(a), math.sin(a)) * (r - 24),
        tick,
      );
    }
    // Needle.
    final a = math.pi + math.pi * t;
    final tip = c + Offset(math.cos(a), math.sin(a)) * (r + 4);
    canvas.drawLine(
      c,
      tip,
      Paint()
        ..color = theme.a.withOpacity(0.55)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawLine(
      c,
      tip,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(c, 9, Paint()..color = Colors.white);
    canvas.drawCircle(c, 5, Paint()..color = theme.b);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.t != t;
}

/// One fighter: name, hearts for rounds won, a health bar with a damage
/// trail, and a big thumb with its accessory over a coloured aura. The thumb
/// bobs, lunges when [strikeKey] changes and shakes when [hitKey] changes,
/// showing [lastDamage] floating up.
class ThumbFighter extends StatelessWidget {
  final String name;
  final String accessory;
  final int hp;
  final int roundsWon;
  final bool top;
  final Color color;
  final int strikeKey;
  final int hitKey;
  final int lastDamage;

  const ThumbFighter({
    super.key,
    required this.name,
    required this.accessory,
    required this.hp,
    required this.roundsWon,
    required this.top,
    required this.color,
    required this.strikeKey,
    required this.hitKey,
    required this.lastDamage,
  });

  @override
  Widget build(BuildContext context) {
    final calm = calmMotion(context);
    Widget thumb = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!top) Text(accessory, style: const TextStyle(fontSize: 30)),
        Transform.rotate(
          angle: top ? math.pi : 0,
          child: const Text('👍', style: TextStyle(fontSize: 72)),
        ),
        if (top) Text(accessory, style: const TextStyle(fontSize: 30)),
      ],
    );
    if (!calm) {
      thumb = thumb
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
            begin: -3,
            end: 3,
            duration: (top ? 900 : 1050).ms,
            curve: Curves.easeInOut,
          );
      if (strikeKey > 0) {
        thumb = thumb
            .animate(key: ValueKey('strike$strikeKey'))
            .moveY(end: top ? 26 : -26, duration: 140.ms, curve: Curves.easeOut)
            .scaleXY(end: 1.2, duration: 140.ms)
            .then()
            .moveY(end: 0, duration: 260.ms, curve: Curves.easeOutBack)
            .scaleXY(end: 1 / 1.2, duration: 260.ms);
      }
      if (hitKey > 0) {
        thumb = thumb
            .animate(key: ValueKey('hit$hitKey'))
            .shakeX(hz: 7, amount: 7, duration: 420.ms)
            .tint(color: const Color(0xFFFF4D6D), end: 0.45, duration: 120.ms)
            .then()
            .tint(end: 0, duration: 300.ms);
      }
    }

    final fighter = SizedBox(
      width: 118,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withOpacity(0.55), color.withOpacity(0)],
              ),
            ),
          ),
          thumb,
          if (hitKey > 0 && lastDamage > 0)
            Positioned(
              top: top ? null : 0,
              bottom: top ? 0 : null,
              child: FloatingNumber(
                key: ValueKey('dmg$hitKey'),
                text: '-$lastDamage',
                color: const Color(0xFFFF6B8B),
              ),
            ),
        ],
      ),
    );

    final bar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (var i = 0; i < ThumbWar.roundsToWin; i++)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  i < roundsWon ? '❤️' : '🤍',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _HealthBar(hp: hp, color: color),
        const SizedBox(height: 4),
        Text('$hp / ${ThumbWar.maxHp}', style: GameText.caption),
      ],
    );

    return Semantics(
      label: '$name, $hp health, $roundsWon rounds won',
      excludeSemantics: true,
      child: Row(
        children: top
            ? [Expanded(child: bar), const SizedBox(width: 8), fighter]
            : [fighter, const SizedBox(width: 8), Expanded(child: bar)],
      ),
    );
  }
}

/// Health bar with a white "damage taken" trail that catches up slowly.
class _HealthBar extends StatelessWidget {
  final int hp;
  final Color color;

  const _HealthBar({required this.hp, required this.color});

  @override
  Widget build(BuildContext context) {
    final f = hp / ThumbWar.maxHp;
    final calm = calmMotion(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 14,
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              Container(color: Colors.white.withOpacity(0.08)),
              TweenAnimationBuilder<double>(
                tween: Tween(end: f),
                duration: calm ? Duration.zero : 900.ms,
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Container(
                  width: box.maxWidth * v,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(end: f),
                duration: calm ? Duration.zero : 220.ms,
                builder: (context, v, _) => Container(
                  width: box.maxWidth * v,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, Color.lerp(color, Colors.white, 0.35)!],
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
}

/// A move card: big emoji, name and what it beats; glows when picked.
class MoveCard extends StatelessWidget {
  final ThumbMove move;
  final bool selected;
  final bool dimmed;
  final GameTheme theme;
  final VoidCallback? onTap;

  const MoveCard({
    super.key,
    required this.move,
    required this.selected,
    required this.dimmed,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: selected
            ? theme.gradient
            : LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.04),
                ],
              ),
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withOpacity(0.14),
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [BoxShadow(color: theme.a.withOpacity(0.55), blurRadius: 20)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(move.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 6),
          Text(
            move.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'beats ${move.beats.emoji}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${move.label}, beats ${move.beats.label}',
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: dimmed ? 0.4 : 1,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          scale: selected ? 1.06 : 1,
          curve: Curves.easeOutBack,
          child: GestureDetector(onTap: onTap, child: card),
        ),
      ),
    );
  }
}
