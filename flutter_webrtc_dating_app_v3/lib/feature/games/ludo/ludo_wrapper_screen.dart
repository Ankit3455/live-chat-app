import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ludo_lobby_screen.dart';
import 'ludo_multiplayer_provider.dart';
import 'widgets/board_widget.dart';
import 'widgets/dice_widget.dart';
import 'widgets/game_chat_widget.dart';
import 'constants.dart';
import 'services/ludo_game_service.dart';
import '../../../core/constants/app_colors.dart';

class LudoWrapperScreen extends StatefulWidget {
  final String matchId;
  const LudoWrapperScreen({Key? key, required this.matchId}) : super(key: key);

  @override
  State<LudoWrapperScreen> createState() => _LudoWrapperScreenState();
}

class _LudoWrapperScreenState extends State<LudoWrapperScreen> with WidgetsBindingObserver {
  late LudoMultiplayerProvider _provider;
  final _gameService = LudoGameService();
  bool _hasLeft = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = LudoMultiplayerProvider(matchId: widget.matchId);
    _provider.start();
    // Opening the match (e.g. "Resume match" from the lobby) clears 'away'.
    _handlePlayerReconnect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.dispose();
    super.dispose();
  }

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GameChatWidget(
        matchId: widget.matchId,
        localColor: _provider.localColor ?? 'green',
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _handlePlayerAway();
    }

    if (state == AppLifecycleState.resumed) {
      _handlePlayerReconnect();
    }
  }

  /// Backgrounding is not leaving: start the away grace period instead.
  Future<void> _handlePlayerAway() async {
    if (_hasLeft) return;
    if (_provider.gameState == LudoGameState.finish) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _gameService.playerAway(matchId: widget.matchId, odId: uid);
  }

  Future<void> _handlePlayerReconnect() async {
    if (_hasLeft) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _gameService.playerReconnect(matchId: widget.matchId, odId: uid);
  }

  Future<void> _handlePlayerLeave() async {
    _hasLeft = true;
    _provider.stopActions();
    if (_provider.gameState == LudoGameState.finish) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _gameService.playerLeft(matchId: widget.matchId, odId: uid);
    debugPrint('📤 Player left');
  }

  Future<bool> _onWillPop() async {
    if (_provider.gameState == LudoGameState.finish || _provider.matchMissing) {
      _hasLeft = true;
      _provider.stopActions();
      return true;
    }

    final multiPlayer = _provider.maxPlayers > 2;
    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '🚪 Leave Game?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          multiPlayer
              ? 'If you leave, you are out of this match and cannot rejoin. The other players keep playing.'
              : 'If you leave, you forfeit this match and your opponent wins.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay', style: TextStyle(color: Colors.green)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      await _handlePlayerLeave();
      return true;
    }

    return false;
  }

  void _backToLobby() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LudoLobbyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: ChangeNotifierProvider<LudoMultiplayerProvider>.value(
        value: _provider,
        child: Scaffold(
          backgroundColor: AppColors.backgroundDeep,
          body: SafeArea(
            child: Consumer<LudoMultiplayerProvider>(
              builder: (context, provider, _) {
                if (provider.matchMissing) {
                  return _buildMatchMissingView();
                }

                if (!provider.ready) {
                  return _buildLoadingView('Connecting to game...');
                }

                if (!provider.isGameReady) {
                  return _buildWaitingForOpponent();
                }

                return Stack(
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 8),
                        _buildHeader(context, provider),
                        const SizedBox(height: 8),
                        _buildTurnIndicator(provider),
                        if (provider.gameState != LudoGameState.finish)
                          _buildAwayBanner(provider),
                        const SizedBox(height: 8),
                        const Expanded(
                          child: Center(child: BoardWidget()),
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(
                          width: 70,
                          height: 70,
                          child: DiceWidget(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                    if (provider.gameState == LudoGameState.finish)
                      _buildGameOverOverlay(provider),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildWaitingForOpponent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_top, size: 60, color: Colors.blue),
          ),
          const SizedBox(height: 24),
          const Text(
            'Waiting for opponent...',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Match ID: ${widget.matchId.substring(0, 8)}...',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) _backToLobby();
              }
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Lobby'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchMissingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            'This match is no longer available.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              _hasLeft = true;
              _backToLobby();
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Lobby'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown while an opponent is away; the game keeps going underneath.
  Widget _buildAwayBanner(LudoMultiplayerProvider provider) {
    return ValueListenableBuilder<int>(
      valueListenable: provider.secondTick,
      builder: (context, _, __) {
        final away = provider.awayOpponents;
        if (away.isEmpty) return const SizedBox.shrink();
        final twoPlayer = provider.maxPlayers <= 2;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.6)),
          ),
          child: Column(
            children: away.map((p) {
              final String text;
              if (p.skipped) {
                text = '${p.name} is away. Their turns are skipped until they return.';
              } else if (twoPlayer) {
                text = '${p.name} is away. You win if they do not return in ${p.secondsLeft}s.';
              } else {
                text = '${p.name} is away. Their turns are skipped in ${p.secondsLeft}s.';
              }
              return Row(
                children: [
                  const Icon(Icons.person_off, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ✅ FIXED: Chat button is now INSIDE this method
  Widget _buildHeader(BuildContext context, LudoMultiplayerProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'Leave game',
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () async {
                if (await _onWillPop()) {
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ),
          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎲 Ludo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Playing as ${provider.localColor?.toUpperCase() ?? "..."}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),

          // Chat button ✅ HERE!
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'Open game chat',
              icon: const Icon(Icons.chat, color: Colors.blue),
              onPressed: _openChat,
            ),
          ),

          const SizedBox(width: 8),

          // Players count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${provider.activePlayers}/${provider.maxPlayers}',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnIndicator(LudoMultiplayerProvider provider) {
    final isMyTurn = provider.isLocalPlayerTurn;
    final turnColor = provider.currentPlayer.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [turnColor.withOpacity(0.3), turnColor.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: turnColor, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: turnColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMyTurn ? Icons.videogame_asset : Icons.hourglass_top,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMyTurn ? '🎯 Your Turn!' : '⏳ Opponent\'s Turn',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _getStateText(provider.gameState),
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: provider.turnTimeLeft,
            builder: (context, timeLeft, _) {
              final low = timeLeft <= 10;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: low ? Colors.red.withOpacity(0.3) : Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: low ? Colors.red : Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${timeLeft}s',
                      style: TextStyle(
                        color: low ? Colors.red : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getStateText(LudoGameState state) {
    switch (state) {
      case LudoGameState.throwDice:
        return 'Roll the dice';
      case LudoGameState.pickPawn:
        return 'Select a pawn to move';
      case LudoGameState.moving:
        return 'Moving...';
      case LudoGameState.finish:
        return 'Game Over';
    }
  }

  Widget _buildGameOverOverlay(LudoMultiplayerProvider provider) {
    final winner = provider.winners.isNotEmpty ? provider.winners.first : null;
    final isLocalWinner =
        winner != null && winner.name == provider.localColor;
    final localRank = provider.winners
            .indexWhere((w) => w.name == provider.localColor) +
        1;
    final reason = provider.finishReason;

    String title = '';
    String subtitle = '';
    IconData icon = Icons.sports_score;
    Color iconColor = Colors.white70;

    if (isLocalWinner) {
      // Local player WON
      title = '🎉 You Win!';
      subtitle = reason == 'forfeit'
          ? 'Opponent forfeited the game!'
          : 'Congratulations! Winner: ${winner?.name.toUpperCase()}';
      icon = Icons.emoji_events;
      iconColor = Colors.amber;
    } else if (localRank > 1) {
      title = '🏅 You finished #$localRank';
      subtitle = 'Winner: ${winner?.name.toUpperCase()}';
      icon = Icons.emoji_events;
      iconColor = Colors.blueGrey;
    } else if (reason == 'forfeit') {
      title = '😔 You Forfeited';
      subtitle = 'You left or were away too long.';
      icon = Icons.flag;
      iconColor = Colors.red;
    } else if (winner != null) {
      // Local player LOST normally
      title = '😔 You Lost';
      subtitle = 'Winner: ${winner.name.toUpperCase()}';
      icon = Icons.sports_score;
      iconColor = Colors.grey;
    } else {
      // Draw or no winner
      title = '🤝 Game Over';
      subtitle = 'Thanks for playing!';
      icon = Icons.gamepad;
      iconColor = Colors.blue;
    }

    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surfaceCard, AppColors.backgroundDeep],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLocalWinner ? Colors.amber : Colors.white24,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 60, color: iconColor),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  color: isLocalWinner ? Colors.amber : Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _hasLeft = true;
                    _backToLobby();
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Back to Lobby'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}