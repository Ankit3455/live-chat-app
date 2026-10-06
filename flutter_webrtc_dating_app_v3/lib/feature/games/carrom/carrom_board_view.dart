import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'carrom_physics.dart';
import 'carrom_rules.dart';

/// Wooden frame drawn around the 74 cm surface (render only).
const double kBoardFrame = 5.0;
const double kBoardTotal = kBoardSize + 2 * kBoardFrame;

/// Pull-back distance (cm) for full power, and the dead zone that cancels.
const double _kMaxPull = 20.0;
const double _kCancelPull = 2.5;
const double _kMinShotSpeed = 25.0;

/// Shots must go forward: at most this far from straight ahead.
const double _kMaxAimAngle = 80 * math.pi / 180;

const double _kLerpSeconds = 0.6;
const double _kEffectSeconds = 0.8;

enum _DragMode { none, pending, place, aim }

class _PocketFx {
  _PocketFx(this.pos, this.color);
  final CarromPos pos;
  final Color color;
  double age = 0;
}

/// Everything the board shows: synced coins, the local striker, aiming, shot
/// playback and pocket effects. Positions are in board centimetres.
class CarromBoardController extends ChangeNotifier {
  CarromBoardController({
    required this.canShoot,
    required this.onShoot,
    this.onEvent,
  });

  final bool Function() canShoot;
  final void Function(CarromPos strikerPos, CarromPos velocity) onShoot;
  final void Function(ShotEvent event)? onEvent;

  /// Aim power 0..1 while pulling back, null otherwise.
  final ValueNotifier<double?> aimPower = ValueNotifier(null);

  bool _flipped = false;
  bool get flipped => _flipped;
  bool _strikerHostSide = true;

  Map<String, CarromPos> _coins = CarromState.initial().coins;
  Map<String, CarromPos> get coins => _coins;
  CarromPos? _striker;
  CarromPos? get striker => _striker;

  final List<_PocketFx> _effects = [];

  _DragMode _mode = _DragMode.none;
  CarromPos? _dragStart;
  double _grabOffsetX = 0;
  CarromPos? _finger;
  CarromPos? _aimDir;

  ShotResult? _playback;
  double _playT = 0;
  int _nextEvent = 0;
  VoidCallback? _onDone;

  Map<String, CarromPos>? _lerpFrom;
  Map<String, CarromPos>? _lerpTo;
  double _lerpT = 0;

  bool get busy => _playback != null || _lerpTo != null;
  bool get wantsTicks => busy || _effects.isNotEmpty;
  bool get aiming => _mode == _DragMode.aim && _aimDir != null;
  CarromPos? get aimDir => _aimDir;
  CarromPos? get finger => _finger;
  double get power => aimPower.value ?? 0;
  bool get showPlacementHint => !busy && _mode == _DragMode.none && canShoot();

  void setPerspective({required bool isHost}) {
    if (_flipped == !isHost) return;
    _flipped = !isHost;
    notifyListeners();
  }

  void setStrikerSide({required bool hostSide}) {
    if (_strikerHostSide == hostSide && _striker != null) return;
    _strikerHostSide = hostSide;
    if (!busy) {
      _cancelDrag();
      _resetStriker();
      notifyListeners();
    }
  }

  /// Snaps to a synced state; coins that disappeared get a pocket effect.
  void showState(CarromState state, {bool effects = false}) {
    _finishAnimations();
    if (effects) {
      for (final id in _coins.keys) {
        if (!state.coins.containsKey(id)) {
          _effects.add(_PocketFx(_nearestPocket(_coins[id]!), Colors.orange));
        }
      }
    }
    _coins = Map.of(state.coins);
    _cancelDrag();
    _resetStriker();
    notifyListeners();
  }

  /// Fallback when a shot can't be replayed: slide to the new state.
  void animateTo(CarromState state, {VoidCallback? onDone}) {
    _finishAnimations();
    _lerpFrom = Map.of(_coins);
    _lerpTo = {
      for (final e in _coins.entries)
        e.key: state.coins[e.key] ?? _nearestPocket(e.value),
    };
    _lerpT = 0;
    _onDone = () {
      showState(state, effects: true);
      onDone?.call();
    };
    _cancelDrag();
    notifyListeners();
  }

  /// Plays a simulated shot in real time, then calls [onDone].
  void play(ShotResult result, {VoidCallback? onDone}) {
    _finishAnimations();
    _cancelDrag();
    _playback = result;
    _playT = 0;
    _nextEvent = 0;
    _onDone = onDone;
    _applyFrame();
    notifyListeners();
  }

