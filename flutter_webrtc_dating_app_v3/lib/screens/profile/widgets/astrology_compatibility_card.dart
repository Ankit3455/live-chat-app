import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:availchat/models/public_profile.dart';
import 'package:availchat/models/user_model.dart';
import '../../../core/constants/app_colors.dart';

class AstrologyCompatibilityCard extends StatelessWidget {
  final UserModel user;

  const AstrologyCompatibilityCard({Key? key, required this.user})
      : super(key: key);

  Future<Map<String, dynamic>?> _getAstrologyData() async {
    try {
      // Own doc for me; other users only expose public_profiles.
      final isMe = user.uid == FirebaseAuth.instance.currentUser?.uid;
      final doc = await FirebaseFirestore.instance
          .collection(isMe ? 'users' : PublicProfile.collection)
          .doc(user.uid)
          .get();

      return doc.data();
    } catch (e) {
      return null;
    }
  }

  String _getZodiacEmoji(String? sign) {
    final emojis = {
      'aries': '♈',
      'taurus': '♉',
      'gemini': '♊',
      'cancer': '♋',
      'leo': '♌',
      'virgo': '♍',
      'libra': '♎',
      'scorpio': '♏',
      'sagittarius': '♐',
      'capricorn': '♑',
      'aquarius': '♒',
      'pisces': '♓',
    };
    return emojis[sign?.toLowerCase()] ?? '✨';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getAstrologyData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brandPurple),
          );
        }

        final data = snapshot.data;
        final zodiacSign = user.zodiacSign;
        final preferredSigns = (data?['preferredSigns'] as List?)?.toList();
        final dynamic beliefRaw = data?['believesInAstrology'];
        final String? believesInAstrology = beliefRaw == null
        ? null
          : (beliefRaw is bool ? (beliefRaw ? 'yes' : 'no') : beliefRaw.toString());

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.brandPurple.withOpacity(0.2),
                AppColors.surfaceCard,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.gold.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: AppColors.gold,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Cosmic Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Zodiac Sign
              if (zodiacSign != null) ...[
                _buildInfoRow(
                  label: 'Zodiac Sign',
                  value: '${_getZodiacEmoji(zodiacSign)} ${zodiacSign.toUpperCase()}',
                ),
                const SizedBox(height: 12),
              ],

              // Preferred Signs
              if (preferredSigns != null && preferredSigns.isNotEmpty) ...[
                const Text(
                  'Compatible with',
                  style: TextStyle(
                    color: AppColors.lavender,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: preferredSigns.map((sign) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPurple.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_getZodiacEmoji(sign.toString())} ${sign.toString().toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Belief Level
              if (believesInAstrology != null) ...[
                _buildInfoRow(
                  label: 'Believes in Astrology',
                  value: believesInAstrology,
                ),
              ],

              // No Data Message
              if (zodiacSign == null &&
                  (preferredSigns == null || preferredSigns.isEmpty) &&
                  believesInAstrology == null)
                const Text(
                  'Complete astrology questionnaire to show cosmic compatibility!',
                  style: TextStyle(
                    color: AppColors.lavender,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.lavender,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}