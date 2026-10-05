// lib/feature/games/love_physics/love_physics_game.dart
// Love Physics - solo puzzle: draw ramps so the two hearts roll into each other.
// Targets flame ^1.34.0 and flame_forge2d ^0.19.2+2.

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Transform;
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../widgets/custom_button.dart';

// Camera zoom: 100 logical px = 1 world meter. The camera is anchored top-left,
// so world = screen / pixelsPerMeter.
const double pixelsPerMeter = 100.0;

Vector2 toWorld(Vector2 screen) => screen / pixelsPerMeter;

const double _playerRadius = 0.3;
const double _matchTolerance = 0.03;
const double _lineStroke = 0.06;
const int _maxLines = 30;

// -----------------------------------------------------------------------------
// LovePhysicsScreen - Flutter wrapper; handles drawing gestures and the result.
// -----------------------------------------------------------------------------

class LovePhysicsScreen extends StatefulWidget {
  const LovePhysicsScreen({super.key});
  @override
  State<LovePhysicsScreen> createState() => _LovePhysicsScreenState();
}

class _LovePhysicsScreenState extends State<LovePhysicsScreen> {
  late LovePhysicsGame _game;
  Vector2? _lastPoint;

  @override
  void initState() {
    super.initState();
    _game = LovePhysicsGame();
    _game.matched.addListener(_onMatched);
  }

  void _onMatched() {
    if (_game.matched.value) Haptics.success();
  }

  @override
  void dispose() {
    _game.pauseEngine();
    _game.matched.dispose();
    super.dispose();
  }

  void _restart() {
    final old = _game;
    old.matched.removeListener(_onMatched);
    setState(() => _game = LovePhysicsGame());
    _game.matched.addListener(_onMatched);
    old.pauseEngine();
    WidgetsBinding.instance.addPostFrameCallback((_) => old.matched.dispose());
  }

  Vector2 _toWorld(Offset local) => toWorld(Vector2(local.dx, local.dy));

  void _onPanStart(DragStartDetails details) {
    final pt = _toWorld(details.localPosition);
    _lastPoint = pt;
    _game.startDrawingAt(pt);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final pt = _toWorld(details.localPosition);
    if (_lastPoint == null || (_lastPoint! - pt).length > 0.05) {
      _lastPoint = pt;
      _game.addDrawingPoint(pt);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _game.finishDrawing();
    _lastPoint = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDarkest,
      appBar: AppBar(
        title: const Text('Love Physics'),
        backgroundColor: AppColors.surfaceCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restart',
            onPressed: _restart,
          ),
        ],
      ),
      // expand: the win overlay is the only non-positioned child and is
      // zero-size until a match, which would shrink the game to nothing.
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: GameWidget(key: ObjectKey(_game), game: _game),
            ),
          ),
          const Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: IgnorePointer(
              child: Text(
                'Draw ramps with your finger to bring the hearts together.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.lavender, fontSize: 14),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _game.matched,
            builder: (context, matched, _) {
              if (!matched) return const SizedBox.shrink();
              final win = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: const Text(
                      'You brought them together!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.pinkLight,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Play again',
                    leftIcon: Icons.refresh,
                    width: 200,
                    onPressed: _restart,
                  ),
                ],
              );
              return Align(
                alignment: const Alignment(0, -0.6),
                child: MediaQuery.disableAnimationsOf(context)
                    ? win
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutBack,
                        builder: (context, t, child) => Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.85 + 0.15 * t,
                            child: child,
                          ),
                        ),
                        child: win,
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LovePhysicsGame - main Forge2D game class
// -----------------------------------------------------------------------------

class LovePhysicsGame extends Forge2DGame {
  LovePhysicsGame() : super(gravity: Vector2(0, 10), zoom: pixelsPerMeter);

  final ValueNotifier<bool> matched = ValueNotifier<bool>(false);

  late PlayerBody playerA;
  late PlayerBody playerB;

  final List<Vector2> _drawingPoints = [];
  final List<DrawnLineBody> _lines = [];
  late _DrawingPreview _preview;
  bool _released = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;

    final worldSize = toWorld(size);
    final w = worldSize.x;
    final h = worldSize.y;

    playerA = PlayerBody(
      initialPosition: Vector2(w * 0.2, h * 0.2),
      color: Colors.pinkAccent,
      nudge: Vector2(-0.05, 0),
    );
    playerB = PlayerBody(
      initialPosition: Vector2(w * 0.8, h * 0.8),
      color: Colors.lightBlueAccent,
      nudge: Vector2(0.05, 0),
    );
    _preview = _DrawingPreview(_drawingPoints);

