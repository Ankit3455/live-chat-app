// lib/feature/games/carrom/carrom_result_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../screens/chat/chat_screen.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/custom_button.dart';
import 'carrom_lobby_screen.dart';
import 'carrom_match_screen.dart';
import 'common/carrom_rank_badge.dart';
import 'common/game_leaderboard_screen.dart';
import 'services/carrom_stats_service.dart';
import 'services/carrom_audio_service.dart';

// Kept so existing imports of this file still resolve the leaderboard.
export 'common/game_leaderboard_screen.dart' show CarromLeaderboardScreen;

class CarromResultScreen extends StatefulWidget {
  final String matchId;
  final int myScore;
  final int opponentScore;
  final String opponentUid;
  final String opponentName;
  final int? gameDurationSeconds;

  /// Set when the match has a decided winner (cleared board, forfeit or
  /// timeout). Null falls back to comparing scores.
  final String? winnerUid;

  /// 'cleared', 'forfeit' or 'timeout'.
  final String? finishReason;

  const CarromResultScreen({
    Key? key,
    required this.matchId,
    required this.myScore,
    required this.opponentScore,
    required this.opponentUid,
    required this.opponentName,
    this.gameDurationSeconds,
    this.winnerUid,
    this.finishReason,
  }) : super(key: key);

  @override
  State<CarromResultScreen> createState() => _CarromResultScreenState();
}

