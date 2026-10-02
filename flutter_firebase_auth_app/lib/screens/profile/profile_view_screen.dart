import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/profile/widgets/profile_info_card.dart';
import 'package:availchat/screens/profile/widgets/profile_stats_row.dart';
import 'package:availchat/screens/profile/widgets/interests_grid.dart';
import 'package:availchat/screens/profile/widgets/astrology_compatibility_card.dart';
import 'package:availchat/screens/chat/chat_screen.dart';
import 'package:availchat/screens/profile/profile_view_screen.dart';

class ProfileViewScreen extends StatelessWidget {
  final UserModel user;

  const ProfileViewScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E2E),
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 100,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF2D1B4E),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                user.username,
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
                      const Color(0xFF7B2CBF).withOpacity(0.3),
                      const Color(0xFF2D1B4E),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Info Card
                  ProfileInfoCard(
                    user: user,
                    completionPercentage: 100, // Assume complete for other users
                  ),
                  const SizedBox(height: 16),

                  // Profile Stats
                  ProfileStatsRow(user: user),
                  const SizedBox(height: 24),

                  // Interests Section
                  if (user.interests.isNotEmpty) ...[
                    const Text(
                      'Interests',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InterestsGrid(interests: user.interests),
                    const SizedBox(height: 24),
                  ],

                  // Astrology Section
                  const Text(
                    'Astrology Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AstrologyCompatibilityCard(user: user),
                  const SizedBox(height: 100), // Bottom padding for FAB
                ],
              ),
            ),
          ),
        ],
      ),

      // Chat FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(otherUserId: user.uid ?? ''),
            ),
          );
        },
        backgroundColor: const Color(0xFF7B2CBF),
        icon: const Icon(Icons.chat, color: Colors.white),
        label: const Text(
          'Message',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}