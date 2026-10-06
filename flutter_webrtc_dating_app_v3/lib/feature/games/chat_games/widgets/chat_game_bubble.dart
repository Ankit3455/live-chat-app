// lib/feature/games/chat_games/widgets/chat_game_bubble.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../models/chat_message_model.dart';
import '../build_our_date/date_cards.dart';
import '../build_our_date/widgets/date_card_tile.dart';
import '../chat_game.dart';
import '../chat_game_invites.dart';
import '../chat_game_logic.dart';
import '../chat_game_registry.dart';

/// What the chat screen lets a game card do. Each callback receives the game
/// name (see [ChatGames]).
class GameCardActions {
  /// Live state of the chat's games (see [GameRoomsWatcher]).
  final ValueListenable<Map<String, GameRoomState?>> rooms;
  final ValueChanged<String> open;
  final Future<void> Function(String name) accept;

  /// Decline (receiver) or cancel (sender) a pending invite.
  final Future<void> Function(String name) close;

  const GameCardActions({
    required this.rooms,
    required this.open,
    required this.accept,
    required this.close,
  });
}

/// Chat bubble for MessageType.game: a game invite or a result card.
class ChatGameBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String otherUserName;

  /// Null when the user can't play in this chat (e.g. blocked).
  final GameCardActions? actions;

  const ChatGameBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.otherUserName,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? const <String, dynamic>{};
    final entry = ChatGames.byName(meta['game']);
    final kind = ChatGameKind.byName(meta['game']);
    final isResult = meta['stage'] == ChatGameLogic.resultStage;
    final gameId = meta['gameId'];
    final actions = this.actions;
    final myUid = isMe ? message.senderId : message.receiverId;

    if (entry == null) {
      return _GameCard(title: '🎮 Game', body: message.message);
    }
    final title = '${entry.emoji} ${entry.title}';

    if (isResult) {
      final line = ChatGames.resultLine(
        entry.name,
        meta,
        viewer: myUid,
        otherName: otherUserName,
      );
      final chips = kind == ChatGameKind.date
          ? [
              ...ChatGameLogic.resultAnswers(
                meta,
                viewer: myUid,
                otherName: otherUserName,
              ),
              // Old 5-card date plans.
              for (final id in (meta['cards'] as List?) ?? const [])
                if (id is String && DateCards.byId(id) != null)
                  '${DateCards.byId(id)!.emoji} ${DateCards.byId(id)!.label}',
            ]
          : const <String>[];
      return _GameCard(
        title: title,
        body: line.isEmpty ? message.message : line,
        chips: chips,
        buttons: [
          if (actions != null)
            _CardButton('Open', onTap: () async => actions.open(entry.name)),
        ],
      );
    }

    final invited = isMe
        ? 'You invited $otherUserName to play.'
        : '$otherUserName wants to play with you.';

    // Invites sent before invites carried a game id: open the game room.
    if (gameId is! String || actions == null) {
      return _GameCard(
        title: title,
        body: invited,
        buttons: [
          if (actions != null)
            _CardButton('Play', onTap: () async => actions.open(entry.name)),
        ],
      );
    }

    return ValueListenableBuilder<Map<String, GameRoomState?>>(
      valueListenable: actions.rooms,
      builder: (context, rooms, _) {
        if (!rooms.containsKey(entry.name)) {
          return _GameCard(title: title, body: invited);
        }
        final room = rooms[entry.name];
        if (room == null || room.gameId != gameId) {
          return _GameCard(title: title, body: 'This invite has expired.');
        }
        if (room.isPending) {
          if (isMe) {
            return _GameCard(
              title: title,
              body: 'Waiting for $otherUserName to accept…',
              buttons: [
                _CardButton(
                  'Cancel invite',
                  secondary: true,
                  onTap: () => actions.close(entry.name),
                ),
              ],
            );
          }
          return _GameCard(
            title: title,
            body: invited,
            buttons: [
              _CardButton(
                'Decline',
                secondary: true,
                onTap: () => actions.close(entry.name),
              ),
              _CardButton('Accept', onTap: () => actions.accept(entry.name)),
            ],
          );
        }
        if (room.isOpen) {
          return _GameCard(
            title: title,
            body: "Game on! You're both in.",
            buttons: [
              _CardButton(
                'Open game',
                onTap: () async => actions.open(entry.name),
              ),
            ],
          );
        }
        final leftBy = room.leftBy;
        if (leftBy != null) {
          return _GameCard(
            title: title,
            body: leftBy == myUid
                ? 'You left the game.'
                : '$otherUserName left the game.',
          );
        }
        if (room.bothJoined) {
          return _GameCard(title: title, body: 'This game has ended.');
        }
        return _GameCard(title: title, body: _closedLine(room, myUid));
      },
    );
  }

  String _closedLine(GameRoomState room, String myUid) {
    final by = room.closedBy;
    if (by == null) return 'This invite was closed.';
    final senderClosed = by == message.senderId;
    if (by == myUid) {
      return senderClosed ? 'You cancelled this invite.' : 'You declined.';
    }
    return senderClosed
        ? '$otherUserName cancelled the invite.'
        : '$otherUserName declined.';
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String body;
  final List<String> chips;
  final List<_CardButton> buttons;

  const _GameCard({
    required this.title,
    required this.body,
    this.chips = const [],
    this.buttons = const [],
  });

  @override
  Widget build(BuildContext context) {
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
          Semantics(
            liveRegion: true,
            child: Text(
              body,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final c in chips) DateCardChip(text: c)],
            ),
          ],
          if (buttons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: buttons[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// White pill button (or an outlined one when [secondary]); disabled while
/// [onTap] runs.
class _CardButton extends StatefulWidget {
  final String label;
  final bool secondary;
  final Future<void> Function() onTap;

  const _CardButton(this.label, {required this.onTap, this.secondary = false});

  @override
  State<_CardButton> createState() => _CardButtonState();
}

class _CardButtonState extends State<_CardButton> {
  bool _busy = false;

  Future<void> _tap() async {
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
    );
    final label = _busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.secondary ? AppColors.white : AppColors.brandPurple,
            ),
          )
        : Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          );
    if (widget.secondary) {
      return OutlinedButton(
        onPressed: _busy ? null : _tap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.white,
          side: BorderSide(color: AppColors.white.withOpacity(0.7)),
          minimumSize: const Size.fromHeight(44),
          shape: shape,
        ),
        child: label,
      );
    }
    return ElevatedButton(
      onPressed: _busy ? null : _tap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.brandPurple,
        minimumSize: const Size.fromHeight(44),
        shape: shape,
      ),
      child: label,
    );
  }
}
