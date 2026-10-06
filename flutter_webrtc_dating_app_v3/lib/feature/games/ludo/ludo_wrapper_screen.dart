import 'dart:async';

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
import '../../../core/utils/haptics.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/custom_button.dart';

class LudoWrapperScreen extends StatefulWidget {
  final String matchId;

  /// Opened from a chat invite: "back" returns to the chat, not the lobby.
  final bool fromChat;

  const LudoWrapperScreen({
    Key? key,
    required this.matchId,
    this.fromChat = false,
  }) : super(key: key);

  /// How long a private match waits for the other player to open it.
  static const Duration joinWait = Duration(seconds: 60);

  @override
  State<LudoWrapperScreen> createState() => _LudoWrapperScreenState();
}

class _LudoWrapperScreenState extends State<LudoWrapperScreen>
    with WidgetsBindingObserver {
  late LudoMultiplayerProvider _provider;
  final _gameService = LudoGameService();
  bool _hasLeft = false;
  Timer? _joinTimer;

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
    _joinTimer?.cancel();
    // Closed without Leave (e.g. route removed): start the away grace so the
    // others aren't left waiting on a player who is gone.
    if (!_hasLeft &&
        !_provider.matchMissing &&
        _provider.gameState != LudoGameState.finish) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        unawaited(_gameService.playerAway(matchId: widget.matchId, odId: uid));
      }
    }
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
    Haptics.warning();
    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Leave game?',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          multiPlayer
              ? "If you leave, you're out of this match and can't rejoin. The other players keep playing."
              : 'If you leave, you forfeit and your opponent wins.',
          style: const TextStyle(
            color: AppColors.lavender,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandPurpleLight,
              minimumSize: const Size(64, 48),
            ),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              minimumSize: const Size(64, 48),
            ),
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
    if (widget.fromChat) {
      Navigator.of(context).pop();
      return;
    }
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
                  return _buildLoadingView('Connecting to the game…');
                }

                if (provider.abandoned) {
                  return _buildNotJoinedView();
                }

                if (!provider.isGameReady || provider.waitingForJoin) {
                  if (provider.waitingForJoin) {
                    _joinTimer ??= Timer(LudoWrapperScreen.joinWait, () {
                      if (_provider.waitingForJoin) {
                        _gameService.abandonPrivateMatch(widget.matchId);
                      }
                    });
                  }
                  return _buildWaitingForOpponent();
                }

                return Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth > constraints.maxHeight
                              ? _buildLandscapeGame(context, provider)
                              : _buildPortraitGame(context, provider),
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

  Widget _buildPortraitGame(
    BuildContext context,
    LudoMultiplayerProvider provider,
  ) {
    return Column(
      children: [
        const SizedBox(height: 4),
        _buildHeader(context, provider),
        const SizedBox(height: 8),
        _buildTurnIndicator(provider),
        if (provider.gameState != LudoGameState.finish)
          _buildAwayBanner(provider),
        const SizedBox(height: 8),
        const Expanded(child: Center(child: BoardWidget())),
        const SizedBox(height: 12),
        const SizedBox(width: 70, height: 70, child: DiceWidget()),
        const SizedBox(height: 20),
      ],
    );
  }

  // Landscape: board on the left (sized by height), controls on the right.
  Widget _buildLandscapeGame(
    BuildContext context,
    LudoMultiplayerProvider provider,
  ) {
    return Row(
      children: [
        const Expanded(child: Center(child: BoardWidget())),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _buildHeader(context, provider),
                const SizedBox(height: 8),
                _buildTurnIndicator(provider),
                if (provider.gameState != LudoGameState.finish)
                  _buildAwayBanner(provider),
                const SizedBox(height: 16),
                const SizedBox(width: 70, height: 70, child: DiceWidget()),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView(String message) {
    return Center(
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.brandPurpleLight),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: AppColors.lavender, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingForOpponent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: AppColors.brandPurpleMid.withOpacity(0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.brandPurpleMid.withOpacity(0.4),
                  ),
                ),
                child: const Icon(
                  Icons.hourglass_top,
                  size: 56,
                  color: AppColors.brandPurpleLight,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                _provider.maxPlayers > 2
                    ? 'Waiting for players…'
                    : 'Waiting for your opponent…',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The game starts as soon as everyone joins.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.lavender, fontSize: 14),
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: _backLabel,
              leftIcon: Icons.arrow_back,
              type: ButtonType.outline,
              width: 240,
              onPressed: () async {
                if (await _onWillPop()) {
                  if (mounted) _backToLobby();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotJoinedView() {
    return AppEmptyState(
      icon: Icons.timer_off_outlined,
      illustration: AppIllustrationKind.noResults,
      title: "They didn't join",
      message:
          'Your match did not open the game in time. Invite them again '
          'from the chat.',
      actionLabel: _backLabel,
      onAction: () {
        _hasLeft = true;
        _backToLobby();
      },
    );
  }

  String get _backLabel => widget.fromChat ? 'Back to chat' : 'Back to lobby';

  Widget _buildMatchMissingView() {
    return AppEmptyState(
      icon: Icons.error_outline,
      illustration: AppIllustrationKind.noResults,
      title: 'Match not found',
      message:
          'This match has ended or was cancelled. Find a new one from the lobby.',
      actionLabel: _backLabel,
      onAction: () {
        _hasLeft = true;
        _backToLobby();
      },
    );
  }

  /// Shown while an opponent is away; the game keeps going underneath.
  Widget _buildAwayBanner(LudoMultiplayerProvider provider) {
    return ValueListenableBuilder<int>(
      valueListenable: provider.secondTick,
      builder: (context, _, __) {
        final away = provider.awayOpponents;
        final localAway = provider.localAway;
        if (away.isEmpty && !localAway) return const SizedBox.shrink();
        final twoPlayer = provider.maxPlayers <= 2;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              if (localAway)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: AppBanner(
                    message: twoPlayer
                        ? "You're marked away. Tap I'm back or you'll forfeit."
                        : "You're marked away. Tap I'm back to keep playing.",
                    tone: AppBannerTone.warning,
                    icon: Icons.person_off_outlined,
                    actionLabel: "I'm back",
                    onAction: provider.reconnectLocal,
                  ),
                ),
              ...away.map((p) {
                final String text;
                if (p.skipped) {
                  text =
                      '${p.name} is away. Their turns are skipped until they return.';
                } else if (twoPlayer) {
                  text =
                      "${p.name} is away. You win if they're not back in ${p.secondsLeft}s.";
                } else {
                  text =
                      '${p.name} is away. Their turns are skipped in ${p.secondsLeft}s.';
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: AppBanner(
                    message: text,
                    tone: AppBannerTone.warning,
                    icon: Icons.person_off_outlined,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, LudoMultiplayerProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Leave game',
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: () async {
              if (await _onWillPop()) {
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: const Text(
                    'Ludo',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Playing as ${provider.localColor ?? "…"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.lavender,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open game chat',
            icon: const Icon(
              Icons.chat_bubble_outline,
              color: AppColors.brandPurpleLight,
            ),
            onPressed: _openChat,
          ),
          const SizedBox(width: 4),
          Semantics(
            label:
                '${provider.activePlayers} of ${provider.maxPlayers} players',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.people_outline,
                    color: AppColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${provider.activePlayers}/${provider.maxPlayers}',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnIndicator(LudoMultiplayerProvider provider) {
    final isMyTurn = provider.isLocalPlayerTurn;
    // Player colour shows whose turn it is (game semantics).
    final turnColor = provider.currentPlayer.color;

    final turnFade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);

    return AnimatedContainer(
      duration: turnFade,
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: turnColor, width: 2),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: turnFade,
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: turnColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMyTurn ? Icons.videogame_asset : Icons.hourglass_top,
              color: AppColors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMyTurn ? 'Your turn' : "Opponent's turn",
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _getStateText(provider.gameState),
                    style: const TextStyle(
                      color: AppColors.lavender,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: provider.turnTimeLeft,
            builder: (context, timeLeft, _) {
              final low = timeLeft <= 10;
              return Semantics(
                label: '$timeLeft seconds left',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: low
                        ? AppColors.error.withOpacity(0.18)
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: low ? AppColors.error : AppColors.lavender,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${timeLeft}s',
                        style: TextStyle(
                          color: low ? AppColors.error : AppColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
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
        return 'Moving…';
      case LudoGameState.finish:
        return 'Game over';
    }
  }

  Widget _buildGameOverOverlay(LudoMultiplayerProvider provider) {
    final winner = provider.winners.isNotEmpty ? provider.winners.first : null;
    final isLocalWinner = winner != null && winner.name == provider.localColor;
    final localRank =
        provider.winners.indexWhere((w) => w.name == provider.localColor) + 1;
    final reason = provider.finishReason;

    String title = '';
    String subtitle = '';
    IconData icon = Icons.sports_score;
    Color iconColor = AppColors.lavender;

    if (isLocalWinner) {
      // Local player WON
      title = 'You won!';
      subtitle = reason == 'forfeit'
          ? _forfeitWinText(provider.departedNames)
          : 'Nice one, you got all your tokens home first.';
      icon = Icons.emoji_events_outlined;
      iconColor = AppColors.pinkLight;
    } else if (localRank > 1) {
      title = 'You finished #$localRank';
      subtitle = '${_colorName(winner?.name)} won this round.';
      icon = Icons.emoji_events_outlined;
      iconColor = AppColors.brandPurpleLight;
    } else if (reason == 'forfeit') {
      title = 'You forfeited';
      subtitle = 'You left the match or were away too long.';
      icon = Icons.flag_outlined;
      iconColor = AppColors.error;
    } else if (winner != null) {
      // Local player LOST normally
      title = 'You lost';
      subtitle = '${_colorName(winner.name)} won this round.';
      icon = Icons.sports_score;
      iconColor = AppColors.lavender;
    } else {
      // Draw or no winner
      title = 'Game over';
      subtitle = 'Thanks for playing!';
      icon = Icons.gamepad_outlined;
      iconColor = AppColors.brandPurpleLight;
    }

    return Container(
      color: AppColors.backgroundDeep.withOpacity(0.92),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _ResultEntrance(
            celebrate: isLocalWinner,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isLocalWinner
                      ? AppColors.pinkLight.withOpacity(0.6)
                      : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 56, color: iconColor),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isLocalWinner
                            ? AppColors.pinkLight
                            : AppColors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.lavender,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  CustomButton(
                    text: _backLabel,
                    leftIcon: Icons.home_outlined,
                    onPressed: () {
                      _hasLeft = true;
                      _backToLobby();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _forfeitWinText(List<String> names) {
    if (names.isEmpty) return 'Your opponent left the game — you win.';
    if (names.length == 1) return '${names.first} left the game — you win.';
    return 'Everyone else left the game — you win.';
  }

  String _colorName(String? color) {
    if (color == null || color.isEmpty) return 'Another player';
    return '${color[0].toUpperCase()}${color.substring(1)}';
  }
}

/// Scale/fade-in for the result card; buzzes once on a local win.
class _ResultEntrance extends StatefulWidget {
  const _ResultEntrance({required this.celebrate, required this.child});

  final bool celebrate;
  final Widget child;

  @override
  State<_ResultEntrance> createState() => _ResultEntranceState();
}

class _ResultEntranceState extends State<_ResultEntrance> {
  @override
  void initState() {
    super.initState();
    if (widget.celebrate) Haptics.success();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
      child: widget.child,
    );
  }
}
