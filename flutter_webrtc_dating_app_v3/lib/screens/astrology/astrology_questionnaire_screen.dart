import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:availchat/screens/astrology/steps/step_one_screen.dart';

class AstrologyQuestionnaireScreen extends StatelessWidget {
  const AstrologyQuestionnaireScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottie Animation
              Lottie.asset(
                'assets/animations/star_animation.json',
                width: 250,
                height: 250,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.auto_awesome,
                    size: 120,
                    color: Color(0xFF7B2CBF),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                '✨ Discover Your Cosmic Match',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF7B2CBF),
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Answer 8 fun questions about astrology and personality to enhance your profile and find better matches!',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFFB39DDB),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Start Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AstrologyStepOneScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Start Journey',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Skip Button
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: Color(0xFFB39DDB),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}