class _CarromResultScreenState extends State<CarromResultScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _audioService = CarromAudioService();

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _haloAnimation;

  bool get isWinner => widget.winnerUid != null
      ? widget.winnerUid == _auth.currentUser?.uid
      : widget.myScore > widget.opponentScore;
  bool get isDraw =>
      widget.winnerUid == null && widget.myScore == widget.opponentScore;

  bool _statsSaved = false;
  CarromStats? _myStats;
  bool _loadingStats = true;

  // Rematch: both players must agree on the finished match doc.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _matchSub;
  bool _rematchRequested = false;
  bool _opponentWantsRematch = false;
  bool _rematchCreating = false;
  bool _rematchOpened = false;
  bool _opponentLeft = false;

  DocumentReference<Map<String, dynamic>> get _matchRef =>
      FirebaseFirestore.instance
          .collection('carrom_matches')
          .doc(widget.matchId);

  bool get _hasOpponent => widget.opponentUid.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _playResultSound();
    if (isWinner) Haptics.success();
    _saveThenLoadStats();
    if (_hasOpponent) _listenRematch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: show the result without the entrance animation.
    if (MediaQuery.of(context).disableAnimations) _controller.value = 1.0;
  }

  Future<void> _saveThenLoadStats() async {
    await _saveStats();
    await _loadMyStats();
  }

  void _initAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // One soft ring expanding behind the trophy on a win.
    _haloAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  void _playResultSound() {
    if (isWinner) {
      _audioService.playVictory();
    } else if (!isDraw) {
      _audioService.playDefeat();
    }
  }

  Future<void> _saveStats() async {
    if (_statsSaved) return;
    _statsSaved = true;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final saved = await CarromStatsService.saveGameResult(
        odZ: user.uid,
        odZName: user.displayName ?? 'Player',
        odZAvatar: user.photoURL,
        opponentUid: widget.opponentUid,
        opponentName: widget.opponentName,
        myScore: widget.myScore,
        opponentScore: widget.opponentScore,
        matchId: widget.matchId,
        gameDurationSeconds: widget.gameDurationSeconds,
        won: isWinner,
        isDraw: isDraw,
      );
      if (!saved) debugPrint('Carrom stats already recorded for this match');
    } catch (e) {
      debugPrint('Error saving Carrom stats: $e');
    }
  }

  void _listenRematch() {
    final me = _auth.currentUser?.uid;
    _matchSub = _matchRef.snapshots().listen((snap) {
      final d = snap.data();
      if (d == null || !mounted) return;
      final rematch = Map<String, dynamic>.from(d['rematch'] ?? {});
      final left = Map<String, dynamic>.from(d['left'] ?? {});
      setState(() {
        _rematchRequested = rematch[me] == true;
        _opponentWantsRematch = rematch[widget.opponentUid] == true;
        _opponentLeft = left[widget.opponentUid] == true;
      });
      final newId = d['rematchMatchId'] as String?;
      if (newId != null) {
        if (_rematchRequested) _openRematch(newId);
      } else if (_rematchRequested && _opponentWantsRematch && !_opponentLeft) {
        _createRematch();
      }
    }, onError: (Object e) => debugPrint('Carrom rematch listener error: $e'));
  }

  Future<void> _requestRematch() async {
    final me = _auth.currentUser?.uid;
    if (me == null || _rematchRequested || _opponentLeft) return;
    setState(() => _rematchRequested = true);
    try {
      await _matchRef.update({'rematch.$me': true});
    } catch (e) {
      debugPrint('Carrom rematch request failed: $e');
      if (!mounted) return;
      setState(() => _rematchRequested = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't send your rematch request. Try again."),
        ),
      );
    }
  }

  /// Either client may create the new match; the transaction makes sure only
  /// one is created. Colours swap: the previous guest hosts (white).
  Future<void> _createRematch() async {
    if (_rematchCreating) return;
    _rematchCreating = true;
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final d = (await tx.get(_matchRef)).data();
        if (d == null || d['rematchMatchId'] != null) return;
        final rematch = Map<String, dynamic>.from(d['rematch'] ?? {});
        final players = Map<String, dynamic>.from(d['players'] ?? {});
        if (players.length < 2 ||
            !players.keys.every((u) => rematch[u] == true)) {
          return;
        }
        final oldHost = d['host'] as String?;
        final newHost = players.keys.firstWhere(
          (u) => u != oldHost,
          orElse: () => players.keys.first,
        );
        final newRef =
            FirebaseFirestore.instance.collection('carrom_matches').doc();
        tx.set(newRef, {
          'players': players,
          'playerUids': players.keys.toList(),
          'status': 'ready',
          'host': newHost,
          'turn': newHost,
          'joined': <String, bool>{},
          'createdAt': FieldValue.serverTimestamp(),
          'boardState': null,
          'lastMove': null,
          'scores': {for (final u in players.keys) u: 0},
          'moveSeq': 0,
          'turnSeq': 0,
          'rematchOf': widget.matchId,
        });
        tx.update(_matchRef, {'rematchMatchId': newRef.id});
      });
    } catch (e) {
      debugPrint('Carrom rematch creation failed: $e');
    } finally {
      _rematchCreating = false;
    }
  }

  void _openRematch(String matchId) {
    if (_rematchOpened || !mounted) return;
    _rematchOpened = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => CarromMatchScreen(matchId: matchId)),
    );
  }

  Future<void> _loadMyStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final stats = await CarromStatsService.getUserStats(user.uid);
      if (mounted) {
        setState(() {
          _myStats = stats;
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    // Tell the opponent we left and withdraw an unanswered rematch request.
    final me = _auth.currentUser?.uid;
    if (_hasOpponent && !_rematchOpened && me != null) {
      _matchRef.update({
        'left.$me': true,
        if (_rematchRequested) 'rematch.$me': false,
      }).catchError((_) {});
    }
    _controller.dispose();
    super.dispose();
  }

  Color get _accent {
    if (isWinner) return AppColors.pinkLight;
    if (isDraw) return AppColors.lavender;
    return AppColors.brandPurpleLight;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToGameList();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    _buildResultIcon(),
                    const SizedBox(height: 20),
                    _buildResultText(),
                    const SizedBox(height: 28),
                    _buildScoreCard(),
                    const SizedBox(height: 16),
                    _buildStatsCard(),
                    const SizedBox(height: 28),
                    _buildActionButtons(),
                    const SizedBox(height: 8),
                    _buildBackLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultIcon() {
    final icon = ScaleTransition(
      scale: _scaleAnimation,
      child: ExcludeSemantics(
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _accent.withOpacity(0.12),
            border: Border.all(color: _accent.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(color: _accent.withOpacity(0.25), blurRadius: 40),
            ],
          ),
          child: Icon(
            isWinner
                ? Icons.emoji_events_outlined
                : isDraw
                    ? Icons.handshake_outlined
                    : Icons.sentiment_dissatisfied_outlined,
            size: 60,
            color: _accent,
          ),
        ),
      ),
    );
    if (!isWinner) return icon;
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _haloAnimation,
          builder: (context, _) {
            final t = _haloAnimation.value;
            // Fully faded at t = 1, so reduced motion shows no ring.
            return Container(
              width: 112 + 72 * t,
              height: 112 + 72 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _accent.withOpacity(0.5 * (1 - t)),
                  width: 2,
                ),
              ),
            );
          },
        ),
        icon,
      ],
    );
  }

  Widget _buildResultText() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                isWinner
                    ? 'You won!'
                    : isDraw
                        ? "It's a draw"
                        : 'You lost',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getSubtitle(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.lavender, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _buildScoreColumn('You', widget.myScore, isWinner),
              const VerticalDivider(width: 1, color: AppColors.border),
              _buildScoreColumn(
                _formatName(widget.opponentName),
                widget.opponentScore,
                !isWinner && !isDraw,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreColumn(String label, int score, bool isHighlighted) {
    return Expanded(
      child: Semantics(
        label: '$label: $score points${isHighlighted ? ', winner' : ''}',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.lavender,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: isHighlighted
                  ? BoxDecoration(
                      color: AppColors.pinkLight.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.pinkLight.withOpacity(0.5),
                      ),
                    )
                  : null,
              child: Text(
                '$score',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: isHighlighted ? 44 : 38,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (isHighlighted) ...[
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: AppColors.pinkLight, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Winner',
                    style: TextStyle(
                      color: AppColors.pinkLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = _myStats;
    final Widget body;
    if (_loadingStats) {
      body = const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: AppColors.brandPurpleLight,
            strokeWidth: 2,
          ),
        ),
      );
    } else if (stats != null) {
      body = Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart,
                color: AppColors.brandPurpleLight,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Your stats',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              CarromTierBadge(tier: stats.rank),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem('Games', '${stats.totalGames}'),
              _buildStatItem('Wins', '${stats.wins}'),
              _buildStatItem(
                'Win rate',
                '${stats.winRate.toStringAsFixed(0)}%',
              ),
              _buildStatItem('Streak', '${stats.winStreak}🔥'),
            ],
          ),
        ],
      );
    } else {
      body = const Row(
        children: [
          ExcludeSemantics(
            child: AppIllustration(kind: AppIllustrationKind.stars, size: 56),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "We couldn't load your stats. They'll show here next time.",
              style: TextStyle(color: AppColors.lavender, fontSize: 14),
            ),
          ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _slideAnimation.value),
        child: child,
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.brandPurple.withOpacity(0.22),
                AppColors.brandPink.withOpacity(0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AppColors.brandPurpleMid.withOpacity(0.35)),
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.lavender, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // Rematch (needs both players) or a new opponent
            if (_hasOpponent) ...[
              CustomButton(
                text: _rematchLabel(),
                leftIcon: Icons.replay,
                onPressed: _rematchRequested || _opponentLeft
                    ? null
                    : _requestRematch,
              ),
              const SizedBox(height: 12),
            ],
            CustomButton(
              text: 'New opponent',
              leftIcon: Icons.search,
              type: _hasOpponent ? ButtonType.outline : ButtonType.primary,
              onPressed: _playAgain,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Chat',
                    leftIcon: Icons.chat_bubble_outline,
                    type: ButtonType.outline,
                    onPressed: _hasOpponent ? _openChat : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Leaderboard',
                    leftIcon: Icons.leaderboard_outlined,
                    type: ButtonType.outline,
                    onPressed: _openLeaderboard,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackLink() {
    return CustomButton(
      text: 'Back to games',
      type: ButtonType.text,
      width: 220,
      onPressed: _goToGameList,
    );
  }

  String _rematchLabel() {
    if (_opponentLeft) return '${_formatName(widget.opponentName)} left';
    if (_rematchRequested) return 'Waiting for opponent…';
    if (_opponentWantsRematch) return 'Accept rematch';
    return 'Rematch';
  }

  String _getSubtitle() {
    if (widget.finishReason == 'forfeit') {
      return isWinner ? 'Your opponent left the match.' : 'You left the match.';
    }
    if (widget.finishReason == 'timeout') {
      return isWinner
          ? 'Your opponent missed too many turns.'
          : 'You missed too many turns.';
    }
    if (isWinner) return 'Congratulations, well played.';
    if (isDraw) return 'Good game. You finished level.';
    return 'Good game. Better luck next time.';
  }

  String _formatName(String name) {
    if (name.isEmpty) return 'Opponent';
    if (name.length > 12) return '${name.substring(0, 10)}…';
    return name;
  }

  void _playAgain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CarromLobbyScreen()),
    );
  }

  void _openChat() {
    if (widget.opponentUid.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(otherUserId: widget.opponentUid),
      ),
    );
  }

  void _openLeaderboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CarromLeaderboardScreen(),
      ),
    );
  }

  // Lobby, match and game were replaced along the way, so the route below
  // this one is the game list.
  void _goToGameList() {
    Navigator.of(context).pop();
  }
}
