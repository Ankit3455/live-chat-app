// lib/feature/games/common/game_leaderboard_screen.dart
// STATUS: NEW FILE ✅

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/carrom_stats_service.dart';

class CarromLeaderboardScreen extends StatefulWidget {
  const CarromLeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<CarromLeaderboardScreen> createState() => _CarromLeaderboardScreenState();
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
            colors: [Color(0xFF1A0E2E), Color(0xFF2D1B4E)],
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🏆 LEADERBOARD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'Carrom Rankings',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'TODAY'),
          Tab(text: 'WEEK'),
          Tab(text: 'ALL TIME'),
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
            child: CircularProgressIndicator(color: Colors.orange),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red.shade300,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading leaderboard',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          );
        }

        final entries = snapshot.data ?? [];

        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.white.withOpacity(0.3),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'No rankings yet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Play games to appear here!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isMe
            ? LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.3),
            Colors.orange.withOpacity(0.1),
          ],
        )
            : null,
        color: isMe ? null : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: isMe
            ? Border.all(color: Colors.orange, width: 2)
            : isTop3
            ? Border.all(color: _getRankColor(entry.rank), width: 1)
            : null,
      ),
      child: Row(
        children: [
          // Rank Badge
          _buildRankBadge(entry.rank),
          const SizedBox(width: 16),

          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isTop3 ? _getRankColor(entry.rank) : Colors.white24,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: entry.avatar.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: entry.avatar,
                memCacheWidth: 150,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _defaultAvatar(entry.displayName),
              )
                  : _defaultAvatar(entry.displayName),
            ),
          ),
          const SizedBox(width: 12),

          // Name and Stats
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
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.wins} wins • ${entry.gamesPlayed} games',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score}',
                style: TextStyle(
                  color: isTop3 ? _getRankColor(entry.rank) : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'points',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank <= 3) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getRankColor(rank),
              _getRankColor(rank).withOpacity(0.6),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _getRankColor(rank).withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.1),
      ),
      child: Center(
        child: Text(
          '$rank',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey.shade400;
      case 3:
        return Colors.brown.shade400;
      default:
        return Colors.white54;
    }
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
      color: Colors.grey.shade800,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}