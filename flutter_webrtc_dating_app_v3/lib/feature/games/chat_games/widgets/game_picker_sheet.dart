// lib/feature/games/chat_games/widgets/game_picker_sheet.dart

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../chat_game_registry.dart';

/// Bottom sheet listing the chat games; returns the chosen game's name.
Future<String?> showGamePickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: AppColors.border),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: const Text(
                'Play a game',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final g in ChatGames.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.surfaceCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Text(
                      g.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    title: Text(
                      g.title,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      g.tagline,
                      style: const TextStyle(color: AppColors.lavender),
                    ),
                    onTap: () => Navigator.pop(context, g.name),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
