// lib/feature/games/game_list_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'carrom/carrom_lobby_screen.dart';
import 'carrom/common/game_leaderboard_screen.dart';
import 'carrom/services/carrom_stats_service.dart';
import 'love_physics/love_physics_game.dart' show LovePhysicsScreen;
import 'ludo/ludo_lobby_screen.dart';
import '../../core/constants/app_colors.dart';

class GameListScreen extends StatefulWidget {
  const GameListScreen({super.key});

  @override
  State<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends State<GameListScreen> {
  CarromStats? _myStats;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _myStats = null;
          _loadingStats = false;
        });
      }
      return;
    }

    final stats = await CarromStatsService.getUserStats(uid);
    if (mounted) {
      setState(() {
        _myStats = stats;
        _loadingStats = false;
      });
    }
  }

  // Stats can change while a game screen is open, so reload on return.
  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundDeep, AppColors.surfaceCard],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ===== HEADER =====
              _buildHeader(),

              // ===== CONTENT =====
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== MY STATS CARD =====
                      if (!_loadingStats && _myStats != null)
                        _buildMyStatsCard(),

                      const SizedBox(height: 24),

                      // ===== GAMES SECTION =====
                      _buildSectionTitle('Games'),
                      const SizedBox(height: 12),

                      // Carrom
                      _GameCard(
                        title: 'Carrom',
                        subtitle: 'Classic Board Game • 2 Players',
                        icon: Icons.radio_button_checked,
                        iconColor: Colors.orange,
                        stats: _myStats != null
                            ? '${_myStats!.wins}W - ${_myStats!.losses}L'
                            : null,
                        gradientColors: [
                          Colors.orange.withOpacity(0.3),
                          AppColors.surfaceCard,
                        ],
                        borderColor: Colors.orange.withOpacity(0.5),
                        isAvailable: true,
                        onTap: () => _open(const CarromLobbyScreen()),
                      ),
                      const SizedBox(height: 12),

                      _GameCard(
                        title: 'Ludo',
                        subtitle: 'Classic Ludo • 2-4 Players',
                        icon: Icons.casino,
                        iconColor: Colors.blue,
                        gradientColors: [
                          Colors.blue.withOpacity(0.25),
                          AppColors.surfaceCard,
                        ],
                        borderColor: Colors.blue.withOpacity(0.4),
                        isAvailable: true,
                        onTap: () => _open(const LudoLobbyScreen()),
                      ),
                      const SizedBox(height: 12),

                      _GameCard(
                        title: 'Love Physics',
                        subtitle: 'Draw bridges to bring two hearts together • Solo',
                        icon: Icons.favorite,
                        iconColor: Colors.pinkAccent,
                        gradientColors: [
                          Colors.pinkAccent.withOpacity(0.25),
                          AppColors.surfaceCard,
                        ],
                        borderColor: Colors.pinkAccent.withOpacity(0.4),
                        isAvailable: true,
                        onTap: () => _open(const LovePhysicsScreen()),
                      ),
                      const SizedBox(height: 12),

                      // Not implemented yet: shown disabled, no tap action.
                      _GameCard(
                        title: 'Chess',
                        subtitle: 'Coming Soon',
                        icon: Icons.grid_3x3,
                        iconColor: Colors.brown,
                        gradientColors: [
                          Colors.brown.withOpacity(0.2),
                          AppColors.surfaceCard,
                        ],
                        borderColor: Colors.brown.withOpacity(0.3),
                        isAvailable: false,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Hidden when shown as a tab of the main shell (nothing to pop).
          if (Navigator.canPop(context)) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 16),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎮 Game Zone',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Play with your matches!',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Leaderboard Button
          Container(
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.leaderboard, color: Colors.orange),
              tooltip: 'Carrom leaderboard',
              onPressed: () => _open(const CarromLeaderboardScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.3),
            Colors.blue.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purple.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Your Stats',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
              _buildQuickStat('Games', '${_myStats!.totalGames}'),
              _buildQuickStat('Wins', '${_myStats!.wins}'),
              _buildQuickStat('Win Rate', '${_myStats!.winRate.toStringAsFixed(0)}%'),
              _buildQuickStat('Streak', '${_myStats!.winStreak}🔥'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
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
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        rank,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }
}

// ===== GAME CARD WIDGET =====
class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String? stats;
  final List<Color> gradientColors;
  final Color borderColor;
  final bool isAvailable;
  final VoidCallback? onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.stats,
    required this.gradientColors,
    required this.borderColor,
    required this.isAvailable,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isAvailable ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAvailable ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),

                // Title, Subtitle & Stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      if (stats != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            stats!,
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Arrow or Badge
                if (isAvailable)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: iconColor,
                      size: 16,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'SOON',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}