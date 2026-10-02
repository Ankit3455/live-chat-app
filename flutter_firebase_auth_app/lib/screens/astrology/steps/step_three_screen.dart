import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:availchat/core/utils/astrology_view_model.dart';
import 'package:availchat/screens/astrology/widgets/astrology_progress_header.dart';
import 'package:availchat/screens/astrology/steps/step_four_screen.dart';

class AstrologyStepThreeScreen extends StatefulWidget {
  const AstrologyStepThreeScreen({Key? key}) : super(key: key);

  @override
  State<AstrologyStepThreeScreen> createState() =>
      _AstrologyStepThreeScreenState();
}

class _AstrologyStepThreeScreenState extends State<AstrologyStepThreeScreen> {
  String? selectedPriority;

  final List<String> priorities = [
    'Adventurous',
    'Empathetic',
    'Intellectual',
    'Passionate',
    'Humorous',
    'Loyal',
    'Creative',
    'Ambitious',
  ];

  void _continue() {
    if (selectedPriority == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a trait')),
      );
      return;
    }

    context.read<AstrologyViewModel>().updatePersonalityPriority(selectedPriority!);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepFourScreen()),
    );
  }

  void _skip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepFourScreen()),
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
              currentStep: 3,
              onSkip: _skip,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What personality trait matters most to you?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: priorities.map((priority) {
                        final isSelected = selectedPriority == priority;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedPriority = priority;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF7B2CBF)
                                  : const Color(0xFF2D1B4E),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF7B2CBF)
                                    : const Color(0xFF2D1B4E),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              priority,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFFB39DDB),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
                  onPressed: selectedPriority != null ? _continue : null,
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