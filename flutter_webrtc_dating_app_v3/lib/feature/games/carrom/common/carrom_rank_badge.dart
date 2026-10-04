// lib/feature/games/carrom/common/carrom_rank_badge.dart
//
// Tier badge (Beginner … Legend) shared by the result screen and stats card.

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Token colour for a Carrom tier name.
Color carromTierColor(String tier) {
  switch (tier.toLowerCase()) {
    case 'legend':
      return AppColors.brandPink;
    case 'diamond':
      return AppColors.cyan;
    case 'platinum':
      return AppColors.brandPurpleLight;
    case 'gold':
      return AppColors.warning;
    case 'silver':
      return AppColors.lavenderLight;
    case 'bronze':
      return AppColors.pinkLight;
    default:
      return AppColors.lavender;
  }
}

/// Token colour for a leaderboard position (top three highlighted).
Color carromPlaceColor(int place) {
  switch (place) {
    case 1:
      return AppColors.warning;
    case 2:
      return AppColors.lavenderLight;
    case 3:
      return AppColors.pinkLight;
    default:
      return AppColors.lavender;
  }
}

class CarromTierBadge extends StatelessWidget {
  final String tier;

  const CarromTierBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = carromTierColor(tier);
    return Semantics(
      label: 'Rank $tier',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.military_tech, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              tier,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