  void tick(double dt) {
    if (dt <= 0) return;
    // Long frames (app paused) must not skip the whole shot.
    final step = dt > 0.1 ? 0.1 : dt;
    for (final fx in _effects) {
      fx.age += step;
    }
    _effects.removeWhere((fx) => fx.age >= _kEffectSeconds);

    if (_playback != null) {
      _playT += step;
      _applyFrame();
      if (_playT >= _playback!.duration) _completeAnimation();
    } else if (_lerpTo != null) {
      _lerpT += step / _kLerpSeconds;
      if (_lerpT >= 1) {
        _completeAnimation();
      } else {
        final t = Curves.easeOut.transform(_lerpT);
        final from = _lerpFrom!;
        _coins = {
          for (final e in _lerpTo!.entries)
            e.key: CarromPos(
              from[e.key]!.x + (e.value.x - from[e.key]!.x) * t,
              from[e.key]!.y + (e.value.y - from[e.key]!.y) * t,
            ),
        };
      }
    }
    notifyListeners();
  }

  void _applyFrame() {
    final r = _playback!;
    final pos = r.positionsAt(_playT);
    _striker = pos.remove(kStrikerId);
    _coins = pos;
    while (
        _nextEvent < r.events.length && r.events[_nextEvent].time <= _playT) {
      final e = r.events[_nextEvent++];
      if (e.type == ShotEventType.pocket) {
        _effects.add(_PocketFx(
          kPockets[e.pocket],
          e.a == kStrikerId ? Colors.yellow : Colors.orange,
        ));
      }
      onEvent?.call(e);
    }
  }

  void _completeAnimation() {
    final done = _onDone;
    _playback = null;
    _lerpTo = null;
    _lerpFrom = null;
    _onDone = null;
    done?.call();
  }

  /// Ends any running animation immediately (a newer state is arriving).
  void _finishAnimations() {
    if (!busy) return;
    _playback = null;
    _lerpTo = null;
    _lerpFrom = null;
    _onDone = null;
  }

  void _resetStriker() {
    _striker = strikerSpot(_coins, hostSide: _strikerHostSide);
  }

  CarromPos _nearestPocket(CarromPos from) {
    var best = kPockets.first;
    for (final p in kPockets) {
      if (from.distanceTo(p) < from.distanceTo(best)) best = p;
    }
    return best;
  }

  // ==================== INPUT ====================
  double get _forwardY => _strikerHostSide ? -1 : 1;

  void dragStart(CarromPos p) {
    _cancelDrag();
    final s = _striker;
    if (s == null || busy || !canShoot()) return;
    if (p.distanceTo(s) <= kStrikerRadius * 2.4) {
      _mode = _DragMode.pending;
      _dragStart = p;
      _grabOffsetX = s.x - p.x;
    } else if ((p.y - s.y).abs() <= kStrikerRadius * 2 &&
        p.x >= kBaselineMinX - kStrikerRadius &&
        p.x <= kBaselineMaxX + kStrikerRadius) {
      _mode = _DragMode.place;
      _grabOffsetX = 0;
      _placeAt(p.x);
    }
  }

  void dragUpdate(CarromPos p) {
    if (_mode == _DragMode.none) return;
    if (busy || !canShoot()) {
      _cancelDrag();
      notifyListeners();
      return;
    }
    switch (_mode) {
      case _DragMode.pending:
        final start = _dragStart!;
        final dx = p.x - start.x;
        final dy = p.y - start.y;
        if (dx * dx + dy * dy < 0.8 * 0.8) return;
        // Pulling back toward your own rail aims; sideways places.
        final back = -dy * _forwardY;
        _mode = back > dx.abs() * 0.6 ? _DragMode.aim : _DragMode.place;
        dragUpdate(p);
      case _DragMode.place:
        _placeAt(p.x + _grabOffsetX);
      case _DragMode.aim:
        _aim(p);
      case _DragMode.none:
        break;
    }
  }

  void dragEnd() {
    final s = _striker;
    final dir = _aimDir;
    final shoot = _mode == _DragMode.aim &&
        dir != null &&
        s != null &&
        !busy &&
        canShoot();
    final speed = _kMinShotSpeed + power * (kMaxStrikerSpeed - _kMinShotSpeed);
    _cancelDrag();
    notifyListeners();
    if (shoot) onShoot(s, CarromPos(dir.x * speed, dir.y * speed));
  }

  void dragCancel() {
    _cancelDrag();
    notifyListeners();
  }

  void _cancelDrag() {
    _mode = _DragMode.none;
    _dragStart = null;
    _finger = null;
    _aimDir = null;
    aimPower.value = null;
  }

