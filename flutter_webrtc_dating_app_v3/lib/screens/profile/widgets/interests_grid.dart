import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class InterestsGrid extends StatelessWidget {
  final List<String> interests;

  const InterestsGrid({super.key, required this.interests});

  IconData _getInterestIcon(String interest) {
    final icons = {
      'Music': Icons.music_note,
      'Movies': Icons.movie,
      'Sports': Icons.sports_soccer,
      'Travel': Icons.flight,
      'Reading': Icons.book,
      'Gaming': Icons.sports_esports,
      'Cooking': Icons.restaurant,
      'Art': Icons.palette,
      'Photography': Icons.camera_alt,
      'Fitness': Icons.fitness_center,
    };
    return icons[interest] ?? Icons.star;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: interests.map((interest) {
        return Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getInterestIcon(interest),
                color: AppColors.lavender,
                size: 14,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  interest,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
