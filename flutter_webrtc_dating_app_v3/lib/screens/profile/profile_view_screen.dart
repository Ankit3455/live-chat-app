// lib/screens/profile/profile_view_screen.dart
import 'package:flutter/material.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/profile/widgets/profile_info_card.dart';
import 'package:availchat/screens/profile/widgets/profile_stats_row.dart';
import 'package:availchat/screens/profile/widgets/interests_grid.dart';
import 'package:availchat/screens/profile/widgets/astrology_compatibility_card.dart';
import 'package:availchat/screens/chat/chat_screen.dart';
import '../../core/constants/app_colors.dart';

class ProfileViewScreen extends StatelessWidget {
  final UserModel user;

  const ProfileViewScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: CustomScrollView(
        slivers: [
          // ✔ Clean SliverAppBar
          SliverAppBar(
            expandedHeight: 100,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.surfaceCard,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                user.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.brandPurple.withOpacity(0.3),
                      AppColors.surfaceCard,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ Avatar + Username + Bio + progress
                      ProfileInfoCard(
                        user: user,
                        completionPercentage:
                            100, // Viewing other user → assume full
                      ),
                      const SizedBox(height: 16),

                      // ✅ Stats Row
                      ProfileStatsRow(user: user),
                      const SizedBox(height: 24),

                      // ✅ Interests Grid
                      if (user.interests.isNotEmpty) ...[
                        Semantics(
                          header: true,
                          child: const Text(
                            'Interests',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InterestsGrid(interests: user.interests),
                        const SizedBox(height: 24),
                      ],

                      // ✅ Astrology Profile Card
                      Semantics(
                        header: true,
                        child: const Text(
                          'Astrology profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AstrologyCompatibilityCard(user: user),

                      const SizedBox(height: 100), // bottom space for FAB
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // ✅ Floating Chat Button
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brandPurple,
        icon: const Icon(Icons.chat, color: Colors.white),
        label: const Text(
          'Message',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(otherUserId: user.uid ?? ''),
            ),
          );
        },
      ),
    );
  }
}
