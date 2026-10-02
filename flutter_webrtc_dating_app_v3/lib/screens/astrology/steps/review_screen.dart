import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:availchat/core/utils/astrology_view_model.dart';
import 'package:availchat/screens/home/home_screen.dart';

class AstrologyReviewScreen extends StatelessWidget {
  const AstrologyReviewScreen({Key? key}) : super(key: key);

  Future<void> _saveToFirestore(BuildContext context, AstrologyViewModel viewModel) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final data = viewModel.getAllAnswers();
      
      // Remove null/empty values
      data.removeWhere((key, value) => value == null || 
        (value is List && value.isEmpty) || 
        (value is String && value.isEmpty));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(data, SetOptions(merge: true));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Astrology profile saved!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to Home
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AstrologyViewModel>();
    final answers = viewModel.getAllAnswers();

    return Scaffold(
      backgroundColor: const Color(0xFF1A0E2E),
      appBar: AppBar(
        title: const Text('Review Your Answers'),
        backgroundColor: const Color(0xFF2D1B4E),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                _buildReviewCard(
                  context,
                  'Preferred Zodiac Signs',
                  (answers['preferredSigns'] as List<dynamic>?)?.join(', ') ?? 'Not answered',
                  Icons.star,
                ),
                _buildReviewCard(
                  context,
                  'Believes in Astrology',
                  answers['believesInAstrology'] ?? 'Not answered',
                  Icons.auto_awesome,
                ),
                _buildReviewCard(
                  context,
                  'Personality Priority',
                  answers['personalityPriority'] ?? 'Not answered',
                  Icons.psychology,
                ),
                _buildReviewCard(
                  context,
                  'Astrology Belief Level',
                  answers['astrologyBeliefLevel']?.toString() ?? 'Not answered',
                  Icons.trending_up,
                ),
                _buildReviewCard(
                  context,
                  'Relationship Priority',
                  answers['relationshipPriority'] ?? 'Not answered',
                  Icons.favorite,
                ),
                _buildReviewCard(
                  context,
                  'Vibe Preference',
                  answers['vibePreference'] ?? 'Not answered',
                  Icons.mood,
                ),
                _buildReviewCard(
                  context,
                  'Sleep Schedule',
                  answers['sleepSchedule'] ?? 'Not answered',
                  Icons.bedtime,
                ),
                _buildReviewCard(
                  context,
                  'Ideal Date',
                  answers['idealDate'] ?? 'Not answered',
                  Icons.celebration,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _saveToFirestore(context, viewModel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2CBF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Save & Continue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B4E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF7B2CBF), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFB39DDB),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}