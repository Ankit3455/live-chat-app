import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// Core
import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/managers/filter_preferences.dart';

// Models
import 'package:availchat/models/user_model.dart';

// Screens
import 'package:availchat/screens/chat/chat_screen.dart';
import 'package:availchat/services/presence_watch.dart';
import 'package:availchat/screens/home/user_search_screen.dart';
import 'package:availchat/screens/profile/profile_details_screen.dart';
import 'package:availchat/screens/settings/discovery_settings_screen.dart';
import 'package:availchat/screens/shell/main_shell.dart';

// Widgets
import 'widgets/profile_bubble.dart';
import 'widgets/profile_card.dart';
import 'widgets/profile_completion_banner.dart';

import 'package:availchat/widgets/app_states.dart';

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
    PresenceWatch.instance.online.addListener(_onControllerUpdate);
    HomeOnboarding.showing.addListener(_onControllerUpdate);
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
    PresenceWatch.instance.online.removeListener(_onControllerUpdate);
    HomeOnboarding.showing.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});
    _maybeStartAutoTour();
  }

  void _onShellTabChanged() => _maybeStartAutoTour();

  /// Online list frozen while the home tour is showing.
  List<UserModel>? _onlineDuringTour;

  bool get _isVisibleTab =>
      (_shellTab?.value ?? MainShell.discoverTab) == MainShell.discoverTab;

  // ===========================================================================
  // Onboarding
  // ===========================================================================

  /// First-run tour starts once the grid first has profiles to point at.
  void _maybeStartAutoTour() {
    if (_autoTourRequested || !mounted || !_isVisibleTab) return;
    if (_controller.isLoading || _controller.displayedUsers.isEmpty) return;
    // The profile banner can still appear and push the grid down; the tour
    // would then spotlight the old position.
    if (!_controller.profileChecked) return;
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

  Future<void> _clearFilters() => _controller.clearFilters();

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserSearchScreen()),
    );
  }

  void _openProfile(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileDetailsScreen(user: user)),
    );
  }

  void _navigateToChat(UserModel user) {
    if (!_controller.isValidUserForChat(user)) {
      _showSnackBar("Couldn't open this chat. Please try again.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(otherUserId: user.uid!, initialUser: user),
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

  // More columns on tablets: 3 at >= 600dp, 4 at >= 900dp.
  static SliverGridDelegate _gridDelegateFor(double width) {
    final columns = width >= 900
        ? 4
        : width >= 600
            ? 3
            : 2;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      childAspectRatio: 4 / 5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterLabels = _activeFilterLabels();
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(filterLabels.isNotEmpty),
                Expanded(child: _buildFeed(filterLabels)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Filters
  // ===========================================================================

  /// Chip labels for the filters that currently narrow the feed.
  List<String> _activeFilterLabels() {
    final f = _controller.filters;
    if (!f.applyFilters) return const [];

    String? gender;
    if (f.gender == 'male') {
      gender = 'Men';
    } else if (f.gender == 'female') {
      gender = 'Women';
    }
    final ageNarrowed = f.ageMin > FilterPreferences.minAllowedAge ||
        f.ageMax < FilterPreferences.maxAllowedAge;
    final ages = '${f.ageMin}–${f.ageMax}';

    return [
      if (gender != null && ageNarrowed)
        '$gender · $ages'
      else if (gender != null)
        gender
      else if (ageNarrowed)
        'Ages $ages',
      if (f.distanceKm > 0) 'Within ${f.distanceKm} km',
      if (f.onlineOnly) 'Online only',
    ];
  }

  // ===========================================================================
  // UI COMPONENTS
  // ===========================================================================

  Widget _buildBackground() {
    return Stack(
      children: [
        // A still frame in its own layer: animating this full-screen Lottie
        // repainted every frame (also while idle) and made scrolling jank on
        // phones.
        Positioned.fill(
          child: RepaintBoundary(
            child: Lottie.asset(
              'assets/animations/space.json',
              fit: BoxFit.cover,
              animate: false,
              errorBuilder: (context, error, stackTrace) {
                return const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.backgroundDeep,
                        AppColors.backgroundDarkest,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned.fill(
          child: ColoredBox(color: AppColors.black.withOpacity(0.3)),
        ),
      ],
    );
  }

  Widget _buildHeader(bool filtersActive) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Discover',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Search users',
            onPressed: _openSearch,
            icon: const Icon(Icons.search_rounded, color: AppColors.white),
          ),
          IconButton(
            tooltip: 'Discovery filters',
            onPressed: _openDiscoverySettings,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.white),
                if (filtersActive)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.brandPink,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.backgroundDeep,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One scroll view: chips, nudge, online strip and grid all scroll together.
  Widget _buildFeed(List<String> filterLabels) {
    final filtersActive = filterLabels.isNotEmpty;
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.brandPurple,
      backgroundColor: AppColors.surfaceCard,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onFeedScroll,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final grid = _gridDelegateFor(constraints.maxWidth);
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (filtersActive)
                  SliverToBoxAdapter(child: _buildFilterChips(filterLabels)),
                ..._buildStateSlivers(filtersActive, grid),
              ],
            );
          },
        ),
      ),
    );
  }

  // Paginated feed: fetch the next page near the end of the grid.
  bool _onFeedScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical &&
        n.metrics.extentAfter < 600 &&
        _controller.displayedUsers.isNotEmpty) {
      unawaited(_controller.loadMore());
    }
    return false;
  }

  List<Widget> _buildStateSlivers(bool filtersActive, SliverGridDelegate grid) {
    if (_controller.error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            icon: Icons.cloud_off_outlined,
            illustration: AppIllustrationKind.offline,
            title: "Couldn't load people",
            message: 'Check your internet connection, then try again.',
            actionLabel: 'Try again',
            onAction: _onRefresh,
          ),
        ),
      ];
    }

    if (_controller.isLoading) return [_buildSkeletonGrid(grid)];

    // Online state comes from RTDB presence; the users' `online` field goes
    // stale when an app is killed.
    final presence = PresenceWatch.instance;
    final allUsers = _controller.displayedUsers;
    var online = allUsers.where((u) => presence.isOnline(u.uid)).toList();
    // Keep the "Online now" strip as it was while the tour is up, so the
    // spotlighted widgets don't move under it.
    if (HomeOnboarding.showing.value) {
      online = _onlineDuringTour ??= online;
    } else {
      _onlineDuringTour = null;
    }
    final users = _controller.filters.onlineOnly ? online : allUsers;
    if (users.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(filtersActive),
        ),
      ];
    }

    return [
      if (_controller.showBanner)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: ProfileCompletionBanner(
              completionPercentage: _controller.profileCompletionPercentage,
              onDismiss: _controller.dismissBanner,
            ),
          ),
        ),
      if (online.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _buildSectionTitle(
            'Online now',
            online.length == 1 ? '1 person' : '${online.length} people',
          ),
        ),
        SliverToBoxAdapter(child: _buildOnlineStrip(online.take(20).toList())),
      ],
      SliverToBoxAdapter(
        child: _buildSectionTitle('For you', 'Recently active'),
      ),
      _buildProfileGrid(users, grid),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: _controller.isLoadingMore
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandPurpleLight,
                    ),
                  ),
                )
              : const SizedBox(height: 24),
        ),
      ),
    ];
  }

  Widget _buildFilterChips(List<String> labels) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final label in labels)
            Container(
              constraints: const BoxConstraints(minHeight: 32),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brandPurpleMid.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.brandPurpleMid),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.brandPurpleLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String caption) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Text(caption, style: textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildOnlineStrip(List<UserModel> users) {
    return SizedBox(
      key: _tourKeys.bubbles,
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final user = users[index];
          return Align(
            alignment: Alignment.topCenter,
            child: ProfileBubble(
              user: user,
              onTap: () => _navigateToChat(user),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileGrid(List<UserModel> users, SliverGridDelegate grid) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: grid,
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final user = users[index];
            final card = ProfileCard(
              user: user,
              currentUser: _controller.currentUser,
              distanceKm: _controller.distanceKmFor(user),
              onTap: () => _openProfile(user),
              onMessage: () => _navigateToChat(user),
            );

            // Onboarding tour targets.
            if (index == 0) {
              return KeyedSubtree(key: _tourKeys.firstGridItem, child: card);
            }
            if (index == 1) {
              return KeyedSubtree(key: _tourKeys.secondGridItem, child: card);
            }
            return card;
          },
          childCount: users.length,
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid(SliverGridDelegate grid) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      sliver: SliverGrid(
        gridDelegate: grid,
        delegate: SliverChildBuilderDelegate(
          (_, index) => Semantics(
            label: index == 0 ? 'Loading people' : null,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.surfaceCard, AppColors.surface2],
                ),
              ),
            ),
          ),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool filtersActive) {
    final String message;
    if (!filtersActive) {
      message = 'Check back soon — new people join every day.';
    } else if (_controller.filters.onlineOnly) {
      message = 'Your filters are narrow. Widen the distance or turn off '
          '“Online only” to see more people.';
    } else {
      message = 'Your filters are narrow. Widen the distance or age range '
          'to see more people.';
    }

    return AppEmptyState(
      icon: Icons.nights_stay_outlined,
      illustration: AppIllustrationKind.noResults,
      title: 'No one new right now',
      message: message,
      actionLabel: 'Adjust filters',
      onAction: _openDiscoverySettings,
      secondaryLabel: filtersActive ? 'Clear all filters' : null,
      onSecondary: filtersActive ? _clearFilters : null,
    );
  }
}
