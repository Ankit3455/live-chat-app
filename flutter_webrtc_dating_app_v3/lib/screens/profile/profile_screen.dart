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
import 'package:availchat/services/profile_photo_service.dart';
import 'package:availchat/widgets/user_avatar.dart';
import 'package:availchat/widgets/avatar_story.dart';
import '../../core/constants/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;
  String? _loadError;
  bool _avatarBusy = false;
  int _completionPercentage = 0;

  @override
  void initState() {
    super.initState();
    // Deferred so the signed-out path never calls setState during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserData());
  }

  Future<void> _loadUserData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _currentUser = null;
            _loadError = 'You are signed out. Please sign in again.';
          });
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!mounted) return;

      if (!doc.exists) {
        setState(() {
          _currentUser = null;
          _loadError = 'We could not find your profile.';
        });
        return;
      }

      setState(() {
        _currentUser = UserModel.fromFirestore(doc);
        _loadError = null;
      });

      final percentage =
          await ProfileCompletionManager().getCompletionPercentage();
      if (!mounted) return;
      setState(() => _completionPercentage = percentage);
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (!mounted) return;
      if (_currentUser == null) {
        setState(() => _loadError = 'Please check your connection.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not refresh your profile.')),
        );
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshProfile() async {
    if (!mounted) return;
    // Keep the current profile on screen during a refresh; only show the
    // full-screen spinner when there is nothing to show yet.
    if (_currentUser == null) setState(() => _isLoading = true);
    await _loadUserData();
  }

  Future<void> _runAvatarAction(
    Future<Object?> Function() action, {
    required String successMessage,
  }) async {
    if (_avatarBusy) return;
    setState(() => _avatarBusy = true);
    try {
      final result = await action();
      if (!mounted) return;
      // null means the user cancelled (e.g. closed the photo picker).
      if (result == null) return;
      await _loadUserData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ProfilePhotoException
          ? e.message
          : 'Could not update your photo. Please try again.';
      debugPrint('Avatar action failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  /// "Why you look like this" for the generated avatar in use.
  void _showAvatarStorySheet() {
    final user = _currentUser;
    if (user == null || _avatarBusy) return;
    final traits = avatarTraitsFor(user);
    if (traits.isEmpty) return;
    final unique = user.avatarProperties?['avatarUnique'] == true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        void choose(Future<Object?> Function() action, String message) {
          Navigator.pop(sheetContext);
          _runAvatarAction(action, successMessage: message);
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (_, controller) => SafeArea(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lavender.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(child: UserAvatar(user: user, size: 96, borderRadius: 48)),
                const SizedBox(height: 12),
                const Text(
                  'Made from your answers',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your habits, interests and zodiac sign shaped this face.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.lavender, fontSize: 14),
                ),
                if (unique) ...[
                  const SizedBox(height: 12),
                  const Center(child: AvatarUniqueBadge()),
                ],
                const SizedBox(height: 16),
                AvatarWhyCard(traits: traits),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => choose(
                      ProfilePhotoService.regenerateAvatar,
                      'New avatar created',
                    ),
                    icon: const Icon(Icons.autorenew, size: 20),
                    label: const Text(
                      'Generate a new one',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => choose(
                      ProfilePhotoService.pickAndUploadPhoto,
                      'Profile photo updated',
                    ),
                    icon: const Icon(Icons.photo_camera_outlined, size: 20),
                    label: const Text(
                      'Upload a photo',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: AppColors.lavender.withOpacity(0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A new one still follows your answers and stays unique to you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChangeAvatarSheet() {
    final user = _currentUser;
    if (user == null || _avatarBusy) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        void choose(Future<Object?> Function() action, String message) {
          Navigator.pop(sheetContext);
          _runAvatarAction(action, successMessage: message);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(user: user, size: 88, borderRadius: 44),
                const SizedBox(height: 12),
                const Text(
                  'Change Avatar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.photo_library,
                      color: AppColors.cyan),
                  title: const Text('Upload a photo',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Choose from your gallery',
                      style: TextStyle(color: AppColors.lavender)),
                  onTap: () => choose(
                    ProfilePhotoService.pickAndUploadPhoto,
                    'Profile photo updated',
                  ),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.face, color: AppColors.brandPurpleMid),
                  title: const Text('Use my avatar',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Switch back to your generated avatar',
                      style: TextStyle(color: AppColors.lavender)),
                  onTap: () => choose(
                    ProfilePhotoService.resetToAvatar,
                    'Avatar restored',
                  ),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.autorenew, color: AppColors.gold),
                  title: const Text('Generate a new avatar',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Based on your profile answers',
                      style: TextStyle(color: AppColors.lavender)),
                  onTap: () => choose(
                    ProfilePhotoService.regenerateAvatar,
                    'New avatar created',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandPurple))
          : _currentUser == null
              ? _buildErrorState(_loadError ?? 'Please try again')
              : RefreshIndicator(
                  onRefresh: _refreshProfile,
                  color: AppColors.brandPurple,
                  backgroundColor: AppColors.surfaceCard,
                  child: CustomScrollView(
                    slivers: [
                      // App Bar with Edit & Settings
                      SliverAppBar(
                        expandedHeight: 120,
                        floating: false,
                        pinned: true,
                        backgroundColor: AppColors.surfaceCard,
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
                                  AppColors.brandPurple.withOpacity(0.3),
                                  AppColors.surfaceCard,
                                ],
                              ),
                            ),
                          ),
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            tooltip: 'Edit profile',
                            onPressed: () async {
                              if (_currentUser == null) return;
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProfileEditScreen(user: _currentUser!),
                                ),
                              );
                              if (result == true && mounted) {
                                _refreshProfile();
                              }
                            },
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.settings, color: Colors.white),
                            tooltip: 'Settings',
                            onPressed: _openSettings,
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
                                onAvatarStoryTap:
                                    avatarTraitsFor(_currentUser!).isEmpty
                                        ? null
                                        : _showAvatarStorySheet,
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
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCompletionCTA() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandPurple, AppColors.brandPurpleMid],
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
              if (mounted) _refreshProfile();
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
                color: AppColors.brandPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
          color: AppColors.gold,
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
          color: AppColors.brandPurple,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfileCompletionScreen(),
              ),
            );
            if (mounted) _refreshProfile();
          },
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.photo_camera,
          title: 'Change Avatar',
          subtitle: _avatarBusy
              ? 'Updating your photo...'
              : 'Upload a photo or use your avatar',
          color: AppColors.cyan,
          onTap: _showChangeAvatarSheet,
          trailing: _avatarBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.cyan,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.settings,
          title: 'Settings',
          subtitle: 'Account, help & support, sign out',
          color: AppColors.lavender,
          onTap: _openSettings,
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
    Widget? trailing,
  }) {
    return Semantics(
      button: true,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
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
                      color: AppColors.lavender,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.lavender,
                ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
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
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.lavender,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPurple,
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