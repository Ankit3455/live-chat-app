// lib/feature/games/chat_games/random_match_screen.dart
//
// Games tab → a chat game: looks for anyone else searching for the same game
// (RandomMatchService) and opens the game room for both. Nobody within a
// minute: offer to try again or to invite a match from the chats.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../services/discovery_feed_service.dart';
import 'chat_game_registry.dart';
import 'random_match_service.dart';
import 'ui/game_ui.dart';
import 'ui/player_info.dart';

enum _Phase { searching, nobody, failed }

class RandomMatchScreen extends StatefulWidget {
  /// A game name from [ChatGames].
  final String game;

  /// Switches the app to the Chats tab.
  final VoidCallback? onOpenChats;

  const RandomMatchScreen({super.key, required this.game, this.onOpenChats});

  @override
  State<RandomMatchScreen> createState() => _RandomMatchScreenState();
}

class _RandomMatchScreenState extends State<RandomMatchScreen> with MyProfile {
  final RandomMatchService _service = RandomMatchService.instance;

  _Phase _phase = _Phase.searching;
  bool _closed = false;
  bool _matched = false;
  int _secondsLeft = RandomMatchService.searchTime.inSeconds;
  Timer? _countdown;

  ChatGameEntry get _entry =>
      ChatGames.byName(widget.game) ?? ChatGames.all.first;
  GameTheme get _theme => GameTheme.of(widget.game);

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    // Leaving while searching: drop the search now, not on the next loop
    // turn, so nobody gets matched with someone who already left.
    if (!_closed && _phase == _Phase.searching && !_matched) {
      _service.cancelSearch();
    }
    _closed = true;
    _countdown?.cancel();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _phase = _Phase.searching;
      _secondsLeft = RandomMatchService.searchTime.inSeconds;
    });
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _secondsLeft > 0) setState(() => _secondsLeft--);
    });
    final profile = me;
    RandomMatch? match;
    try {
      match = await _service.find(
        game: widget.game,
        displayName: profile?.username ?? '',
        avatar: avatarUrlOf(profile) ?? '',
        cancelled: () => _closed,
      );
    } catch (_) {
      _countdown?.cancel();
      if (mounted) setState(() => _phase = _Phase.failed);
      return;
    }
    _countdown?.cancel();
    if (!mounted) return;
    if (match == null) {
      setState(() => _phase = _Phase.nobody);
      return;
    }
    _matched = true;
    final other = await DiscoveryFeed.fetchProfile(
      match.otherUid,
      myUid: myUid,
    );
    if (!mounted) return;
    final name = (other?.username.trim().isNotEmpty ?? false)
        ? other!.username.trim()
        : 'your match';
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatGames.screen(
          widget.game,
          conversationId: match!.spaceId,
          otherUserId: match.otherUid,
          otherName: name,
          otherUser: other,
          startOnOpen: match.iMadeIt,
        ),
      ),
    );
  }

  void _openChats() {
    Navigator.of(context).pop();
    widget.onOpenChats?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: gameAppBar(context, title: _entry.title),
      body: GameBackdrop(
        theme: _theme,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: _content(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (_phase) {
      case _Phase.searching:
        Widget orb = GameOrb(theme: _theme);
        if (!calmMotion(context)) {
          orb = RepaintBoundary(
            child: RepaintBoundary(child: orb)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(end: 1.08, duration: 900.ms, curve: Curves.easeInOut),
          );
        }
        return Column(
          children: [
            orb,
            const SizedBox(height: 28),
            Semantics(
              liveRegion: true,
              child: Text(
                'Finding a player…',
                textAlign: TextAlign.center,
                style: GameText.display.copyWith(fontSize: 26),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Looking for someone who wants to play ${_entry.title} '
              'right now.',
              textAlign: TextAlign.center,
              style: GameText.body,
            ),
            const SizedBox(height: 14),
            Text(
              '${_secondsLeft}s',
              style: GameText.caption.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 28),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      case _Phase.nobody:
        return _message(
          emoji: '🌙',
          title: 'No one is online for this game',
          body: 'Try again in a bit, or invite one of your matches from '
              'your chats.',
          primary: ('Try again', Icons.refresh_rounded, _search),
          secondary: widget.onOpenChats == null
              ? null
              : ('Invite a match from chats', Icons.chat_rounded, _openChats),
        );
      case _Phase.failed:
        return _message(
          emoji: '📡',
          title: "Couldn't search right now",
          body: 'Check your connection and try again.',
          primary: ('Try again', Icons.refresh_rounded, _search),
        );
    }
  }

  Widget _message({
    required String emoji,
    required String title,
    required String body,
    required (String, IconData, VoidCallback) primary,
    (String, IconData, VoidCallback)? secondary,
  }) {
    final second = secondary;
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 64)),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GameText.display.copyWith(fontSize: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center, style: GameText.body),
        const SizedBox(height: 26),
        GameButton(
          label: primary.$1,
          icon: primary.$2,
          theme: _theme,
          onPressed: primary.$3,
        ),
        if (second != null) ...[
          const SizedBox(height: 12),
          GameButton(
            label: second.$1,
            icon: second.$2,
            theme: _theme,
            secondary: true,
            onPressed: second.$3,
          ),
        ],
      ],
    );
  }
}
