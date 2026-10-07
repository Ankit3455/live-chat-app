import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A colour look applied to video at render time. The sender's choice is
/// shared over signaling so both sides draw the same look for that video.
class VideoFilter {
  final String id;
  final String label;

  /// 5x4 colour matrix for [ColorFilter.matrix]; null means unchanged.
  final List<double>? matrix;

  /// Soft light wash drawn over the video (the "Glow" look).
  final bool glow;

  const VideoFilter._(this.id, this.label, this.matrix, {this.glow = false});

  // Ids are sent to the other side, so existing ones keep their meaning
  // (an older app still maps them); unknown new ids fall back to Normal there.
  // Looks are kept subtle so skin stays natural.

  static const normal = VideoFilter._('normal', 'Normal', null);

  static final vivid = VideoFilter._(
    'vivid',
    'Vivid',
    _compose([_saturation(1.18), _contrast(1.08), _temperature(0.1)]),
  );

  // Clean and airy: a touch brighter, slightly softer contrast.
  static final bright = VideoFilter._(
    'bright',
    'Bright',
    _compose([
      _brightness(0.045),
      _contrast(0.96),
      _saturation(1.04),
      _temperature(0.05),
    ]),
  );

  static final warm = VideoFilter._(
    'warm',
    'Warm',
    _compose([
      _temperature(0.55),
      _tint(0.1),
      _saturation(1.04),
      _brightness(0.015),
    ]),
  );

  static final golden = VideoFilter._(
    'golden',
    'Golden',
    _compose([
      _temperature(0.85),
      _tint(0.15),
      _saturation(1.08),
      _contrast(1.04),
      _fade(10, 6, 0),
      _brightness(0.02),
    ]),
  );

  static final rosy = VideoFilter._(
    'rosy',
    'Rosy',
    _compose([
      _tint(0.5),
      _temperature(0.15),
      _contrast(0.97),
      _fade(8, 6, 7),
      _brightness(0.02),
    ]),
  );

  // Lifted blacks and lower contrast, plus a light pink wash.
  static final glowLook = VideoFilter._(
    'glow',
    'Glow',
    _compose([
      _contrast(0.9),
      _fade(14, 12, 13),
      _tint(0.15),
      _saturation(1.02),
      _brightness(0.03),
    ]),
    glow: true,
  );

  static final cool = VideoFilter._(
    'cool',
    'Cool',
    _compose([
      _temperature(-0.45),
      _tint(0.05),
      _contrast(1.03),
      _saturation(0.97),
    ]),
  );

  // Faded film: muted colour, softer contrast, cool-lifted shadows.
  static final vintage = VideoFilter._(
    'vintage',
    'Film',
    _compose([
      _saturation(0.82),
      _contrast(0.92),
      _fade(12, 16, 20, drop: 12),
      _temperature(0.2),
    ]),
  );

  static final sepia = VideoFilter._(
    'sepia',
    'Sepia',
    _compose([
      _saturation(0),
      _contrast(0.95),
      _gains(1.08, 0.98, 0.82),
      _fade(10, 6, 2),
    ]),
  );

  static final mono = VideoFilter._(
    'bw',
    'Noir',
    _compose([_saturation(0), _contrast(1.25), _brightness(-0.02)]),
  );

  static final all = [
    normal,
    vivid,
    bright,
    warm,
    golden,
    rosy,
    glowLook,
    cool,
    vintage,
    sepia,
    mono,
  ];

  // ── Matrix composer ──────────────────────────────────────────────────────
  // Each step is a 5x4 matrix (offsets in 0..255); _compose applies them in
  // list order, first step first.

  static List<double> _compose(List<List<double>> steps) {
    var m = _gains(1, 1, 1);
    for (final step in steps) {
      m = _multiply(step, m);
    }
    return List.unmodifiable(m);
  }

  /// [a] after [b].
  static List<double> _multiply(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 5; c++) {
        var v = c == 4 ? a[r * 5 + 4] : 0.0;
        for (var k = 0; k < 4; k++) {
          v += a[r * 5 + k] * b[k * 5 + c];
        }
        out[r * 5 + c] = v;
      }
    }
    return out;
  }

  static List<double> _gains(
    double r,
    double g,
    double b, {
    double offR = 0,
    double offG = 0,
    double offB = 0,
  }) => [
    r, 0, 0, 0, offR, //
    0, g, 0, 0, offG,
    0, 0, b, 0, offB,
    0, 0, 0, 1, 0,
  ];

  /// 0 = grey, 1 = unchanged.
  static List<double> _saturation(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final t = 1 - s;
    return [
      lr * t + s, lg * t, lb * t, 0, 0, //
      lr * t, lg * t + s, lb * t, 0, 0,
      lr * t, lg * t, lb * t + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  /// Around mid-grey, so the overall brightness stays put.
  static List<double> _contrast(double c) {
    final o = 128 * (1 - c);
    return _gains(c, c, c, offR: o, offG: o, offB: o);
  }

  /// Fraction of full scale added to every channel.
  static List<double> _brightness(double b) {
    final o = 255 * b;
    return _gains(1, 1, 1, offR: o, offG: o, offB: o);
  }

  /// Positive is warmer (amber), negative cooler (blue).
  static List<double> _temperature(double t) =>
      _gains(1 + 0.10 * t, 1 + 0.02 * t, 1 - 0.12 * t);

  /// Positive is pinker (magenta), negative greener.
  static List<double> _tint(double t) =>
      _gains(1 + 0.02 * t, 1 - 0.06 * t, 1 + 0.02 * t);

  /// Lifts blacks to (r, g, b) and pulls whites down by [drop].
  static List<double> _fade(double r, double g, double b, {double drop = 0}) =>
      _gains(
        (255 - r - drop) / 255,
        (255 - g - drop) / 255,
        (255 - b - drop) / 255,
        offR: r,
        offG: g,
        offB: b,
      );

  /// Unknown or missing ids fall back to [normal].
  static VideoFilter byId(String? id) {
    for (final f in all) {
      if (f.id == id) return f;
    }
    return normal;
  }

  static const _prefKey = 'call_video_filter';

  static Future<VideoFilter> loadPreferred() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return byId(prefs.getString(_prefKey));
    } catch (_) {
      return normal;
    }
  }

  static Future<void> savePreferred(VideoFilter filter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, filter.id);
    } catch (_) {}
  }
}

/// Draws [child] with [filter] applied.
class VideoFilterView extends StatelessWidget {
  final VideoFilter filter;
  final Widget child;

  const VideoFilterView({super.key, required this.filter, required this.child});

  @override
  Widget build(BuildContext context) {
    final matrix = filter.matrix;
    if (matrix == null) return child;
    final filtered = ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: child,
    );
    if (!filter.glow) return filtered;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        filtered,
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.9,
                  colors: [Color(0x10FFFFFF), Color(0x1AFFC9D9)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
