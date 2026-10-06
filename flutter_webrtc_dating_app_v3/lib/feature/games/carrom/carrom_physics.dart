// Deterministic Carrom physics in centimetres on an ICF board. Pure Dart (no
// Flutter/Firebase) so the shooter and the opponent replay a shot to the same
// result: fixed time step, fixed body order, only + - * / sqrt in the loop.
import 'dart:math' as math;
import 'dart:typed_data';

import 'carrom_rules.dart';

/// Bump whenever anything below changes the outcome of a shot. Opponents only
/// replay shots recorded with the same version.
const int kCarromPhysicsVersion = 2;

const double kCoinMass = 5.5;
const double kStrikerMass = 15.0;

const double kRestitutionCoin = 0.85;
const double kRestitutionStriker = 0.80;
const double kRestitutionRail = 0.70;

/// Sliding friction: speed' = speed - (kDecel + kVisc * speed) * dt.
const double kDecel = 180.0;
const double kVisc = 0.25;

const int kStepsPerSecond = 1200;
const double kStep = 1 / kStepsPerSecond;
const int kFrameRate = 60;
const int kStepsPerFrame = kStepsPerSecond ~/ kFrameRate;

/// A body whose centre is over a pocket drops only below this speed.
const double kPocketCaptureSpeed = 350.0;
const double kSleepSpeed = 0.5;

/// Full power. Covers roughly 2.5–3 board lengths including rail bounces.
const double kMaxStrikerSpeed = 480.0;

/// Safety net only; a full-power shot settles in well under 10 s.
const double kMaxSimSeconds = 40.0;

const String kStrikerId = 's';

enum ShotEventType { collision, rail, pocket }

class ShotEvent {
  /// Seconds since the strike.
  final double time;
  final ShotEventType type;
  final String a;
  final String? b;

  /// Closing speed (collision), normal speed (rail) or speed (pocket), cm/s.
  final double speed;

  /// Index into [kPockets] for pocket events, otherwise -1.
  final int pocket;

  const ShotEvent({
    required this.time,
    required this.type,
    required this.a,
    this.b,
    required this.speed,
    this.pocket = -1,
  });
}

class PhysicsBody {
  PhysicsBody({
    required this.id,
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    required this.radius,
    required this.mass,
  });

  final String id;
  final double radius;
  final double mass;
  double x;
  double y;
  double vx;
  double vy;
  bool active = true;

  double get speed => math.sqrt(vx * vx + vy * vy);
  bool get resting => vx == 0 && vy == 0;

  factory PhysicsBody.coin(String id, CarromPos p) => PhysicsBody(
        id: id,
        x: p.x,
        y: p.y,
        radius: radiusOfCoin(id),
        mass: kCoinMass,
      );

  factory PhysicsBody.striker(CarromPos p, CarromPos v) => PhysicsBody(
        id: kStrikerId,
        x: p.x,
        y: p.y,
        vx: v.x,
        vy: v.y,
        radius: kStrikerRadius,
        mass: kStrikerMass,
      );
}

double _pairRestitution(PhysicsBody a, PhysicsBody b) =>
    a.id == kStrikerId || b.id == kStrikerId
        ? kRestitutionStriker
        : kRestitutionCoin;

/// One board in motion. [simulateShot] is the normal entry point; tests drive
/// [step] directly.
class CarromWorld {
  CarromWorld(
    this.bodies, {
    this.friction = true,
    this.pockets = true,
    this.restitution,
    this.railRestitution = kRestitutionRail,
  });

  /// Stepped in list order; keep it identical on every device.
  final List<PhysicsBody> bodies;
  final bool friction;
  final bool pockets;

  /// Overrides the body–body restitution (tests).
  final double? restitution;
  final double railRestitution;

  final List<ShotEvent> events = [];
  final List<String> pocketed = [];
  int steps = 0;

  double get time => steps * kStep;

  bool get moving {
    for (final b in bodies) {
      if (b.active && !b.resting) return true;
    }
    return false;
  }

  void step() {
    steps++;
    final t = time;
    if (friction) {
      for (final b in bodies) {
        if (b.active && !b.resting) _applyFriction(b);
      }
    }
    for (final b in bodies) {
      if (!b.active || b.resting) continue;
      b.x += b.vx * kStep;
      b.y += b.vy * kStep;
    }
    final n = bodies.length;
    for (int i = 0; i < n; i++) {
      final a = bodies[i];
      if (!a.active) continue;
      for (int j = i + 1; j < n; j++) {
        final b = bodies[j];
        if (!b.active || (a.resting && b.resting)) continue;
        _collide(a, b, t);
      }
    }
    for (final b in bodies) {
      if (b.active) _rails(b, t);
    }
    if (pockets) {
      for (final b in bodies) {
        if (b.active) _pocket(b, t);
      }
    }
  }

  void _applyFriction(PhysicsBody b) {
    final s = b.speed;
    var ns = s - (kDecel + kVisc * s) * kStep;
    if (ns < kSleepSpeed) ns = 0;
    if (ns == 0) {
      b.vx = 0;
      b.vy = 0;
    } else {
      final k = ns / s;
      b.vx *= k;
      b.vy *= k;
    }
  }

