// lib/feature/games/chat_games/widgets/premium_pickers.dart
//
// Richer pickers and reveals for the round games: an emoji rating slider,
// a swipe card for red / green flag votes and a pair of cards that flip open
// to show both answers.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../ui/game_ui.dart';

/// 1..10 slider with a face that changes as you drag, and a lock-in button.
class RateDial extends StatefulWidget {
  final GameTheme theme;
  final int? locked;
  final bool enabled;
  final ValueChanged<int> onSubmit;

  const RateDial({
    super.key,
    required this.theme,
    required this.locked,
    required this.enabled,
    required this.onSubmit,
  });

  static const List<String> faces = [
    '🤢', '😖', '😕', '😐', '🙂', '😊', '😄', '😍', '🤩', '🔥', //
  ];

  static String faceFor(int n) => faces[(n - 1).clamp(0, 9)];

  @override
  State<RateDial> createState() => _RateDialState();
}

class _RateDialState extends State<RateDial> {
  double _value = 5;

  @override
  Widget build(BuildContext context) {
    final locked = widget.locked;
    final n = locked ?? _value.round();
    Widget face = Text(
      RateDial.faceFor(n),
      style: const TextStyle(fontSize: 64),
    );
    if (!calmMotion(context)) {
      face = face
          .animate(key: ValueKey(n))
          .scaleXY(
            begin: 0.7,
            end: 1,
            duration: 260.ms,
            curve: Curves.easeOutBack,
          );
    }
    return Column(
      children: [
        face,
        ShaderMask(
          shaderCallback: (r) => widget.theme.gradient.createShader(r),
          child: Text(
            '$n',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10,
            activeTrackColor: widget.theme.a,
            inactiveTrackColor: Colors.white.withOpacity(0.12),
            thumbColor: Colors.white,
            overlayColor: widget.theme.a.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            tickMarkShape: SliderTickMarkShape.noTickMark,
          ),
          child: Slider(
            value: n.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$n',
            semanticFormatterCallback: (v) => '${v.round()} out of 10',
            onChanged: locked == null && widget.enabled
                ? (v) => setState(() => _value = v)
                : null,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text('Not for me', style: GameText.caption),
              Spacer(),
              Text('Love it', style: GameText.caption),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (locked == null)
          GameButton(
            label: 'Lock in $n',
            icon: Icons.lock_rounded,
            theme: widget.theme,
            onPressed: widget.enabled ? () => widget.onSubmit(n) : null,
          ),
      ],
    );
  }
}

/// A statement card you swipe left (red flag) or right (green flag), with
/// buttons for the same.
class SwipeVote extends StatefulWidget {
  final String text;
  final String? locked;
  final bool enabled;
  final ValueChanged<String> onVote;

  const SwipeVote({
    super.key,
    required this.text,
    required this.locked,
    required this.enabled,
    required this.onVote,
  });

  @override
  State<SwipeVote> createState() => _SwipeVoteState();
}

class _SwipeVoteState extends State<SwipeVote>
    with SingleTickerProviderStateMixin {
  static const double _threshold = 110;

  double _dx = 0;
  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(() => setState(() => _dx = _from * (1 - _back.value)));
  double _from = 0;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _vote(String v) {
    if (!widget.enabled || widget.locked != null) return;
    widget.onVote(v);
  }

  void _end() {
    if (_dx.abs() > _threshold) {
      _vote(_dx < 0 ? 'red' : 'green');
    }
    _from = _dx;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.locked;
    final tilt = (_dx / 300).clamp(-1.0, 1.0);
    final red = (-_dx / _threshold).clamp(0.0, 1.0);
    final green = (_dx / _threshold).clamp(0.0, 1.0);
    final card = Transform.translate(
      offset: Offset(_dx, 0),
      child: Transform.rotate(
        angle: tilt * 0.25,
        child: Container(
          height: 220,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: [
                Color.lerp(
                  const Color(0xFF2A1F45),
                  const Color(0xFFFF5A5F),
                  red * 0.6,
                )!,
                Color.lerp(
                  const Color(0xFF1C1530),
                  const Color(0xFF2BD98C),
                  green * 0.6,
                )!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  '“${widget.text}”',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: Opacity(
                  opacity: locked == 'red' ? 1 : red,
                  child: const Text('🚩 RED', style: _stamp),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Opacity(
                  opacity: locked == 'green' ? 1 : green,
                  child: const Text('GREEN 💚', style: _stamp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      children: [
        Semantics(
          label:
              '${widget.text}. Swipe left for red flag, right for green flag.',
          child: GestureDetector(
            onHorizontalDragUpdate: locked == null && widget.enabled
                ? (d) => setState(() => _dx += d.delta.dx)
                : null,
            onHorizontalDragEnd: locked == null && widget.enabled
                ? (_) => _end()
                : null,
            child: card,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundVote(
              emoji: '🚩',
              label: 'Red flag',
              color: const Color(0xFFFF5A5F),
              selected: locked == 'red',
              onTap: locked == null && widget.enabled
                  ? () => _vote('red')
                  : null,
            ),
            const SizedBox(width: 36),
            _RoundVote(
              emoji: '💚',
              label: 'Green flag',
              color: const Color(0xFF2BD98C),
              selected: locked == 'green',
              onTap: locked == null && widget.enabled
                  ? () => _vote('green')
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  static const TextStyle _stamp = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
  );
}

class _RoundVote extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _RoundVote({
    required this.emoji,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 74,
          height: 74,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? color : Colors.white.withOpacity(0.08),
            border: Border.all(color: color, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(selected ? 0.7 : 0.25),
                blurRadius: selected ? 26 : 12,
              ),
            ],
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 32)),
        ),
      ),
    );
  }
}

/// Two cards, "You" and the other player, that flip open one after the
/// other to show both answers, with a verdict line under them.
class FlipPair extends StatelessWidget {
  final GameTheme theme;
  final String mine;
  final String theirs;
  final String otherName;
  final String verdict;

  /// Highlights both cards (a match).
  final bool same;

  const FlipPair({
    super.key,
    required this.theme,
    required this.mine,
    required this.theirs,
    required this.otherName,
    required this.verdict,
    required this.same,
  });

  Widget _card(BuildContext context, String who, String value, int order) {
    final face = Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: same
            ? theme.gradient
            : LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.14),
                  Colors.white.withOpacity(0.05),
                ],
              ),
        border: Border.all(color: Colors.white.withOpacity(same ? 0.8 : 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(who, style: GameText.caption.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    if (calmMotion(context)) return face;
    return face
        .animate(delay: (order * 180).ms)
        .custom(
          duration: 520.ms,
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY((1 - v) * math.pi / 2),
            child: Opacity(opacity: v.clamp(0, 1), child: child),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: verdict,
      child: GlassPanel(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        borderColor: same ? theme.a.withOpacity(0.7) : null,
        child: Column(
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  Expanded(child: _card(context, 'YOU', mine, 0)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _card(context, otherName.toUpperCase(), theirs, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              verdict,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
