import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../managers/profile_completion_manager.dart';
import '../../../models/question_model.dart';
import '../helpers/questionnaire_helper.dart';

bool isAnswered(Object? v) {
  if (v == null) return false;
  if (v is String) return v.trim().isNotEmpty;
  if (v is List) return v.isNotEmpty;
  return true;
}

/// Value to write for an answer; clearing deletes the field.
Object answerWriteValue(Object? v) => isAnswered(v) ? v! : FieldValue.delete();

/// One card in a deck: usually one question, or several sharing a deckGroup.
class DeckCard {
  final List<Question> questions;
  const DeckCard(this.questions);

  Question get lead => questions.first;

  bool isDone(Map<String, dynamic> answers) =>
      questions.any((q) => isAnswered(answers[q.fieldName]));

  static List<DeckCard> fromQuestions(List<Question> qs) {
    final cards = <DeckCard>[];
    for (final q in qs) {
      final group = q.deckGroup;
      if (group != null &&
          cards.isNotEmpty &&
          cards.last.lead.deckGroup == group) {
        cards.last.questions.add(q);
      } else {
        cards.add(DeckCard([q]));
      }
    }
    return cards;
  }
}

/// Lifestyle or Personality: its questions, cards and completion flag.
enum DeckSection {
  lifestyle,
  personality;

  String get title => this == lifestyle ? 'Lifestyle' : 'Personality';
  String get roman => this == lifestyle ? 'DECK I' : 'DECK II';
  String get emoji => this == lifestyle ? '🌿' : '✨';
  String get completedFlag =>
      this == lifestyle ? 'lifestyleCompleted' : 'personalityCompleted';
  DeckSection get other => this == lifestyle ? personality : lifestyle;

  List<Question> get questions => this == lifestyle
      ? QuestionnaireHelper.getLifestyleQuestions()
      : QuestionnaireHelper.getPersonalityQuestions();

  List<DeckCard> get cards => DeckCard.fromQuestions(questions);

  /// Same rule as before the redesign: half the questions answered.
  int get threshold => (questions.length * 0.5).ceil();

  int answeredCount(Map<String, dynamic> answers) =>
      questions.where((q) => isAnswered(answers[q.fieldName])).length;

  bool isComplete(Map<String, dynamic> answers) =>
      answers[completedFlag] == true || answeredCount(answers) >= threshold;

  Future<void> markComplete() => this == lifestyle
      ? ProfileCompletionManager().markLifestyleComplete()
      : ProfileCompletionManager().markPersonalityComplete();
}
