import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:availchat/core/utils/astrology_view_model.dart';
import 'package:availchat/screens/astrology/widgets/astrology_progress_header.dart';
import 'package:availchat/screens/astrology/steps/step_five_screen.dart';

class AstrologyStepFourScreen extends StatefulWidget {
  const AstrologyStepFourScreen({Key? key}) : super(key: key);

  @override
  State<AstrologyStepFourScreen> createState() =>
      _AstrologyStepFourScreenState();
}

class _AstrologyStepFourScreenState extends State<AstrologyStepFourScreen> {
  double beliefLevel = 5.0;

  void _continue() {
    context.read<AstrologyViewModel>().updateAstrologyBeliefLevel(beliefLevel.toInt());
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepFiveScreen()),
    );
  }

  void _skip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AstrologyStepFiveScreen()),
    );
  }

  String _getBeliefLabel() {
    if (beliefLevel <= 3) return 'Skeptical';
    if (beliefLevel <= 6) return 'Open-minded';
    if (beliefLevel <= 8) return 'Believer';
    return 'True Devotee';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E2E),
      body: SafeArea(
        child: Column(
          children: [
            AstrologyProgressHeader(
              currentStep: 4,
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
                      'How much do you believe in astrology?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            beliefLevel.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7B2CBF),
                            ),
                          ),
                          Text(
                            _getBeliefLabel(),
                            style: const TextStyle(
                              fontSize: 24,
                              color: Color(0xFFB39DDB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFF7B2CBF),
                        inactiveTrackColor: const Color(0xFF2D1B4E),
                        thumbColor: const Color(0xFF7B2CBF),
                        overlayColor: const Color(0xFF7B2CBF).withOpacity(0.2),
                        trackHeight: 8,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 16,
                        ),
                      ),
                      child: Slider(
                        value: beliefLevel,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        onChanged: (value) {
                          setState(() {
                            beliefLevel = value;
                          });
                        },
                      ),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1', style: TextStyle(color: Color(0xFFB39DDB))),
                        Text('10', style: TextStyle(color: Color(0xFFB39DDB))),
                      ],
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
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
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