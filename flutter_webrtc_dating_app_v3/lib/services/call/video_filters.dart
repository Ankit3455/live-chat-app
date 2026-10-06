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

  static const normal = VideoFilter._('normal', 'Normal', null);

  static const warm = VideoFilter._('warm', 'Warm', [
    1.10, 0, 0, 0, 12, //
    0, 1.02, 0, 0, 4,
    0, 0, 0.85, 0, -6,
    0, 0, 0, 1, 0,
  ]);

  static const cool = VideoFilter._('cool', 'Cool', [
    0.90, 0, 0, 0, -6, //
    0, 1.0, 0, 0, 2,
    0, 0, 1.15, 0, 14,
    0, 0, 0, 1, 0,
  ]);

  static const mono = VideoFilter._('bw', 'B&W', [
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  static const vintage = VideoFilter._('vintage', 'Vintage', [
    0.90, 0.06, 0.04, 0, 22, //
    0.07, 0.84, 0.05, 0, 14,
    0.05, 0.08, 0.68, 0, 8,
    0, 0, 0, 1, 0,
  ]);

  static const bright = VideoFilter._('bright', 'Bright', [
    1.12, 0, 0, 0, 20, //
    0, 1.12, 0, 0, 20,
    0, 0, 1.12, 0, 20,
    0, 0, 0, 1, 0,
  ]);

  // Lifted blacks and lower contrast, plus a light pink wash.
  static const glowLook = VideoFilter._('glow', 'Glow', [
    0.88, 0, 0, 0, 34, //
    0, 0.86, 0, 0, 28,
    0, 0, 0.88, 0, 30,
    0, 0, 0, 1, 0,
  ], glow: true);

  static const sepia = VideoFilter._('sepia', 'Sepia', [
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  static const all = [normal, warm, cool, mono, vintage, bright, glowLook, sepia];

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
                  colors: [Color(0x14FFFFFF), Color(0x26F9A8D4)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
