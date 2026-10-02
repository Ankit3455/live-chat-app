import 'question_model.dart';
import 'question_category.dart';

/// Profile section for grouping questions
/// Converted from ProfileSection.kt
class ProfileSection {
  final String title;
  final String description;
  final List<Question> questions;
  final QuestionCategory category;
  final bool isMandatory;
  final String? icon;

  const ProfileSection({
    required this.title,
    this.description = '',
    required this.questions,
    required this.category,
    this.isMandatory = false,
    this.icon,
  });

  ProfileSection copyWith({
    String? title,
    String? description,
    List<Question>? questions,
    QuestionCategory? category,
    bool? isMandatory,
    String? icon,
  }) {
    return ProfileSection(
      title: title ?? this.title,
      description: description ?? this.description,
      questions: questions ?? this.questions,
      category: category ?? this.category,
      isMandatory: isMandatory ?? this.isMandatory,
      icon: icon ?? this.icon,
    );
  }

  @override
  String toString() {
    return 'ProfileSection(title: $title, questions: ${questions.length})';
  }
}