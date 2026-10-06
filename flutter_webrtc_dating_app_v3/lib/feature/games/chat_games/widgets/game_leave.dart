// lib/feature/games/chat_games/widgets/game_leave.dart
//
// Leaving a game the other player is still in: back asks first, then ends
// the game for both with leftBy = me, so the other player sees that I left
// instead of waiting on the clock. Closing the screen any other way writes
// the same thing without asking. Pausing the app writes nothing; a player
// who is away too long is claimed as left by the other (TurnClockTicker).

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../random_match_screen.dart';
import '../ui/game_motion.dart';
import '../ui/game_ui.dart';
import 'room_mode.dart';

mixin GameLeave<T extends StatefulWidget> on State<T> {
  bool _endsGame = false;
  bool _ask = false;
  bool _leaveSent = false;
  Future<void> Function()? _leave;

  /// Call from build. [endsGame]: closing the screen now would leave a game
  /// the other player is in; [ask]: confirm first (the game is under way).
  /// [leave] writes the leave (cancel or resign with leftBy = me).
  void updateLeave({
    required bool endsGame,
    required bool ask,
    required Future<void> Function() leave,
  }) {
    if (!endsGame) _leaveSent = false;
    _endsGame = endsGame;
    _ask = endsGame && ask;
    _leave = leave;
  }

  /// Wraps the screen: back asks before leaving a running game.
  Widget leaveScope({
    required String otherName,
    required String leaveMessage,
    required Widget child,
  }) {
    return PopScope(
      canPop: !_ask,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(otherName, leaveMessage);
      },
      child: child,
    );
  }

  Future<void> _confirmLeave(String otherName, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text(
          'Leave game?',
          style: TextStyle(color: AppColors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.lavender),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Leave',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await leaveAndPop();
  }

  /// Writes the leave (if a game would be left) and closes the screen.
  Future<void> leaveAndPop() async {
    await _sendLeave();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _sendLeave() async {
    final leave = _leave;
    if (!_endsGame || _leaveSent || leave == null) return;
    _leaveSent = true;
    try {
      await leave();
    } catch (_) {
      // dispose tries once more; after that the other player's stale clock
      // claim ends the game.
      _leaveSent = false;
    }
  }

  @override
  void dispose() {
    final leave = _leave;
    if (_endsGame && !_leaveSent && leave != null) {
      _leaveSent = true;
      unawaited(leave().catchError((Object _) {}));
    }
    super.dispose();
  }
}

/// Shown to the player who stayed: "[otherName] left the game".
/// [competitive] games are a win; co-op round games just end.
class LeftPanel extends StatelessWidget {
  final GameTheme theme;
  final String otherName;
  final String otherUserId;
  final bool competitive;

  /// Random-match room: offer a chat and a new player instead of a rematch.
  final bool inRoom;

  /// Game name from ChatGames, for "Find another player".
  final String gameName;
  final bool busy;
  final VoidCallback onPlayAgain;

  const LeftPanel({
    super.key,
    required this.theme,
    required this.otherName,
    required this.otherUserId,
    required this.competitive,
    required this.inRoom,
    required this.gameName,
    required this.busy,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          children: [
            ResultHero(
              theme: theme,
              emoji: competitive ? '🏆' : '👋',
              title: '$otherName left the game',
              subtitle: competitive ? 'You win!' : 'Game ended',
              celebrate: competitive,
            ),
            const SizedBox(height: 24),
            if (inRoom) ...[
              SayHiButton(
                theme: theme,
                otherUserId: otherUserId,
                otherName: otherName,
              ),
              const SizedBox(height: 12),
              GameButton(
                label: 'Find another player',
                icon: Icons.search_rounded,
                theme: theme,
                secondary: true,
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => RandomMatchScreen(game: gameName),
                  ),
                ),
              ),
            ] else
              GameButton(
                label: 'Play again',
                icon: Icons.refresh_rounded,
                theme: theme,
                loading: busy,
                onPressed: busy ? null : onPlayAgain,
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text(
                'Back',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
