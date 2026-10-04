import 'package:flutter/material.dart';

import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/screens/questionnaire/profile_completion_screen.dart';

/// Slim profile-completion nudge shown at the top of the Discover feed.
class ProfileCompletionBanner extends StatelessWidget {
  final int completionPercentage;
  final VoidCallback onDismiss;

  const ProfileCompletionBanner({
    super.key,
    required this.completionPercentage,
    required this.onDismiss,
  });

  void _openCompletion(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileCompletionScreen()),
    ).then((_) => onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    final pct = completionPercentage.clamp(0, 100);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandPurple.withOpacity(0.22),
            AppColors.brandPink.withOpacity(0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: [
          Semantics(
            label: 'Profile $pct% complete',
            excludeSemantics: true,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: pct / 100,
                      strokeWidth: 4,
                      color: AppColors.brandPink,
                      backgroundColor: AppColors.surface2,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Complete your profile',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Complete profiles stand out in Discover.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.lavender, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _openCompletion(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.white,
              backgroundColor: AppColors.surfaceCard,
              side: const BorderSide(color: AppColors.borderStrong),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Complete'),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18, color: AppColors.lavender),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
