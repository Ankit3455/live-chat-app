import 'package:intl/intl.dart';

/// Astrology utility functions converted from AstrologyUtils.kt
class AstrologyUtils {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  /// Get zodiac sign from date of birth
  static String? zodiacFromDob(String? dob) {
    if (dob == null || dob.isEmpty) return null;

    try {
      final date = _dateFormat.parse(dob);
      final day = date.day;
      final month = date.month;

      if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) return 'Aries';
      if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) return 'Taurus';
      if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) return 'Gemini';
      if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) return 'Cancer';
      if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return 'Leo';
      if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) return 'Virgo';
      if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) return 'Libra';
      if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) return 'Scorpio';
      if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) return 'Sagittarius';
      if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) return 'Capricorn';
      if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) return 'Aquarius';
      if ((month == 2 && day >= 19) || (month == 3 && day <= 20)) return 'Pisces';

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get element for a zodiac sign
  static String? elementOf(String? sign) {
    switch (sign) {
      case 'Aries':
      case 'Leo':
      case 'Sagittarius':
        return 'Fire';
      case 'Taurus':
      case 'Virgo':
      case 'Capricorn':
        return 'Earth';
      case 'Gemini':
      case 'Libra':
      case 'Aquarius':
        return 'Air';
      case 'Cancer':
      case 'Scorpio':
      case 'Pisces':
        return 'Water';
      default:
        return null;
    }
  }

  /// Simple compatibility score calculation (0-100)
  static int compatibilityScore(
    String? aSign,
    String? bSign, {
    String? preferElement,
  }) {
    if (aSign == null || aSign.isEmpty || bSign == null || bSign.isEmpty) {
      return 50;
    }

    if (aSign == bSign) return 85;

    final aEl = elementOf(aSign);
    final bEl = elementOf(bSign);

    int score = 60;

    if (aEl != null && bEl != null && aEl == bEl) {
      score += 20;
    }

    if (preferElement != null &&
        preferElement.isNotEmpty &&
        bEl == preferElement) {
      score += 10;
    }

    return score.clamp(0, 100);
  }

  /// All zodiac signs
  static const List<String> zodiacSigns = [
    'Aries',
    'Taurus',
    'Gemini',
    'Cancer',
    'Leo',
    'Virgo',
    'Libra',
    'Scorpio',
    'Sagittarius',
    'Capricorn',
    'Aquarius',
    'Pisces',
  ];

  /// All elements
  static const List<String> elements = [
    'Fire',
    'Earth',
    'Air',
    'Water',
  ];
}