// lib/feature/games/chat_games/widgets/choice_button.dart

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// A big tappable choice (a 1..10 score, a red/green vote). [selected] is my
/// pick; [dimmed] = I picked something else.
class ChoiceButton extends StatelessWidget {
  final String label;
  final String? semanticLabel;
  final bool selected;
  final bool dimmed;
  final Color accent;
  final double fontSize;
  final VoidCallback? onTap;

  const ChoiceButton({
    super.key,
    required this.label,
    this.semanticLabel,
    this.selected = false,
    this.dimmed = false,
    this.accent = AppColors.brandPink,
    this.fontSize = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: duration,
        opacity: dimmed ? 0.4 : 1,
        child: AnimatedContainer(
          duration: duration,
          constraints: const BoxConstraints(minHeight: 52, minWidth: 52),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? LinearGradient(
                    colors: [accent, Color.lerp(accent, Colors.white, 0.25)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.10),
                      Colors.white.withOpacity(0.04),
                    ],
                  ),
            border: Border.all(
              color: selected ? Colors.white : Colors.white.withOpacity(0.14),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [BoxShadow(color: accent.withOpacity(0.55), blurRadius: 18)]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of a results list: a label on the left, both answers on the right.
class ResultRow extends StatelessWidget {
  final String label;
  final String mine;
  final String theirs;
  final bool same;

  const ResultRow({
    super.key,
    required this.label,
    required this.mine,
    required this.theirs,
    required this.same,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label. You: $mine. Them: $theirs.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$mine · $theirs',
              style: TextStyle(
                color: same ? AppColors.pinkLight : AppColors.lavender,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
