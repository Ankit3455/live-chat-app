import 'package:flutter/material.dart';
import 'package:availchat/models/question_model.dart';
import 'package:availchat/models/question_type.dart';

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

  @override
  void initState() {
    super.initState();
    _currentAnswer = widget.answer;
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
                if (widget.question.isMandatory) // ✅ FIXED
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
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
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
    switch (widget.question.inputType) { // ✅ FIXED
      case QuestionType.text:
        return TextField(
          controller: TextEditingController(text: _currentAnswer?.toString()),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter your answer',
          ),
          maxLines: widget.question.fieldName == 'bio' ? 5 : 1,
          onChanged: (value) {
            _currentAnswer = value;
            widget.onAnswerChanged(value);
          },
        );

      case QuestionType.singleChoice:
        return _buildSingleChoice();

      case QuestionType.multiChoice:
        return _buildMultiChoice();

      default:
        return const SizedBox();
    }
  }

  Widget _buildSingleChoice() {
    return Column(
      children: widget.question.options?.map((option) {
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
          }).toList() ??
          [],
    );
  }

  Widget _buildMultiChoice() {
    final selectedList = _currentAnswer is List<String>
        ? _currentAnswer as List<String>
        : <String>[];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.question.options?.map((option) {
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
          }).toList() ??
          [],
    );
  }
}