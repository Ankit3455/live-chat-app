import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/core/utils/haptics.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/questionnaire/deck/deck_widgets.dart';
import 'package:availchat/services/presence_watch.dart';

import 'cosmic_match_card.dart';

/// One zoom level of the orbit: a radius in km, or (radiusKm == null) a
/// country / everyone bucket.
class OrbitLevel {
  final String label;
  final String name;
  final double? radiusKm;
  final bool countryOnly;
  final List<Color> sky;
  const OrbitLevel(
    this.label,
    this.name,
    this.radiusKm,
    this.sky, {
    this.countryOnly = false,
  });
}

/// "In your orbit": a zoomable radar of people around me. Pinch or drag the
/// bar to zoom from ~5 km (the finest the public ~5 km location allows) out
/// to my country and everyone. Counts cover the people loaded in the feed.
class OrbitZoom extends StatefulWidget {
  final UserModel? me;
  final List<UserModel> people;
  final int? Function(UserModel) distanceKmOf;
  final ValueChanged<UserModel> onOpen;
  const OrbitZoom({
    super.key,
    required this.me,
    required this.people,
    required this.distanceKmOf,
    required this.onOpen,
  });

  static const List<OrbitLevel> levels = [
    OrbitLevel('~5 km', 'your area', 5, [Color(0xFF3B1A6E), Color(0xFF1A0F33)]),
    OrbitLevel('~10 km', 'nearby', 10, [Color(0xFF33206E), Color(0xFF160F33)]),
    OrbitLevel(
        '~25 km', 'your city', 25, [Color(0xFF25307A), Color(0xFF111536)]),
    OrbitLevel('~50 km', 'around your city', 50,
        [Color(0xFF1D3F80), Color(0xFF0F1B38)]),
    OrbitLevel(
        '~150 km', 'your region', 150, [Color(0xFF13536F), Color(0xFF0B1E2E)]),
    OrbitLevel(
        'Country', 'your country', null, [Color(0xFF0F5A5A), Color(0xFF081D22)],
        countryOnly: true),
    OrbitLevel(
        'All', 'everywhere', null, [Color(0xFF1A1240), Color(0xFF05030A)]),
  ];

  /// People inside [level]. Unknown distances only count in the country /
  /// everyone buckets.
  static List<UserModel> within(
    OrbitLevel level,
    List<UserModel> people,
    UserModel? me,
    int? Function(UserModel) distanceKmOf,
  ) {
    final r = level.radiusKm;
    if (r != null) {
      return people.where((u) {
        final d = distanceKmOf(u);
        return d != null && d <= r;
      }).toList();
    }
    if (level.countryOnly) {
      final mine = me?.countryCode;
      if (mine == null) return people;
      return people.where((u) => u.countryCode == mine).toList();
    }
    return people;
  }

  /// Smallest level with at least [enough] people, so the radar opens
  /// somewhere lively (idea from duolicious' "best distance").
  static int smartDefault(
    List<UserModel> people,
    UserModel? me,
    int? Function(UserModel) distanceKmOf, {
    int enough = 6,
  }) {
    for (var i = 0; i < levels.length; i++) {
      if (within(levels[i], people, me, distanceKmOf).length >= enough) {
        return i;
      }
    }
    return levels.length - 1;
  }

  @override
  State<OrbitZoom> createState() => _OrbitZoomState();
}

class _OrbitZoomState extends State<OrbitZoom> {
  int? _level;
  double _pinchStart = 0;
  int _levelAtPinchStart = 0;

  int get _index =>
      _level ??
      OrbitZoom.smartDefault(widget.people, widget.me, widget.distanceKmOf);

  void _setLevel(int i) {
    final next = i.clamp(0, OrbitZoom.levels.length - 1);
    if (next == _index) return;
    Haptics.selection();
    setState(() => _level = next);
  }

