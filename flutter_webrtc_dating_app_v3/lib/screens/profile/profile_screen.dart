import 'package:availchat/screens/questionnaire/profile_completion_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/profile/profile_edit_screen.dart';
import 'package:availchat/screens/astrology/astrology_questionnaire_screen.dart';
import 'package:availchat/screens/settings/settings_screen.dart';
import 'package:availchat/screens/profile/widgets/profile_info_card.dart';
import 'package:availchat/screens/profile/widgets/profile_stats_row.dart';
import 'package:availchat/screens/profile/widgets/interests_grid.dart';
import 'package:availchat/screens/profile/widgets/astrology_compatibility_card.dart';
import 'package:availchat/managers/profile_completion_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;
  int _completionPercentage = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        setState(() {
          _currentUser = UserModel.fromMap(doc.data()!);
          _isLoading = false;
        });
      }

      // Load completion percentage
      final percentage =
          await ProfileCompletionManager().getCompletionPercentage();
      
      if (mounted) {  // ✅ SAFETY CHECK
        setState(() {
          _completionPercentage = percentage;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading user: $e');
      if (mounted) {  // ✅ SAFETY CHECK
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshProfile() async {
    if (mounted) {  // ✅ SAFETY CHECK
      setState(() {
        _isLoading = true;
      });
    }
    await _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E2E),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7B2CBF)))
          : _currentUser == null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _refreshProfile,
                  color: const Color(0xFF7B2CBF),
                  backgroundColor: const Color(0xFF2D1B4E),
                  child: CustomScrollView(
                    slivers: [
                      // App Bar with Edit & Settings
                      SliverAppBar(
                        expandedHeight: 120,
                        floating: false,
                        pinned: true,
                        backgroundColor: const Color(0xFF2D1B4E),
                        flexibleSpace: FlexibleSpaceBar(
                          title: const Text(
                            'My Profile',
                            style: TextStyle(
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
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () async {
                              if (_currentUser == null) return;
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProfileEditScreen(user: _currentUser!),
                                ),
                              );
                              if (result == true) {
                                _refreshProfile();
                              }
                            },
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.settings, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
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
                                user: _currentUser!,
                                completionPercentage: _completionPercentage,
                              ),
                              const SizedBox(height: 16),

                              // Profile Completion CTA
                              if (_completionPercentage < 100)
                                _buildCompletionCTA(),

                              const SizedBox(height: 16),

                              // Profile Stats
                              ProfileStatsRow(user: _currentUser!),

                              const SizedBox(height: 24),

                              // Interests Section
                              if (_currentUser!.interests.isNotEmpty) ...[
                                const Text(
                                  'Interests',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                InterestsGrid(
                                    interests: _currentUser!.interests),
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
                              AstrologyCompatibilityCard(user: _currentUser!),
                              const SizedBox(height: 24),

                              // Quick Actions
                              _buildQuickActions(),
                              const SizedBox(height: 100), // Bottom padding
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ✅ THIS METHOD WAS MISSING - NOW ADDED
  Widget _buildCompletionCTA() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_completionPercentage% complete',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileCompletionScreen(),
                ),
              );
              _refreshProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Complete',
              style: TextStyle(
                color: Color(0xFF7B2CBF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.auto_awesome,
          title: 'Astrology Questionnaire',
          subtitle: 'Update your cosmic profile',
          color: const Color(0xFFFFD700),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AstrologyQuestionnaireScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.assignment,
          title: 'Profile Completion',
          subtitle: 'Complete optional sections',
          color: const Color(0xFF7B2CBF),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfileCompletionScreen(),
              ),
            );
            _refreshProfile();
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.photo_camera,
          title: 'Change Avatar',
          subtitle: 'Pick a new avatar',
          color: const Color(0xFF00BCD4),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Avatar selection coming soon!'),
                backgroundColor: Color(0xFF7B2CBF),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D1B4E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFB39DDB),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFB39DDB),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please try again',
            style: TextStyle(
              color: Color(0xFFB39DDB),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}