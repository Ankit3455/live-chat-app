import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:availchat/core/utils/astrology_view_model.dart';
import 'package:availchat/screens/astrology/widgets/astrology_progress_header.dart';
import 'package:availchat/screens/astrology/steps/step_seven_screen.dart';

class AstrologyStepSixScreen extends StatefulWidget {
  const AstrologyStepSixScreen({Key? key}) : super(key: key);

  @override
  State<AstrologyStepSixScreen> createState() => _AstrologyStepSixScreenState();
}

class _AstrologyStepSixScreenState extends State<AstrologyStepSixScreen> {
  String? selectedVibe;

  final List<String> vibes = [
    'Chill & Relaxed',
    'Energetic & Spontaneous',
    'Deep & Meaningful',
    'Fun & Playful',
    'Mysterious & Intriguing',
    'Calm & Peaceful',
  ];

  void _continue() {
    if (selectedVibe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vibe')),
      );
      return;
    }

    context.read<AstrologyViewModel>().updateVibePreference(selectedVibe!);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepSevenScreen()),
    );
  }

  void _skip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepSevenScreen()),
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
              currentStep: 6,
              onSkip: _skip,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What vibe are you looking for?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...vibes.map((vibe) {
                      final isSelected = selectedVibe == vibe;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedVibe = vibe;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  vibe,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF7B2CBF)
                                        : Colors.white,
                                    fontSize: 18,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF7B2CBF),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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
                  onPressed: selectedVibe != null ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    disabledBackgroundColor: const Color(0xFF2D1B4E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
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
