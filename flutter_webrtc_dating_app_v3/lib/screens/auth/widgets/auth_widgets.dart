// Shared building blocks for the auth screens (login, signup, age gate,
// splash, verify email).

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_links.dart';
import '../../../core/constants/app_colors.dart';

/// Gradient rounded square with the sparkle icon.
class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(size / 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPink.withOpacity(0.3),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(Icons.auto_awesome, size: size / 2, color: AppColors.white),
    );
  }
}

/// Brand mark, "Destined" title and tagline.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          child: Text(
            'Destined',
            style: GoogleFonts.montserrat(
              color: AppColors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Find your cosmic connection.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.lavender, fontSize: 15),
        ),
      ],
    );
  }
}

/// Cheap static starfield; paints once.
class Starfield extends StatelessWidget {
  const Starfield({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _StarPainter(), size: Size.infinite),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 48; i++) {
      final offset = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height * 0.6,
      );
      paint.color = AppColors.white.withOpacity(0.15 + rnd.nextDouble() * 0.4);
      canvas.drawCircle(offset, 0.6 + rnd.nextDouble() * 0.9, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Field label with optional "*" (required) or "(optional)" marker.
class AuthLabel extends StatelessWidget {
  final String text;
  final bool required;
  final bool optional;

  const AuthLabel(
    this.text, {
    super.key,
    this.required = false,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.pinkLight),
              ),
            if (optional)
              const TextSpan(
                text: ' (optional)',
                style: TextStyle(
                  color: AppColors.textSubtle,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        style: const TextStyle(
          color: AppColors.lavender,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Thin "or" divider between auth options.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.border, height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(color: AppColors.textSubtle, fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border, height: 1)),
      ],
    );
  }
}

/// Opens a legal page; placeholders get a short notice instead.
Future<void> openLegalLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  if (AppLinks.isPlaceholder(url)) {
    messenger.showSnackBar(
      const SnackBar(content: Text('This page is not available yet.')),
    );
    return;
  }
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(
          content: Text("Couldn't open this page. Please try again later.")),
    );
  }
}

/// Text with tappable Terms / Privacy links.
class LegalText extends StatefulWidget {
  final String prefix;
  final String termsLabel;
  final String between;
  final String privacyLabel;
  final String suffix;
  final TextStyle style;
  final TextAlign textAlign;

  const LegalText({
    super.key,
    required this.prefix,
    this.termsLabel = 'Terms of Service',
    this.between = ' and ',
    this.privacyLabel = 'Privacy Policy',
    this.suffix = '.',
    this.style = const TextStyle(
      color: AppColors.textSubtle,
      fontSize: 12,
      height: 1.6,
    ),
    this.textAlign = TextAlign.center,
  });

  @override
  State<LegalText> createState() => _LegalTextState();
}

class _LegalTextState extends State<LegalText> {
  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;

  @override
  void initState() {
    super.initState();
    _terms = TapGestureRecognizer()
      ..onTap = () => openLegalLink(context, AppLinks.terms);
    _privacy = TapGestureRecognizer()
      ..onTap = () => openLegalLink(context, AppLinks.privacyPolicy);
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(
      color: AppColors.brandPurpleLight,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.brandPurpleLight,
    );
    return Text.rich(
      TextSpan(
        text: widget.prefix,
        children: [
          TextSpan(text: widget.termsLabel, style: link, recognizer: _terms),
          TextSpan(text: widget.between),
          TextSpan(
            text: widget.privacyLabel,
            style: link,
            recognizer: _privacy,
          ),
          TextSpan(text: widget.suffix),
        ],
      ),
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }
}

/// Three soft pulsing dots; static when reduced motion is on.
class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only loop when motion is allowed.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _dot(double opacity) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandPurpleLight.withOpacity(opacity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Loading',
      child: reduceMotion
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [_dot(0.6), _dot(0.6), _dot(0.6)],
            )
          : RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final phase = (t - i / 3) % 1.0;
                      final wave = 0.5 + 0.5 * math.cos(phase * 2 * math.pi);
                      return _dot(0.25 + 0.65 * wave);
                    }),
                  );
                },
              ),
            ),
    );
  }
}
