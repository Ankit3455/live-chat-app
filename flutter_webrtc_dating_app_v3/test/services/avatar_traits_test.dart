import 'package:flutter_test/flutter_test.dart';
import 'package:availchat/services/avatar_mapping.dart';
import 'package:availchat/services/avatar_traits.dart';

Map<String, dynamic> stored(Map<String, dynamic> answers, String uid) {
  final props = AvatarMapping.buildFromAnswers(answers);
  final r = AvatarMapping.resolve(props, uniqueKey: uid);
  return {...props, 'avatarParams': r.params};
}

void main() {
  test('every row matches a param that was actually drawn', () {
    for (var i = 0; i < 200; i++) {
      final s = stored({
        'gender': i.isEven ? 'female' : 'male',
        'habits': 'Night Owl',
        'interests': ['Reading', 'Astrology', 'Romance', 'Cooking'],
        'profession': 'Engineer',
        'dateOfBirth': DateTime(2000, 3, 12),
      }, 'user_$i');
      final params = s['avatarParams'] as Map<String, String>;
      final effects = AvatarTraits.explain(s).map((t) => t.effect).toList();

      expect(effects, contains('Ocean colours'));
      expect(effects.contains('Glasses'),
          params['accessoriesProbability'] == '100' &&
              params['accessories']!.startsWith('prescription'));
      expect(effects.contains('Heart eyes'), params['eyes'] == 'hearts');
      if (effects.contains('Diamond print')) {
        expect(params['clothing'], 'graphicShirt');
        expect(params['clothingGraphic'], 'diamond');
      }
    }
  });

  test('no rows without stored params (e.g. legacy avatars)', () {
    expect(AvatarTraits.explain({'gender': 'female'}), isEmpty);
  });

  test('change hint names the answer and what it changed', () {
    final before = AvatarMapping.resolve(
      AvatarMapping.buildFromAnswers({'gender': 'female', 'habits': 'Night Owl'}),
      uniqueKey: 'u1',
    ).params;
    final after = AvatarMapping.resolve(
      AvatarMapping.buildFromAnswers({
        'gender': 'female',
        'habits': 'Night Owl',
        'interests': ['Reading'],
      }),
      uniqueKey: 'u1',
    ).params;
    expect(
      AvatarTraits.changeHint(before: before, after: after, answerLabel: 'Reading'),
      'Reading → glasses added',
    );
    expect(AvatarTraits.changeHint(before: null, after: after, answerLabel: 'x'), isNull);
    expect(AvatarTraits.changeHint(before: after, after: after, answerLabel: 'x'), isNull);
  });
}
