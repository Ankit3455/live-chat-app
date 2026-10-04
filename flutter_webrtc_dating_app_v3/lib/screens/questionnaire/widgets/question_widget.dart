import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:availchat/models/question_model.dart';
import 'package:availchat/models/question_type.dart';
import 'package:availchat/models/question_category.dart';
import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/core/utils/haptics.dart';

class QuestionWidget extends StatefulWidget {
  final Question question;
  final dynamic answer;
  final Function(dynamic) onAnswerChanged;

  /// Compact header (no eyebrow, smaller title) for lists of questions.
  final bool dense;

  const QuestionWidget({
    super.key,
    required this.question,
    this.answer,
    required this.onAnswerChanged,
    this.dense = false,
  });

  @override
  State<QuestionWidget> createState() => _QuestionWidgetState();
}

class _QuestionWidgetState extends State<QuestionWidget> {
  late dynamic _currentAnswer;
  TextEditingController? _textController;

  @override
  void initState() {
    super.initState();
    _currentAnswer = _normalize(widget.answer);
    if (widget.question.inputType == QuestionType.text) {
      _textController = TextEditingController(text: _currentAnswer as String);
    }
  }

  @override
  void didUpdateWidget(covariant QuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _normalize(widget.answer);
    if (_sameAnswer(next, _currentAnswer)) return;
    // Answer changed from outside (e.g. loaded from Firestore after build).
    _currentAnswer = next;
    final controller = _textController;
    if (controller != null && controller.text != next) {
      controller.value = TextEditingValue(
        text: next as String,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    _textController?.dispose();
    super.dispose();
  }

  /// Firestore returns lists as List<dynamic>; legacy docs may hold a single
  /// String for fields that are now multi-choice.
  dynamic _normalize(dynamic raw) {
    switch (widget.question.inputType) {
      case QuestionType.text:
        return raw?.toString() ?? '';
      case QuestionType.singleChoice:
        if (raw is List) return raw.isEmpty ? null : raw.first?.toString();
        return raw?.toString();
      case QuestionType.multiChoice:
        if (raw is List) {
          return List<String>.from(
            raw.where((e) => e != null).map((e) => e.toString()),
          );
        }
        if (raw is String && raw.trim().isNotEmpty) return <String>[raw];
        return <String>[];
    }
  }

  bool _sameAnswer(dynamic a, dynamic b) {
    if (a is List && b is List) return listEquals(a, b);
    return a == b;
  }

  _TextSpec get _textSpec {
    switch (widget.question.fieldName) {
      case 'username':
        return const _TextSpec(maxLength: 30, keyboardType: TextInputType.name);
      case 'location':
        return const _TextSpec(
          maxLength: 100,
          keyboardType: TextInputType.streetAddress,
          capitalization: TextCapitalization.words,
        );
      case 'bio':
        return const _TextSpec(
          maxLength: 500,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          capitalization: TextCapitalization.sentences,
        );
      case 'relationshipGoal':
        return const _TextSpec(
          maxLength: 200,
          maxLines: 3,
          keyboardType: TextInputType.multiline,
          capitalization: TextCapitalization.sentences,
        );
      default:
        return const _TextSpec(
          maxLength: 200,
          capitalization: TextCapitalization.sentences,
        );
    }
  }

  static const Map<QuestionCategory, String> _eyebrows = {
    QuestionCategory.basic: 'About you',
    QuestionCategory.physical: 'Looks',
    QuestionCategory.lifestyle: 'Lifestyle',
    QuestionCategory.preferences: 'Preferences',
    QuestionCategory.personality: 'Personality',
    QuestionCategory.entertainment: 'Interests',
    QuestionCategory.relationship: 'Relationships',
  };

  // Display-only emoji for known options; unknown options fall back to the
  // question icon.
  static const Map<String, String> _optionEmoji = {
    'Male': '👨',
    'Female': '👩',
    'Other': '✨',
    'Early Riser': '🌅',
    'Night Owl': '🦉',
    'Balanced': '⚖️',
    'Student': '🎒',
    'Engineer': '🛠️',
    'Doctor': '🩺',
    'Artist': '🎨',
    'Astrology Consultant': '🔮',
    'Low': '🌱',
    'Moderate': '🔥',
    'High': '💥',
    'Single': '🙋',
    'In a relationship': '💞',
    'Divorced': '🕊️',
    'Widowed': '🤍',
    'Complicated': '🌀',
    'Dating': '🌹',
    'Long-term relationship': '💍',
    'Friendship': '🤝',
    'Open for everything': '🌈',
    'Casual dating': '☕',
    'Slim': '🧍',
    'Athletic': '🏃',
    'Average': '🙂',
    'Curvy': '💃',
    'Heavyset': '🐻',
    'High School': '🏫',
    "Bachelor's": '🎓',
    "Master's": '📜',
    'PhD': '🧪',
    'Diploma': '📘',
    'Self-taught': '💡',
    'Reading': '📚',
    'Music': '🎵',
    'Art': '🎨',
    'Sports': '⚽',
    'Tech': '💻',
    'Astrology': '🌙',
    'Romance': '💘',
    'Deep Conversations': '💬',
    'Stargazing': '🔭',
    'Mysticism': '🔮',
    'Travel': '✈️',
    'Cooking': '🍳',
    'Dancing': '💃',
    'Photography': '📷',
    'Gaming': '🎮',
    'Yoga': '🧘',
    'Meditation': '🕯️',
  };

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final textTheme = Theme.of(context).textTheme;
    final helper = question.helperText;
    final eyebrow = _eyebrows[question.category];

    return Padding(
      padding: EdgeInsets.only(top: widget.dense ? 0 : 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.dense && eyebrow != null) ...[
            Text(
              eyebrow.toUpperCase(),
              style: const TextStyle(
                color: AppColors.pinkLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Semantics(
            header: !widget.dense,
            child: Text.rich(
              TextSpan(
                text: question.text,
                children: [
                  if (question.isMandatory && widget.dense)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: AppColors.pinkLight),
                    ),
                ],
              ),
              style: widget.dense
                  ? textTheme.titleLarge
                  : textTheme.headlineMedium,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 8),
            Text(
              helper,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          SizedBox(height: widget.dense ? 16 : 24),
          _buildQuestionInput(),
        ],
      ),
    );
  }

  Widget _buildQuestionInput() {
    switch (widget.question.inputType) {
      case QuestionType.text:
        final spec = _textSpec;
        return TextField(
          controller: _textController,
          style: const TextStyle(color: AppColors.white, fontSize: 15),
          decoration: const InputDecoration(
            hintText: 'Type your answer',
            counterStyle: TextStyle(color: AppColors.textSubtle, fontSize: 12),
          ),
          keyboardType: spec.keyboardType,
          textCapitalization: spec.capitalization,
          textInputAction: spec.maxLines > 1
              ? TextInputAction.newline
              : TextInputAction.done,
          maxLines: spec.maxLines,
          maxLength: spec.maxLength,
          onChanged: (value) {
            _currentAnswer = value;
            widget.onAnswerChanged(value);
          },
        );

      case QuestionType.singleChoice:
        return _buildSingleChoice();

      case QuestionType.multiChoice:
        return _buildMultiChoice();
    }
  }

  String? _emojiFor(String option) =>
      _optionEmoji[option] ?? widget.question.icon;

  Widget _buildSingleChoice() {
    final selected = _currentAnswer as String?;
    return Column(
      children: [
        for (final option in widget.question.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OptionRow(
              label: option,
              emoji: _emojiFor(option),
              selected: option == selected,
              onTap: () {
                Haptics.selection();
                setState(() => _currentAnswer = option);
                widget.onAnswerChanged(option);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMultiChoice() {
    final selectedList = List<String>.from(_currentAnswer as List);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final option in widget.question.options)
              _SelectChip(
                label: option,
                emoji: _optionEmoji[option],
                selected: selectedList.contains(option),
                onTap: () {
                  Haptics.selection();
                  final newList = List<String>.from(selectedList);
                  if (!newList.remove(option)) newList.add(option);
                  setState(() => _currentAnswer = newList);
                  widget.onAnswerChanged(newList);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            '${selectedList.length} selected',
            style: const TextStyle(color: AppColors.textSubtle, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// Full-width single-choice row: emoji tile, label, radio circle.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = emoji;
    final radius = BorderRadius.circular(14);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      // Colour and border ease in on selection.
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandPurpleMid.withOpacity(0.12)
              : AppColors.surfaceCard,
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppColors.brandPurpleMid : AppColors.border,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    if (e != null) ...[
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedContainer(
                      duration: duration,
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? AppColors.brandPurple : null,
                        border: Border.all(
                          color: selected
                              ? AppColors.brandPurpleMid
                              : AppColors.borderStrong,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: AppColors.white,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 40px selectable chip with a 48dp tap target.
class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = emoji;
    return FilterChip(
      label: Text(label),
      avatar: e != null ? Text(e, style: const TextStyle(fontSize: 14)) : null,
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: const StadiumBorder(),
      side: BorderSide(
        color: selected ? AppColors.brandPurpleMid : AppColors.border,
      ),
      backgroundColor: AppColors.surfaceCard,
      selectedColor: AppColors.brandPurpleMid.withOpacity(0.18),
      labelStyle: TextStyle(
        color: selected ? AppColors.brandPurpleLight : AppColors.white,
        fontSize: 14,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

class _TextSpec {
  final int maxLength;
  final int maxLines;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;

  const _TextSpec({
    required this.maxLength,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
  });
}
