import 'package:flutter_test/flutter_test.dart';
import 'package:availchat/services/avatar_mapping.dart';

Map<String, String> paramsFor(Map<String, dynamic> answers) =>
    AvatarMapping.dicebearParams(AvatarMapping.buildFromAnswers(answers));

void main() {
  const forbiddenEyes = ['xDizzy', 'cry', 'eyeRoll', 'closed', 'surprised', 'side'];
  const forbiddenMouths = ['vomit', 'grimace', 'screamOpen', 'disbelief', 'sad', 'concerned', 'serious', 'eating', 'tongue'];
  const forbiddenBrows = ['angry', 'angryNatural', 'sadConcerned', 'sadConcernedNatural', 'frownNatural', 'unibrowNatural'];

  List<String> listOf(Map<String, String> p, String key) => (p[key] ?? '').split(',');

  test('expressions never include ugly variants', () {
    for (final answers in [
      {'gender': 'Female', 'habits': 'Night Owl', 'interests': ['Reading']},
      {'gender': 'Male', 'habits': 'Early Riser', 'interests': ['Sports', 'Travel']},
      {'gender': 'Other', 'habits': 'Balanced', 'interests': ['Romance']},
    ]) {
      final p = paramsFor(answers);
      expect(listOf(p, 'eyes').where(forbiddenEyes.contains), isEmpty);
      expect(listOf(p, 'mouth').where(forbiddenMouths.contains), isEmpty);
      expect(listOf(p, 'eyebrows').where(forbiddenBrows.contains), isEmpty);
    }
  });

  test('no zoom params that crop the hair', () {
    final p = paramsFor({'gender': 'Female'});
    expect(p.containsKey('scale'), isFalse);
    expect(p.containsKey('translateY'), isFalse);
  });

  test('women get long-hair tops and no facial hair', () {
    final p = paramsFor({'gender': 'Female'});
    expect(listOf(p, 'top'), contains('longButNotTooLong'));
    expect(listOf(p, 'top'), isNot(contains('shortFlat')));
    expect(p['facialHairProbability'], '0');
  });

  test('other gender never gets an eyepatch or hat', () {
    final tops = listOf(paramsFor({'gender': 'Other'}), 'top');
    expect(tops, isNot(contains('eyepatch')));
    expect(tops.where((t) => t.toLowerCase().contains('hat')), isEmpty);
  });

  test('answers change the look', () {
    expect(paramsFor({'interests': ['Reading']})['accessoriesProbability'], '100');
    expect(paramsFor({'interests': ['Romance']})['eyes'], startsWith('hearts'));
    expect(paramsFor({'profession': 'Doctor'})['clothing'], contains('collarAndSweater'));
    expect(paramsFor({'habits': 'Night Owl'})['backgroundColor'], '3b2a6b,4c2f7a');
  });

  test('older users can get grey hair and more beards; skin is never yellow', () {
    final adult = paramsFor({'gender': 'Male', 'dateOfBirth': DateTime(1980, 1, 1)});
    final young = paramsFor({'gender': 'Male', 'dateOfBirth': DateTime(2003, 1, 1)});
    expect(listOf(adult, 'hairColor'), contains('e8e1e1'));
    expect(listOf(young, 'hairColor'), isNot(contains('e8e1e1')));
    expect(adult['facialHairProbability'], '70');
    expect(listOf(young, 'skinColor'), isNot(contains('f8d25c')));
  });

  test('zodiac element from DOB picks the palette, night owls get the dark one', () {
    // 5 Apr = Aries (fire), 12 Mar = Pisces (water).
    final fireDay = paramsFor({'dateOfBirth': DateTime(1996, 4, 5), 'habits': 'Early Riser'});
    final waterNight = paramsFor({'dateOfBirth': DateTime(2000, 3, 12), 'habits': 'Night Owl'});
    expect(fireDay['backgroundColor'], 'ffd1c1,ffb3a7');
    expect(waterNight['backgroundColor'], '1f2f5c,3b2a6b');
    expect(AvatarMapping.buildFromAnswers({'dateOfBirth': DateTime(2000, 3, 12)})['element'], 'water');
  });

  test('personality overrides interest-based expression', () {
    final extro = paramsFor({'personalityType': 'Extrovert', 'interests': ['Meditation']});
    final intro = paramsFor({'personalityType': 'Introvert', 'interests': ['Sports']});
    expect(extro['mouth'], 'smile,twinkle');
    expect(intro['mouth'], 'default,smile');
  });

  test('T-shirt print follows interests and is only set for graphic shirts', () {
    final cook = paramsFor({'profession': 'Engineer', 'interests': ['Cooking', 'Astrology']});
    expect(listOf(cook, 'clothingGraphic'), containsAll(['pizza', 'diamond']));
    final doctor = paramsFor({'profession': 'Doctor', 'interests': ['Cooking']});
    expect(doctor.containsKey('clothingGraphic'), isFalse);
  });

  test('post-signup answers add variety', () {
    expect(paramsFor({'exerciseFrequency': 'Daily'})['clothing'], 'shirtVNeck,hoodie');
    expect(paramsFor({'musicGenres': ['Classical']})['clothing'], contains('collarAndSweater'));
    expect(paramsFor({'partyingFrequency': 'Love it, often'})['accessories'], 'wayfarers,sunglasses');
    expect(listOf(paramsFor({'profession': 'Artist'}), 'hairColor'), contains('f59797'));
    expect(listOf(paramsFor({'profession': 'Doctor'}), 'hairColor'), isNot(contains('f59797')));
  });

  group('resolve (unique face per user)', () {
    final props = AvatarMapping.buildFromAnswers({
      'gender': 'female',
      'habits': 'Night Owl',
      'interests': ['Reading', 'Astrology'],
      'dateOfBirth': DateTime(2000, 3, 12),
    });

    test('same uid and variant always give the same face', () {
      final a = AvatarMapping.resolve(props, uniqueKey: 'uidA');
      final b = AvatarMapping.resolve(props, uniqueKey: 'uidA');
      expect(a.fingerprint, b.fingerprint);
      expect(a.params, b.params);
      expect(a.fingerprint, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('one value per part, always from the allowed list', () {
      final allowed = AvatarMapping.dicebearParams(props);
      final r = AvatarMapping.resolve(props, uniqueKey: 'uidB').params;
      for (final k in ['top', 'hairColor', 'skinColor', 'eyes', 'eyebrows', 'mouth', 'clothing']) {
        expect(allowed[k]!.split(','), contains(r[k]), reason: k);
      }
    });

    test('identical answers still spread across many faces', () {
      final faces = {
        for (var i = 0; i < 2000; i++)
          AvatarMapping.resolve(props, uniqueKey: 'user_$i').fingerprint,
      };
      expect(faces.length, greaterThan(1900));
      expect(
        AvatarMapping.resolve(props, uniqueKey: 'uidA', variant: 1).fingerprint,
        isNot(AvatarMapping.resolve(props, uniqueKey: 'uidA').fingerprint),
      );
    });
  });
}
