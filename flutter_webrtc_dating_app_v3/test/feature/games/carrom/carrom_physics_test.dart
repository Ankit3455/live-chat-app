import 'dart:math' as math;

import 'package:availchat/feature/games/carrom/carrom_physics.dart';
import 'package:availchat/feature/games/carrom/carrom_rules.dart';

import 'carrom_test_shim.dart'
    if (dart.library.ui) 'package:flutter_test/flutter_test.dart';

// Also runs without Flutter: dart run test/feature/games/carrom/carrom_physics_test.dart
void main() {
  PhysicsBody coin(String id, double x, double y,
          {double vx = 0, double vy = 0}) =>
      PhysicsBody(
        id: id,
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        radius: kCoinRadius,
        mass: kCoinMass,
      );

  PhysicsBody striker(double x, double y, {double vx = 0, double vy = 0}) =>
      PhysicsBody(
        id: kStrikerId,
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        radius: kStrikerRadius,
        mass: kStrikerMass,
      );

  void runUntil(CarromWorld w, bool Function() done, {int max = 100000}) {
    for (var i = 0; i < max && !done(); i++) {
      w.step();
    }
  }

  double pathLength(ShotResult r, int body) {
    var d = 0.0;
    for (var i = 1; i < r.frames.length; i++) {
      final a = r.frames[i - 1];
      final b = r.frames[i];
      if (b[2 * body].isNaN) break;
      final dx = b[2 * body] - a[2 * body];
      final dy = b[2 * body + 1] - a[2 * body + 1];
      d += math.sqrt(dx * dx + dy * dy);
    }
    return d;
  }

  void expectValidBoard(Map<String, CarromPos> coins) {
    final ids = coins.keys.toList();
    for (var i = 0; i < ids.length; i++) {
      final p = coins[ids[i]]!;
      final r = radiusOfCoin(ids[i]);
      expect(p.x, greaterThanOrEqualTo(r - 1e-9), reason: ids[i]);
      expect(p.x, lessThanOrEqualTo(kBoardSize - r + 1e-9), reason: ids[i]);
      expect(p.y, greaterThanOrEqualTo(r - 1e-9), reason: ids[i]);
      expect(p.y, lessThanOrEqualTo(kBoardSize - r + 1e-9), reason: ids[i]);
      for (var j = i + 1; j < ids.length; j++) {
        expect(
          p.distanceTo(coins[ids[j]]!),
          greaterThanOrEqualTo(r + radiusOfCoin(ids[j]) - 1e-6),
          reason: '${ids[i]} overlaps ${ids[j]}',
        );
      }
    }
  }

  test('momentum is conserved in body collisions', () {
    final bodies = [
      striker(20, 37, vx: 300, vy: 20),
      coin('w0', 30, 37.5),
      coin('b0', 34, 36),
      coin('w1', 38, 38.5),
    ];
    double px() => bodies.fold(0.0, (s, b) => s + b.mass * b.vx);
    double py() => bodies.fold(0.0, (s, b) => s + b.mass * b.vy);
    final px0 = px();
    final py0 = py();
    final w = CarromWorld(bodies, friction: false, pockets: false);
    var hits = 0;
    for (var i = 0; i < 40; i++) {
      w.step();
      hits = w.events.where((e) => e.type == ShotEventType.collision).length;
    }
    expect(hits, greaterThan(0));
    expect(w.events.where((e) => e.type == ShotEventType.rail), isEmpty);
    expect(px(), closeTo(px0, 1e-9 * px0.abs()));
    expect(py(), closeTo(py0, 1e-6));
  });

  test('head-on equal masses swap velocities at e = 1', () {
    final a = coin('w0', 30, 37, vx: 120);
    final b = coin('w1', 30 + 2 * kCoinRadius + 0.5, 37);
    final w =
        CarromWorld([a, b], friction: false, pockets: false, restitution: 1);
    runUntil(w, () => w.events.isNotEmpty);
    expect(a.vx, closeTo(0, 1e-9));
    expect(b.vx, closeTo(120, 1e-9));
    expect(a.vy, closeTo(0, 1e-12));
    expect(b.vy, closeTo(0, 1e-12));
  });

  test('striker hitting a coin head-on follows the 1D impulse formula', () {
    const v = 300.0;
    final s = striker(20, 37, vx: v);
    final c = coin('w0', 20 + kStrikerRadius + kCoinRadius + 1, 37);
    final w = CarromWorld([s, c], friction: false, pockets: false);
    runUntil(w, () => w.events.isNotEmpty);
    const ms = kStrikerMass;
    const mc = kCoinMass;
    const e = kRestitutionStriker;
    expect(c.vx, closeTo((1 + e) * ms / (ms + mc) * v, 1e-9));
    expect(s.vx, closeTo((ms - e * mc) / (ms + mc) * v, 1e-9));
  });

  test('rails reflect the normal velocity with rail restitution', () {
    final c = coin('w0', kBoardSize - 5, 30, vx: 100, vy: 40);
    final w = CarromWorld([c], friction: false, pockets: false);
    runUntil(w, () => w.events.isNotEmpty);
    expect(w.events.single.type, ShotEventType.rail);
    expect(c.vx, closeTo(-100 * kRestitutionRail, 1e-9));
    expect(c.vy, closeTo(40, 1e-9));
    expect(c.x, lessThanOrEqualTo(kBoardSize - kCoinRadius));
  });

  test('stopping distance matches the analytic friction model', () {
    for (final v0 in [60.0, 150.0]) {
      final c = coin('w0', 5, 37, vx: v0);
      final w = CarromWorld([c], pockets: false);
      runUntil(w, () => !w.moving);
      const a = kDecel;
      const k = kVisc;
      final expected = (v0 - a / k * math.log(1 + k * v0 / a)) / k;
      expect(c.x - 5, closeTo(expected, expected * 0.01), reason: 'v0 $v0');
    }
  });

  test('a full-power striker covers 2.5 to 3 board lengths', () {
    final r = simulateShot(
      const {},
      CarromPos(kBoardSize / 2, baselineY(hostSide: true)),
      const CarromPos(0, -kMaxStrikerSpeed),
    );
    final boards = pathLength(r, 0) / kBoardSize;
    expect(boards, greaterThanOrEqualTo(2.5));
    expect(boards, lessThanOrEqualTo(3.0));
  });

  test('no tunnelling: every aimed max-speed shot hits its target', () {
    final rnd = math.Random(7);
    for (var i = 0; i < 300; i++) {
      final sx =
          kBaselineMinX + rnd.nextDouble() * (kBaselineMaxX - kBaselineMinX);
      final sy = baselineY(hostSide: true);
      final tx = 8 + rnd.nextDouble() * (kBoardSize - 16);
      final ty = 8 + rnd.nextDouble() * (sy - 16);
      final dx = tx - sx;
      final dy = ty - sy;
      final d = math.sqrt(dx * dx + dy * dy);
      // Offset the aim sideways by up to 90% of a full-ball miss.
      final off =
          (rnd.nextDouble() * 2 - 1) * 0.9 * (kStrikerRadius + kCoinRadius);
      final ax = tx + -dy / d * off;
      final ay = ty + dx / d * off;
      final ad = math.sqrt((ax - sx) * (ax - sx) + (ay - sy) * (ay - sy));
      final r = simulateShot(
        {'w0': CarromPos(tx, ty)},
        CarromPos(sx, sy),
        CarromPos((ax - sx) / ad * kMaxStrikerSpeed,
            (ay - sy) / ad * kMaxStrikerSpeed),
      );
      final first = r.events.firstWhere((e) => e.type != ShotEventType.pocket);
      expect(first.type, ShotEventType.collision, reason: 'shot $i');
    }
  });

  test('fast coins never pass through each other', () {
    final rnd = math.Random(11);
    for (var i = 0; i < 200; i++) {
      final y = 20 + rnd.nextDouble() * 30;
      final off = (rnd.nextDouble() * 2 - 1) * 1.9 * kCoinRadius;
      final a = coin('w0', 8, y, vx: 650);
      final b = coin('b0', 40, y + off, vx: -650);
      final w = CarromWorld([a, b], friction: false, pockets: false);
      runUntil(w, () => w.events.isNotEmpty);
      expect(w.events.first.type, ShotEventType.collision, reason: 'pair $i');
    }
  });

  test('pocket captures slow coins only', () {
    final slow = coin('w0', kPockets[0].x, kPockets[0].y, vx: 60, vy: 60);
    final ws = CarromWorld([slow]);
    ws.step();
    expect(ws.pocketed, ['w0']);
    expect(ws.events.single.pocket, 0);

    final fast = coin('w1', kPockets[0].x, kPockets[0].y, vx: 300, vy: 300);
    final wf = CarromWorld([fast]);
    runUntil(
      wf,
      () => CarromPos(fast.x, fast.y).distanceTo(kPockets[0]) > kPocketRadius,
    );
    expect(wf.pocketed, isEmpty);
    expect(fast.active, isTrue);
  });

  test('a coin rolled gently into a corner drops into that pocket', () {
    final c = coin('w0', 15, 15, vx: -110, vy: -110);
    final w = CarromWorld([c]);
    runUntil(w, () => !w.moving || w.pocketed.isNotEmpty);
    expect(w.pocketed, ['w0']);
    expect(w.events.last.pocket, 0);
    expect(w.events.last.speed, lessThanOrEqualTo(kPocketCaptureSpeed));
  });

  test('striker straight into a pocket is reported as a foul input', () {
    final p = kPockets[3];
    final from = CarromPos(p.x - 20, p.y - 20);
    final r = simulateShot(const {}, from, const CarromPos(150, 150));
    expect(r.strikerPocketed, isTrue);
    expect(r.strikerFinal, isNull);
  });

  test('simulation is deterministic and independent of map order', () {
    final start = CarromState.initial().coins;
    final reversed = Map.fromEntries(start.entries.toList().reversed);
    final pos = CarromPos(kBoardSize / 2 + 3, baselineY(hostSide: true));
    const vel = CarromPos(-25, -470);
    final a = simulateShot(start, pos, vel);
    final b = simulateShot(reversed, pos, vel);
    final c = simulateShot(start, pos, vel, recordFrames: false);
    expect(a.hash, b.hash);
    expect(a.hash, c.hash);
    expect(a.pocketed, b.pocketed);
    // Golden: changes here mean old shots replay differently, so bump
    // kCarromPhysicsVersion together with this value.
    expect(a.hash, kGoldenBreakHash);
  });

  test('random shots always terminate with a valid board', () {
    final rnd = math.Random(2024);
    for (var i = 0; i < 150; i++) {
      final board = i.isEven ? CarromState.initial().coins : _scatter(rnd);
      final host = rnd.nextBool();
      final spot = strikerSpot(
        board,
        hostSide: host,
        x: kBaselineMinX + rnd.nextDouble() * (kBaselineMaxX - kBaselineMinX),
      );
      final ang = (rnd.nextDouble() * 2 - 1) * 1.3;
      final speed = rnd.nextDouble() * kMaxStrikerSpeed;
      final dir = host ? -1.0 : 1.0;
      final r = simulateShot(
        board,
        spot,
        CarromPos(math.sin(ang) * speed, dir * math.cos(ang) * speed),
      );
      expect(r.duration, lessThan(15), reason: 'shot $i');
      expect(r.coins.length + r.pocketed.length, board.length);
      expectValidBoard(r.coins);
      expect(r.frames.length, greaterThanOrEqualTo(2));
    }
  });

  test('the starting layout leaves the striker free on both baselines', () {
    final start = CarromState.initial().coins;
    expectValidBoard(start);
    for (final host in [true, false]) {
      final p = strikerSpot(start, hostSide: host);
      expect(p.x, closeTo(kBoardSize / 2, 1e-9));
    }
  });
}

/// Golden hash for the break shot in the determinism test.
const String kGoldenBreakHash = '00fd8d462b3cb78b';

Map<String, CarromPos> _scatter(math.Random rnd) {
  final coins = <String, CarromPos>{};
  final ids = [
    kQueenId,
    for (var i = 0; i < 9; i++) 'w$i',
    for (var i = 0; i < 9; i++) 'b$i',
  ];
  for (final id in ids) {
    if (rnd.nextDouble() < 0.25) continue;
    for (var tries = 0; tries < 50; tries++) {
      final p = CarromPos(
        3 + rnd.nextDouble() * (kBoardSize - 6),
        14 + rnd.nextDouble() * (kBoardSize - 28),
      );
      if (coins.values.every((q) => q.distanceTo(p) > 2 * kCoinRadius + 0.01)) {
        coins[id] = p;
        break;
      }
    }
  }
  return coins;
}
