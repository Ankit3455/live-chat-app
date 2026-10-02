// lib/feature/games/common/game_stats_widget.dart
// STATUS: NEW FILE ✅
// Use this widget in your profile screen to show game stats

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/carrom_stats_service.dart';
import 'game_leaderboard_screen.dart';

class CarromStatsCard extends StatefulWidget {
  final String? userId; // If null, uses current user

  const CarromStatsCard({Key? key, this.userId}) : super(key: key);

  @override
  State<CarromStatsCard> createState() => _CarromStatsCardState();
}

class _CarromStatsCardState extends State<CarromStatsCard> {
  CarromStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final uid = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final stats = await CarromStatsService.getUserStats(uid);
    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.withOpacity(0.2),
            Colors.purple.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CarromLeaderboardScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _loading
                ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.orange,
                  strokeWidth: 2,
                ),
              ),
            )
                : _stats == null
                ? _buildEmptyState()
                : _buildStatsContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.radio_button_checked,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Carrom',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'No games played yet',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white38,
              size: 16,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_circle_outline,
                color: Colors.orange.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Play your first game!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsContent() {
    return Column(
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.radio_button_checked,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Carrom',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_stats!.totalGames} games played',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _buildRankBadge(_stats!.rank),
          ],
        ),
        const SizedBox(height: 20),

        // Stats Grid
        Row(
          children: [
            Expanded(child: _buildStatBox('Wins', '${_stats!.wins}', Colors.green)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatBox('Win Rate', '${_stats!.winRate.toStringAsFixed(0)}%', Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatBox('Best Streak', '${_stats!.bestWinStreak}🔥', Colors.orange)),
          ],
        ),
        const SizedBox(height: 16),

        // View Leaderboard
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.leaderboard,
                color: Colors.orange,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'View Leaderboard',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.orange,
                size: 12,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.military_tech, color: badgeColor, size: 16),
          const SizedBox(width: 4),
          Text(
            rank,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}