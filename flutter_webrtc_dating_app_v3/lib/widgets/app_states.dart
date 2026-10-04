// lib/widgets/app_states.dart
//
// Shared state widgets from the Destined design system: an inline banner
// (info / warning / error) and an empty / error state with an optional
// action. Screens should use these instead of private copies.

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import 'custom_button.dart';

enum AppBannerTone { info, warning, error }

class AppBanner extends StatelessWidget {
  final String message;
  final AppBannerTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppBanner({
    super.key,
    required this.message,
    this.tone = AppBannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent;
    final IconData fallbackIcon;
    switch (tone) {
      case AppBannerTone.info:
        accent = AppColors.brandPurpleMid;
        fallbackIcon = Icons.info_outline;
        break;
      case AppBannerTone.warning:
        accent = AppColors.warning;
        fallbackIcon = Icons.warning_amber_rounded;
        break;
      case AppBannerTone.error:
        accent = AppColors.error;
        fallbackIcon = Icons.error_outline;
        break;
    }

    return Semantics(
      liveRegion: tone != AppBannerTone.info,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icon ?? fallbackIcon,
                size: 20,
                color: tone == AppBannerTone.info
                    ? AppColors.brandPurpleLight
                    : accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: [
                    AppColors.brandPink.withValues(alpha: 0.35),
                    AppColors.brandPurple.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: Icon(icon, size: 40, color: AppColors.pinkLight),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.lavender,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              CustomButton(text: actionLabel!, onPressed: onAction, width: 220),
            ],
            if (secondaryLabel != null && onSecondary != null)
              CustomButton(
                text: secondaryLabel!,
                onPressed: onSecondary,
                type: ButtonType.text,
                width: 220,
              ),
          ],
        ),
      ),
    );
  }
}
