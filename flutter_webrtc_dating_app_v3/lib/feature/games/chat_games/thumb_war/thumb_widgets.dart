// lib/feature/games/chat_games/thumb_war/thumb_widgets.dart
//
// The Thumb War arena: two fists with thumbs, health and stamina bars,
// round pips and the ROUND / FIGHT! / K.O. calls. You are always on the
// left. Hold anywhere on the arena to press.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'thumb_live.dart';
import 'thumb_war.dart';

class ThumbArena extends StatefulWidget {
  final ThumbLiveMatch match;

  /// Names and hats by player index.
  final List<String> names;
  final List<String> hats;

  const ThumbArena({
    super.key,
    required this.match,
    required this.names,
    required this.hats,
  });

  @override
  State<ThumbArena> createState() => _ThumbArenaState();
}

class _ThumbArenaState extends State<ThumbArena>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_frame);
  final _ArenaLook _look = _ArenaLook();
  final Set<int> _pointers = {};
  Duration _last = Duration.zero;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _look.seenPins = widget.match.fight.pins;
    _ticker.start();
  }

  void _frame(Duration now) {
    final real = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    final m = widget.match;
    final f = m.fight;
    final l = _look;
    if (f.pins > l.seenPins) {
      l.seenPins = f.pins;
      _hitFx(f.state.pinner);
    }
    final ko = f.phase == FightPhase.ko || f.phase == FightPhase.over;
    if (ko && !l.koSeen) {
      l.koSeen = true;
      l.timeScale = 0.35;
      l.shake = 14;
    }
    if (!ko) l.koSeen = false;
    l.timeScale += (1 - l.timeScale) * min(1, real * 6);
    final dt = real * l.timeScale;
    l.t += dt;
    for (final side in const [0, 1]) {
      final p = _playerAt(side);
      final target = _poseOf(f.state, p);
      final speed = target > l.angle[side] ? 28.0 : 14.0;
      l.angle[side] += (target - l.angle[side]) * min(1, dt * speed);
      if (f.state.pinner == 1 - p) l.hurt[side] = 0.25;
      l.hurt[side] = max(0, l.hurt[side] - dt);
      l.hp[side] += (f.hp[p] - l.hp[side]) * min(1, real * 20);
      l.recoil[side] += (f.hp[p] - l.recoil[side]) * min(1, real * 2);
    }
    l.shake = l.shake > 0.3 ? l.shake * 0.85 : 0;
    l.flash = max(0, l.flash - real * 4);
    for (final s in l.sparks) {
      s.pos += s.vel * dt;
      s.vel += Offset(0, 400 * dt);
      s.life -= dt;
    }
    l.sparks.removeWhere((s) => s.life <= 0);
    setState(() {});
  }

  /// Screen side 0 (left) is me.
  int _playerAt(int side) => side == 0 ? widget.match.me : 1 - widget.match.me;

  /// 0 = thumb up, 1 = lying across the middle, more = slammed on top.
  static double _poseOf(FightState s, int p) {
    if (s.down == p) return 1;
    if (s.pinner == p) return 1.22;
    if (s.pinner == 1 - p) return 0.88;
    if (s.winner == p) return -0.12;
    return 0;
  }

  void _hitFx(int? pinner) {
    final l = _look;
    l.timeScale = 0.5;
    l.flash = 1;
    l.shake = 10;
    final side = pinner == null ? 0 : (pinner == widget.match.me ? 0 : 1);
    l.sparkAt = side;
    for (var i = 0; i < 14; i++) {
      final a = _random.nextDouble() * pi * 2;
      final v = 80 + _random.nextDouble() * 180;
      l.sparks.add(
        _Spark(Offset.zero, Offset(cos(a) * v, sin(a) * v), 0.5, i.isEven),
      );
    }
  }

  void _down(PointerEvent e) {
    _pointers.add(e.pointer);
    widget.match.press(true);
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) widget.match.press(false);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final f = m.fight;
    return Semantics(
      label: 'Thumb War arena. Hold anywhere to press.',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: CustomPaint(
          painter: _ArenaPainter(
            look: _look,
            fight: f,
            me: m.me,
            names: [widget.names[m.me], widget.names[1 - m.me]],
            hats: [widget.hats[m.me], widget.hats[1 - m.me]],
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Animated values the painter reads; by screen side (0 = me, left).
class _ArenaLook {
  double t = 0;
  double timeScale = 1;
  double shake = 0;
  double flash = 0;
  bool koSeen = false;
  int seenPins = 0;
  int sparkAt = 0;
  final List<double> angle = [0, 0];
  final List<double> hurt = [0, 0];
  final List<double> hp = [ThumbWar.maxHp, ThumbWar.maxHp];
  final List<double> recoil = [ThumbWar.maxHp, ThumbWar.maxHp];
  final List<_Spark> sparks = [];
}

class _Spark {
  Offset pos;
  Offset vel;
  double life;
  final bool white;
  _Spark(this.pos, this.vel, this.life, this.white);
}

class _Skin {
  final Color lite, base, shade, edge, ring;
  const _Skin(this.lite, this.base, this.shade, this.edge, this.ring);
}

const List<_Skin> _skins = [
  _Skin(
    Color(0xFFFFD2B0),
    Color(0xFFF2B48A),
    Color(0xFFD68A5E),
    Color(0xFF8A4A2C),
    Color(0xFFF5C76B),
  ),
  _Skin(
    Color(0xFFF0BC98),
    Color(0xFFD99A78),
    Color(0xFFB5734F),
    Color(0xFF6E3A22),
    Color(0xFFFF5C8A),
  ),
];

class _ArenaPainter extends CustomPainter {
  final _ArenaLook look;
  final ThumbFight fight;
  final int me;

  /// By screen side (0 = me).
  final List<String> names;
  final List<String> hats;

  _ArenaPainter({
    required this.look,
    required this.fight,
    required this.me,
    required this.names,
    required this.hats,
  });

  int _player(int side) => side == 0 ? me : 1 - me;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rnd = Random(look.t.hashCode);
    canvas.save();
    if (look.shake > 0) {
      canvas.translate(
        (rnd.nextDouble() * 2 - 1) * look.shake,
        (rnd.nextDouble() * 2 - 1) * look.shake,
      );
    }
    _arenaFloor(canvas, w, h);

    // Whoever is pinning is drawn on top.
    final pinner = fight.state.pinner;
    final order = pinner != null && _sideOf(pinner) == 0 ? [1, 0] : [0, 1];
    for (final side in order) {
      _fighter(canvas, w, h, side);
    }
    canvas.restore();

    final sparkOrigin = Offset(w / 2 + (look.sparkAt == 0 ? 20 : -20), h * .6);
    for (final s in look.sparks) {
      canvas.drawCircle(
        sparkOrigin + s.pos,
        4,
        Paint()
          ..color = (s.white ? Colors.white : _skins[look.sparkAt].ring)
              .withValues(alpha: (s.life * 2).clamp(0.0, 1.0)),
      );
    }
    if (look.flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: look.flash * .5),
      );
    }
    _hud(canvas, w);
    _banner(canvas, w, h);
  }

  int _sideOf(int player) => player == me ? 0 : 1;

  void _arenaFloor(Canvas canvas, double w, double h) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * .9),
        width: w * 1.5,
        height: h * .4,
      ),
      Paint()..color = const Color(0xFF2B1F5E),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * .84),
        width: w * .84,
        height: h * .13,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x33F5C76B),
    );
  }

  Paint _fill(_Skin s, Offset a, Offset b) => Paint()
    ..shader = ui.Gradient.linear(
      a,
      b,
      [s.lite, s.base, s.shade],
      const [0, .55, 1],
    );

  Paint _stroke(Color c, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = c;

  void _fighter(Canvas canvas, double w, double h, int side) {
    final p = _player(side);
    final s = _skins[side];
    final dir = side == 0 ? 1.0 : -1.0;
    final k = min(w / 390 * .92, h / 700);
    final a = look.angle[side];
    final st = fight.state;
    final edge = _stroke(s.edge, 5);

    canvas.save();
    canvas.translate(w / 2 - dir * w * .25, h * .82);
    canvas.scale(dir * k, k);

    // Forearm from the bottom corner.
    final arm = Path()
      ..moveTo(-58, 40)
      ..cubicTo(-90, 120, -150, 190, -190, 260)
      ..lineTo(10, 260)
      ..cubicTo(20, 190, 40, 120, 50, 70)
      ..close();
    canvas.drawPath(arm, _fill(s, const Offset(-140, 0), const Offset(40, 0)));
    canvas.drawPath(arm, edge);

    // Back of the hand.
    final hand = Path()
      ..moveTo(-62, 10)
      ..cubicTo(-70, -30, -30, -42, 10, -36)
      ..cubicTo(50, -32, 70, -10, 70, 30)
      ..cubicTo(72, 80, 50, 110, 0, 112)
      ..cubicTo(-45, 112, -66, 70, -62, 10)
      ..close();
    canvas.drawPath(
        hand, _fill(s, const Offset(-70, -20), const Offset(70, 90)));
    canvas.drawPath(hand, edge);

    // Curled fingers on the side facing the opponent.
    for (var i = 0; i < 4; i++) {
      final y = -24.0 + i * 30;
      final finger = Path()
        ..moveTo(34, y)
        ..cubicTo(70, y - 6, 90, y + 4, 90, y + 15)
        ..cubicTo(90, y + 28, 68, y + 33, 34, y + 28)
        ..close();
      canvas.drawPath(finger, _fill(s, Offset(30, y), Offset(92, y + 30)));
      canvas.drawPath(finger, edge);
      canvas.drawPath(
        Path()
          ..moveTo(74, y + 6)
          ..quadraticBezierTo(80, y + 15, 74, y + 23),
        _stroke(s.edge.withValues(alpha: .6), 2.5),
      );
    }
    for (final x in const [-30.0, -6.0, 18.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(x, -30), radius: 9),
        pi * 1.1,
        pi * .8,
        false,
        _stroke(s.edge.withValues(alpha: .5), 3),
      );
    }

    // The thumb pivots at its base joint and leans toward the middle.
    final bob = sin(look.t * 3.2 + p * 1.7) * .05 * (1 - min(1.0, a.abs()));
    canvas.save();
    canvas.translate(-14, -30);
    canvas.rotate(bob + a * 1.28);
    if (st.pinner == 1 - p) canvas.scale(1.06, .9);
    final thumb = Path()
      ..moveTo(-34, 14)
      ..cubicTo(-42, -40, -40, -104, -6, -132)
      ..cubicTo(22, -146, 40, -118, 38, -86)
      ..cubicTo(36, -50, 34, -16, 32, 14)
      ..close();
    canvas.drawPath(thumb, _fill(s, const Offset(-36, 0), const Offset(34, 0)));
    canvas.drawPath(thumb, edge);
    canvas.drawPath(
      Path()
        ..moveTo(20, -36)
        ..quadraticBezierTo(27, -30, 33, -36)
        ..moveTo(18, -28)
        ..quadraticBezierTo(26, -21, 33, -27),
      _stroke(s.edge.withValues(alpha: .6), 2.5),
    );
    // Nail on the back of the tip.
    canvas.save();
    canvas.translate(-22, -104);
    canvas.rotate(-.35);
    final nail = Rect.fromCenter(center: Offset.zero, width: 22, height: 48);
    canvas.drawOval(nail, Paint()..color = const Color(0xFFFFE6DA));
    canvas.drawOval(nail, _stroke(s.edge, 3));
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(0, -6), radius: 7),
      pi * 1.15,
      pi * .7,
      false,
      _stroke(Colors.white.withValues(alpha: .8), 3),
    );
    canvas.restore();

    _face(canvas, p);

    // Hat on the tip.
    canvas.save();
    canvas.translate(4, -136);
    canvas.rotate(-.15);
    final hat = TextPainter(
      text: TextSpan(text: hats[side], style: const TextStyle(fontSize: 40)),
      textDirection: TextDirection.ltr,
    )..layout();
    hat.paint(canvas, Offset(-hat.width / 2, -hat.height + 8));
    canvas.restore();

    canvas.restore();
    canvas.restore();
  }

  void _face(Canvas canvas, int p) {
    final st = fight.state;
    final side = _sideOf(p);
    final hurt = look.hurt[side] > 0 || st.winner == 1 - p;
    final smug = st.down == p || st.winner == p;
    final pinning = st.pinner == p;
    const ink = Color(0xFF2A1610);
    final line = _stroke(ink, 2.6);
    canvas.save();
    canvas.translate(14, -86);
    for (final ex in const [-7.0, 11.0]) {
      if (hurt) {
        canvas.drawLine(Offset(ex - 5, -5), Offset(ex + 5, 5), line);
        canvas.drawLine(Offset(ex + 5, -5), Offset(ex - 5, 5), line);
      } else {
        final eye = Rect.fromCenter(
          center: Offset(ex, 0),
          width: 13,
          height: smug ? 8 : 16,
        );
        canvas.drawOval(eye, Paint()..color = Colors.white);
        canvas.drawOval(eye, line);
        canvas.drawCircle(
          Offset(ex + 2.5, smug ? 1 : .5),
          2.8,
          Paint()..color = ink,
        );
      }
    }
    final brow = _stroke(ink, 3.2);
    canvas.drawLine(
        const Offset(-15, -14), Offset(-2, pinning ? -7 : -10), brow);
    canvas.drawLine(const Offset(20, -15), Offset(7, pinning ? -7 : -10), brow);
    if (hurt) {
      final mouth =
          Rect.fromCenter(center: const Offset(2, 20), width: 16, height: 12);
      canvas.drawOval(mouth, Paint()..color = const Color(0xFF5A1F1F));
      canvas.drawOval(mouth, line);
    } else if (smug) {
      canvas.drawPath(
        Path()
          ..moveTo(-8, 16)
          ..quadraticBezierTo(4, 26, 14, 13),
        line,
      );
    } else {
      final teeth = RRect.fromLTRBR(-8, 13, 14, 23, const Radius.circular(4));
      canvas.drawRRect(teeth, Paint()..color = Colors.white);
      canvas.drawRRect(teeth, line);
      canvas.drawLine(const Offset(-8, 18), const Offset(14, 18), line);
    }
    canvas.restore();
  }

  void _hud(Canvas canvas, double w) {
    const top = 14.0;
    final half = w / 2 - 14;
    for (final side in const [0, 1]) {
      final p = _player(side);
      final x0 = side == 0 ? 12.0 : w / 2 + 8;
      final bw = half - 8;
      // Bars drain from the outside toward the middle.
      void bar(double frac, Paint paint, double y, double bh, double width) {
        final ww = max(bh, width * frac.clamp(0.0, 1.0));
        final left = side == 0 ? x0 + bw - ww : x0;
        canvas.drawRRect(
          RRect.fromLTRBR(left, y, left + ww, y + bh, Radius.circular(bh / 2)),
          paint,
        );
      }

      canvas.drawRRect(
        RRect.fromLTRBR(x0, top, x0 + bw, top + 16, const Radius.circular(8)),
        Paint()..color = Colors.white.withValues(alpha: .08),
      );
      bar(
        look.recoil[side] / 100,
        Paint()..color = const Color(0xFFFF5C8A),
        top,
        16,
        bw,
      );
      bar(
        look.hp[side] / 100,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, top),
            const Offset(0, top + 16),
            [const Color(0xFFFFF3C9), _skins[side].ring],
          ),
        top,
        16,
        bw,
      );
      // Stamina, blinking while the other player's taunt drains it.
      final drained = fight.state.down == 1 - p;
      final blink = drained ? .55 + .45 * sin(look.t * 30) : 1.0;
      final sw = bw * .75;
      final sx = side == 0 ? x0 + bw - sw : x0;
      canvas.drawRRect(
        RRect.fromLTRBR(
            sx, top + 22, sx + sw, top + 29, const Radius.circular(4)),
        Paint()..color = Colors.white.withValues(alpha: .06),
      );
      final staminaFrac = max(.04, fight.stamina[p] / 100);
      final stw = sw * staminaFrac;
      final stx = side == 0 ? x0 + bw - stw : x0;
      canvas.drawRRect(
        RRect.fromLTRBR(
            stx, top + 22, stx + stw, top + 29, const Radius.circular(4)),
        Paint()..color = const Color(0xFF8BE9FF).withValues(alpha: blink),
      );
      // Name and round pips.
      final name = TextPainter(
        text: TextSpan(
          text: names[side],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: half - 60);
      name.paint(
        canvas,
        Offset(side == 0 ? 14 : w - 14 - name.width, top + 38),
      );
      final won = fight.roundsOf(p);
      for (var i = 0; i < ThumbWar.roundsToWin; i++) {
        final cx = side == 0 ? w / 2 - 22 - i * 18.0 : w / 2 + 22 + i * 18.0;
        final c = Offset(cx, top + 46);
        if (won > i) {
          canvas.drawCircle(c, 6, Paint()..color = const Color(0xFFF5C76B));
        }
        canvas.drawCircle(
            c, 6, _stroke(Colors.white.withValues(alpha: .5), 1.5));
      }
    }
    final vs = TextPainter(
      text: const TextSpan(
        text: 'VS',
        style: TextStyle(
          color: Color(0xFFF5C76B),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    vs.paint(canvas, Offset(w / 2 - vs.width / 2, top));
  }

  void _banner(Canvas canvas, double w, double h) {
    final f = fight;
    String? text;
    var ticks = f.phaseTicks;
    if (f.phase == FightPhase.intro) {
      if (ticks < ThumbWar.fightCallTick) {
        text = f.isFinalRound ? 'FINAL ROUND' : 'ROUND ${f.round}';
      } else {
        text = 'FIGHT!';
        ticks -= ThumbWar.fightCallTick;
      }
    } else if (f.phase == FightPhase.ko || f.phase == FightPhase.over) {
      text = 'K.O.';
    }
    if (text == null) return;
    final grow = min(1.0, ticks / 12);
    final scale = .6 + .4 * grow;
    final style = TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.w900,
      letterSpacing: 1,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF1B1030),
    );
    final outline = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final fill = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          foreground: Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, -outline.height / 2),
              Offset(0, outline.height / 2),
              [
                const Color(0xFFFFF3C9),
                text == 'K.O.'
                    ? const Color(0xFFFF5C8A)
                    : const Color(0xFFF5C76B),
              ],
            ),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(w / 2, h * .36);
    canvas.scale(scale);
    final at = Offset(-outline.width / 2, -outline.height / 2);
    outline.paint(canvas, at);
    fill.paint(canvas, at);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter old) => true;
}