    world.addAll([
      Wall(worldWidth: w, worldHeight: h),
      playerA,
      playerB,
      _preview,
    ]);
  }

  // Called from widget gestures (world coordinates).
  void startDrawingAt(Vector2 worldPt) {
    if (matched.value) return;
    _drawingPoints
      ..clear()
      ..add(worldPt);
  }

  void addDrawingPoint(Vector2 worldPt) {
    if (_drawingPoints.isEmpty) return;
    _drawingPoints.add(worldPt);
  }

  void finishDrawing() {
    if (_drawingPoints.length >= 2) {
      final line = DrawnLineBody(points: List.of(_drawingPoints));
      _lines.add(line);
      world.add(line);
      // The hearts hold still until the first ramp exists, otherwise they
      // fall into the corners before the player can draw anything.
      if (!_released) {
        _released = true;
        playerA.release();
        playerB.release();
      }
      // Keep the body count bounded; removing a BodyComponent destroys its body.
      if (_lines.length > _maxLines) {
        _lines.removeAt(0).removeFromParent();
      }
    }
    _drawingPoints.clear();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (matched.value || !playerA.isLoaded || !playerB.isLoaded) return;

    final distance = (playerA.body.position - playerB.body.position).length;
    if (distance <= playerA.radius + playerB.radius + _matchTolerance) {
      matched.value = true;
      playerA.body.applyLinearImpulse(Vector2(0, -0.3));
      playerB.body.applyLinearImpulse(Vector2(0, -0.3));
    }
  }
}

// -----------------------------------------------------------------------------
// _DrawingPreview - renders the stroke currently being drawn.
// -----------------------------------------------------------------------------

class _DrawingPreview extends Component {
  _DrawingPreview(this.points) : super(priority: 100);

  final List<Vector2> points;

  final Paint _paint = Paint()
    ..color = Colors.pinkAccent.withOpacity(0.6)
    ..strokeWidth = _lineStroke
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void render(Canvas canvas) {
    if (points.length < 2) return;
    canvas.drawPath(_pathOf(points), _paint);
  }
}

Path _pathOf(List<Vector2> points) {
  final path = Path()..moveTo(points.first.x, points.first.y);
  for (var i = 1; i < points.length; i++) {
    path.lineTo(points[i].x, points[i].y);
  }
  return path;
}

// -----------------------------------------------------------------------------
// DrawnLineBody - one static body with a single chain fixture along the stroke.
// -----------------------------------------------------------------------------

class DrawnLineBody extends BodyComponent {
  DrawnLineBody({required this.points});

  final List<Vector2> points; // world coords (meters)

  final Paint _linePaint = Paint()
    ..color = Colors.pinkAccent
    ..strokeWidth = _lineStroke
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  Body createBody() {
    final bd = BodyDef()
      ..type = BodyType.static
      ..position = Vector2.zero();
    final body = world.createBody(bd);
    final chain = ChainShape()..createChain(points);
    body.createFixture(FixtureDef(chain)
      ..friction = 0.8
      ..restitution = 0.0);
    return body;
  }

  // The body sits at the origin, so local coordinates equal world coordinates.
  @override
  void render(Canvas canvas) {
    canvas.drawPath(_pathOf(points), _linePaint);
  }
}

// -----------------------------------------------------------------------------
// PlayerBody - dynamic circle body
// -----------------------------------------------------------------------------

class PlayerBody extends BodyComponent {
  PlayerBody({
    required this.initialPosition,
    required this.color,
    required this.nudge,
    this.radius = _playerRadius,
  });

  final Vector2 initialPosition;
  final Color color;
  final Vector2 nudge;
  final double radius;

  @override
  Body createBody() {
    final bd = BodyDef()
      ..type = BodyType.static
      ..position = initialPosition;
    final b = world.createBody(bd);
    final shape = CircleShape()..radius = radius;
    b.createFixture(FixtureDef(shape)
      ..density = 1.0
      ..friction = 0.3
      ..restitution = 0.2);
    return b;
  }

  /// Lets gravity act on the heart. Called outside the physics step.
  void release() {
    if (!isLoaded) return;
    body.setType(BodyType.dynamic);
    body.applyLinearImpulse(nudge);
  }

  // Canvas is already in body-local space (meters).
  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, radius, Paint()..color = color);
    canvas.drawCircle(
      Offset.zero,
      radius * 0.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 0.02,
    );
  }
}

// -----------------------------------------------------------------------------
// Wall - world boundaries as one closed chain loop.
// -----------------------------------------------------------------------------

class Wall extends BodyComponent {
  Wall({required this.worldWidth, required this.worldHeight});

  final double worldWidth;
  final double worldHeight;

  @override
  Body createBody() {
    final bd = BodyDef()
      ..type = BodyType.static
      ..position = Vector2.zero();
    final body = world.createBody(bd);
    final loop = ChainShape()
      ..createLoop([
        Vector2(0, 0),
        Vector2(worldWidth, 0),
        Vector2(worldWidth, worldHeight),
        Vector2(0, worldHeight),
      ]);
    body.createFixture(FixtureDef(loop)..friction = 0.5);
    return body;
  }

  // Screen edges are the walls; nothing to draw.
  @override
  void render(Canvas canvas) {}
}
