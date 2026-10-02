// // lib/feature/games/ludo/ludo_wrapper_screen.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'ludo_multiplayer_provider.dart';
// import 'widgets/board_widget.dart';
// import 'widgets/dice_widget.dart';
// import 'constants.dart';
//
// class LudoWrapperScreen extends StatefulWidget {
//   final String matchId;
//   const LudoWrapperScreen({Key? key, required this.matchId}) : super(key: key);
//
//   @override
//   State<LudoWrapperScreen> createState() => _LudoWrapperScreenState();
// }
//
// class _LudoWrapperScreenState extends State<LudoWrapperScreen> {
//   late LudoMultiplayerProvider _provider;
//
//   @override
//   void initState() {
//     super.initState();
//     _provider = LudoMultiplayerProvider(matchId: widget.matchId);
//     _provider.start();
//   }
//
//   @override
//   void dispose() {
//     _provider.disposeProvider();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider<LudoMultiplayerProvider>.value(
//       value: _provider,
//       child: Scaffold(
//         backgroundColor: const Color(0xFF1A0E2E),
//         body: SafeArea(
//           child: Consumer<LudoMultiplayerProvider>(
//             builder: (context, provider, _) {
//               // Show loading while connecting
//               if (!provider.ready) {
//                 return _buildLoadingView('Connecting to game...');
//               }
//
//               // Show waiting if not enough players
//               if (!provider.isGameReady) {
//                 return _buildWaitingForOpponent();
//               }
//
//               // Game is ready - show board
//               return Stack(
//                 children: [
//                   Column(
//                     children: [
//                       const SizedBox(height: 8),
//                       _buildHeader(context, provider),
//                       const SizedBox(height: 8),
//                       _buildTurnIndicator(provider),
//                       const SizedBox(height: 8),
//                       const Expanded(
//                         child: Center(child: BoardWidget()),
//                       ),
//                       const SizedBox(height: 16),
//                       const SizedBox(
//                         width: 70,
//                         height: 70,
//                         child: DiceWidget(),
//                       ),
//                       const SizedBox(height: 24),
//                     ],
//                   ),
//                   if (provider.gameState == LudoGameState.finish)
//                     _buildGameOverOverlay(provider),
//                 ],
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLoadingView(String message) {
//     return Center(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const CircularProgressIndicator(color: Colors.white),
//           const SizedBox(height: 16),
//           Text(
//             message,
//             style: const TextStyle(color: Colors.white70),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildWaitingForOpponent() {
//     return Center(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(24),
//             decoration: BoxDecoration(
//               color: Colors.blue.withOpacity(0.2),
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(
//               Icons.hourglass_top,
//               size: 60,
//               color: Colors.blue,
//             ),
//           ),
//           const SizedBox(height: 24),
//           const Text(
//             'Waiting for opponent...',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Match ID: ${widget.matchId.substring(0, 8)}...',
//             style: const TextStyle(color: Colors.white54, fontSize: 12),
//           ),
//           const SizedBox(height: 32),
//           OutlinedButton.icon(
//             onPressed: () => Navigator.pop(context),
//             icon: const Icon(Icons.arrow_back),
//             label: const Text('Back to Lobby'),
//             style: OutlinedButton.styleFrom(
//               foregroundColor: Colors.white70,
//               side: BorderSide(color: Colors.white.withOpacity(0.3)),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildHeader(BuildContext context, LudoMultiplayerProvider provider) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       child: Row(
//         children: [
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: IconButton(
//               icon: const Icon(Icons.arrow_back, color: Colors.white),
//               onPressed: () => _showExitDialog(context),
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   '🎲 Ludo',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 Text(
//                   'Playing as ${provider.localColor?.toUpperCase() ?? "..."}',
//                   style: const TextStyle(color: Colors.white54, fontSize: 12),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//             decoration: BoxDecoration(
//               color: Colors.green.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Row(
//               children: [
//                 const Icon(Icons.people, color: Colors.green, size: 18),
//                 const SizedBox(width: 6),
//                 Text(
//                   '${provider.playersInfo.length}/2',
//                   style: const TextStyle(
//                     color: Colors.green,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTurnIndicator(LudoMultiplayerProvider provider) {
//     final isMyTurn = provider.isLocalPlayerTurn;
//     final turnColor = provider.currentPlayer.color;
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//       margin: const EdgeInsets.symmetric(horizontal: 16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [
//             turnColor.withOpacity(0.3),
//             turnColor.withOpacity(0.1),
//           ],
//         ),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: turnColor, width: 2),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: turnColor.withOpacity(0.3),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(
//               isMyTurn ? Icons.videogame_asset : Icons.hourglass_top,
//               color: Colors.white,
//               size: 20,
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   isMyTurn ? '🎯 Your Turn!' : '⏳ Opponent\'s Turn',
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//                 Text(
//                   _getStateText(provider.gameState),
//                   style: TextStyle(
//                     color: Colors.white.withOpacity(0.7),
//                     fontSize: 12,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             decoration: BoxDecoration(
//               color: provider.turnTimeLeft <= 10
//                   ? Colors.red.withOpacity(0.3)
//                   : Colors.black26,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Row(
//               children: [
//                 Icon(
//                   Icons.timer,
//                   color: provider.turnTimeLeft <= 10 ? Colors.red : Colors.white70,
//                   size: 16,
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   '${provider.turnTimeLeft}s',
//                   style: TextStyle(
//                     color: provider.turnTimeLeft <= 10 ? Colors.red : Colors.white,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   String _getStateText(LudoGameState state) {
//     switch (state) {
//       case LudoGameState.throwDice:
//         return 'Roll the dice';
//       case LudoGameState.pickPawn:
//         return 'Select a pawn to move';
//       case LudoGameState.moving:
//         return 'Moving...';
//       case LudoGameState.finish:
//         return 'Game Over';
//     }
//   }
//
//   Widget _buildGameOverOverlay(LudoMultiplayerProvider provider) {
//     final winner = provider.winners.isNotEmpty ? provider.winners.first : null;
//     final isLocalWinner = winner != null && winner.name == provider.localColor;
//
//     return Container(
//       color: Colors.black.withOpacity(0.9),
//       child: Center(
//         child: Container(
//           margin: const EdgeInsets.all(32),
//           padding: const EdgeInsets.all(24),
//           decoration: BoxDecoration(
//             gradient: const LinearGradient(
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//               colors: [Color(0xFF2D1B4E), Color(0xFF1A0E2E)],
//             ),
//             borderRadius: BorderRadius.circular(24),
//             border: Border.all(
//               color: isLocalWinner ? Colors.amber : Colors.white24,
//               width: 2,
//             ),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: (isLocalWinner ? Colors.amber : Colors.grey).withOpacity(0.2),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(
//                   isLocalWinner ? Icons.emoji_events : Icons.sports_score,
//                   size: 60,
//                   color: isLocalWinner ? Colors.amber : Colors.white70,
//                 ),
//               ),
//               const SizedBox(height: 24),
//               Text(
//                 isLocalWinner ? '🎉 You Won!' : '😔 Game Over',
//                 style: TextStyle(
//                   color: isLocalWinner ? Colors.amber : Colors.white,
//                   fontSize: 28,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 winner != null
//                     ? 'Winner: ${winner.name.toUpperCase()}'
//                     : 'Thanks for playing!',
//                 style: const TextStyle(color: Colors.white70, fontSize: 16),
//               ),
//               const SizedBox(height: 32),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton.icon(
//                   onPressed: () => Navigator.of(context).popUntil(
//                         (route) => route.isFirst || route.settings.name == '/games',
//                   ),
//                   icon: const Icon(Icons.home),
//                   label: const Text('Back to Lobby'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _showExitDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         backgroundColor: const Color(0xFF2D1B4E),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Text('Leave Game?', style: TextStyle(color: Colors.white)),
//         content: const Text(
//           'Are you sure you want to leave? You will lose this match.',
//           style: TextStyle(color: Colors.white70),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Stay'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(ctx);
//               Navigator.pop(context);
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             child: const Text('Leave'),
//           ),
//         ],
//       ),
//     );
//   }
// }


// lib/feature/games/ludo/ludo_wrapper_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'audio.dart';
import 'ludo_lobby_screen.dart';
import 'ludo_multiplayer_provider.dart';
import 'widgets/board_widget.dart';
import 'widgets/dice_widget.dart';
import 'widgets/game_chat_widget.dart';
import 'constants.dart';
import 'services/ludo_game_service.dart';

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
  bool _gameOverHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = LudoMultiplayerProvider(matchId: widget.matchId);
    _provider.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.disposeProvider();
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
      _handlePlayerLeave();
    }

    if (state == AppLifecycleState.resumed) {
      _handlePlayerReconnect();
    }
  }

  Future<void> _handlePlayerLeave() async {
    if (_hasLeft) return;
    if (_provider.gameState == LudoGameState.finish) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _gameService.playerLeft(
      matchId: widget.matchId,
      odId: uid,
    );

    debugPrint('📤 Player left: $uid');
  }

  Future<void> _handlePlayerReconnect() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final reconnected = await _gameService.playerReconnect(
      matchId: widget.matchId,
      odId: uid,
    );

    if (reconnected) {
      debugPrint('📥 Player reconnected: $uid');
    }
  }

  Future<bool> _onWillPop() async {
    if (_provider.gameState == LudoGameState.finish) {
      _hasLeft = true;
      return true;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B4E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '🚪 Leave Game?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'If you leave, your opponent will win after 5 minutes.\n\nYou can rejoin within 5 minutes to continue playing.',
          style: TextStyle(color: Colors.white70),
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
      _hasLeft = true;
      await _handlePlayerLeave();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: ChangeNotifierProvider<LudoMultiplayerProvider>.value(
        value: _provider,
        child: Scaffold(
          backgroundColor: const Color(0xFF1A0E2E),
          body: SafeArea(
            child: Consumer<LudoMultiplayerProvider>(
              builder: (context, provider, _) {
                if (provider.gameState == LudoGameState.finish && !_gameOverHandled) {
                  _gameOverHandled = true;
                  if (provider.winners.isNotEmpty) {
                    if (provider.winners.first.name == provider.localColor) {
                      Audio.playWin();
                    } else {
                      Audio.playLose();
                    }
                  }
                }

                if (!provider.ready) {
                  return _buildLoadingView('Connecting to game...');
                }

                if (!provider.isGameReady) {
                  return _buildWaitingForOpponent();
                }

                if (provider.opponentLeft && provider.gameState != LudoGameState.finish) {
                  return _buildOpponentLeftView(provider);
                }

                return Stack(
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 8),
                        _buildHeader(context, provider),
                        const SizedBox(height: 8),
                        _buildTurnIndicator(provider),
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
                if (mounted) Navigator.pop(context);
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

  Widget _buildOpponentLeftView(LudoMultiplayerProvider provider) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF2D1B4E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off, size: 60, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              '😔 Opponent Left',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting ${provider.forfeitTimeLeft} for them to return...',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'You will win automatically if they don\'t return!',
              style: TextStyle(color: Colors.green, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: provider.forfeitProgress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.orange),
            ),
          ],
        ),
      ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: provider.turnTimeLeft <= 10 ? Colors.red.withOpacity(0.3) : Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  color: provider.turnTimeLeft <= 10 ? Colors.red : Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${provider.turnTimeLeft}s',
                  style: TextStyle(
                    color: provider.turnTimeLeft <= 10 ? Colors.red : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
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

  // Widget _buildGameOverOverlay(LudoMultiplayerProvider provider) {
  //   final winner = provider.winners.isNotEmpty ? provider.winners.first : null;
  //   final isLocalWinner = winner != null && winner.name == provider.localColor;
  //   final reason = provider.finishReason;
  //
  //   String subtitle = '';
  //   if (reason == 'forfeit') {
  //     subtitle = isLocalWinner ? 'Opponent forfeited the game!' : 'You forfeited the game';
  //   } else {
  //     subtitle = winner != null ? 'Winner: ${winner.name.toUpperCase()}' : 'Thanks for playing!';
  //   }
  //
  //   return Container(
  //     color: Colors.black.withOpacity(0.9),
  //     child: Center(
  //       child: Container(
  //         margin: const EdgeInsets.all(32),
  //         padding: const EdgeInsets.all(24),
  //         decoration: BoxDecoration(
  //           gradient: const LinearGradient(
  //             begin: Alignment.topLeft,
  //             end: Alignment.bottomRight,
  //             colors: [Color(0xFF2D1B4E), Color(0xFF1A0E2E)],
  //           ),
  //           borderRadius: BorderRadius.circular(24),
  //           border: Border.all(
  //             color: isLocalWinner ? Colors.amber : Colors.white24,
  //             width: 2,
  //           ),
  //         ),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Container(
  //               padding: const EdgeInsets.all(20),
  //               decoration: BoxDecoration(
  //                 color: (isLocalWinner ? Colors.amber : Colors.grey).withOpacity(0.2),
  //                 shape: BoxShape.circle,
  //               ),
  //               child: Icon(
  //                 isLocalWinner ? Icons.emoji_events : Icons.sports_score,
  //                 size: 60,
  //                 color: isLocalWinner ? Colors.amber : Colors.white70,
  //               ),
  //             ),
  //             const SizedBox(height: 24),
  //             Text(
  //               isLocalWinner ? '🎉 You Won!' : '😔 Game Over',
  //               style: TextStyle(
  //                 color: isLocalWinner ? Colors.amber : Colors.white,
  //                 fontSize: 28,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             const SizedBox(height: 8),
  //             Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
  //             const SizedBox(height: 32),
  //             SizedBox(
  //               width: double.infinity,
  //               child: ElevatedButton.icon(
  //                 onPressed: () {
  //                   _hasLeft = true;
  //                   Navigator.of(context).pop();
  //                 },
  //                 icon: const Icon(Icons.home),
  //                 label: const Text('Back to Lobby'),
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: Colors.blue,
  //                   foregroundColor: Colors.white,
  //                   padding: const EdgeInsets.symmetric(vertical: 16),
  //                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //                 ),
  //               ),
  //             ),
  //             const SizedBox(height: 12),
  //             SizedBox(
  //               width: double.infinity,
  //               child: OutlinedButton.icon(
  //                 onPressed: () {
  //                   _hasLeft = true;
  //                   Navigator.of(context).pushReplacement(
  //                     MaterialPageRoute(builder: (_) => const LudoLobbyScreen()),
  //                   );
  //                 },
  //                 icon: const Icon(Icons.refresh),
  //                 label: const Text('Play Again'),
  //                 style: OutlinedButton.styleFrom(
  //                   foregroundColor: Colors.white,
  //                   side: const BorderSide(color: Colors.white54),
  //                   padding: const EdgeInsets.symmetric(vertical: 16),
  //                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildGameOverOverlay(LudoMultiplayerProvider provider) {
    // Check if local player is winner (regardless of finish reason)
    final isLocalWinner = provider.winners.isNotEmpty &&
        provider.localColor != null &&
        provider.winners.any((w) => w.name == provider.localColor);

    final winner = provider.winners.isNotEmpty ? provider.winners.first : null;
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
    } else if (reason == 'forfeit') {
      // Local player forfeited (left the game)
      title = '😔 You Forfeited';
      subtitle = 'You left the game. Opponent wins!';
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
              colors: [Color(0xFF2D1B4E), Color(0xFF1A0E2E)],
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
                    Navigator.of(context).pop();
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