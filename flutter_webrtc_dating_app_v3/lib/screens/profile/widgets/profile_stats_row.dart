import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:availchat/models/user_model.dart';

class ProfileStatsRow extends StatelessWidget {
  final UserModel user;

  const ProfileStatsRow({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B4E),
        borderRadius: BorderRadius.circular(16),
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
          _buildStat(
            icon: Icons.cake,
            label: 'Age',
            value: _ageLabel(),
          ),
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
    // Prefer computed DateTime if available
    if (user.dateOfBirth != null) {
      return _calculateAgeFromDate(user.dateOfBirth!).toString();
    }
    // Fallback to raw dob string (Kotlin writes dd/MM/yyyy)
    if (user.dob != null && user.dob!.trim().isNotEmpty) {
      final age = _calculateAgeFromDobString(user.dob!.trim());
      return age > 0 ? age.toString() : 'N/A';
    }
    return 'N/A';
  }

  int _calculateAgeFromDate(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    final hasHadBirthdayThisYear = (today.month > birthDate.month) ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hasHadBirthdayThisYear) age--;
    return age;
  }

  // Robust parser with logging instead of empty catch
  int _calculateAgeFromDobString(String dob) {
    // Try dd/MM/yyyy first (Kotlin app), then dd-MM-yyyy, then ISO-8601
    try {
      final parts = dob.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final parsed = DateTime(year, month, day);
        return _calculateAgeFromDate(parsed);
      }
    } catch (e, st) {
      debugPrint('Age parse (dd/MM/yyyy) failed for dob="$dob": $e\n$st');
    }

    try {
      final partsDash = dob.split('-');
      if (partsDash.length == 3) {
        // try dd-MM-yyyy
        final day = int.parse(partsDash[0]);
        final month = int.parse(partsDash[1]);
        final year = int.parse(partsDash[2]);
        final parsed = DateTime(year, month, day);
        return _calculateAgeFromDate(parsed);
      }
    } catch (e, st) {
      debugPrint('Age parse (dd-MM-yyyy) failed for dob="$dob": $e\n$st');
    }

    try {
      final iso = DateTime.tryParse(dob);
      if (iso != null) {
        return _calculateAgeFromDate(iso);
      }
    } catch (e, st) {
      debugPrint('Age parse (ISO) failed for dob="$dob": $e\n$st');
    }

    // Could not parse
    debugPrint('Age parse failed for dob="$dob" (all strategies)');
    return 0;
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF7B2CBF), size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB39DDB),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 50,
      color: const Color(0xFF7B2CBF).withOpacity(0.3),
    );
  }
}