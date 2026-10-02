import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:availchat/core/utils/astrology_view_model.dart';
import 'package:availchat/screens/astrology/widgets/astrology_progress_header.dart';
import 'package:availchat/screens/astrology/steps/step_six_screen.dart';

class AstrologyStepFiveScreen extends StatefulWidget {
  const AstrologyStepFiveScreen({Key? key}) : super(key: key);

  @override
  State<AstrologyStepFiveScreen> createState() =>
      _AstrologyStepFiveScreenState();
}

class _AstrologyStepFiveScreenState extends State<AstrologyStepFiveScreen> {
  String? selectedPriority;

  final List<Map<String, dynamic>> options = [
    {'value': 'emotional_connection', 'label': 'Emotional Connection', 'icon': Icons.favorite},
    {'value': 'intellectual_match', 'label': 'Intellectual Match', 'icon': Icons.school},
    {'value': 'physical_attraction', 'label': 'Physical Attraction', 'icon': Icons.bolt},
    {'value': 'shared_values', 'label': 'Shared Values', 'icon': Icons.handshake},
    {'value': 'adventure', 'label': 'Adventure & Fun', 'icon': Icons.explore},
  ];

  void _continue() {
    if (selectedPriority == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a priority')),
      );
      return;
    }

    context.read<AstrologyViewModel>().updateRelationshipPriority(selectedPriority!);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepSixScreen()),
    );
  }

  void _skip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepSixScreen()),
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
              currentStep: 5,
              onSkip: _skip,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What matters most in a relationship?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...options.map((option) {
                      final isSelected = selectedPriority == option['value'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedPriority = option['value'];
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
                              children: [
                                Icon(
                                  option['icon'],
                                  color: isSelected
                                      ? const Color(0xFF7B2CBF)
                                      : const Color(0xFFB39DDB),
                                  size: 28,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    option['label'],
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