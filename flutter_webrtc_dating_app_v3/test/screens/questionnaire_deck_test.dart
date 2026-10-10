import 'package:availchat/core/utils/vibe_line.dart';
import 'package:availchat/models/question_model.dart';
import 'package:availchat/models/question_type.dart';
import 'package:availchat/screens/questionnaire/deck/deck_models.dart';
import 'package:availchat/screens/questionnaire/helpers/questionnaire_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final all = QuestionnaireHelper.getAllQuestions();

  group('question data', () {
    test('every field is asked once', () {
      final names = all.map((q) => q.fieldName).toList();
      expect(names.toSet().length, names.length);
    });

    test('emojis and quips line up with options', () {
      for (final q in all) {
        if (q.optionEmojis.isNotEmpty) {
          expect(q.optionEmojis.length, q.options.length, reason: q.fieldName);
        }
        if (q.optionQuips.isNotEmpty) {
          expect(q.optionQuips.length, q.options.length, reason: q.fieldName);
        }
        for (final x in q.exclusiveOptions) {
          expect(q.options, contains(x), reason: q.fieldName);
        }
      }
    });

    test('stored option values from before the redesign still exist', () {
      Question q(String f) => QuestionnaireHelper.getQuestionByFieldName(f)!;
      expect(q('drinkingHabits').options,
          containsAll(['Never', 'Socially', 'Regularly', 'Occasionally']));
      expect(
          q('exerciseFrequency').options,
          containsAll(
              ['Daily', '3-4 times/week', 'Occasionally', 'Rarely', 'Never']));
      expect(q('pets').options, contains('No, but I love them'));
      expect(q('activityLevel').options, ['Low', 'Moderate', 'High']);
      expect(
          q('profession').options,
          containsAll([
            'Student',
            'Engineer',
            'Doctor',
            'Artist',
            'Astrology Consultant',
            'Other'
          ]));
      expect(q('habits').options,
          containsAll(['Early Riser', 'Night Owl', 'Balanced']));
    });

    test('signup and post-signup keep their required questions', () {
      expect(
        QuestionnaireHelper.getSignupQuestions().every((q) => q.isMandatory),
        isTrue,
      );
      final post = QuestionnaireHelper.getMandatoryQuestions();
      expect(post.where((q) => q.isMandatory).map((q) => q.fieldName), [
        'relationshipStatus',
        'hereFor',
        'height',
        'bodyType',
        'education',
      ]);
      expect(post.last.fieldName, 'relationshipGoal');
      expect(post.last.isMandatory, isFalse);
    });

    test('status has Married, "here for" is one pick, city can be located', () {
      Question q(String f) => QuestionnaireHelper.getQuestionByFieldName(f)!;
      final status = q('relationshipStatus');
      expect(status.options, contains('Married'));
      expect(status.optionEmojis.length, status.options.length);
      expect(status.optionQuips.length, status.options.length);
      expect(q('hereFor').inputType, QuestionType.singleChoice);
      expect(q('location').offersCurrentLocation, isTrue);
      expect(
        all.where((x) => x.offersCurrentLocation).map((x) => x.fieldName),
        ['location'],
      );
    });

    test('write cards are text questions', () {
      for (final q in all.where((q) => q.deckStyle == DeckStyle.write)) {
        expect(q.options, isEmpty, reason: q.fieldName);
        expect(q.maxLength, isNotNull, reason: q.fieldName);
      }
    });
  });

  group('decks', () {
    test('movies and series share one personality card', () {
      final cards = DeckSection.personality.cards;
      expect(cards.length, 9);
      expect(cards.last.questions.map((q) => q.fieldName),
          ['movieGenres', 'tvGenres']);
    });

    test('section completes at half its questions or with the flag', () {
      const s = DeckSection.lifestyle;
      expect(s.threshold, 5);
      final answers = <String, dynamic>{
        'foodPreference': 'Vegan',
        'drinkingHabits': 'Never',
        'smokingHabits': 'Never',
        'pets': <String>[],
        'tattoos': '  ',
      };
      expect(s.answeredCount(answers), 3);
      expect(s.isComplete(answers), isFalse);
      expect(s.isComplete({...answers, 'lifestyleCompleted': true}), isTrue);
      answers['exerciseFrequency'] = 'Daily';
      answers['wantsChildren'] = 'No';
      expect(s.isComplete(answers), isTrue);
    });

    test('clearing an answer deletes the field', () {
      expect(answerWriteValue(<String>[]), isA<FieldValue>());
      expect(answerWriteValue(''), isA<FieldValue>());
      expect(answerWriteValue('Vegan'), 'Vegan');
      expect(answerWriteValue(['Hindi']), ['Hindi']);
    });
  });

  group('vibe line', () {
    test('null until a key answer exists', () {
      expect(VibeLine.from({}), isNull);
      expect(VibeLine.from({'tattoos': 'No'}), isNull);
    });

    test('reads naturally with the right article', () {
      expect(
        VibeLine.from({
          'exerciseFrequency': '3-4 times/week',
          'foodPreference': 'Vegetarian',
          'personalityType': 'Ambivert',
          'partyingFrequency': 'Occasionally',
        }),
        'An active, veggie-loving ambivert who parties occasionally.',
      );
      expect(
        VibeLine.from(
            {'personalityType': 'Introvert', 'loveLanguage': 'Gifts'}),
        'An introvert, who feels loved through gifts.',
      );
      expect(
          VibeLine.from({'foodPreference': 'Vegan'}), 'A plant-powered soul.');
    });
  });
}