  void _placeAt(double x) {
    final target = CarromPos(
      x.clamp(kBaselineMinX, kBaselineMaxX).toDouble(),
      baselineY(hostSide: _strikerHostSide),
    );
    if (strikerSpotFree(_coins, target)) {
      _striker = target;
      notifyListeners();
    }
  }

  void _aim(CarromPos p) {
    final s = _striker!;
    _finger = p;
    var ux = s.x - p.x;
    var uy = s.y - p.y;
    final len = math.sqrt(ux * ux + uy * uy);
    if (len < _kCancelPull) {
      _aimDir = null;
      aimPower.value = null;
      notifyListeners();
      return;
    }
    ux /= len;
    uy /= len;
    final minForward = math.cos(_kMaxAimAngle);
    if (uy * _forwardY < minForward) {
      final side = ux < 0 ? -1.0 : 1.0;
      ux = side * math.sin(_kMaxAimAngle);
      uy = minForward * _forwardY;
    }
    _aimDir = CarromPos(ux, uy);
    aimPower.value =
        ((len - _kCancelPull) / (_kMaxPull - _kCancelPull)).clamp(0.0, 1.0);
    notifyListeners();
  }

  @override
  void dispose() {
    aimPower.dispose();
    super.dispose();
  }
}

/// Square board widget: paints the controller and feeds it touches.
class CarromBoardView extends StatefulWidget {
  const CarromBoardView({super.key, required this.controller});

  final CarromBoardController controller;

  @override
  State<CarromBoardView> createState() => _CarromBoardViewState();
}

