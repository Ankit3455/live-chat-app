// lib/feature/games/chat_games/widgets/room_mode.dart
//
// Random-match rooms (Games tab): the player who made the room starts the
// first game as soon as the screen opens, the other player joins it as soon
// as it appears, and the result offers a way to start chatting. In a chat
// none of this applies (the invite card does the asking).

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../screens/chat/chat_screen.dart';
import '../game_space.dart';
import '../ui/game_ui.dart';

mixin RoomMode<T extends StatefulWidget> on State<T> {
  /// The screen's conversation id / room space id.
  String get spaceId;

  bool get inRoom => GameSpace.isRoom(spaceId);

  bool _roomStarted = false;
  bool _autoJoined = false;
  bool _setupDone = false;

  /// Call from build once the game stream has its first value.
  /// [needsMyJoin]: the game is waiting for me. Only the first game is
  /// joined automatically; a rematch asks like a chat invite does.
  void roomStep({
    required bool hasGame,
    required bool bothJoined,
    required bool needsMyJoin,
    required bool startOnOpen,
    required Future<void> Function() start,
    required Future<void> Function() join,
  }) {
    if (!inRoom) return;
    if (!hasGame && startOnOpen && !_roomStarted) {
      _roomStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) start();
      });
    }
    if (hasGame) _roomStarted = true;
    // First game under way: later games (rematches) ask like an invite.
    if (hasGame && bothJoined) _setupDone = true;
    if (needsMyJoin && !_autoJoined && !_setupDone) {
      _autoJoined = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) join();
      });
    }
  }

  /// While the first game of a room is being set up or joined.
  bool get roomSettingUp => inRoom && !_setupDone;
}

/// Shown in a room while the first game is set up.
class RoomWaiting extends StatelessWidget {
  final GameTheme theme;
  final String otherName;

  const RoomWaiting({super.key, required this.theme, required this.otherName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.a),
            const SizedBox(height: 20),
            Text(
              'Matched with $otherName!',
              textAlign: TextAlign.center,
              style: GameText.display.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 8),
            const Text(
              'Getting your game ready…',
              textAlign: TextAlign.center,
              style: GameText.body,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text(
                'Leave',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Say hi to X" on a room's result: opens the chat, which is created by
/// the first message.
class SayHiButton extends StatelessWidget {
  final GameTheme theme;
  final String otherUserId;
  final String otherName;
  final bool secondary;

  const SayHiButton({
    super.key,
    required this.theme,
    required this.otherUserId,
    required this.otherName,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return enterFx(
      context,
      GameButton(
        label: 'Say hi to $otherName',
        icon: Icons.chat_bubble_rounded,
        theme: theme,
        secondary: secondary,
        onPressed: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChatScreen(otherUserId: otherUserId),
          ),
        ),
      ),
      delay: 600.ms,
    );
  }
}
