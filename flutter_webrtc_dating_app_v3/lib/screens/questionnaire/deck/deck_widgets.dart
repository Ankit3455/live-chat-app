import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../models/question_model.dart';

const Color deckGoldLight = Color(0xFFFCE7B2);
const LinearGradient deckGradient = LinearGradient(
  colors: [AppColors.brandPurple, AppColors.brandMagenta, AppColors.brandPink],
  stops: [0, .6, 1],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

TextStyle deckSerif(double size,
        {Color color = AppColors.white, bool italic = false}) =>
    GoogleFonts.cormorantGaramond(
      fontSize: size,
      fontWeight: FontWeight.w700,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      color: color,
      height: 1.1,
    );

const List<String> deckNumerals = [
  'I',
  'II',
  'III',
  'IV',
  'V',
  'VI',
  'VII',
  'VIII',
  'IX',
  'X',
  'XI',
  'XII',
];

/// Night-sky backdrop shared by the hub and the deck.
class DeckBackground extends StatelessWidget {
  final Widget child;
  const DeckBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.1),
          radius: 1.3,
          colors: [Color(0xFF24124A), Color(0xFF120A22), Color(0xFF0B0614)],
          stops: [0, .45, 1],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child:
                  RepaintBoundary(child: CustomPaint(painter: _SkyPainter())),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 110; i++) {
      paint.color = (rnd.nextDouble() < .15 ? deckGoldLight : Colors.white)
          .withOpacity(.12 + rnd.nextDouble() * .45);
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 1.3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => false;
}

/// Star positions in a gentle zig-zag across [size].
List<Offset> constellationPoints(int n, Size size, {double swing = 16}) {
  if (n == 1) return [Offset(size.width / 2, size.height / 2)];
  return List.generate(n, (i) {
    final x = 14 + i * (size.width - 28) / (n - 1);
    final y = size.height / 2 +
        math.sin(i * 1.9 + .6) * swing +
        (i % 3 == 0 ? -swing / 4 : swing / 4);
    return Offset(x, y);
  });
}

/// Progress as a constellation: a lit star per answered card. Tapping a star
/// jumps to that card.
class Constellation extends StatelessWidget {
  final List<bool> lit;
  final int? current;
  final double height;
  final double swing;
  final ValueChanged<int>? onTap;

