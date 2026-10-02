import 'package:flutter/material.dart';

class AstrologyProgressHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onSkip;

  const AstrologyProgressHeader({
    Key? key,
    required this.currentStep,
    this.totalSteps = 8,
    this.onSkip,
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
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            if (onSkip != null)
              TextButton(
                onPressed: onSkip,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Color(0xFFB39DDB),
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
                  color: Color(0xFFB39DDB),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: currentStep / totalSteps,
                  backgroundColor: const Color(0xFF2D1B4E),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7B2CBF)),
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