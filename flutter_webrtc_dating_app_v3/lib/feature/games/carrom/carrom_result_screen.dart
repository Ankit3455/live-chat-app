// lib/feature/games/carrom/carrom_result_screen.dart
// STATUS: UPDATED WITH STATS SAVING ✅

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../screens/chat/chat_screen.dart';
import 'carrom_lobby_screen.dart';
import 'carrom_match_screen.dart';
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

  DocumentReference<Map<String, dynamic>> get _matchRef => FirebaseFirestore
      .instance
      .collection('carrom_matches')
      .doc(widget.matchId);

  bool get _hasOpponent => widget.opponentUid.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _playResultSound();
    _saveThenLoadStats();
    if (_hasOpponent) _listenRematch();
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
      setState(() {
        _rematchRequested = rematch[me] == true;
        _opponentWantsRematch = rematch[widget.opponentUid] == true;
      });
      final newId = d['rematchMatchId'] as String?;
      if (newId != null) {
        if (_rematchRequested) _openRematch(newId);
      } else if (_rematchRequested && _opponentWantsRematch) {
        _createRematch();
      }
    }, onError: (Object e) => debugPrint('Carrom rematch listener error: $e'));
  }

  Future<void> _requestRematch() async {
    final me = _auth.currentUser?.uid;
    if (me == null || _rematchRequested) return;
    setState(() => _rematchRequested = true);
    try {
      await _matchRef.update({'rematch.$me': true});
    } catch (e) {
      debugPrint('Carrom rematch request failed: $e');
      if (!mounted) return;
      setState(() => _rematchRequested = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send rematch request')),
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
    // Withdraw an unanswered rematch request when leaving.
    final me = _auth.currentUser?.uid;
    if (_rematchRequested && !_rematchOpened && me != null) {
      _matchRef.update({'rematch.$me': false}).catchError((_) {});
    }
    _controller.dispose();
    super.dispose();
  }

  Color get _primaryColor {
    if (isWinner) return const Color(0xFF2E7D32);
    if (isDraw) return const Color(0xFF616161);
    return const Color(0xFFC62828);
  }

  Color get _secondaryColor {
    if (isWinner) return const Color(0xFF1B5E20);
    if (isDraw) return const Color(0xFF424242);
    return const Color(0xFFB71C1C);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToGameList();
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_secondaryColor, _primaryColor],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // ===== RESULT ICON =====
                    _buildResultIcon(),
                    const SizedBox(height: 24),

                    // ===== RESULT TEXT =====
                    _buildResultText(),
                    const SizedBox(height: 40),

                    // ===== SCORE CARD =====
                    _buildScoreCard(),
                    const SizedBox(height: 24),

                    // ===== STATS CARD =====
                    _buildStatsCard(),
                    const SizedBox(height: 32),

                    // ===== ACTION BUTTONS =====
                    _buildActionButtons(),
                    const SizedBox(height: 16),

                    // ===== BACK LINK =====
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
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          isWinner
              ? Icons.emoji_events
              : isDraw
              ? Icons.handshake
              : Icons.sentiment_dissatisfied,
          size: 70,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildResultText() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        children: [
          Text(
            isWinner ? '🎉 VICTORY!' : isDraw ? '🤝 DRAW!' : '😔 DEFEAT',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getSubtitle(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildScoreColumn('YOU', widget.myScore, isWinner),
            Container(
              height: 80,
              width: 1,
              color: Colors.white.withOpacity(0.3),
            ),
            _buildScoreColumn(
              _formatName(widget.opponentName),
              widget.opponentScore,
              !isWinner && !isDraw,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreColumn(String label, int score, bool isHighlighted) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: isHighlighted
                ? BoxDecoration(
              color: Colors.amber.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber, width: 2),
            )
                : null,
            child: Text(
              '$score',
              style: TextStyle(
                color: Colors.white,
                fontSize: isHighlighted ? 48 : 40,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isHighlighted) ...[
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 18),
                SizedBox(width: 4),
                Text(
                  'WINNER',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _loadingStats
                  ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
                  : _myStats != null
                  ? Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bar_chart,
                        color: Colors.white.withOpacity(0.8),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'YOUR STATS',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      _buildRankBadge(_myStats!.rank),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Games', '${_myStats!.totalGames}'),
                      _buildStatItem('Wins', '${_myStats!.wins}'),
                      _buildStatItem('Win Rate', '${_myStats!.winRate.toStringAsFixed(0)}%'),
                      _buildStatItem('Streak', '${_myStats!.winStreak}🔥'),
                    ],
                  ),
                ],
              )
                  : Text(
                'Stats will appear after this game',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildRankBadge(String rank) {
    Color badgeColor;
    switch (rank.toLowerCase()) {
      case 'legend':
        badgeColor = Colors.purple;
        break;
      case 'diamond':
        badgeColor = Colors.cyan;
        break;
      case 'platinum':
        badgeColor = Colors.blueGrey;
        break;
      case 'gold':
        badgeColor = Colors.amber;
        break;
      case 'silver':
        badgeColor = Colors.grey.shade400;
        break;
      case 'bronze':
        badgeColor = Colors.brown;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.military_tech, color: badgeColor, size: 14),
          const SizedBox(width: 4),
          Text(
            rank.toUpperCase(),
            style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            // Rematch (needs both players) or a new opponent
            if (_hasOpponent) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _rematchRequested ? null : _requestRematch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _primaryColor,
                    disabledBackgroundColor: Colors.white.withOpacity(0.6),
                    disabledForegroundColor: _primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.replay, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        _rematchLabel(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _playAgain,
                icon: const Icon(Icons.search, size: 20),
                label: const Text(
                  'NEW OPPONENT',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Row with Chat and Leaderboard buttons
            Row(
              children: [
                // Chat Button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _hasOpponent ? _openChat : null,
                      icon: const Icon(Icons.chat_bubble_outline, size: 20),
                      label: const Text(
                        'CHAT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Leaderboard Button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _openLeaderboard,
                      icon: const Icon(Icons.leaderboard, size: 20),
                      label: const Text(
                        'RANKINGS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
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
    return TextButton(
      onPressed: _goToGameList,
      child: Text(
        'Back to Game List',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 14,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  String _rematchLabel() {
    if (_rematchRequested) return 'WAITING FOR OPPONENT...';
    if (_opponentWantsRematch) return 'ACCEPT REMATCH';
    return 'REMATCH';
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
    if (isWinner) return 'Congratulations! Well played! 🎉';
    if (isDraw) return 'Great match! It\'s a tie! 🤝';
    return 'Better luck next time! 💪';
  }

  String _formatName(String name) {
    if (name.isEmpty) return 'OPPONENT';
    if (name.length > 10) return '${name.substring(0, 8).toUpperCase()}..';
    return name.toUpperCase();
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
