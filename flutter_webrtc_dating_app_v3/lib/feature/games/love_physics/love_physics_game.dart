// lib/feature/games/love_physics/love_physics_game.dart
// Love Physics - single-file prototype compatible with
// flame: ^1.34.0 and flame_forge2d: ^0.19.2+2

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

// -----------------------------------------------------------------------------
// Helpers & configuration
// -----------------------------------------------------------------------------

const double pixelsPerMeter = 100.0; // 100 px = 1 meter

Vector2 toWorld(Vector2 screen) => screen / pixelsPerMeter;
Vector2 toScreen(Vector2 world) => world * pixelsPerMeter;

double worldDistance(Vector2 a, Vector2 b) => (a - b).length;

// -----------------------------------------------------------------------------
// GameListScreen - entry to open the Love Physics game
// -----------------------------------------------------------------------------

class GameListScreen extends StatelessWidget {
  const GameListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Games'), backgroundColor: const Color(0xFF2D1B4E)),
      backgroundColor: const Color(0xFF0D0221),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.pinkAccent),
            title: const Text('Love Physics', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Draw bridges to bring players together', style: TextStyle(color: Colors.white70)),
            tileColor: const Color(0xFF2D1B4E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LovePhysicsScreen())),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.sports_esports, color: Colors.white30),
            title: const Text('Coming soon...', style: TextStyle(color: Colors.white)),
            tileColor: const Color(0xFF2D1B4E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LovePhysicsScreen - Flutter wrapper with GestureDetector (handles input)
// -----------------------------------------------------------------------------

class LovePhysicsScreen extends StatefulWidget {
  const LovePhysicsScreen({super.key});
  @override
  State<LovePhysicsScreen> createState() => _LovePhysicsScreenState();
}

class _LovePhysicsScreenState extends State<LovePhysicsScreen> {
  late LovePhysicsGame _game;
  List<Vector2> _currentDragPoints = [];

  @override
  void initState() {
    super.initState();
    // Create game with named gravity (compatible with flame_forge2d 0.19.x)
    _game = LovePhysicsGame();
  }

  @override
  void dispose() {
    // Pause game when leaving to avoid running in background
    _game.pauseEngine();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    final worldPt = toWorld(Vector2(local.dx, local.dy));
    _currentDragPoints = [worldPt];
    _game.startDrawingAt(worldPt);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    final worldPt = toWorld(Vector2(local.dx, local.dy));
    if (_currentDragPoints.isEmpty || (_currentDragPoints.last - worldPt).length > 0.02) {
      _currentDragPoints.add(worldPt);
      _game.addDrawingPoint(worldPt);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _game.finishDrawing();
    _currentDragPoints.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0221),
      appBar: AppBar(title: const Text('Love Physics'), backgroundColor: const Color(0xFF2D1B4E)),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: GameWidget(game: _game),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LovePhysicsGame - main Forge2D game class
// -----------------------------------------------------------------------------

class LovePhysicsGame extends Forge2DGame {
  LovePhysicsGame() : super(gravity: Vector2(0, 10));

  late PlayerBodyA playerA;
  late PlayerBodyB playerB;

  final List<Vector2> _drawingPoints = [];
  final List<DrawnPath> _renderedPaths = [];

  bool _matchFound = false;
  late TextComponent _matchText;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // screen pixel size -> world conversion
    final screenPx = size.clone(); // size in pixels
    final worldW = toWorld(screenPx).x;
    final worldH = toWorld(screenPx).y;

    // world bounds (walls)
    add(Wall(worldWidth: worldW, worldHeight: worldH));

    // add two players far apart
    playerA = PlayerBodyA(position: Vector2(worldW * 0.2, worldH * 0.2));
    playerB = PlayerBodyB(position: Vector2(worldW * 0.8, worldH * 0.8));
    add(playerA);
    add(playerB);

    // match text, anchored near top-center (in world coords)
    _matchText = TextComponent(
      text: '',
      textRenderer: TextPaint(style: const TextStyle(color: Colors.pinkAccent, fontSize: 36, fontWeight: FontWeight.bold)),
      anchor: Anchor.topCenter,
      position: Vector2(screenPx.x / 2 / pixelsPerMeter, 24 / pixelsPerMeter),
      priority: 1000,
    );
    add(_matchText);
  }

  // Called from widget gestures
  void startDrawingAt(Vector2 worldPt) {
    _drawingPoints.clear();
    _drawingPoints.add(worldPt);
    _renderedPaths.add(DrawnPath(points: List.from(_drawingPoints)));
  }

  void addDrawingPoint(Vector2 worldPt) {
    if (_drawingPoints.isEmpty) return;
    _drawingPoints.add(worldPt);
    _renderedPaths.last.points = List.from(_drawingPoints);
  }

  void finishDrawing() {
    if (_drawingPoints.length < 2) {
      _drawingPoints.clear();
      if (_renderedPaths.isNotEmpty) _renderedPaths.removeLast();
      return;
    }
    add(DrawnLineBody(points: List.from(_drawingPoints)));
    // leave the visual path in _renderedPaths so the bridge remains visible
    _drawingPoints.clear();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_matchFound) return;

    // Access bodies safely; body is late-initialized inside BodyComponent
    Vector2? aPos;
    Vector2? bPos;
    try {
      aPos = playerA.body.position;
      bPos = playerB.body.position;
    } catch (_) {
      // Body not yet initialized; skip this tick
      return;
    }

    if (aPos != null && bPos != null) {
      if (worldDistance(aPos, bPos) <= 0.15) {
        _matchFound = true;
        _matchText.text = 'Match Found! ❤️';
        // celebration impulses (guarded)
        try {
          playerA.body.applyLinearImpulse(Vector2(0, -0.3));
          playerB.body.applyLinearImpulse(Vector2(0, -0.3));
        } catch (_) {}
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // draw all persistent drawn paths as thick pink paths
    final paint = Paint()
      ..color = Colors.pinkAccent
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final p in _renderedPaths) {
      if (p.points.length < 2) continue;
      final path = Path();
      final first = toScreen(p.points.first);
      path.moveTo(first.x, first.y);
      for (int i = 1; i < p.points.length; i++) {
        final pt = toScreen(p.points[i]);
        path.lineTo(pt.x, pt.y);
      }
      canvas.drawPath(path, paint);
    }
  }
}

// -----------------------------------------------------------------------------
// DrawnPath (visual helper)
// -----------------------------------------------------------------------------

class DrawnPath {
  List<Vector2> points;
  DrawnPath({required this.points});
}

// -----------------------------------------------------------------------------
// DrawnLineBody: create small static circle bodies along the drawn path
// (We create many small static bodies to approximate a continuous, thick ramp)
// -----------------------------------------------------------------------------

class DrawnLineBody extends BodyComponent {
  final List<Vector2> points; // world coords (meters)
  final double segmentRadius = 0.06; // thickness in meters (~6 px if ppm=100)

  DrawnLineBody({required this.points});

  @override
  Body createBody() {
    // Create a dummy static body for component contract
    final dummyDef = BodyDef()..type = BodyType.static..position = Vector2.zero();
    final dummy = world.createBody(dummyDef);

    // Create many small static bodies placed along the points
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final bd = BodyDef()..type = BodyType.static..position = p;
      final small = world.createBody(bd);
      final cs = CircleShape()..radius = segmentRadius;
      final fd = FixtureDef(cs)..friction = 0.8..restitution = 0.0;
      small.createFixture(fd);
    }

    return dummy;
  }
}

// -----------------------------------------------------------------------------
// PlayerBodyA & PlayerBodyB - dynamic circle bodies (simple visual rendering)
// -----------------------------------------------------------------------------

class PlayerBodyA extends BodyComponent {
  final Vector2 position;
  PlayerBodyA({required this.position});

  @override
  Body createBody() {
    final bd = BodyDef()..type = BodyType.dynamic..position = position..fixedRotation = false;
    final b = world.createBody(bd);
    final shape = CircleShape()..radius = 1.2; // meters
    final fd = FixtureDef(shape)..density = 1.0..friction = 0.3..restitution = 0.2;
    b.createFixture(fd);
    // nudge left to encourage movement
    b.applyLinearImpulse(Vector2(-0.2, 0));
    return b;
  }

  @override
  void render(Canvas canvas) {
    // guard body access
    try {
      final pos = body.position;
      final screen = toScreen(pos);
      final rPx = 1.2 * pixelsPerMeter;
      final paint = Paint()..color = Colors.pinkAccent;
      canvas.drawCircle(Offset(screen.x, screen.y), rPx, paint);
      final ring = Paint()..style = PaintingStyle.stroke..color = Colors.white..strokeWidth = 2;
      canvas.drawCircle(Offset(screen.x, screen.y), rPx - 6, ring);
    } catch (_) {
      // body not ready yet; nothing to render
      return;
    }
  }
}

class PlayerBodyB extends BodyComponent {
  final Vector2 position;
  PlayerBodyB({required this.position});

  @override
  Body createBody() {
    final bd = BodyDef()..type = BodyType.dynamic..position = position..fixedRotation = false;
    final b = world.createBody(bd);
    final shape = CircleShape()..radius = 1.2;
    final fd = FixtureDef(shape)..density = 1.0..friction = 0.3..restitution = 0.2;
    b.createFixture(fd);
    // nudge right
    b.applyLinearImpulse(Vector2(0.2, 0));
    return b;
  }

  @override
  void render(Canvas canvas) {
    try {
      final pos = body.position;
      final screen = toScreen(pos);
      final rPx = 1.2 * pixelsPerMeter;
      final paint = Paint()..color = Colors.lightBlueAccent;
      canvas.drawCircle(Offset(screen.x, screen.y), rPx, paint);
      final ring = Paint()..style = PaintingStyle.stroke..color = Colors.white..strokeWidth = 2;
      canvas.drawCircle(Offset(screen.x, screen.y), rPx - 6, ring);
    } catch (_) {
      return;
    }
  }
}

// -----------------------------------------------------------------------------
// Wall - world boundaries (static boxes around the edges)
// -----------------------------------------------------------------------------

class Wall extends Component with HasGameRef<Forge2DGame> {
  final double worldWidth;
  final double worldHeight;
  Wall({required this.worldWidth, required this.worldHeight});

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // left
    final leftDef = BodyDef()..position = Vector2(0, worldHeight / 2)..type = BodyType.static;
    final leftBody = gameRef.world.createBody(leftDef);
    final leftBox = PolygonShape()..setAsBoxXY(0.1, worldHeight);
    leftBody.createFixtureFromShape(leftBox);

    // right
    final rightDef = BodyDef()..position = Vector2(worldWidth, worldHeight / 2)..type = BodyType.static;
    final rightBody = gameRef.world.createBody(rightDef);
    final rightBox = PolygonShape()..setAsBoxXY(0.1, worldHeight);
    rightBody.createFixtureFromShape(rightBox);

    // top
    final topDef = BodyDef()..position = Vector2(worldWidth / 2, 0)..type = BodyType.static;
    final topBody = gameRef.world.createBody(topDef);
    final topBox = PolygonShape()..setAsBoxXY(worldWidth, 0.1);
    topBody.createFixtureFromShape(topBox);

    // bottom
    final bottomDef = BodyDef()..position = Vector2(worldWidth / 2, worldHeight)..type = BodyType.static;
    final bottomBody = gameRef.world.createBody(bottomDef);
    final bottomBox = PolygonShape()..setAsBoxXY(worldWidth, 0.1);
    bottomBody.createFixtureFromShape(bottomBox);
  }
}