class _CarromBoardViewState extends State<CarromBoardView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  CarromBoardController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_syncTicker);
    _syncTicker();
  }

  @override
  void didUpdateWidget(CarromBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncTicker);
      _c.addListener(_syncTicker);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_syncTicker);
    _ticker.dispose();
    super.dispose();
  }

  void _syncTicker() {
    if (_c.wantsTicks && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!_c.wantsTicks && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _c.tick(dt);
  }

  CarromPos _toBoard(Offset local, double side) {
    final scale = side / kBoardTotal;
    var x = local.dx / scale - kBoardFrame;
    var y = local.dy / scale - kBoardFrame;
    if (_c.flipped) {
      x = kBoardSize - x;
      y = kBoardSize - y;
    }
    return CarromPos(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Start where the finger went down, not after the touch slop.
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (d) => _c.dragStart(_toBoard(d.localPosition, side)),
          onPanUpdate: (d) => _c.dragUpdate(_toBoard(d.localPosition, side)),
          onPanEnd: (_) => _c.dragEnd(),
          onPanCancel: _c.dragCancel,
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.square(side),
              painter: _BoardPainter(_c),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.c) : super(repaint: c);

  final CarromBoardController c;

  static final Paint _pocketPaint = Paint()..color = const Color(0xFF1A1A1A);
  static final Paint _linePaint = Paint()
    ..color = Colors.black87
    ..strokeWidth = 0.18
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / kBoardTotal;
    canvas.save();
    canvas.scale(scale);
    if (c.flipped) {
      canvas.translate(kBoardTotal / 2, kBoardTotal / 2);
      canvas.rotate(math.pi);
      canvas.translate(-kBoardTotal / 2, -kBoardTotal / 2);
    }
    _paintFrame(canvas);
    canvas.translate(kBoardFrame, kBoardFrame);
    _paintSurface(canvas);
    for (final fx in c._effects) {
      final t = (fx.age / _kEffectSeconds).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(fx.pos.x, fx.pos.y),
        kPocketRadius + t * 3.5,
        Paint()
          ..color = fx.color.withValues(alpha: 1 - t)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
    c.coins.forEach((id, p) => _paintCoin(canvas, id, p));
    final s = c.striker;
    if (s != null) {
      if (c.aiming) _paintAim(canvas, s);
      _paintStriker(canvas, s);
      if (c.showPlacementHint) {
        canvas.drawCircle(
          Offset(s.x, s.y),
          kStrikerRadius + 0.6,
          Paint()
            ..color = Colors.lightGreenAccent.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.25,
        );
      }
    }
    canvas.restore();
  }

  void _paintFrame(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, kBoardTotal, kBoardTotal);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
  }

  void _paintSurface(Canvas canvas) {
    const surface = Rect.fromLTWH(0, 0, kBoardSize, kBoardSize);
    canvas.drawRect(surface, Paint()..color = const Color(0xFFF3E5AB));
    canvas.drawRect(surface.deflate(0.4), _linePaint);

    for (final p in kPockets) {
      canvas.drawCircle(Offset(p.x, p.y), kPocketRadius, _pocketPaint);
    }

    // Baselines on all four sides: two lines 3.18 apart, red end circles.
    final red = Paint()..color = const Color(0xFFC62828);
    for (int side = 0; side < 4; side++) {
      canvas.save();
      canvas.translate(kBoardSize / 2, kBoardSize / 2);
      canvas.rotate(side * math.pi / 2);
      canvas.translate(-kBoardSize / 2, -kBoardSize / 2);
      const outer = kBoardSize - kBaselineOuter;
      const inner = outer - kBaselineWidth;
      const x0 = kBaselineMinX;
      const x1 = kBaselineMaxX;
      canvas.drawLine(
          const Offset(x0, outer), const Offset(x1, outer), _linePaint);
      canvas.drawLine(
          const Offset(x0, inner), const Offset(x1, inner), _linePaint);
      for (final x in const [x0, x1]) {
        const cy = outer - kBaselineWidth / 2;
        canvas.drawCircle(Offset(x, cy), kBaselineWidth / 2, red);
        canvas.drawCircle(Offset(x, cy), kBaselineWidth / 2, _linePaint);
      }
      // Diagonal arrow line from the pocket toward the centre.
      canvas.drawLine(
        const Offset(kBoardSize - 6.5, kBoardSize - 6.5),
        const Offset(kBoardSize - 26, kBoardSize - 26),
        _linePaint,
      );
      canvas.restore();
    }

    const centre = Offset(kBoardSize / 2, kBoardSize / 2);
    canvas.drawCircle(
      centre,
      8.5,
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.25,
    );
    canvas.drawCircle(centre, kCoinRadius, red);
  }

  static Color _colorFor(String id) {
    if (id == kQueenId) return const Color(0xFFD32F2F);
    return colourOfCoin(id) == kWhite
        ? const Color(0xFFFAF3E0)
        : const Color(0xFF212121);
  }

  void _paintCoin(Canvas canvas, String id, CarromPos p) {
    final r = radiusOfCoin(id);
    final o = Offset(p.x, p.y);
    canvas.drawCircle(
      o + Offset(r * 0.15, r * 0.15),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.15),
    );
    canvas.drawCircle(o, r, Paint()..color = _colorFor(id));
    canvas.drawCircle(
      o,
      r * 0.7,
      Paint()
        ..color = colourOfCoin(id) == kBlack ? Colors.white24 : Colors.black12
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.15,
    );
    canvas.drawOval(
      Rect.fromLTWH(o.dx - r * 0.5, o.dy - r * 0.6, r * 0.6, r * 0.3),
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );
  }

  void _paintStriker(Canvas canvas, CarromPos p) {
    const r = kStrikerRadius;
    final o = Offset(p.x, p.y);
    canvas.drawCircle(
      o + const Offset(r * 0.12, r * 0.12),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );
    final rect = Rect.fromCircle(center: o, radius: r);
    canvas.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.yellow.shade50, Colors.orange.shade100],
        ).createShader(rect),
    );
    canvas.drawCircle(
      o,
      r * 0.7,
      Paint()
        ..color = Colors.blue.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12,
    );
    canvas.drawArc(
      Rect.fromCircle(center: o, radius: r * 0.9),
      math.pi,
      math.pi / 2,
      false,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  void _paintAim(Canvas canvas, CarromPos s) {
    final dir = c.aimDir!;
    final power = c.power;
    final o = Offset(s.x, s.y);
    final color = Color.lerp(Colors.lightGreenAccent, Colors.redAccent, power)!;

    final f = c.finger;
    if (f != null) {
      canvas.drawLine(
        o,
        Offset(f.x, f.y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 0.35
          ..strokeCap = StrokeCap.round,
      );
    }

    // Dashed aim line, longer with more power.
    final length = 10 + power * 45;
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 0.35
      ..strokeCap = StrokeCap.round;
    for (double d = kStrikerRadius + 0.6; d < length; d += 2.2) {
      final e = math.min(d + 1.2, length);
      canvas.drawLine(
        o + Offset(dir.x * d, dir.y * d),
        o + Offset(dir.x * e, dir.y * e),
        dash,
      );
    }
    final tip = o + Offset(dir.x * length, dir.y * length);
    final side = Offset(-dir.y, dir.x);
    final back = Offset(dir.x, dir.y) * 1.6;
    canvas.drawPath(
      ui.Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((tip - back + side * 0.9).dx, (tip - back + side * 0.9).dy)
        ..lineTo((tip - back - side * 0.9).dx, (tip - back - side * 0.9).dy)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // Power ring around the striker.
    canvas.drawArc(
      Rect.fromCircle(center: o, radius: kStrikerRadius + 1.0),
      -math.pi / 2,
      2 * math.pi * power,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) => oldDelegate.c != c;
}
