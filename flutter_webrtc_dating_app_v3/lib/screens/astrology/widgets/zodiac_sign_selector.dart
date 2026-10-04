import 'package:flutter/material.dart';

import '../../../core/utils/astrology_utils.dart';
import '../../../core/constants/app_colors.dart';

/// Multi-select grid of the 12 signs. Values are canonical names ('Aries').
class ZodiacSignSelector extends StatelessWidget {
  final List<String> selectedSigns;
  final Function(String) onToggle;

  const ZodiacSignSelector({
    Key? key,
    required this.selectedSigns,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 60,
      ),
      itemCount: AstrologyUtils.zodiacSigns.length,
      itemBuilder: (context, index) {
        final sign = AstrologyUtils.zodiacSigns[index];
        return _SignTile(
          sign: sign,
          selected: selectedSigns.contains(sign),
          onTap: () => onToggle(sign),
        );
      },
    );
  }
}

class _SignTile extends StatelessWidget {
  const _SignTile({
    required this.sign,
    required this.selected,
    required this.onTap,
  });

  final String sign;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    // Gold is reserved for zodiac.
    final fg = selected ? AppColors.gold : AppColors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: sign,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? AppColors.gold.withOpacity(0.12)
            : AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected
                ? AppColors.gold.withOpacity(0.5)
                : AppColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          // Stacked glyph + name so long names (Sagittarius) fit at 13px.
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AstrologyUtils.zodiacEmoji[sign] ?? '',
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.1,
                          color: selected
                              ? AppColors.gold
                              : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sign,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.gold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
