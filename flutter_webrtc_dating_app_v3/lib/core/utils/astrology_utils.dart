import 'package:intl/intl.dart';

/// Astrology utility functions converted from AstrologyUtils.kt
class AstrologyUtils {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  /// Get zodiac sign from a legacy dd/MM/yyyy date of birth.
  static String? zodiacFromDob(String? dob) {
    if (dob == null || dob.isEmpty) return null;
    try {
      return zodiacFromDate(_dateFormat.parse(dob));
    } catch (e) {
      return null;
    }
  }

  /// Western sun sign for a calendar date.
  static String zodiacFromDate(DateTime date) {
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
    if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) {
      return 'Sagittarius';
    }
    if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) return 'Capricorn';
    if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) return 'Aquarius';
    return 'Pisces';
  }

  /// Canonical sign name ('aries ' -> 'Aries'), or null if not a sign.
  static String? normalizeSign(String? sign) {
    final s = sign?.trim().toLowerCase();
    if (s == null || s.isEmpty) return null;
    for (final z in zodiacSigns) {
      if (z.toLowerCase() == s) return z;
    }
    return null;
  }

  static const Map<String, String> zodiacEmoji = {
    'Aries': '\u2648',
    'Taurus': '\u2649',
    'Gemini': '\u264A',
    'Cancer': '\u264B',
    'Leo': '\u264C',
    'Virgo': '\u264D',
    'Libra': '\u264E',
    'Scorpio': '\u264F',
    'Sagittarius': '\u2650',
    'Capricorn': '\u2651',
    'Aquarius': '\u2652',
    'Pisces': '\u2653',
  };

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

  /// Sun-sign compatibility (45-90) from the angle between the two signs:
  /// trine (same element) is highest, square lowest. Null if either sign is
  /// unknown, so callers can hide the score instead of showing a fake one.
  static int? signCompatibility(String? aSign, String? bSign) {
    final a = normalizeSign(aSign);
    final b = normalizeSign(bSign);
    if (a == null || b == null) return null;

    final diff = (zodiacSigns.indexOf(a) - zodiacSigns.indexOf(b)).abs();
    final distance = diff > 6 ? 12 - diff : diff;
    const byDistance = [80, 60, 80, 45, 90, 55, 70];
    return byDistance[distance];
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