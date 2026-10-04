// lib/widgets/motion.dart
//
// Small reusable micro-interactions. Every widget here renders its child
// unchanged when the platform asks for reduced motion.

import 'package:flutter/material.dart';

/// Briefly scales [child] up and back whenever [value] changes while
/// [active] is true (badge counts, newly selected tab icons).
class PopOnChange extends StatefulWidget {
  final Object? value;
  final bool active;
  final double peak;
  final Duration duration;
  final Widget child;

  const PopOnChange({
    super.key,
    required this.value,
    required this.child,
    this.active = true,
    this.peak = 1.25,
    this.duration = const Duration(milliseconds: 320),
  });

  @override
  State<PopOnChange> createState() => _PopOnChangeState();
}

class _PopOnChangeState extends State<PopOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late Animation<double> _scale = _buildScale();

  Animation<double> _buildScale() => TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: widget.peak)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: Tween(begin: widget.peak, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 60,
        ),
      ]).animate(_controller);

  @override
  void didUpdateWidget(PopOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peak != widget.peak) _scale = _buildScale();
    if (oldWidget.value != widget.value &&
        widget.active &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Shrinks [child] slightly while a pointer is down. Uses a [Listener], so
/// it never competes with the child's own gesture handling.
class PressScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;

  const PressScale({super.key, required this.child, this.pressedScale = 0.9});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed && !reduce ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fades (and optionally slides) [child] in once, when first built with
/// [animate] true. Flipping [animate] later never replays the motion, so the
/// widget tree stays stable across rebuilds.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Offset offset;
  final Duration duration;
  final bool animate;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.offset = Offset.zero,
    this.duration = const Duration(milliseconds: 280),
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final play = animate && !MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: play ? 0 : 1, end: 1),
      duration: play ? duration : Duration.zero,
      curve: Curves.easeOutCubic,
      child: child,
      // Same wrappers at t == 1 so the child keeps its state.
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(offset.dx * (1 - t), offset.dy * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}