  @override
  Widget build(BuildContext context) {
    final i = _index;
    final level = OrbitZoom.levels[i];
    final inside =
        OrbitZoom.within(level, widget.people, widget.me, widget.distanceKmOf);
    final presence = PresenceWatch.instance;
    final online = inside.where((u) => presence.isOnline(u.uid)).length;
    final further = widget.people.length - inside.length;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 450);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: AnimatedContainer(
        duration: duration,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.borderStrong),
          gradient: RadialGradient(
            center: const Alignment(0, -.2),
            radius: 1.1,
            colors: level.sky,
          ),
        ),
        child: Column(
          children: [
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${inside.length}', style: deckSerif(32)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        level.radiusKm != null
                            ? 'people within ${level.label}'
                            : level.countryOnly
                                ? 'people in your country'
                                : 'people everywhere',
                        style: const TextStyle(
                          color: AppColors.lavenderLight,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.online.withOpacity(.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '● $online online',
                      style: const TextStyle(
                        color: AppColors.online,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onScaleStart: (d) {
                _pinchStart = 1;
                _levelAtPinchStart = i;
              },
              onScaleUpdate: (d) {
                if (d.pointerCount < 2) return;
                // Pinch out (scale > 1) zooms in to a smaller radius.
                final steps =
                    (math.log(d.scale / _pinchStart) / math.ln2 * 1.5).round();
                _setLevel(_levelAtPinchStart - steps);
              },
              child: SizedBox(
                height: 300,
                child: LayoutBuilder(
                  builder: (context, box) => _Radar(
                    size: Size(box.maxWidth, 300),
                    level: level,
                    levelIndex: i,
                    inside: inside,
                    further: further,
                    me: widget.me,
                    distanceKmOf: widget.distanceKmOf,
                    onOpen: widget.onOpen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('🔍', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      activeTrackColor: AppColors.brandMagenta,
                      inactiveTrackColor: const Color(0x730B0614),
                      thumbColor: Colors.white,
                      overlayColor: AppColors.gold.withOpacity(.15),
                      showValueIndicator: ShowValueIndicator.never,
                    ),
                    child: Slider(
                      value: i.toDouble(),
                      min: 0,
                      max: (OrbitZoom.levels.length - 1).toDouble(),
                      divisions: OrbitZoom.levels.length - 1,
                      semanticFormatterCallback: (v) =>
                          '${OrbitZoom.levels[v.round()].label}, ${OrbitZoom.levels[v.round()].name}',
                      onChanged: (v) => _setLevel(v.round()),
                    ),
                  ),
                ),
                const Text('🌍', style: TextStyle(fontSize: 13)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var k = 0; k < OrbitZoom.levels.length; k++)
                    GestureDetector(
                      onTap: () => _setLevel(k),
                      child: Text(
                        OrbitZoom.levels[k].label.replaceAll('~', ''),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: k == i ? deckGoldLight : AppColors.textSubtle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Radar extends StatelessWidget {
  final Size size;
  final OrbitLevel level;
  final int levelIndex;
  final List<UserModel> inside;
  final int further;
  final UserModel? me;
  final int? Function(UserModel) distanceKmOf;
  final ValueChanged<UserModel> onOpen;
  const _Radar({
    required this.size,
    required this.level,
    required this.levelIndex,
    required this.inside,
    required this.further,
    required this.me,
    required this.distanceKmOf,
    required this.onOpen,
  });

  static const double _face = 34;

  /// Range used to place people: the level's radius, or the farthest known
  /// distance for the country / everyone buckets.
  double _range() {
    final r = level.radiusKm;
    if (r != null) return r;
    var far = 150.0;
    for (final u in inside) {
      final d = distanceKmOf(u);
      if (d != null && d > far) far = d.toDouble();
    }
    return far;
  }

  // Stable angle per person so faces don't jump between rebuilds.
  static double _angle(String? uid) {
    var h = 0;
    for (final c in (uid ?? '').codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return (h % 3600) / 3600 * 2 * math.pi;
  }

  @override
  Widget build(BuildContext context) {
    final centre = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) / 2 - 22;
    final range = _range();
    double radiusOf(int? km) {
      if (km == null) return maxR;
      return math.min(1.0, math.log(1 + km) / math.log(1 + range)) * maxR;
    }

    final sorted = [...inside]..sort((a, b) =>
        (distanceKmOf(a) ?? 1 << 30).compareTo(distanceKmOf(b) ?? 1 << 30));
    final faces = sorted.take(levelIndex <= 3 ? 12 : 6).toList();
    final dots = sorted.skip(faces.length).take(220).toList();
    final presence = PresenceWatch.instance;
    final rings = [
      for (final l in OrbitZoom.levels)
        if (l.radiusKm != null && l.radiusKm! <= range * 1.001)
          (
            label: l.label,
            r: radiusOf(l.radiusKm!.round()),
            current: l == level
          ),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _RingsPainter(
                centre: centre,
                rings: rings,
                dots: [
                  for (final u in dots)
                    (
                      offset: centre +
                          Offset.fromDirection(
                            _angle(u.uid),
                            radiusOf(distanceKmOf(u)),
                          ),
                      online: presence.isOnline(u.uid),
                    ),
                ],
              ),
            ),
          ),
        ),
        for (final u in faces)
          Builder(builder: (context) {
            final p = centre +
                Offset.fromDirection(
                  _angle(u.uid),
                  math.max(52, radiusOf(distanceKmOf(u))),
                );
            final online = presence.isOnline(u.uid);
            final km = distanceKmOf(u);
            return Positioned(
              left: p.dx - _face / 2,
              top: p.dy - _face / 2,
              child: Semantics(
                button: true,
                label:
                    '${u.username}, ${km == null ? 'distance unknown' : km <= 5 ? 'in your area' : 'about $km km away'}${online ? ', online' : ''}. Open profile',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onOpen(u),
                  child: Container(
                    width: _face,
                    height: _face,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: online
                            ? AppColors.online
                            : AppColors.brandPurpleLight.withOpacity(.35),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: DiscoverPhoto(user: u, memCacheWidth: 120),
                    ),
                  ),
                ),
              ),
            );
          }),
        Positioned(
          left: centre.dx - 29,
          top: centre.dy - 29,
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: deckGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandMagenta.withOpacity(.55),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: me == null
                      ? const ColoredBox(color: AppColors.surface2)
                      : DiscoverPhoto(user: me!, memCacheWidth: 160),
                ),
              ),
              const Text(
                'You',
                style: TextStyle(
                  color: deckGoldLight,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 2,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x990B0614),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              further > 0 ? '+$further further' : "That's everyone",
              style: const TextStyle(
                color: AppColors.lavenderLight,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (inside.isEmpty)
          Positioned(
            left: 0,
            right: 0,
            top: centre.dy + 50,
            child: const Text(
              "No one here yet.\nZoom out to see who's around ✦",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.lavenderLight,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  final Offset centre;
  final List<({String label, double r, bool current})> rings;
  final List<({Offset offset, bool online})> dots;
  _RingsPainter(
      {required this.centre, required this.rings, required this.dots});

  @override
  void paint(Canvas canvas, Size size) {
    for (final ring in rings) {
      if (ring.r < 30) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ring.current
            ? AppColors.gold.withOpacity(.6)
            : AppColors.brandPurpleLight.withOpacity(.22);
      const dashes = 64;
      for (var k = 0; k < dashes; k++) {
        final a = k / dashes * 2 * math.pi;
        canvas.drawArc(
          Rect.fromCircle(center: centre, radius: ring.r),
          a,
          math.pi / dashes,
          false,
          paint,
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: ring.label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: ring.current
                ? deckGoldLight
                : AppColors.lavenderLight.withOpacity(.6),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, centre + Offset(-tp.width / 2, -ring.r - tp.height - 2));
    }
    final dim = Paint()..color = AppColors.lavenderLight.withOpacity(.55);
    final on = Paint()..color = AppColors.online;
    for (final d in dots) {
      canvas.drawCircle(d.offset, 3, d.online ? on : dim);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => true;
}
