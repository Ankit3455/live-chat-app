import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:availchat/core/utils/astrology_view_model.dart';
import 'package:availchat/screens/astrology/widgets/astrology_progress_header.dart';
import 'package:availchat/screens/astrology/steps/step_eight_screen.dart';

class AstrologyStepSevenScreen extends StatefulWidget {
  const AstrologyStepSevenScreen({Key? key}) : super(key: key);

  @override
  State<AstrologyStepSevenScreen> createState() =>
      _AstrologyStepSevenScreenState();
}

class _AstrologyStepSevenScreenState extends State<AstrologyStepSevenScreen> {
  String? selectedSchedule;

  final List<Map<String, dynamic>> schedules = [
    {'value': 'early_bird', 'label': 'Early Bird 🌅', 'desc': 'Up with the sun'},
    {'value': 'night_owl', 'label': 'Night Owl 🌙', 'desc': 'Alive after dark'},
    {'value': 'flexible', 'label': 'Flexible ⏰', 'desc': 'It varies'},
  ];

  void _continue() {
    if (selectedSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your sleep schedule')),
      );
      return;
    }

    context.read<AstrologyViewModel>().updateSleepSchedule(selectedSchedule!);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepEightScreen()),
    );
  }

  void _skip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepEightScreen()),
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
              currentStep: 7,
              onSkip: _skip,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "What's your sleep schedule like?", // ✅ FIXED: Double quotes
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ...schedules.map((schedule) {
                      final isSelected = selectedSchedule == schedule['value'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedSchedule = schedule['value'];
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(24),
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
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        schedule['label'],
                                        style: TextStyle(
                                          color: isSelected
                                              ? const Color(0xFF7B2CBF)
                                              : Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        schedule['desc'],
                                        style: const TextStyle(
                                          color: Color(0xFFB39DDB),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF7B2CBF),
                                    size: 32,
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
                  onPressed: selectedSchedule != null ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    disabledBackgroundColor: const Color(0xFF2D1B4E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Continue',
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