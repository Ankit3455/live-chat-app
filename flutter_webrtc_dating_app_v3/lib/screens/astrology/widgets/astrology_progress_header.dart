import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AstrologyProgressHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onSkip;

  /// Defaults to popping the route.
  final VoidCallback? onBack;

  const AstrologyProgressHeader({
    Key? key,
    required this.currentStep,
    required this.totalSteps,
    this.onSkip,
    this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack ?? () => Navigator.maybePop(context),
            ),
            if (onSkip != null)
              TextButton(
                onPressed: onSkip,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: AppColors.lavender,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step $currentStep of $totalSteps',
                style: const TextStyle(
                  color: AppColors.lavender,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: currentStep / totalSteps,
                  backgroundColor: AppColors.surfaceCard,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandPurple),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}