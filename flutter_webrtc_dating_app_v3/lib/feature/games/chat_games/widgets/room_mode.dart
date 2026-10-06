// lib/feature/games/chat_games/widgets/room_mode.dart
//
// Random-match rooms (Games tab): the player who made the room starts the
// first game as soon as the screen opens, the other player joins it as soon
// as it appears, and the result offers a way to start chatting. In a chat
// none of this applies (the invite card does the asking).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../screens/chat/chat_screen.dart';
import '../game_space.dart';
import '../random_match_screen.dart';
import '../ui/game_ui.dart';

mixin RoomMode<T extends StatefulWidget> on State<T> {
  /// The screen's conversation id / room space id.
  String get spaceId;

  bool get inRoom => GameSpace.isRoom(spaceId);

  bool _roomStarted = false;
  bool _autoJoined = false;
  bool _setupDone = false;

  /// How long the first game may take to get both players in before the
  /// other player is treated as gone (e.g. they cancelled their search just
  /// as they were matched).
  static const Duration setupWait = Duration(seconds: 20);
  Timer? _setupTimer;
  bool _otherGone = false;

  /// The other player never joined the first game.
  bool get roomOtherGone => _otherGone;

  @override
  void dispose() {
    _setupTimer?.cancel();
    super.dispose();
  }

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
    if (!_setupDone && _setupTimer == null) {
      _setupTimer = Timer(setupWait, () {
        if (mounted && !_setupDone) setState(() => _otherGone = true);
      });
    }
    if (!hasGame && startOnOpen && !_roomStarted) {
      _roomStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) start();
      });
    }
    if (hasGame) _roomStarted = true;
    // First game under way: later games (rematches) ask like an invite.
    if (hasGame && bothJoined) {
      _setupDone = true;
      _setupTimer?.cancel();
    }
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

/// Shown in a room while the first game is set up, or, once [gameName] is
/// given with [otherGone], that the other player left before it started.
class RoomWaiting extends StatelessWidget {
  final GameTheme theme;
  final String otherName;
  final bool otherGone;

  /// Game name from ChatGames, for "Find another player".
  final String? gameName;

  const RoomWaiting({
    super.key,
    required this.theme,
    required this.otherName,
    this.otherGone = false,
    this.gameName,
  });

  @override
  Widget build(BuildContext context) {
    final game = gameName;
    if (otherGone && game != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👋', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  '$otherName left before the game started',
                  textAlign: TextAlign.center,
                  style: GameText.display.copyWith(fontSize: 22),
                ),
              ),
              const SizedBox(height: 24),
              GameButton(
                label: 'Find another player',
                icon: Icons.search_rounded,
                theme: theme,
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => RandomMatchScreen(game: game),
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
