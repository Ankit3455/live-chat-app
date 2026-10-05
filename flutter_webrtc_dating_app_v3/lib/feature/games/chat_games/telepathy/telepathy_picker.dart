// lib/feature/games/chat_games/telepathy/telepathy_picker.dart

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../ui/game_ui.dart';
import '../widgets/choice_button.dart';
import 'telepathy_prompts.dart';

/// 3x3 emoji grid: tap 3, then lock them in. Shows [locked] once sent.
class TelepathyPicker extends StatefulWidget {
  final List<String> choices;
  final List<String>? locked;
  final bool enabled;
  final GameTheme theme;
  final ValueChanged<List<String>> onSubmit;

  const TelepathyPicker({
    super.key,
    required this.choices,
    required this.locked,
    required this.enabled,
    required this.theme,
    required this.onSubmit,
  });

  @override
  State<TelepathyPicker> createState() => _TelepathyPickerState();
}

class _TelepathyPickerState extends State<TelepathyPicker> {
  final List<String> _selected = [];

  @override
  void didUpdateWidget(covariant TelepathyPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New round: start fresh.
    if (oldWidget.choices.join() != widget.choices.join()) _selected.clear();
  }

  void _toggle(String emoji) {
    setState(() {
      if (_selected.contains(emoji)) {
        _selected.remove(emoji);
      } else if (_selected.length < TelepathyPrompts.picksPerRound) {
        _selected.add(emoji);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.locked;
    final shown = locked ?? _selected;
    final canTap = locked == null && widget.enabled;
    final full = _selected.length == TelepathyPrompts.picksPerRound;

    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (final e in widget.choices)
              ChoiceButton(
                label: e,
                semanticLabel: e,
                fontSize: 34,
                accent: widget.theme.a,
                selected: shown.contains(e),
                dimmed: (locked != null || full) && !shown.contains(e),
                onTap: canTap ? () => _toggle(e) : null,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (locked == null)
          GameButton(
            label: full
                ? 'Lock in'
                : 'Pick ${TelepathyPrompts.picksPerRound - _selected.length} more',
            icon: Icons.psychology_alt_rounded,
            theme: widget.theme,
            onPressed: full && widget.enabled
                ? () => widget.onSubmit(List.of(_selected))
                : null,
          )
        else
          Text(
            'Locked in: ${locked.join(' ')}',
            style: const TextStyle(color: AppColors.lavender, fontSize: 14),
          ),
      ],
    );
  }
}
