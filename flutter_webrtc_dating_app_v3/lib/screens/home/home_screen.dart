import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Core
import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/core/utils/compatibility_utils.dart';
import 'package:availchat/core/utils/discover_picks.dart';
import 'package:availchat/managers/filter_preferences.dart';

// Models
import 'package:availchat/models/user_model.dart';

// Screens
import 'package:availchat/screens/chat/chat_screen.dart';
import 'package:availchat/services/presence_watch.dart';
import 'package:availchat/screens/home/user_search_screen.dart';
import 'package:availchat/screens/profile/profile_details_screen.dart';
import 'package:availchat/screens/questionnaire/deck/deck_widgets.dart';
import 'package:availchat/screens/questionnaire/profile_completion_screen.dart';
import 'package:availchat/screens/settings/discovery_settings_screen.dart';
import 'package:availchat/screens/shell/main_shell.dart';

// Widgets
import 'widgets/cosmic_match_card.dart';
import 'widgets/orbit_view.dart';
import 'widgets/tonights_draw.dart';

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

/// Discover tab ("Tonight's Draw"): today's three most compatible people,
/// a zoomable orbit of who's around, and cosmic match cards. Lives inside
/// [MainShell].
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

  /// Quick lens over the loaded feed (chips above the match cards).
  _Lens _lens = _Lens.forYou;

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

  Future<void> _openCompletion() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileCompletionScreen()),
    );
    if (mounted) await _controller.refresh();
  }

  void _pass(UserModel user) {
    unawaited(_controller.pass(user));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${user.username} hidden for a week'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => unawaited(_controller.undoPass(user)),
          ),
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
    final filterLabels = _activeFilterLabels();
    return Scaffold(
      backgroundColor: AppColors.backgroundDarkest,
      body: DeckBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  _buildHeader(filterLabels.isNotEmpty),
                  Expanded(child: _buildFeed(filterLabels)),
                ],
              ),
            ),
          ),
        ),
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

  Widget _buildHeader(bool filtersActive) {
    final me = _controller.currentUser;
    final now = DateTime.now();
    final moon = DiscoverPicks.moonPhase(now);
    final name = (me?.username ?? '').trim();
    final pct = _controller.profileCompletionPercentage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 4),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Profile $pct% complete. Complete your profile',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _openCompletion,
              child: SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 2.5,
                        backgroundColor: Colors.white.withOpacity(.12),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.gold),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ClipOval(
                          child: me == null
                              ? const ColoredBox(color: AppColors.surface2)
                              : DiscoverPhoto(user: me, memCacheWidth: 140),
                        ),
                      ),
                    ),
                    if (pct < 100)
                      Positioned(
                        right: -6,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$pct%',
                            style: const TextStyle(
                              color: Color(0xFF2A1700),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${moon.emoji} ${moon.name} · tonight',
                  style: deckSerif(13, color: AppColors.gold, italic: true),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    name.isEmpty || name == 'Unknown'
                        ? DiscoverPicks.greeting(now)
                        : '${DiscoverPicks.greeting(now)}, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: deckSerif(21),
                  ),
                ),
              ],
            ),
          ),
          _HeaderButton(
            icon: Icons.search_rounded,
            label: 'Search users',
            onTap: _openSearch,
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            icon: Icons.tune_rounded,
            label: 'Discovery filters',
            dot: filtersActive,
            onTap: _openDiscoverySettings,
          ),
        ],
      ),
    );
  }

  /// One scroll view: draw, nudge, orbit and match cards scroll together.
  Widget _buildFeed(List<String> filterLabels) {
    final filtersActive = filterLabels.isNotEmpty;
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.brandPurple,
      backgroundColor: AppColors.surfaceCard,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onFeedScroll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (filtersActive)
              SliverToBoxAdapter(child: _buildFilterChips(filterLabels)),
            ..._buildStateSlivers(filtersActive),
          ],
        ),
      ),
    );
  }

  // Paginated feed: fetch the next page near the end of the list.
  bool _onFeedScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical &&
        n.metrics.extentAfter < 900 &&
        _controller.displayedUsers.isNotEmpty) {
      unawaited(_controller.loadMore());
    }
    return false;
  }

  List<UserModel> _applyLens(List<UserModel> users) {
    final me = _controller.currentUser;
    final presence = PresenceWatch.instance;
    switch (_lens) {
      case _Lens.forYou:
        return users;
      case _Lens.bestMatch:
        int score(UserModel u) =>
            CompatibilityService.compatibilityScore(me, u) ?? -1;
        return [...users]..sort((a, b) => score(b).compareTo(score(a)));
      case _Lens.nearby:
        int km(UserModel u) => _controller.distanceKmFor(u) ?? 1 << 30;
        return [...users]..sort((a, b) => km(a).compareTo(km(b)));
      case _Lens.online:
        return users.where((u) => presence.isOnline(u.uid)).toList();
      case _Lens.voice:
        return users
            .where((u) => (u.voiceIntroUrl ?? '').trim().isNotEmpty)
            .toList();
      case _Lens.signs:
        final wanted = me?.preferredSigns.toSet() ?? const <String>{};
        return users
            .where((u) => wanted.contains(CompatibilityService.signOf(u)))
            .toList();
    }
  }

  List<Widget> _buildStateSlivers(bool filtersActive) {
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

    if (_controller.isLoading) return [_buildSkeleton()];

    // Online state comes from RTDB presence; the users' `online` field goes
    // stale when an app is killed.
    final presence = PresenceWatch.instance;
    final allUsers = _controller.displayedUsers;
    final users = _controller.filters.onlineOnly
        ? allUsers.where((u) => presence.isOnline(u.uid)).toList()
        : allUsers;
    if (users.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(filtersActive),
        ),
      ];
    }

    final me = _controller.currentUser;
    final picks = DiscoverPicks.tonightsDraw(users, me, DateTime.now());
    final matches = _applyLens(users);

    return [
      SliverToBoxAdapter(
        child: KeyedSubtree(
          key: _tourKeys.bubbles,
          child: TonightsDraw(picks: picks, me: me, onOpen: _openProfile),
        ),
      ),
      if (_controller.showBanner) SliverToBoxAdapter(child: _buildDeckNudge()),
      SliverToBoxAdapter(
        child: _buildSectionTitle(
          'In your orbit',
          'Pinch or slide to explore',
        ),
      ),
      SliverToBoxAdapter(
        child: KeyedSubtree(
          key: _tourKeys.firstGridItem,
          child: OrbitZoom(
            me: me,
            people: users,
            distanceKmOf: _controller.distanceKmFor,
            onOpen: _openProfile,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: _buildSectionTitle(
          'Cosmic matches',
          _lens == _Lens.forYou ? 'Recently active' : _lens.caption,
        ),
      ),
      SliverToBoxAdapter(child: _buildLensChips(me)),
      if (matches.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 8),
            child: Text(
              'No one matches this right now. Try another chip ✦',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.lavender, fontSize: 13),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.separated(
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final user = matches[index];
              final card = CosmicMatchCard(
                key: ValueKey('match-${user.uid}'),
                user: user,
                me: me,
                distanceKm: _controller.distanceKmFor(user),
                onView: () => _openProfile(user),
                onSayHi: () => _navigateToChat(user),
                onPass: () => _pass(user),
              );
              // Onboarding tour target ("hold for a quick look").
              if (index == 0) {
                return KeyedSubtree(key: _tourKeys.secondGridItem, child: card);
              }
              return card;
            },
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 22, 0, 120),
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
              : const Text(
                  "✦ That's everyone for now. New stars rise every day.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSubtle, fontSize: 12),
                ),
        ),
      ),
    ];
  }

  Widget _buildDeckNudge() {
    final pct = _controller.profileCompletionPercentage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openCompletion,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: [
                AppColors.gold.withOpacity(.14),
                AppColors.brandPurple.withOpacity(.14),
              ]),
              border: Border.all(color: AppColors.gold.withOpacity(.3)),
            ),
            child: Row(
              children: [
                const Text('🃏', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your profile is $pct% drawn', style: deckSerif(16)),
                      const Text(
                        'Finish your Destiny Deck to stand out in Discover',
                        style: TextStyle(
                            color: AppColors.lavender, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  onPressed: _controller.dismissBanner,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLensChips(UserModel? me) {
    final lenses = [
      for (final l in _Lens.values)
        if (l != _Lens.signs || (me?.preferredSigns.isNotEmpty ?? false)) l,
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: lenses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final l = lenses[i];
          final on = l == _lens;
          return Semantics(
            button: true,
            selected: on,
            label: l.label,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => setState(() => _lens = l),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: on ? deckGradient : null,
                  color: on ? null : AppColors.surfaceCard.withOpacity(.85),
                  border: Border.all(
                    color: on ? Colors.transparent : AppColors.border,
                  ),
                ),
                child: Text(
                  l.label,
                  style: TextStyle(
                    color: on ? Colors.white : AppColors.lavenderLight,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(List<String> labels) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final label in labels)
            Container(
              constraints: const BoxConstraints(minHeight: 30),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.brandPurpleMid.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.brandPurpleMid),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.brandPurpleLight,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String caption) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: deckSerif(23)),
            ),
          ),
          Text(
            caption,
            style: const TextStyle(color: AppColors.textSubtle, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    Widget block(double h) => Container(
          height: h,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surfaceCard, AppColors.surface2],
            ),
          ),
        );
    return SliverToBoxAdapter(
      child: Semantics(
        label: 'Loading people',
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: block(196)),
                  ],
                ],
              ),
            ),
            block(330),
            block(420),
          ],
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

/// Quick views over the loaded feed.
enum _Lens {
  forYou('✦ For you', 'Recently active'),
  bestMatch('💞 Best match', 'Most compatible first'),
  nearby('📍 Nearby', 'Closest first'),
  online('🟢 Online', 'Online now'),
  voice('🎙️ Voice intro', 'Has a voice intro'),
  signs('♎ Your signs', 'Signs you vibe with');

  final String label;
  final String caption;
  const _Lens(this.label, this.caption);
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dot;
  final VoidCallback onTap;
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: dot ? '$label, active' : label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceCard.withOpacity(.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: AppColors.lavenderLight, size: 20),
                if (dot)
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.brandPink,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.backgroundDeep,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
