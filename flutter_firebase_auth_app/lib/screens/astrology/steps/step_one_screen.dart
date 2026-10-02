import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:availchat/core/utils/astrology_view_model.dart';
import 'package:availchat/screens/astrology/widgets/astrology_progress_header.dart';
import 'package:availchat/screens/astrology/widgets/zodiac_sign_selector.dart';
import 'package:availchat/screens/astrology/steps/step_two_screen.dart';

class AstrologyStepOneScreen extends StatefulWidget {
  const AstrologyStepOneScreen({Key? key}) : super(key: key);

  @override
  State<AstrologyStepOneScreen> createState() => _AstrologyStepOneScreenState();
}

class _AstrologyStepOneScreenState extends State<AstrologyStepOneScreen> {
  List<String> selectedSigns = [];

  void _toggleSign(String sign) {
    setState(() {
      if (selectedSigns.contains(sign)) {
        selectedSigns.remove(sign);
      } else {
        selectedSigns.add(sign);
      }
    });
  }

  void _continue() {
    if (selectedSigns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one sign')),
      );
      return;
    }

    context.read<AstrologyViewModel>().updatePreferredSigns(selectedSigns);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepTwoScreen()),
    );
  }

  void _skip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepTwoScreen()),
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
              currentStep: 1,
              onSkip: _skip,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Which zodiac signs attract you the most?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select all that apply',
                      style: TextStyle(
                        color: Color(0xFFB39DDB),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ZodiacSignSelector(
                      selectedSigns: selectedSigns,
                      onToggle: _toggleSign,
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
                  onPressed: selectedSigns.isNotEmpty ? _continue : null,
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