  const Constellation({
    super.key,
    required this.lit,
    this.current,
    this.height = 58,
    this.swing = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, height);
          final points = constellationPoints(lit.length, size, swing: swing);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onTap == null
                ? null
                : (d) {
                    var best = 0;
                    for (var i = 1; i < points.length; i++) {
                      if ((points[i] - d.localPosition).distance <
                          (points[best] - d.localPosition).distance) {
                        best = i;
                      }
                    }
                    onTap!(best);
                  },
            child: Semantics(
              label: '${lit.where((l) => l).length} of ${lit.length} answered',
              child: CustomPaint(
                size: size,
                painter: _ConstellationPainter(points, lit, current),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  final List<Offset> points;
  final List<bool> lit;
  final int? current;
  _ConstellationPainter(this.points, this.lit, this.current);

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()
      ..color = AppColors.brandPurpleLight.withOpacity(.16)
      ..strokeWidth = 1.2;
    final bright = Paint()
      ..color = AppColors.gold.withOpacity(.75)
      ..strokeWidth = 1.3;
    for (var i = 0; i < points.length - 1; i++) {
      if (lit[i] && lit[i + 1]) {
        canvas.drawLine(points[i], points[i + 1], bright);
      } else {
        _dashed(canvas, points[i], points[i + 1], dim);
      }
    }
    final glow = Paint()
      ..color = deckGoldLight.withOpacity(.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    for (var i = 0; i < points.length; i++) {
      final isCurrent = i == current;
      if (lit[i]) canvas.drawCircle(points[i], 6, glow);
      canvas.drawCircle(
        points[i],
        isCurrent ? 5 : (lit[i] ? 4.4 : 3.2),
        Paint()
          ..color = isCurrent
              ? Colors.white
              : (lit[i] ? deckGoldLight : const Color(0xFF3A2D58)),
      );
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint p) {
    final total = (b - a).distance;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += 7) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + 3, total), p);
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) =>
      old.current != current || old.lit.toString() != lit.toString();
}

/// Gold-framed tarot card surface.
class TarotFrame extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final double radius;
  const TarotFrame({
    super.key,
    required this.child,
    this.gradient,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: gradient ??
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A1B47), Color(0xFF1A1030), Color(0xFF140C26)],
            ),
        border: Border.all(color: AppColors.gold.withOpacity(.35)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x8C000000), blurRadius: 40, offset: Offset(0, 18)),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius - 6),
          border: Border.all(color: AppColors.gold.withOpacity(.22)),
        ),
        child: Stack(
          children: [
            const Positioned(top: 8, left: 10, child: _Sparkle()),
            const Positioned(bottom: 8, right: 10, child: _Sparkle()),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle();
  @override
  Widget build(BuildContext context) => Text(
        '✦',
        style: TextStyle(color: AppColors.gold.withOpacity(.55), fontSize: 12),
      );
}

/// Front of a question card.
class CardFront extends StatelessWidget {
  final int index;
  final Question question;
  final String hint;
  final bool required;

  /// Replaces the question icon in the circle.
  final Widget? art;
  const CardFront({
    super.key,
    required this.index,
    required this.question,
    required this.hint,
    this.required = false,
    this.art,
  });

  @override
  Widget build(BuildContext context) {
    return TarotFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            Text(
              deckNumerals[index % deckNumerals.length],
              style: deckSerif(15, color: AppColors.gold, italic: true)
                  .copyWith(letterSpacing: 3),
            ),
            const Spacer(),
            Container(
              width: 100,
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.brandMagenta.withOpacity(.38),
                  AppColors.brandPurple.withOpacity(.16),
                  Colors.transparent,
                ], stops: const [
                  0,
                  .5,
                  1
                ]),
                border: Border.all(color: AppColors.gold.withOpacity(.3)),
              ),
              child: art ??
                  Text(question.icon ?? '✦',
                      style: const TextStyle(fontSize: 48)),
            ),
            const Spacer(),
            Text(
              question.text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: deckSerif(25),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.lavender, fontSize: 12),
            ),
            const SizedBox(height: 4),
            if (required)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.gold.withOpacity(.4)),
                ),
                child: const Text(
                  '✦ REQUIRED',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Back of a card, revealed after a single-choice answer.
class CardBack extends StatelessWidget {
  final String answer;
  final String? emoji;
  final String? quip;
  const CardBack({super.key, required this.answer, this.emoji, this.quip});

  @override
  Widget build(BuildContext context) {
    return TarotFrame(
      gradient: RadialGradient(
        center: const Alignment(0, -.6),
        radius: 1.1,
        colors: [
          AppColors.brandMagenta.withOpacity(.45),
          const Color(0xFF1D1035),
          const Color(0xFF140C26),
        ],
        stops: const [0, .6, 1],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji ?? '✦', style: const TextStyle(fontSize: 70)),
            const SizedBox(height: 12),
            Text(answer, textAlign: TextAlign.center, style: deckSerif(28)),
            if (quip != null) ...[
              const SizedBox(height: 8),
              Text(
                '“$quip”',
                textAlign: TextAlign.center,
                style: deckSerif(16, color: deckGoldLight, italic: true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fanned hand of option cards; tap one to answer.
class OptionFan extends StatelessWidget {
  final Question question;
  final String? selected;
  final ValueChanged<String> onPick;
  const OptionFan({
    super.key,
    required this.question,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final opts = question.options;
    final n = opts.length;
    final many = n > 4;
    final cardW = many ? 66.0 : 80.0;
    final cardH = many ? 116.0 : 128.0;
    final spread = many ? 5.0 : 6.0;
    final mid = (n - 1) / 2;
    return LayoutBuilder(builder: (context, box) {
      final gap = math.min(
          many ? 58.0 : 78.0, (box.maxWidth - cardW) / math.max(n - 1, 1));
      return SizedBox(
        height: cardH + 26,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            for (var k = 0; k < n; k++)
              Transform.translate(
                offset: Offset((k - mid) * gap, (k - mid).abs() * 6),
                child: Transform.rotate(
                  angle: (k - mid) * spread * math.pi / 180,
                  child: _FanCard(
                    width: cardW,
                    height: cardH,
                    label: opts[k],
                    emoji: question.emojiFor(opts[k]),
                    quiet: opts[k] == 'Prefer not to say',
                    selected: selected == opts[k],
                    onTap: () => onPick(opts[k]),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _FanCard extends StatelessWidget {
  final double width;
  final double height;
  final String label;
  final String? emoji;
  final bool quiet;
  final bool selected;
  final VoidCallback onTap;
  const _FanCard({
    required this.width,
    required this.height,
    required this.label,
    required this.emoji,
    required this.quiet,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: height,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: quiet
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2E1F4D), Color(0xFF1B1132)],
                  ),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : AppColors.brandPurpleLight.withOpacity(.25),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              selected
                  ? BoxShadow(
                      color: AppColors.gold.withOpacity(.45), blurRadius: 24)
                  : const BoxShadow(
                      color: Color(0x73000000),
                      blurRadius: 20,
                      offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (emoji != null)
                Text(emoji!, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: quiet ? AppColors.textSubtle : AppColors.lavenderLight,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ordered options on a slider, then "Lock it in".
class ScaleDial extends StatefulWidget {
  final Question question;
  final String? selected;
  final ValueChanged<String> onLock;
  const ScaleDial({
    super.key,
    required this.question,
    required this.selected,
    required this.onLock,
  });

  @override
  State<ScaleDial> createState() => _ScaleDialState();
}

class _ScaleDialState extends State<ScaleDial> {
  int? _index;

  @override
  void initState() {
    super.initState();
    final i = widget.question.options.indexOf(widget.selected ?? '');
    _index = i < 0 ? null : i;
  }

  void _set(int i) {
    if (i == _index) return;
    Haptics.selection();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final opts = widget.question.options;
    final i = _index;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: i == null
                ? Center(
                    child: Text('Where are you on this?',
                        style: deckSerif(18, color: AppColors.textSubtle)),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.question.emojiFor(opts[i]) ?? '',
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 10),
                      Flexible(child: Text(opts[i], style: deckSerif(22))),
                    ],
                  ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              activeTrackColor: AppColors.brandMagenta,
              inactiveTrackColor: AppColors.surface2,
              activeTickMarkColor: Colors.white70,
              inactiveTickMarkColor: const Color(0xFF4A3B6B),
              thumbColor: i == null ? Colors.transparent : Colors.white,
              overlayColor: AppColors.gold.withOpacity(.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13),
            ),
            child: Slider(
              value: (i ?? 0).toDouble(),
              min: 0,
              max: (opts.length - 1).toDouble(),
              divisions: opts.length - 1,
              semanticFormatterCallback: (v) => opts[v.round()],
              onChanged: (v) => _set(v.round()),
            ),
          ),
          Row(
            children: [
              for (var k = 0; k < opts.length; k++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _set(k),
                    child: Text(
                      opts[k],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.25,
                        color: k == i ? deckGoldLight : AppColors.textSubtle,
                        fontWeight: k == i ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DeckButton(
            label: i == null ? 'Slide to choose' : 'Lock it in ✦',
            onPressed: i == null ? null : () => widget.onLock(opts[i]),
          ),
        ],
      ),
    );
  }
}

/// Chips. The caller decides whether a tap toggles or answers.
class StickerPicker extends StatelessWidget {
  final Question question;
  final List<String> selected;
  final ValueChanged<String> onTap;
  final String? label;
  const StickerPicker({
    super.key,
    required this.question,
    required this.selected,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final max = question.maxSelections;
    final full = max != null && selected.length >= max;
    return Column(
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(
              '${label!.toUpperCase()} · ${selected.length}/${max ?? question.options.length}',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var k = 0; k < question.options.length; k++)
              _Sticker(
                label: question.options[k],
                emoji: question.emojiFor(question.options[k]),
                selected: selected.contains(question.options[k]),
                disabled: full && !selected.contains(question.options[k]),
                tilt: k.isEven ? -2 : 2,
                onTap: () => onTap(question.options[k]),
              ),
          ],
        ),
      ],
    );
  }
}

class _Sticker extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool selected;
  final bool disabled;
  final double tilt;
  final VoidCallback onTap;
  const _Sticker({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.disabled,
    required this.tilt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label: label,
      excludeSemantics: true,
      child: AnimatedRotation(
        turns: selected ? tilt / 360 : 0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedOpacity(
          opacity: disabled ? .32 : 1,
          duration: const Duration(milliseconds: 150),
          child: GestureDetector(
            onTap: disabled ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: selected ? deckGradient : null,
                color: selected ? null : AppColors.surfaceCard.withOpacity(.85),
                border: Border.all(
                  color: selected ? Colors.transparent : AppColors.border,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: AppColors.brandMagenta.withOpacity(.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6))
                      ]
                    : null,
              ),
              child: Text(
                emoji == null ? label : '$emoji  $label',
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.lavenderLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient pill button used across the deck.
class DeckButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool ghost;
  final double height;
  const DeckButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.ghost = false,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: enabled && !ghost ? deckGradient : null,
            color: ghost
                ? AppColors.surfaceCard.withOpacity(.9)
                : (enabled ? null : AppColors.surface2),
            border: ghost ? Border.all(color: AppColors.border) : null,
            boxShadow: enabled && !ghost
                ? [
                    BoxShadow(
                        color: AppColors.brandMagenta.withOpacity(.3),
                        blurRadius: 24,
                        offset: const Offset(0, 10))
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              color: enabled || ghost ? Colors.white : AppColors.textSubtle,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded icon button for the deck top bars.
class DeckIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const DeckIconButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceCard.withOpacity(.8),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.lavenderLight, size: 20),
        ),
      ),
    );
  }
}

/// Free-text answer under a write card: counter, length check and idea
/// chips (short ideas replace the text, long ones are appended).
class DeckWriteField extends StatefulWidget {
  final Question question;
  final String initial;
  final String submitLabel;
  final ValueChanged<String> onSubmit;
  const DeckWriteField({
    super.key,
    required this.question,
    required this.initial,
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  State<DeckWriteField> createState() => _DeckWriteFieldState();
}

class _DeckWriteFieldState extends State<DeckWriteField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  Question get _q => widget.question;
  int get _max => _q.maxLength ?? 200;
  bool get _multiline => _max > 120;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _useIdea(String idea) {
    final current = _controller.text.trim();
    final next = _multiline && current.isNotEmpty ? '$current $idea' : idea;
    final clipped = next.length > _max ? next.substring(0, _max) : next;
    _controller.value = TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
    );
    Haptics.selection();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    final tooShort = text.isNotEmpty && text.length < _q.minLength;
    final valid = text.isEmpty ? !_q.isMandatory : !tooShort;
    final String? message = tooShort
        ? 'At least ${_q.minLength} characters'
        : (text.isNotEmpty ? '✓ Looks good' : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard.withOpacity(.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                maxLength: _max,
                minLines: _multiline ? 3 : 1,
                maxLines: _multiline ? 5 : 1,
                textCapitalization: _q.fieldName == 'username'
                    ? TextCapitalization.none
                    : (_multiline
                        ? TextCapitalization.sentences
                        : TextCapitalization.words),
                keyboardType: _multiline
                    ? TextInputType.multiline
                    : (_q.fieldName == 'username'
                        ? TextInputType.name
                        : TextInputType.text),
                textInputAction:
                    _multiline ? TextInputAction.newline : TextInputAction.done,
                onSubmitted: valid && !_multiline
                    ? (_) => widget.onSubmit(_controller.text.trim())
                    : null,
                onChanged: (_) => setState(() {}),
                cursorColor: AppColors.gold,
                style: _multiline
                    ? const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.45,
                      )
                    : deckSerif(20),
                decoration: InputDecoration(
                  hintText: _q.placeholder,
                  hintStyle: const TextStyle(color: Color(0xFF6F6490)),
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
              Row(
                children: [
                  if (message != null)
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tooShort ? AppColors.error : AppColors.success,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '${_controller.text.length}/$_max',
                    style: const TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_q.ideas.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _q.ideas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, i) => ActionChip(
                label: Text(_q.ideas[i]),
                onPressed: () => _useIdea(_q.ideas[i]),
                labelStyle: const TextStyle(
                  color: deckGoldLight,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: AppColors.gold.withOpacity(.08),
                side: BorderSide(color: AppColors.gold.withOpacity(.3)),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        DeckButton(
          label: text.isEmpty && !_q.isMandatory
              ? 'Skip for now'
              : widget.submitLabel,
          onPressed: valid ? () => widget.onSubmit(text) : null,
        ),
      ],
    );
  }
}

/// Twelve signs on a circle; tap to toggle. [ownSign] gets a gold ring.
class ZodiacWheel extends StatelessWidget {
  final List<String> signs;
  final Map<String, String> glyphs;
  final List<String> selected;
  final String? ownSign;
  final ValueChanged<String> onToggle;
  const ZodiacWheel({
    super.key,
    required this.signs,
    required this.glyphs,
    required this.selected,
    required this.ownSign,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    const size = 232.0;
    const radius = 94.0;
    const dot = 46.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold.withOpacity(.25)),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.brandMagenta.withOpacity(.35),
                  AppColors.surfaceCard.withOpacity(.9),
                ]),
                border: Border.all(color: AppColors.gold.withOpacity(.35)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${selected.length}', style: deckSerif(26)),
                  const Text(
                    'signs picked',
                    style: TextStyle(color: AppColors.lavender, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          for (var i = 0; i < signs.length; i++)
            Positioned(
              left: size / 2 +
                  radius *
                      math.cos(i / signs.length * 2 * math.pi - math.pi / 2) -
                  dot / 2,
              top: size / 2 +
                  radius *
                      math.sin(i / signs.length * 2 * math.pi - math.pi / 2) -
                  dot / 2,
              child: _SignDot(
                sign: signs[i],
                glyph: glyphs[signs[i]] ?? '✦',
                selected: selected.contains(signs[i]),
                own: signs[i] == ownSign,
                size: dot,
                onTap: () => onToggle(signs[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _SignDot extends StatelessWidget {
  final String sign;
  final String glyph;
  final bool selected;
  final bool own;
  final double size;
  final VoidCallback onTap;
  const _SignDot({
    required this.sign,
    required this.glyph,
    required this.selected,
    required this.own,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: own ? '$sign, your sign' : sign,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          Haptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: selected ? deckGradient : null,
            color: selected ? null : AppColors.surfaceCard.withOpacity(.9),
            border: Border.all(
              color: own
                  ? AppColors.gold
                  : (selected ? Colors.transparent : AppColors.border),
              width: own ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.brandMagenta.withOpacity(.5),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // U+FE0E asks for the text (not emoji) glyph.
              Text(
                '$glyph︎',
                style: TextStyle(
                  fontSize: 18,
                  height: 1,
                  color: selected ? Colors.white : deckGoldLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sign.substring(0, 3),
                style: TextStyle(
                  fontSize: 8.5,
                  color: selected ? Colors.white : AppColors.textSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
