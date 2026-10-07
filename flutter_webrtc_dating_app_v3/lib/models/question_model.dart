import 'question_type.dart';
import 'question_category.dart';

/// How a profile-completion card asks the question.
enum DeckStyle {
  /// Pick one from a fanned hand of option cards.
  fan,

  /// Ordered options on a slider (options listed low to high).
  scale,

  /// Chips; multi-select unless the question is singleChoice.
  stickers,
}

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

  // Profile-completion deck presentation; unused by other flows.
  final DeckStyle deckStyle;

  /// Parallel to [options].
  final List<String> optionEmojis;

  /// Parallel to [options]; shown when the card flips.
  final List<String> optionQuips;

  final int? maxSelections;

  /// Picking one of these clears the rest, and vice versa.
  final List<String> exclusiveOptions;

  /// Questions sharing a group are asked on one card.
  final String? deckGroup;

  /// Row label inside a grouped card.
  final String? deckLabel;

  const Question({
    required this.text,
    this.options = const [],
    required this.inputType,
    this.fieldName = '',
    this.isMandatory = true,
    this.category = QuestionCategory.basic,
    this.icon,
    this.helperText,
    this.deckStyle = DeckStyle.fan,
    this.optionEmojis = const [],
    this.optionQuips = const [],
    this.maxSelections,
    this.exclusiveOptions = const [],
    this.deckGroup,
    this.deckLabel,
  });

  String? emojiFor(String option) {
    final i = options.indexOf(option);
    return i >= 0 && i < optionEmojis.length ? optionEmojis[i] : null;
  }

  String? quipFor(String option) {
    final i = options.indexOf(option);
    return i >= 0 && i < optionQuips.length ? optionQuips[i] : null;
  }

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
      deckStyle: deckStyle,
      optionEmojis: optionEmojis,
      optionQuips: optionQuips,
      maxSelections: maxSelections,
      exclusiveOptions: exclusiveOptions,
      deckGroup: deckGroup,
      deckLabel: deckLabel,
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