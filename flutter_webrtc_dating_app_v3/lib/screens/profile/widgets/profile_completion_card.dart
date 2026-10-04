// lib/screens/profile/widgets/profile_completion_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:availchat/core/constants/app_colors.dart';

class ProfileTodo {
  final String label;
  final bool done;
  final String actionLabel;
  final VoidCallback onTap;

  const ProfileTodo({
    required this.label,
    required this.done,
    required this.actionLabel,
    required this.onTap,
  });
}

/// "Profile N% complete" with a progress bar and a checklist.
class ProfileCompletionCard extends StatelessWidget {
  final int percentage;
  final List<ProfileTodo> items;

  const ProfileCompletionCard({
    super.key,
    required this.percentage,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final pct = percentage.clamp(0, 100);
    final left = items.where((t) => !t.done).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Profile $pct% complete',
                    style: GoogleFonts.montserrat(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (left > 0)
                  Text(
                    '$left left',
                    style: const TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 8, 4),
            child: Semantics(
              label: 'Profile $pct percent complete',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: AppColors.surface2),
                      ),
                      FractionallySizedBox(
                        widthFactor: pct / 100,
                        heightFactor: 1,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          for (final item in items) _row(item),
        ],
      ),
    );
  }

  Widget _row(ProfileTodo item) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.done ? AppColors.success : null,
              border: Border.all(
                color: item.done ? AppColors.success : AppColors.borderStrong,
                width: 2,
              ),
            ),
            child: item.done
                ? const Icon(
                    Icons.check,
                    size: 14,
                    color: AppColors.backgroundDeep,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.label,
              semanticsLabel:
                  '${item.label}, ${item.done ? 'done' : 'not done'}',
              style: TextStyle(
                color: item.done ? AppColors.textSubtle : AppColors.white,
                fontSize: 14,
                decoration: item.done ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textSubtle,
              ),
            ),
          ),
          if (!item.done)
            Tooltip(
              message: '${item.actionLabel}: ${item.label}',
              child: TextButton(
                onPressed: item.onTap,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandPurpleLight,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(item.actionLabel),
              ),
            ),
        ],
      ),
    );
  }
}
