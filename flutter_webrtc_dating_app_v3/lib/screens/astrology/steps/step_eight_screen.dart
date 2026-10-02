import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:availchat/core/utils/astrology_view_model.dart';
import 'package:availchat/screens/astrology/widgets/astrology_progress_header.dart';
import 'package:availchat/screens/astrology/steps/review_screen.dart';

class AstrologyStepEightScreen extends StatefulWidget {
  const AstrologyStepEightScreen({Key? key}) : super(key: key);

  @override
  State<AstrologyStepEightScreen> createState() =>
      _AstrologyStepEightScreenState();
}

class _AstrologyStepEightScreenState extends State<AstrologyStepEightScreen> {
  String? selectedDate;

  final List<Map<String, String>> dateIdeas = [
    {'value': 'outdoor_adventure', 'label': 'Outdoor Adventure', 'emoji': '🏔️'},
    {'value': 'cozy_dinner', 'label': 'Cozy Dinner', 'emoji': '🍷'},
    {'value': 'cultural_experience', 'label': 'Cultural Experience', 'emoji': '🎨'},
    {'value': 'active_sports', 'label': 'Active & Sports', 'emoji': '⚽'},
    {'value': 'movie_night', 'label': 'Movie Night', 'emoji': '🎬'},
    {'value': 'coffee_chat', 'label': 'Coffee & Chat', 'emoji': '☕'},
    {'value': 'concert_show', 'label': 'Concert/Show', 'emoji': '🎵'},
    {'value': 'spontaneous', 'label': 'Spontaneous!', 'emoji': '✨'},
  ];

  void _continue() {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your ideal date')),
      );
      return;
    }

    context.read<AstrologyViewModel>().updateIdealDate(selectedDate!);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyReviewScreen()),
    );
  }

  void _skip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyReviewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E2E),
      body: SafeArea(
        child: Column(
          children: [
            AstrologyProgressHeader(
              currentStep: 8,
              onSkip: _skip,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "What's your ideal date?", // ✅ FIXED: Double quotes
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: dateIdeas.length,
                      itemBuilder: (context, index) {
                        final idea = dateIdeas[index];
                        final isSelected = selectedDate == idea['value'];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedDate = idea['value'];
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF7B2CBF).withOpacity(0.15)
                                  : const Color(0xFF2D1B4E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF7B2CBF)
                                    : const Color(0xFF2D1B4E),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  idea['emoji']!,
                                  style: const TextStyle(fontSize: 40),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  idea['label']!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF7B2CBF)
                                        : Colors.white,
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: selectedDate != null ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    disabledBackgroundColor: const Color(0xFF2D1B4E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Review Answers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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