// lib/feature/games/chat_games/build_our_date/widgets/date_card_tile.dart

import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';

/// Small "emoji label" chip for a matched date answer, on the result screen
/// and in the chat bubble.
class DateCardChip extends StatelessWidget {
  final String text;

  const DateCardChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.white, fontSize: 13),
      ),
    );
  }
}
