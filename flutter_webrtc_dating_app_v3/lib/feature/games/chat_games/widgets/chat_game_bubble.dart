// lib/feature/games/chat_games/widgets/chat_game_bubble.dart

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../models/chat_message_model.dart';
import '../build_our_date/date_cards.dart';
import '../build_our_date/widgets/date_card_tile.dart';
import '../chat_game.dart';
import '../chat_game_logic.dart';
import '../chat_game_registry.dart';

/// Chat bubble for MessageType.game: a game invite or a result card.
class ChatGameBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String otherUserName;

  /// Receives the game name (see [ChatGames]).
  final ValueChanged<String>? onOpen;

  const ChatGameBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.otherUserName,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? const <String, dynamic>{};
    final entry = ChatGames.byName(meta['game']);
    final kind = ChatGameKind.byName(meta['game']);
    final isResult = meta['stage'] == ChatGameLogic.resultStage;
    final open = onOpen;
    final gameName = entry?.name;
    final myUid = isMe ? message.senderId : message.receiverId;

    final String title;
    final String body;
    if (entry == null) {
      title = '🎮 Game';
      body = message.message;
    } else if (isResult) {
      title = '${entry.emoji} ${entry.title}';
      final line = ChatGames.resultLine(
        entry.name,
        meta,
        viewer: myUid,
        otherName: otherUserName,
      );
      body = line.isEmpty ? message.message : line;
    } else {
      title = '${entry.emoji} ${entry.title}';
      body = isMe
          ? 'You invited $otherUserName to play.'
          : '$otherUserName wants to play with you.';
    }

    final cards = kind == ChatGameKind.date && isResult
        ? [
            for (final id in (meta['cards'] as List?) ?? const [])
              if (id is String && DateCards.byId(id) != null)
                DateCards.byId(id)!,
          ]
        : const <DateCard>[];

    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandPurple.withOpacity(0.55),
            AppColors.brandPink.withOpacity(0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandPink.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (cards.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final c in cards) DateCardChip(card: c)],
            ),
          ],
          if (gameName != null && open != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => open(gameName),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.brandPurple,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Text(
                  isResult ? 'Open' : 'Play',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
