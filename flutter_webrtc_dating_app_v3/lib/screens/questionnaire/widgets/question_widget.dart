import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:availchat/models/question_model.dart';
import 'package:availchat/models/question_type.dart';
import 'package:availchat/core/constants/app_colors.dart';

class QuestionWidget extends StatefulWidget {
  final Question question;
  final dynamic answer;
  final Function(dynamic) onAnswerChanged;

  const QuestionWidget({
    super.key,
    required this.question,
    this.answer,
    required this.onAnswerChanged,
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.question.icon != null) ...[
                  Text(
                    widget.question.icon!,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    widget.question.text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.question.isMandatory)
                  const Text(
                    '*',
                    style: TextStyle(color: Colors.red, fontSize: 20),
                  ),
              ],
            ),
            if (widget.question.helperText != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.question.helperText!,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 16),
            _buildQuestionInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionInput() {
    switch (widget.question.inputType) {
      case QuestionType.text:
        final spec = _textSpec;
        return TextField(
          controller: _textController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter your answer',
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

  Widget _buildSingleChoice() {
    return Column(
      children: widget.question.options.map((option) {
        return RadioListTile<String>(
          title: Text(option),
          value: option,
          groupValue: _currentAnswer as String?,
          onChanged: (value) {
            setState(() {
              _currentAnswer = value;
              widget.onAnswerChanged(value);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildMultiChoice() {
    final selectedList = List<String>.from(_currentAnswer as List);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.question.options.map((option) {
        final isSelected = selectedList.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              final newList = List<String>.from(selectedList);
              if (selected) {
                newList.add(option);
              } else {
                newList.remove(option);
              }
              _currentAnswer = newList;
              widget.onAnswerChanged(newList);
            });
          },
        );
      }).toList(),
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
