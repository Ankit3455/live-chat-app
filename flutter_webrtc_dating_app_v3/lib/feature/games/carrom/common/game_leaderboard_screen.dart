// lib/feature/games/common/game_leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/carrom_stats_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../widgets/app_states.dart';
import 'carrom_rank_badge.dart';

class CarromLeaderboardScreen extends StatefulWidget {
  const CarromLeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<CarromLeaderboardScreen> createState() =>
      _CarromLeaderboardScreenState();
}

class _CarromLeaderboardScreenState extends State<CarromLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

              // ===== TAB BAR =====
              _buildTabBar(),

              // ===== LEADERBOARD CONTENT =====
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLeaderboardList(LeaderboardType.daily),
                    _buildLeaderboardList(LeaderboardType.weekly),
                    _buildLeaderboardList(LeaderboardType.allTime),
                  ],
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
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: const Text(
                    'Leaderboard',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Text(
                  'Carrom rankings',
                  style: TextStyle(color: AppColors.lavender, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.surfaceCard,
        indicator: BoxDecoration(
          color: AppColors.brandPurple,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.lavender,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        tabs: const [
          Tab(text: 'Today'),
          Tab(text: 'Week'),
          Tab(text: 'All time'),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(LeaderboardType type) {
    return StreamBuilder<List<LeaderboardEntry>>(
      stream: CarromStatsService.getLeaderboard(type: type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.brandPurpleLight,
            ),
          );
        }

        if (snapshot.hasError) {
          return AppEmptyState(
            icon: Icons.error_outline,
            illustration: AppIllustrationKind.offline,
            title: "Couldn't load the leaderboard",
            message: 'Check your internet connection and try again.',
            actionLabel: 'Try again',
            // Rebuilding resubscribes to the leaderboard stream.
            onAction: () => setState(() {}),
          );
        }

        final entries = snapshot.data ?? [];

        if (entries.isEmpty) {
          return const AppEmptyState(
            icon: Icons.emoji_events_outlined,
            illustration: AppIllustrationKind.stars,
            title: 'No rankings yet',
            message: 'Play a game of Carrom to get on the board.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            return _buildLeaderboardTile(entries[index], index);
          },
        );
      },
    );
  }

  Widget _buildLeaderboardTile(LeaderboardEntry entry, int index) {
    final isMe = entry.odZ == _auth.currentUser?.uid;
    final isTop3 = entry.rank <= 3;
    final placeColor = carromPlaceColor(entry.rank);

    return Semantics(
      label: 'Rank ${entry.rank}, ${entry.displayName}${isMe ? ' (you)' : ''}, '
          '${entry.score} points, ${entry.wins} wins, '
          '${entry.gamesPlayed} games',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.brandPurple.withOpacity(0.22)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe
                ? AppColors.brandPurpleMid
                : isTop3
                    ? placeColor.withOpacity(0.5)
                    : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            _buildRankBadge(entry.rank),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isTop3 ? placeColor : AppColors.borderStrong,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: entry.avatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: entry.avatar,
                        memCacheWidth: 150,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _defaultAvatar(entry.displayName),
                      )
                    : _defaultAvatar(entry.displayName),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.displayName,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 15,
                            fontWeight:
                                isMe ? FontWeight.w700 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.borderStrong),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              color: AppColors.brandPurpleLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.wins} wins • ${entry.gamesPlayed} games',
                    style: const TextStyle(
                      color: AppColors.lavender,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.score}',
                  style: TextStyle(
                    color: isTop3 ? placeColor : AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'points',
                  style: TextStyle(color: AppColors.lavender, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank <= 3) {
      final color = carromPlaceColor(rank);
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.16),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Center(
          child: Text(
            _getRankEmoji(rank),
            style: const TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface2,
      ),
      child: Center(
        child: Text(
          '$rank',
          style: const TextStyle(
            color: AppColors.lavender,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '$rank';
    }
  }

  Widget _defaultAvatar(String name) {
    return Container(
      color: AppColors.surface2,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
