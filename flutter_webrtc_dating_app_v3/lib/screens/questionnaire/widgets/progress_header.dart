import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ProgressHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String title;

  const ProgressHeader({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentStep / totalSteps;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Title
          Text(
            title,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Progress Bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Step $currentStep of $totalSteps',
                    style: const TextStyle(
                      color: AppColors.hintPurple,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: AppColors.brandPurpleLight,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.hintPurple.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.purpleSecondary,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}