  void _collide(PhysicsBody a, PhysicsBody b, double t) {
    final sum = a.radius + b.radius;
    var dx = b.x - a.x;
    if (dx > sum || -dx > sum) return;
    var dy = b.y - a.y;
    if (dy > sum || -dy > sum) return;
    final d2 = dx * dx + dy * dy;
    if (d2 >= sum * sum) return;

    var d = math.sqrt(d2);
    if (d == 0) {
      dx = 1;
      dy = 0;
      d = 1;
    }
    final nx = dx / d;
    final ny = dy / d;
    final invA = 1 / a.mass;
    final invB = 1 / b.mass;

    final vn = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
    if (vn < 0) {
      final e = restitution ?? _pairRestitution(a, b);
      final j = -(1 + e) * vn / (invA + invB);
      a.vx -= j * invA * nx;
      a.vy -= j * invA * ny;
      b.vx += j * invB * nx;
      b.vy += j * invB * ny;
      events.add(ShotEvent(
        time: t,
        type: ShotEventType.collision,
        a: a.id,
        b: b.id,
        speed: -vn,
      ));
    }

    // Mass-weighted push apart so stacked contacts never sink into each other.
    final pen = (sum - (d2 == 0 ? 0 : d)) / (invA + invB);
    a.x -= pen * invA * nx;
    a.y -= pen * invA * ny;
    b.x += pen * invB * nx;
    b.y += pen * invB * ny;
  }

  void _rails(PhysicsBody b, double t) {
    final r = b.radius;
    final hi = kBoardSize - r;
    if (b.x < r) {
      b.x = r;
      if (b.vx < 0) _bounce(b, t, b.vx, horizontal: true);
    } else if (b.x > hi) {
      b.x = hi;
      if (b.vx > 0) _bounce(b, t, b.vx, horizontal: true);
    }
    if (b.y < r) {
      b.y = r;
      if (b.vy < 0) _bounce(b, t, b.vy, horizontal: false);
    } else if (b.y > hi) {
      b.y = hi;
      if (b.vy > 0) _bounce(b, t, b.vy, horizontal: false);
    }
  }

  void _bounce(PhysicsBody b, double t, double v, {required bool horizontal}) {
    if (horizontal) {
      b.vx = -b.vx * railRestitution;
    } else {
      b.vy = -b.vy * railRestitution;
    }
    events.add(ShotEvent(
      time: t,
      type: ShotEventType.rail,
      a: b.id,
      speed: v < 0 ? -v : v,
    ));
  }

  void _pocket(PhysicsBody b, double t) {
    const r2 = kPocketRadius * kPocketRadius;
    for (int i = 0; i < kPockets.length; i++) {
      final p = kPockets[i];
      final dx = b.x - p.x;
      final dy = b.y - p.y;
      if (dx * dx + dy * dy > r2) continue;
      final s = b.speed;
      if (s > kPocketCaptureSpeed) return;
      b.active = false;
      b.vx = 0;
      b.vy = 0;
      pocketed.add(b.id);
      events.add(ShotEvent(
        time: t,
        type: ShotEventType.pocket,
        a: b.id,
        speed: s,
        pocket: i,
      ));
      return;
    }
  }

  /// Pushes resting bodies apart; used once motion has stopped.
  void settle({int iterations = 12}) {
    for (int it = 0; it < iterations; it++) {
      var moved = false;
      for (int i = 0; i < bodies.length; i++) {
        final a = bodies[i];
        if (!a.active) continue;
        for (int j = i + 1; j < bodies.length; j++) {
          final b = bodies[j];
          if (!b.active) continue;
          final sum = a.radius + b.radius;
          var dx = b.x - a.x;
          var dy = b.y - a.y;
          final d2 = dx * dx + dy * dy;
          if (d2 >= sum * sum) continue;
          var d = math.sqrt(d2);
          if (d == 0) {
            dx = 1;
            dy = 0;
            d = 1;
          }
          final half = (sum - (d2 == 0 ? 0 : d)) / 2 + 0.0005;
          a.x -= half * dx / d;
          a.y -= half * dy / d;
          b.x += half * dx / d;
          b.y += half * dy / d;
          moved = true;
        }
      }
      for (final b in bodies) {
        if (!b.active) continue;
        final r = b.radius;
        if (b.x < r) b.x = r;
        if (b.x > kBoardSize - r) b.x = kBoardSize - r;
        if (b.y < r) b.y = r;
        if (b.y > kBoardSize - r) b.y = kBoardSize - r;
      }
      if (!moved) return;
    }
  }
}

class ShotResult {
  /// Body ids in frame order; index 0 is the striker.
  final List<String> ids;

  /// Positions at [kFrameRate] Hz: x0, y0, x1, y1… NaN once pocketed.
  final List<Float64List> frames;

  final Map<String, CarromPos> coins;
  final List<String> pocketed;
  final bool strikerPocketed;
  final CarromPos? strikerFinal;
  final List<ShotEvent> events;
  final int steps;
  final String hash;

