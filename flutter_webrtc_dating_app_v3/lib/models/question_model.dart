import 'question_type.dart';
import 'question_category.dart';

/// Question model for questionnaire
/// Converted from Question.kt
class Question {
  final String text;
  final List<String> options;
  final QuestionType inputType;
  final String fieldName;
  final bool isMandatory;
  final QuestionCategory category;
  final String? icon;
  final String? helperText;

  const Question({
    required this.text,
    this.options = const [],
    required this.inputType,
    this.fieldName = '',
    this.isMandatory = true,
    this.category = QuestionCategory.basic,
    this.icon,
    this.helperText,
  });

  Question copyWith({
    String? text,
    List<String>? options,
    QuestionType? inputType,
    String? fieldName,
    bool? isMandatory,
    QuestionCategory? category,
    String? icon,
    String? helperText,
  }) {
    return Question(
      text: text ?? this.text,
      options: options ?? this.options,
      inputType: inputType ?? this.inputType,
      fieldName: fieldName ?? this.fieldName,
      isMandatory: isMandatory ?? this.isMandatory,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      helperText: helperText ?? this.helperText,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'options': options,
      'inputType': inputType.name,
      'fieldName': fieldName,
      'isMandatory': isMandatory,
      'category': category.name,
      'icon': icon,
      'helperText': helperText,
    };
  }

  @override
  String toString() {
    return 'Question(text: $text, fieldName: $fieldName, type: ${inputType.name})';
  }
}