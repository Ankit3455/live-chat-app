import 'package:availchat/core/utils/astrology_utils.dart';
import 'package:availchat/core/utils/compatibility_utils.dart';
import 'package:availchat/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AstrologyUtils', () {
    test('zodiacFromDate covers sign boundaries', () {
      expect(AstrologyUtils.zodiacFromDate(DateTime(1990, 3, 21)), 'Aries');
      expect(AstrologyUtils.zodiacFromDate(DateTime(1990, 3, 20)), 'Pisces');
      expect(AstrologyUtils.zodiacFromDate(DateTime(1990, 12, 22)), 'Capricorn');
      expect(AstrologyUtils.zodiacFromDate(DateTime(1990, 1, 19)), 'Capricorn');
      expect(AstrologyUtils.zodiacFromDob('20/01/1990'), 'Aquarius');
    });

    test('normalizeSign accepts any case and rejects unknown values', () {
      expect(AstrologyUtils.normalizeSign(' leo '), 'Leo');
      expect(AstrologyUtils.normalizeSign('Ophiuchus'), isNull);
      expect(AstrologyUtils.normalizeSign(null), isNull);
    });

    test('signCompatibility is symmetric and null without both signs', () {
      for (final a in AstrologyUtils.zodiacSigns) {
        for (final b in AstrologyUtils.zodiacSigns) {
          expect(AstrologyUtils.signCompatibility(a, b),
              AstrologyUtils.signCompatibility(b, a));
        }
      }
      expect(AstrologyUtils.signCompatibility('Aries', 'Leo'), 90); // trine
      expect(AstrologyUtils.signCompatibility('Aries', 'Cancer'), 45); // square
      expect(AstrologyUtils.signCompatibility('Aries', null), isNull);
    });
  });

  group('CompatibilityService', () {
    test('hidden (null) when a sign is missing', () {
      final me = UserModel(uid: 'a', zodiacSign: 'Aries');
      expect(CompatibilityService.compatibilityScore(me, UserModel(uid: 'b')),
          isNull);
      expect(
          CompatibilityService.compatibilityScore(
              null, UserModel(uid: 'b', zodiacSign: 'Leo')),
          isNull);
    });

    test('derives my sign from DOB and adds the preferred-sign bonus', () {
      final me = UserModel(
        uid: 'a',
        dateOfBirth: DateTime(1990, 4, 1), // Aries
        preferredSigns: const ['leo'],
      );
      final leo = UserModel(uid: 'b', zodiacSign: 'Leo');
      final libra = UserModel(uid: 'c', sunSign: 'Libra');
      expect(CompatibilityService.compatibilityScore(me, leo), 100);
      expect(CompatibilityService.compatibilityScore(me, libra), 70);
    });
  });
}
