import 'package:flutter/material.dart';
import 'package:availchat/models/user_model.dart';
import '../../../core/constants/app_colors.dart';

class ProfileStatsRow extends StatelessWidget {
  final UserModel user;

  const ProfileStatsRow({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(
            icon: Icons.location_on,
            label: 'Location',
            value: user.location ?? 'Not set',
          ),
          _buildDivider(),
          _buildStat(icon: Icons.cake, label: 'Age', value: _ageLabel()),
          _buildDivider(),
          _buildStat(
            icon: Icons.favorite,
            label: 'Interests',
            value: user.interests.length.toString(),
          ),
        ],
      ),
    );
  }

  String _ageLabel() {
    final age = user.age;
    return age != null && age > 0 ? age.toString() : 'Not set';
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Column(
          children: [
            Icon(icon, color: AppColors.brandPurpleLight, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.lavender, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 50, color: AppColors.border);
  }
}
