import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// Core
import 'package:availchat/core/constants/app_colors.dart';

// Models
import 'package:availchat/models/user_model.dart';

// Screens
import 'package:availchat/screens/chat/chat_screen.dart';
import 'package:availchat/screens/settings/discovery_settings_screen.dart';
import 'package:availchat/screens/shell/main_shell.dart';

// Widgets
import 'widgets/profile_bubble.dart';
import 'widgets/profile_card.dart';
import 'widgets/profile_completion_banner.dart';

// Shimmers
import 'package:availchat/widgets/shimmers/shimmer_bubble.dart';

// Onboarding
import '../../features/onboarding/home_onboarding.dart';

// Controller (Logic)
import 'home_controller.dart';

/// Signed-in entry point (used by AuthRouter). Hosts the tab shell; the
/// Discover feed itself is [DiscoverTab].
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const MainShell();
}

/// Discover tab: the profile feed. Lives inside [MainShell].
class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  // ===========================================================================
  // Controller & Keys
  // ===========================================================================
  late final HomeController _controller;
  final HomeTourKeys _tourKeys = HomeTourKeys();
  bool _autoTourRequested = false;
  ValueListenable<int>? _shellTab;

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _controller.addListener(_onControllerUpdate);
    _controller.initialize();

    HomeOnboarding.attach(_tourKeys, onReplay: _showTutorial);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartAutoTour());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tab = MainShell.maybeOf(context)?.tabListenable;
    if (!identical(tab, _shellTab)) {
      _shellTab?.removeListener(_onShellTabChanged);
      _shellTab = tab;
      _shellTab?.addListener(_onShellTabChanged);
    }
  }

  @override
  void dispose() {
    _shellTab?.removeListener(_onShellTabChanged);
    HomeOnboarding.detach(_tourKeys);
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});
    _maybeStartAutoTour();
  }

  void _onShellTabChanged() => _maybeStartAutoTour();

  bool get _isVisibleTab =>
      (_shellTab?.value ?? MainShell.discoverTab) == MainShell.discoverTab;

  // ===========================================================================
  // Onboarding
  // ===========================================================================

  /// First-run tour starts once the grid first has profiles to point at.
  void _maybeStartAutoTour() {
    if (_autoTourRequested || !mounted || !_isVisibleTab) return;
    if (_controller.isLoading || _controller.displayedUsers.isEmpty) return;
    _autoTourRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Don't cover a pushed screen or another tab; retry on the next update.
      if (ModalRoute.of(context)?.isCurrent == false || !_isVisibleTab) {
        _autoTourRequested = false;
        return;
      }
      HomeOnboarding.tryShow(context, _tourKeys);
    });
  }

  /// Manual replay (Settings > View App Tutorial). Switches to Discover first.
  void _showTutorial() {
    if (!mounted) return;
    MainShell.maybeOf(context)?.selectTab(MainShell.discoverTab);
    HomeOnboarding.showManually(context, keys: _tourKeys);
  }

  // ===========================================================================
  // Event Handlers
  // ===========================================================================

  Future<void> _onRefresh() async {
    await _controller.refresh();
  }

  Future<void> _openDiscoverySettings() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiscoverySettingsScreen()),
    );
    if (changed == true) {
      await _controller.onFiltersChanged();
    }
  }

  void _navigateToChat(UserModel user) {
    if (!_controller.isValidUserForChat(user)) {
      _showSnackBar('Unable to open chat. Invalid user.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(otherUserId: user.uid!),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.brandPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // UI COMPONENTS
  // ===========================================================================

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned.fill(
          child: Lottie.asset(
            'assets/animations/space.json',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.backgroundDeep, AppColors.backgroundDarkest],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.3)),
        ),
      ],
    );
  }


  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Discover',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            tooltip: 'Discovery filters',
            onPressed: _openDiscoverySettings,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Error State
    if (_controller.error != null) {
      return _buildErrorState();
    }

    // Loading State
    if (_controller.isLoading) {
      return _buildLoadingState();
    }

    // Empty State
    if (_controller.displayedUsers.isEmpty) {
      return _buildEmptyState();
    }

    // Users List
    return _buildUsersList();
  }

  Widget _buildLoadingState() {
    return const Column(
      children: [
        SizedBox(height: 8),
        ShimmerBubbleStrip(),
        SizedBox(height: 16),
        Expanded(child: ShimmerBubbleGrid()),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.redAccent.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            _controller.error ?? 'Something went wrong',
            style: const TextStyle(color: AppColors.lavender, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
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
          Icon(
            Icons.people_outline,
            size: 100,
            color: AppColors.lavender.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No users found',
            style: TextStyle(
              color: AppColors.lavender,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filters',
            style: TextStyle(color: AppColors.lavender, fontSize: 14),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _openDiscoverySettings,
            icon: const Icon(Icons.tune),
            label: const Text('Adjust Filters'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandPurpleLight,
              side: const BorderSide(color: AppColors.brandPurple),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.brandPurple,
      backgroundColor: AppColors.surfaceCard,
      child: Column(
        children: [
          // Profile Completion Banner
          if (_controller.showBanner)
            ProfileCompletionBanner(
              completionPercentage: _controller.profileCompletionPercentage,
              onDismiss: _controller.dismissBanner,
            ),

          // Top Matches Bubbles
          _buildTopMatchesBubbles(),

          // Profile Grid
          Expanded(child: _buildProfileGrid()),
        ],
      ),
    );
  }

  Widget _buildTopMatchesBubbles() {
    final topUsers = _controller.topUsers;
    if (topUsers.isEmpty) return const SizedBox.shrink();

    return Container(
      key: _tourKeys.bubbles,
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: topUsers.length,
        itemBuilder: (context, index) {
          final user = topUsers[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ProfileBubble(
              user: user,
              onTap: () => _navigateToChat(user),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileGrid() {
    final users = _controller.displayedUsers;

    final grid = GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];

        final profileCard = ProfileCard(
          user: user,
          currentUser: _controller.currentUser,
          onTap: () => _navigateToChat(user),
        );

        // Onboarding keys
        if (index == 0) {
          return Container(
            key: _tourKeys.firstGridItem,
            child: profileCard,
          );
        } else if (index == 1) {
          return Container(
            key: _tourKeys.secondGridItem,
            child: profileCard,
          );
        }

        return profileCard;
      },
    );

    // Paginated feed: fetch the next page near the end of the grid.
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 600) {
          _controller.loadMore();
        }
        return false;
      },
      child: Stack(
        children: [
          grid,
          if (_controller.isLoadingMore)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
