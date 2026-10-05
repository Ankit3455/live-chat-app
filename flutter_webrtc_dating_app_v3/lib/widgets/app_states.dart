// lib/widgets/app_states.dart
//
// Shared state widgets from the Destined design system: an inline banner
// (info / warning / error) and an empty / error state with an optional
// action, plus night-sky illustrations for those states. Screens should use
// these instead of private copies.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import 'custom_button.dart';

enum AppBannerTone { info, warning, error }

class AppBanner extends StatelessWidget {
  final String message;
  final AppBannerTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppBanner({
    super.key,
    required this.message,
    this.tone = AppBannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent;
    final IconData fallbackIcon;
    switch (tone) {
      case AppBannerTone.info:
        accent = AppColors.brandPurpleMid;
        fallbackIcon = Icons.info_outline;
        break;
      case AppBannerTone.warning:
        accent = AppColors.warning;
        fallbackIcon = Icons.warning_amber_rounded;
        break;
      case AppBannerTone.error:
        accent = AppColors.error;
        fallbackIcon = Icons.error_outline;
        break;
    }

    return Semantics(
      liveRegion: tone != AppBannerTone.info,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icon ?? fallbackIcon,
                size: 20,
                color: tone == AppBannerTone.info
                    ? AppColors.brandPurpleLight
                    : accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  /// Fallback art when [illustration] is not set.
  final IconData icon;

  /// When set, replaces the icon circle with an [AppIllustration].
  final AppIllustrationKind? illustration;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.illustration,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final kind = illustration;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind != null)
              ExcludeSemantics(child: AppIllustration(kind: kind, size: 120))
            else
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    colors: [
                      AppColors.brandPink.withValues(alpha: 0.35),
                      AppColors.brandPurple.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
                child: Icon(icon, size: 40, color: AppColors.pinkLight),
              ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.lavender,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              CustomButton(text: actionLabel!, onPressed: onAction, width: 220),
            ],
            if (secondaryLabel != null && onSecondary != null)
              CustomButton(
                text: secondaryLabel!,
                onPressed: onSecondary,
                type: ButtonType.text,
                width: 220,
              ),
          ],
        ),
      ),
    );
  }
}

/// Which night-sky illustration [AppIllustration] draws.
enum AppIllustrationKind {
  noResults,
  noChats,
  noBlocked,
  offline,
  error,
  done,
  stars,
}

/// Small decorative illustration for empty / error states. Static when the
/// platform asks for reduced motion; otherwise its stars twinkle gently.
class AppIllustration extends StatefulWidget {
  final AppIllustrationKind kind;
  final double size;

  const AppIllustration({super.key, required this.kind, this.size = 120});

  @override
  State<AppIllustration> createState() => _AppIllustrationState();
}

