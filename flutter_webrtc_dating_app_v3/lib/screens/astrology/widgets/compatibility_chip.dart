import 'package:flutter/material.dart';

import '../../../core/utils/astrology_utils.dart';
import '../../../core/utils/compatibility_utils.dart';
import '../../../models/user_model.dart';

/// Compatibility chip for another user's card. Renders nothing when the score
/// cannot be computed (missing sign on either side). Tap shows the tooltip.
class CompatibilityChip extends StatelessWidget {
  const CompatibilityChip({
    super.key,
    required this.currentUser,
    required this.user,
    this.dense = true,
  });

  final UserModel? currentUser;
  final UserModel user;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final score = CompatibilityService.compatibilityScore(currentUser, user);
    if (score == null) return const SizedBox.shrink();

    final sign = CompatibilityService.signOf(user);
    final emoji = AstrologyUtils.zodiacEmoji[sign] ?? '';
    final fontSize = dense ? 11.5 : 13.5;

    return Tooltip(
      message: CompatibilityService.tooltip,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      child: Semantics(
        label: '$score percent astrology compatibility, $sign',
        excludeSemantics: true,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 12,
            vertical: dense ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji.isNotEmpty)
                Text(emoji, style: TextStyle(fontSize: fontSize + 1)),
              if (emoji.isNotEmpty) const SizedBox(width: 4),
              Text(
                '$score%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