  const ShotResult({
    required this.ids,
    required this.frames,
    required this.coins,
    required this.pocketed,
    required this.strikerPocketed,
    required this.strikerFinal,
    required this.events,
    required this.steps,
    required this.hash,
  });

  double get duration => steps * kStep;

  /// Interpolated positions [seconds] after the strike (playback only).
  Map<String, CarromPos> positionsAt(double seconds) {
    final out = <String, CarromPos>{};
    if (frames.isEmpty) return out;
    final f = seconds * kFrameRate;
    final last = frames.length - 1;
    final i0 = f <= 0 ? 0 : (f >= last ? last : f.floor());
    final i1 = i0 >= last ? last : i0 + 1;
    final k = (f - i0).clamp(0.0, 1.0);
    final a = frames[i0];
    final b = frames[i1];
    for (int i = 0; i < ids.length; i++) {
      final ax = a[2 * i];
      final bx = b[2 * i];
      if (ax.isNaN) continue;
      if (bx.isNaN) {
        out[ids[i]] = CarromPos(ax, a[2 * i + 1]);
        continue;
      }
      out[ids[i]] = CarromPos(
        ax + (bx - ax) * k,
        a[2 * i + 1] + (b[2 * i + 1] - a[2 * i + 1]) * k,
      );
    }
    return out;
  }
}

/// Clamps an aimed velocity to [kMaxStrikerSpeed].
CarromPos clampStrikerVelocity(CarromPos v) {
  final s = math.sqrt(v.x * v.x + v.y * v.y);
  if (s <= kMaxStrikerSpeed) return v;
  final k = kMaxStrikerSpeed / s;
  return CarromPos(v.x * k, v.y * k);
}

/// Runs one shot to rest. Coin order is sorted by id so map ordering (e.g.
/// from Firestore) cannot change the result.
ShotResult simulateShot(
  Map<String, CarromPos> board,
  CarromPos strikerPos,
  CarromPos strikerVel, {
  bool recordFrames = true,
}) {
  final coinIds = board.keys.toList()..sort();
  final bodies = <PhysicsBody>[
    PhysicsBody.striker(strikerPos, clampStrikerVelocity(strikerVel)),
    for (final id in coinIds) PhysicsBody.coin(id, board[id]!),
  ];
  final world = CarromWorld(bodies);
  final ids = [for (final b in bodies) b.id];
  final frames = <Float64List>[];

  Float64List snapshot() {
    final f = Float64List(bodies.length * 2);
    for (int i = 0; i < bodies.length; i++) {
      final b = bodies[i];
      f[2 * i] = b.active ? b.x : double.nan;
      f[2 * i + 1] = b.active ? b.y : double.nan;
    }
    return f;
  }

  if (recordFrames) frames.add(snapshot());
  const maxSteps = kMaxSimSeconds * kStepsPerSecond;
  while (world.moving && world.steps < maxSteps) {
    world.step();
    if (recordFrames && world.steps % kStepsPerFrame == 0) {
      frames.add(snapshot());
    }
  }
  world.settle();
  if (recordFrames) {
    if (world.steps % kStepsPerFrame == 0 && frames.length > 1) {
      frames[frames.length - 1] = snapshot();
    } else {
      frames.add(snapshot());
    }
  }

  final striker = bodies.first;
  final coins = <String, CarromPos>{
    for (final b in bodies.skip(1))
      if (b.active) b.id: CarromPos(b.x, b.y),
  };
  final pocketed = [
    for (final id in world.pocketed)
      if (id != kStrikerId) id,
  ];
  final strikerPocketed = !striker.active;

  return ShotResult(
    ids: ids,
    frames: frames,
    coins: coins,
    pocketed: pocketed,
    strikerPocketed: strikerPocketed,
    strikerFinal: striker.active ? CarromPos(striker.x, striker.y) : null,
    events: world.events,
    steps: world.steps,
    hash: shotHash(coins, pocketed, strikerPocketed, world.steps),
  );
}

/// Short, platform-independent digest of a shot outcome (positions to 0.01 mm).
String shotHash(
  Map<String, CarromPos> coins,
  List<String> pocketed,
  bool strikerPocketed,
  int steps,
) {
  // Two 30-bit accumulators keep every product below 2^53 (web-safe ints).
  var h1 = 0x1234567;
  var h2 = 0x7654321;
  void add(int v) {
    final x = v & 0x3fffffff;
    h1 = (h1 * 31 + x) & 0x3fffffff;
    h2 = (h2 * 37 + (x ^ 0x2545f49)) & 0x3fffffff;
  }

  void addString(String s) {
    for (final c in s.codeUnits) {
      add(c);
    }
    add(0x2f);
  }

  final ids = coins.keys.toList()..sort();
  for (final id in ids) {
    addString(id);
    add((coins[id]!.x * 1000).round());
    add((coins[id]!.y * 1000).round());
  }
  add(0x7c);
  for (final id in pocketed) {
    addString(id);
  }
  add(strikerPocketed ? 1 : 0);
  add(steps);
  return h1.toRadixString(16).padLeft(8, '0') +
      h2.toRadixString(16).padLeft(8, '0');
}
