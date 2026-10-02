import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../bottom_navigation/managers/firestore_manager.dart';
import '../../core/constants/app_colors.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../chat/chat_screen.dart';
import 'widgets/custom_drawer.dart';
import 'widgets/profile_bubble.dart';
import 'widgets/profile_card.dart';
import 'widgets/profile_completion_banner.dart';
import 'home_logic.dart';

class HomeUI extends StatefulWidget {
  const HomeUI({Key? key}) : super(key: key);

  @override
  State<HomeUI> createState() => _HomeUIState();
}

class _HomeUIState extends State<HomeUI> {
  bool _showProfileCompletion = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final manager = context.read<FirestoreManager>();
    await manager.loadUsers(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FirestoreManager>(
      builder: (context, manager, child) {
        return Scaffold(
          backgroundColor: AppColors.appBackground,
          drawer: _buildDrawer(manager),
          appBar: _buildAppBar(),
          body: _buildBody(manager),
          floatingActionButton: _buildFAB(),
        );
      },
    );
  }

  // ==================== UI BUILDERS ====================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.purplePrimary,
      title: const Text('Discover', style: TextStyle(color: Colors.white)),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white),
          onPressed: _handleNotifications,
        ),
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white),
          onPressed: _handleFilterSettings,
        ),
      ],
    );
  }

  Widget _buildDrawer(FirestoreManager manager) {
    return CustomDrawer(
      currentUser: manager.currentUser,
      onSignOut: _handleSignOut,
      onAstrologyTap: _handleAstrologyTap,
    );
  }

  Widget _buildBody(FirestoreManager manager) {
    // Loading state
    if (manager.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.purplePrimary),
      );
    }

    // Error state
    if (manager.error != null) {
      return _buildErrorState(manager.error!);
    }

    // Empty state
    if (manager.filteredUsers.isEmpty) {
      return _buildEmptyState();
    }

    // Success - Show content
    return RefreshIndicator(
      onRefresh: _loadUsers,
      color: AppColors.purplePrimary,
      child: Column(
        children: [
          // Profile Completion Banner
          if (_showProfileCompletion &&
              manager.currentUser != null &&
              (manager.currentUser!.profileCompletionPercentage ?? 100) < 100)
            ProfileCompletionBanner(
              completionPercentage:
              manager.currentUser!.profileCompletionPercentage ?? 65,
              onDismiss: () {
                setState(() {
                  _showProfileCompletion = false;
                });
              },
            ),

          // Horizontal Stories/Top Profiles
          if (manager.getTopUsers(limit: 10).isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: manager.getTopUsers(limit: 10).length,
                itemBuilder: (context, index) {
                  final user = manager.getTopUsers(limit: 10)[index];
                  return ProfileBubble(
                    user: user,
                    onTap: () => _handleUserTap(user),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Grid of Profile Cards
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                itemCount: manager.filteredUsers.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemBuilder: (context, index) {
                  final user = manager.filteredUsers[index];
                  return ProfileCard(
                    user: user,
                    currentUser: manager.currentUser,
                    onTap: () => _handleUserTap(user),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.dangerRed),
          const SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(color: AppColors.hintPurple),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUsers,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purplePrimary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 64, color: AppColors.hintPurple),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: TextStyle(fontSize: 18, color: AppColors.hintPurple),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(fontSize: 14, color: AppColors.hintPurple),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      backgroundColor: AppColors.purplePrimary,
      onPressed: _handleExplore,
      child: const Icon(Icons.explore),
    );
  }

  // ==================== EVENT HANDLERS ====================

  Future<void> _handleUserTap(user) async {
    if (user.uid == null || user.uid!.isEmpty) {
      _showSnackBar('Cannot interact with this user');
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.purplePrimary),
      ),
    );

    try {
      final chatService = ChatService();
      final conversationId = await chatService.getOrCreateConversation(user.uid!);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            otherUserId: user.uid!,
            conversationId: conversationId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      _showSnackBar('Failed to open chat: $e');
    }
  }

  void _handleNotifications() {
    // TODO: Navigate to notifications
    debugPrint('Notifications tapped');
  }

  void _handleFilterSettings() {
    // TODO: Navigate to discovery settings
    debugPrint('Filter settings tapped');
  }

  void _handleExplore() {
    // TODO: Navigate to explore
    debugPrint('Explore tapped');
  }

  Future<void> _handleSignOut() async {
    try {
      final authService = context.read<AuthService>();
      await authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      _showSnackBar('Sign out failed: $e');
    }
  }

  void _handleAstrologyTap() {
    // TODO: Navigate to astrology
    debugPrint('Astrology tapped');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.purplePrimary,
      ),
    );
  }
}