class _AppIllustrationState extends State<AppIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _twinkle
        ..stop()
        ..value = 0.5;
    } else if (!_twinkle.isAnimating && !_twinkle.isCompleted) {
      // A few cycles, then rest: looping forever kept the screen rendering
      // frames while idle. Ends on a cycle boundary, so there is no jump.
      _twinkle.repeat(count: 3);
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _IllustrationPainter(widget.kind, _twinkle),
        ),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  final AppIllustrationKind kind;
  final Animation<double> twinkle;

  _IllustrationPainter(this.kind, this.twinkle) : super(repaint: twinkle);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    _glow(canvas, c, s / 2);
    switch (kind) {
      case AppIllustrationKind.noResults:
        _moon(canvas, c, s);
        _sparkles(canvas, c, s, const [
          Offset(0.30, -0.28),
          Offset(-0.32, 0.22),
          Offset(0.26, 0.30),
        ]);
        break;
      case AppIllustrationKind.noChats:
        _bubbles(canvas, c, s);
        break;
      case AppIllustrationKind.noBlocked:
        _shield(canvas, c, s);
        break;
      case AppIllustrationKind.offline:
        _cloud(canvas, c, s);
        break;
      case AppIllustrationKind.error:
        _warning(canvas, c, s);
        break;
      case AppIllustrationKind.done:
        _done(canvas, c, s);
        break;
      case AppIllustrationKind.stars:
        _constellation(canvas, c, s);
        break;
    }
  }

  // Soft radial night-sky glow behind every illustration.
  void _glow(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        colors: [
          AppColors.brandPink.withValues(alpha: 0.30),
          AppColors.brandPurple.withValues(alpha: 0.16),
          AppColors.brandPurple.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, paint);
  }

  Paint _stroke(Color color, double s, [double width = 0.03]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _fill(Color color) => Paint()..color = color;

  // Four-point star; opacity follows the twinkle phase.
  void _sparkle(Canvas canvas, Offset p, double r, double phase) {
    final t = (math.sin((twinkle.value + phase) * 2 * math.pi) + 1) / 2;
    final opacity = 0.45 + 0.55 * t;
    final k = r * 0.28;
    final path = Path()
      ..moveTo(p.dx, p.dy - r)
      ..quadraticBezierTo(p.dx + k, p.dy - k, p.dx + r, p.dy)
      ..quadraticBezierTo(p.dx + k, p.dy + k, p.dx, p.dy + r)
      ..quadraticBezierTo(p.dx - k, p.dy + k, p.dx - r, p.dy)
      ..quadraticBezierTo(p.dx - k, p.dy - k, p.dx, p.dy - r)
      ..close();
    canvas.drawPath(
      path,
      _fill(AppColors.lavenderLight.withValues(alpha: opacity)),
    );
  }

  void _sparkles(Canvas canvas, Offset c, double s, List<Offset> at) {
    for (var i = 0; i < at.length; i++) {
      final p = c + Offset(at[i].dx * s, at[i].dy * s);
      _sparkle(canvas, p, s * (i.isEven ? 0.05 : 0.035), i / at.length);
    }
  }

  void _moon(Canvas canvas, Offset c, double s) {
    final r = s * 0.22;
    final full = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(center: c + Offset(r * 0.55, -r * 0.35), radius: r),
      );
    final crescent = Path.combine(PathOperation.difference, full, bite);
    canvas.drawPath(crescent, _fill(AppColors.gold));
  }

  Path _bubble(Rect rect, {required bool tailLeft}) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.height * 0.4)),
      );
    final y = rect.bottom - rect.height * 0.05;
    final x = tailLeft
        ? rect.left + rect.width * 0.22
        : rect.right - rect.width * 0.22;
    final dir = tailLeft ? -1.0 : 1.0;
    final tail = Path()
      ..moveTo(x - rect.width * 0.1, y - rect.height * 0.2)
      ..lineTo(x + dir * rect.width * 0.12, y + rect.height * 0.28)
      ..lineTo(x + rect.width * 0.1, y - rect.height * 0.2)
      ..close();
    return Path.combine(PathOperation.union, path, tail);
  }

  void _bubbles(Canvas canvas, Offset c, double s) {
    final back = _bubble(
      Rect.fromCenter(
        center: c + Offset(-s * 0.1, -s * 0.09),
        width: s * 0.46,
        height: s * 0.30,
      ),
      tailLeft: true,
    );
    canvas.drawPath(back, _fill(AppColors.surface2));
    canvas.drawPath(back, _stroke(AppColors.brandPurpleLight, s, 0.02));

    final frontRect = Rect.fromCenter(
      center: c + Offset(s * 0.1, s * 0.09),
      width: s * 0.46,
      height: s * 0.30,
    );
    final front = _bubble(frontRect, tailLeft: false);
    canvas.drawPath(
      front,
      Paint()..shader = AppColors.primaryGradient.createShader(frontRect),
    );
    _heart(canvas, frontRect.center, s * 0.075, AppColors.white);
  }

  void _heart(Canvas canvas, Offset p, double r, Color color) {
    final path = Path()
      ..moveTo(p.dx, p.dy + r)
      ..cubicTo(
        p.dx - r * 1.6,
        p.dy - r * 0.1,
        p.dx - r * 0.7,
        p.dy - r * 1.4,
        p.dx,
        p.dy - r * 0.5,
      )
      ..cubicTo(
        p.dx + r * 0.7,
        p.dy - r * 1.4,
        p.dx + r * 1.6,
        p.dy - r * 0.1,
        p.dx,
        p.dy + r,
      )
      ..close();
    canvas.drawPath(path, _fill(color));
  }

  void _check(Canvas canvas, Offset p, double r, Color color, double s) {
    final path = Path()
      ..moveTo(p.dx - r * 0.55, p.dy + r * 0.02)
      ..lineTo(p.dx - r * 0.12, p.dy + r * 0.42)
      ..lineTo(p.dx + r * 0.6, p.dy - r * 0.38);
    canvas.drawPath(path, _stroke(color, s, 0.045));
  }

  void _shield(Canvas canvas, Offset c, double s) {
    final w = s * 0.40;
    final h = s * 0.48;
    final top = c.dy - h / 2;
    final path = Path()
      ..moveTo(c.dx, top)
      ..lineTo(c.dx + w / 2, top + h * 0.16)
      ..quadraticBezierTo(c.dx + w / 2, top + h * 0.72, c.dx, top + h)
      ..quadraticBezierTo(
        c.dx - w / 2,
        top + h * 0.72,
        c.dx - w / 2,
        top + h * 0.16,
      )
      ..close();
    canvas.drawPath(path, _fill(AppColors.brandPurple.withValues(alpha: 0.55)));
    canvas.drawPath(path, _stroke(AppColors.brandPurpleLight, s, 0.022));
    _check(canvas, c + Offset(0, -s * 0.01), s * 0.13, AppColors.success, s);
    _sparkles(canvas, c, s, const [Offset(0.32, -0.24), Offset(-0.30, 0.26)]);
  }

  void _cloud(Canvas canvas, Offset c, double s) {
    final base = c + Offset(0, s * 0.04);
    var cloud = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: base, width: s * 0.52, height: s * 0.20),
          Radius.circular(s * 0.10),
        ),
      );
    for (final o in [
      Offset(-s * 0.10, -s * 0.08),
      Offset(s * 0.08, -s * 0.11),
    ]) {
      final r = o.dx < 0 ? s * 0.10 : s * 0.13;
      cloud = Path.combine(
        PathOperation.union,
        cloud,
        Path()..addOval(Rect.fromCircle(center: base + o, radius: r)),
      );
    }
    canvas.drawPath(cloud, _fill(AppColors.surface2));
    canvas.drawPath(cloud, _stroke(AppColors.lavender, s, 0.022));
    canvas.drawLine(
      c + Offset(-s * 0.22, -s * 0.22),
      c + Offset(s * 0.22, s * 0.22),
      _stroke(AppColors.backgroundDeep, s, 0.07),
    );
    canvas.drawLine(
      c + Offset(-s * 0.22, -s * 0.22),
      c + Offset(s * 0.22, s * 0.22),
      _stroke(AppColors.pinkLight, s, 0.035),
    );
  }

  void _warning(Canvas canvas, Offset c, double s) {
    canvas.drawCircle(c, s * 0.27, _fill(AppColors.surface2));
    canvas.drawCircle(c, s * 0.27, _stroke(AppColors.borderStrong, s, 0.02));
    final r = s * 0.17;
    final tri = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.95, c.dy + r * 0.65)
      ..lineTo(c.dx - r * 0.95, c.dy + r * 0.65)
      ..close();
    canvas.drawPath(tri, _fill(AppColors.warning.withValues(alpha: 0.18)));
    canvas.drawPath(tri, _stroke(AppColors.warning, s, 0.03));
    canvas.drawLine(
      c + Offset(0, -r * 0.4),
      c + Offset(0, r * 0.18),
      _stroke(AppColors.warning, s, 0.035),
    );
    canvas.drawCircle(
      c + Offset(0, r * 0.42),
      s * 0.02,
      _fill(AppColors.warning),
    );
  }

  void _done(Canvas canvas, Offset c, double s) {
    canvas.drawCircle(
      c,
      s * 0.24,
      _fill(AppColors.success.withValues(alpha: 0.18)),
    );
    canvas.drawCircle(c, s * 0.24, _stroke(AppColors.success, s, 0.03));
    _check(canvas, c, s * 0.14, AppColors.success, s);
    _sparkles(canvas, c, s, const [
      Offset(0.32, -0.26),
      Offset(-0.33, -0.18),
      Offset(0.28, 0.30),
    ]);
  }

  void _constellation(Canvas canvas, Offset c, double s) {
    const pts = [
      Offset(-0.28, 0.12),
      Offset(-0.12, -0.08),
      Offset(0.04, 0.02),
      Offset(0.18, -0.20),
      Offset(0.28, 0.10),
    ];
    final points = [for (final p in pts) c + Offset(p.dx * s, p.dy * s)];
    final line = _stroke(
      AppColors.brandPurpleLight.withValues(alpha: 0.55),
      s,
      0.012,
    );
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], line);
    }
    canvas.drawLine(points[2], points[4], line);
    for (var i = 0; i < points.length; i++) {
      _sparkle(
        canvas,
        points[i],
        s * (i == 3 ? 0.06 : 0.04),
        i / points.length,
      );
    }
  }

  @override
  bool shouldRepaint(_IllustrationPainter old) =>
      old.kind != kind || old.twinkle != twinkle;
}
