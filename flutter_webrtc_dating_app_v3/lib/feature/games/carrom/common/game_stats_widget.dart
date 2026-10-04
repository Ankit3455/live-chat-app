// lib/feature/games/common/game_stats_widget.dart
// Compact Carrom stats card for profile screens.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../widgets/app_states.dart';
import '../services/carrom_stats_service.dart';
import 'carrom_rank_badge.dart';
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
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

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
    final stats = _stats;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        border: Border.all(color: AppColors.brandPurpleMid.withOpacity(0.35)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          button: true,
          hint: 'Opens the Carrom leaderboard',
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
              padding: const EdgeInsets.all(16),
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppColors.brandPurpleLight,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : stats == null
                      ? _buildEmptyState()
                      : _buildStatsContent(stats),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow({required String subtitle, Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.pinkLight.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.pinkLight.withOpacity(0.4)),
          ),
          child: const Icon(Icons.adjust, color: AppColors.pinkLight, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Carrom',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.lavender, fontSize: 13),
              ),
            ],
          ),
        ),
        trailing ??
            const Icon(
              Icons.chevron_right,
              color: AppColors.lavender,
              size: 22,
            ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        _buildHeaderRow(subtitle: 'No games played yet'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: AppIllustration(
                  kind: AppIllustrationKind.stars,
                  size: 48,
                ),
              ),
              SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Play a game of Carrom to see your stats here.',
                  style: TextStyle(color: AppColors.lavender, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsContent(CarromStats stats) {
    return Column(
      children: [
        _buildHeaderRow(
          subtitle: '${stats.totalGames} games played',
          trailing: CarromTierBadge(tier: stats.rank),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatBox('Wins', '${stats.wins}', AppColors.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatBox(
                'Win rate',
                '${stats.winRate.toStringAsFixed(0)}%',
                AppColors.brandPurpleLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatBox(
                'Best streak',
                '${stats.bestWinStreak}🔥',
                AppColors.pinkLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.leaderboard_outlined,
                color: AppColors.brandPurpleLight,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'View leaderboard',
                style: TextStyle(
                  color: AppColors.brandPurpleLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                color: AppColors.brandPurpleLight,
                size: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
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
}
