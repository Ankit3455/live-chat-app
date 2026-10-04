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
}
