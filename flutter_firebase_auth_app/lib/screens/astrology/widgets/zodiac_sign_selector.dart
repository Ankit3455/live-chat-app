import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class ZodiacSignSelector extends StatelessWidget {
  final List<String> selectedSigns;
  final Function(String) onToggle;

  const ZodiacSignSelector({
    Key? key,
    required this.selectedSigns,
    required this.onToggle,
  }) : super(key: key);

  static const List<Map<String, String>> zodiacSigns = [
    {'name': 'Aries', 'emoji': '♈', 'value': 'aries'},
    {'name': 'Taurus', 'emoji': '♉', 'value': 'taurus'},
    {'name': 'Gemini', 'emoji': '♊', 'value': 'gemini'},
    {'name': 'Cancer', 'emoji': '♋', 'value': 'cancer'},
    {'name': 'Leo', 'emoji': '♌', 'value': 'leo'},
    {'name': 'Virgo', 'emoji': '♍', 'value': 'virgo'},
    {'name': 'Libra', 'emoji': '♎', 'value': 'libra'},
    {'name': 'Scorpio', 'emoji': '♏', 'value': 'scorpio'},
    {'name': 'Sagittarius', 'emoji': '♐', 'value': 'sagittarius'},
    {'name': 'Capricorn', 'emoji': '♑', 'value': 'capricorn'},
    {'name': 'Aquarius', 'emoji': '♒', 'value': 'aquarius'},
    {'name': 'Pisces', 'emoji': '♓', 'value': 'pisces'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Lottie Animation
        Lottie.asset(
          'assets/animations/zodiac.json',
          width: 150,
          height: 150,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.stars,
              size: 80,
              color: Color(0xFF7B2CBF),
            );
          },
        ),
        const SizedBox(height: 24),

        // Grid of Signs
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: zodiacSigns.length,
          itemBuilder: (context, index) {
            final sign = zodiacSigns[index];
            final isSelected = selectedSigns.contains(sign['value']);

            return GestureDetector(
              onTap: () => onToggle(sign['value']!),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF7B2CBF) : const Color(0xFF2D1B4E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF7B2CBF)
                        : const Color(0xFF2D1B4E).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      sign['emoji']!,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sign['name']!,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFFB39DDB),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}