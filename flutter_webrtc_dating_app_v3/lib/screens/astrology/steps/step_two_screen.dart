import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:availchat/core/utils/astrology_view_model.dart';
import 'package:availchat/screens/astrology/widgets/astrology_progress_header.dart';
import 'package:availchat/screens/astrology/steps/step_three_screen.dart';

class AstrologyStepTwoScreen extends StatefulWidget {
  const AstrologyStepTwoScreen({Key? key}) : super(key: key);

  @override
  State<AstrologyStepTwoScreen> createState() => _AstrologyStepTwoScreenState();
}

class _AstrologyStepTwoScreenState extends State<AstrologyStepTwoScreen> {
  String? selectedBelief;

  final List<Map<String, dynamic>> options = [
    {'value': 'yes', 'label': 'Yes, absolutely!', 'icon': Icons.star},
    {'value': 'somewhat', 'label': 'Somewhat', 'icon': Icons.star_half},
    {'value': 'no', 'label': 'Not really', 'icon': Icons.star_border},
    {'value': 'unsure', 'label': 'Not sure', 'icon': Icons.help_outline},
  ];

  void _continue() {
    if (selectedBelief == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an option')),
      );
      return;
    }

    context.read<AstrologyViewModel>().updateBelievesInAstrology(selectedBelief!);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepThreeScreen()),
    );
  }

  void _skip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepThreeScreen()),
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
              currentStep: 2,
              onSkip: _skip,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Do you believe in astrology?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ...options.map((option) {
                      final isSelected = selectedBelief == option['value'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedBelief = option['value'];
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
                  onPressed: selectedBelief != null ? _continue : null,
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