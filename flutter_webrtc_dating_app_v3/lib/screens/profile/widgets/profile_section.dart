// lib/screens/profile/widgets/profile_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:availchat/core/constants/app_colors.dart';

/// Section heading with an optional violet text action (e.g. "Edit").
class ProfileSectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final String? actionTooltip;
  final VoidCallback? onAction;

  const ProfileSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.actionTooltip,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: GoogleFonts.montserrat(
                  color: AppColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (label != null && action != null)
            Tooltip(
              message: actionTooltip ?? label,
              child: TextButton(
                onPressed: action,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandPurpleLight,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(label),
              ),
            ),
        ],
      ),
    );
  }
}

class ProfileMenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

/// Card of navigation rows separated by hairline dividers.
class ProfileMenuCard extends StatelessWidget {
  final List<ProfileMenuItem> items;

  const ProfileMenuCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  color: AppColors.border,
                ),
              _tile(items[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(ProfileMenuItem item) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: item.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: AppColors.lavender),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSubtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
