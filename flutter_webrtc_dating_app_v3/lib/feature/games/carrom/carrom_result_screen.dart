// lib/feature/games/carrom/carrom_result_screen.dart
// STATUS: UPDATED WITH STATS SAVING ✅

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'carrom_lobby_screen.dart';
import 'services/carrom_stats_service.dart';
import 'services/carrom_audio_service.dart';

class CarromResultScreen extends StatefulWidget {
  final String matchId;
  final int myScore;
  final int opponentScore;
  final String opponentUid;
  final String opponentName;
  final int? gameDurationSeconds;

  const CarromResultScreen({
    Key? key,
    required this.matchId,
    required this.myScore,
    required this.opponentScore,
    required this.opponentUid,
    required this.opponentName,
    this.gameDurationSeconds,
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

  bool get isWinner => widget.myScore > widget.opponentScore;
  bool get isDraw => widget.myScore == widget.opponentScore;

  bool _statsSaved = false;
  CarromStats? _myStats;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _playResultSound();
    _saveStats();
    _loadMyStats();
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
      await CarromStatsService.saveGameResult(
        odZ: user.uid,
        odZName: user.displayName ?? 'Player',
        odZAvatar: user.photoURL,
        opponentUid: widget.opponentUid,
        opponentName: widget.opponentName,
        myScore: widget.myScore,
        opponentScore: widget.opponentScore,
        matchId: widget.matchId,
        gameDurationSeconds: widget.gameDurationSeconds,
      );
      print('✅ Stats saved successfully');
    } catch (e) {
      print('❌ Error saving stats: $e');
    }
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
    return WillPopScope(
      onWillPop: () async {
        _goToGameList();
        return false;
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
            // Play Again
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _playAgain,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.replay, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'PLAY AGAIN',
                      style: TextStyle(
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

            // Row with Chat and Leaderboard buttons
            Row(
              children: [
                // Chat Button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _openChat,
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

  String _getSubtitle() {
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
    // TODO: Navigate to your chat screen
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (_) => ChatScreen(userId: widget.opponentUid),
    // ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.chat, color: Colors.white),
            const SizedBox(width: 12),
            Text('Opening chat with ${widget.opponentName}...'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _goToGameList() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

// Import this at top if not present:
// Create this file in Step 3
class CarromLeaderboardScreen extends StatelessWidget {
  const CarromLeaderboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Placeholder - will be replaced in Step 3
    return const Scaffold(
      body: Center(child: Text('Leaderboard')),
    );
  }
}