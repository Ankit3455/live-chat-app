import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class InterestsGrid extends StatelessWidget {
  final List<String> interests;

  const InterestsGrid({Key? key, required this.interests}) : super(key: key);

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
      spacing: 12,
      runSpacing: 12,
      children: interests.map((interest) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.brandPurple.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getInterestIcon(interest),
                color: AppColors.brandPurpleLight,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                interest,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}