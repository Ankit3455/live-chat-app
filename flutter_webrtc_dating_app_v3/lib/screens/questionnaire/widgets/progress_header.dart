import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Onboarding top bar: back button, thin gradient progress bar and "3 of 9".
/// A null [onBack] hides the back button (e.g. first step of a root flow).
class ProgressHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onBack;

  /// Replaces the default "3 of 9" label (e.g. "Last step").
  final String? stepLabel;

  const ProgressHeader({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.onBack,
    this.stepLabel,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = totalSteps <= 0
        ? 0.0
        : (currentStep / totalSteps).clamp(0.0, 1.0).toDouble();
    final label = stepLabel ?? '$currentStep of $totalSteps';
    final back = onBack;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            if (back != null)
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.white,
                onPressed: back,
              )
            else
              const SizedBox(width: 48),
            const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                label: 'Progress',
                value: label,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Container(
                    height: 4,
                    color: AppColors.surface2,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      heightFactor: 1,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12),
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSubtle,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
