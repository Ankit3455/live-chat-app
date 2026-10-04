import '../../models/user_model.dart';
import 'astrology_utils.dart';

/// Astrology compatibility shown on other users' cards (DEST-029/100):
/// DOB -> zodiac sign -> score. Only zodiac signs feed it.
class CompatibilityService {
  CompatibilityService._();

  static const String tooltip =
      'Astrology compatibility is calculated from zodiac signs.';

  /// Bonus when the other user's sign is one of my preferred signs.
  static const int preferredSignBonus = 10;

  /// A user's sun sign: stored zodiacSign/sunSign, else derived from the DOB
  /// (only my own profile carries a DOB; public profiles carry the sign).
  static String? signOf(UserModel? user) {
    if (user == null) return null;
    return AstrologyUtils.normalizeSign(user.zodiacSign) ??
        AstrologyUtils.normalizeSign(user.sunSign) ??
        (user.dateOfBirth != null
            ? AstrologyUtils.zodiacFromDate(user.dateOfBirth!)
            : null);
  }

  /// 0-100 score of [other] for [me], or null when either sign is unknown
  /// (the chip is hidden then).
  static int? compatibilityScore(UserModel? me, UserModel other) {
    final mySign = signOf(me);
    final otherSign = signOf(other);
    final base = AstrologyUtils.signCompatibility(mySign, otherSign);
    if (base == null) return null;

    final prefersOther = me!.preferredSigns
        .any((s) => AstrologyUtils.normalizeSign(s) == otherSign);
    return (base + (prefersOther ? preferredSignBonus : 0)).clamp(0, 100);
  }
}
