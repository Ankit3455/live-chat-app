import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/feature/games/game_list_screen.dart';
import 'package:availchat/screens/chat/chat_list_screen.dart';
import 'package:availchat/screens/home/home_screen.dart';
import 'package:availchat/screens/home/widgets/custom_bottom_nav.dart';
import 'package:availchat/screens/profile/profile_screen.dart';

/// Signed-in root: Discover, Chats, Games and Profile behind one persistent
/// bottom nav. Tabs live in an IndexedStack so they keep their state.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const int discoverTab = 0;
  static const int chatsTab = 1;
  static const int gamesTab = 2;
  static const int profileTab = 3;

  static MainShellState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  // Games is an embedded tab: GameListScreen hides its back button when it
  // cannot pop. Set to false to open it as a pushed route instead.
  static const bool _embedGames = true;

  final ValueNotifier<int> _tab = ValueNotifier<int>(MainShell.discoverTab);

  // Tabs are built on first visit, so Chats/Profile do not load at start-up.
  final Set<int> _visited = {MainShell.discoverTab};

  int get currentIndex => _tab.value;

  /// Notifies listeners when the visible tab changes.
  ValueListenable<int> get tabListenable => _tab;

  void selectTab(int index) {
    if (index == MainShell.gamesTab && !_embedGames) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GameListScreen()),
      );
      return;
    }
    if (index == _tab.value) return;
    setState(() => _visited.add(index));
    _tab.value = index;
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Widget _buildTab(int index) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    switch (index) {
      case MainShell.discoverTab:
        return const DiscoverTab();
      case MainShell.chatsTab:
        return const ChatListScreen();
      case MainShell.gamesTab:
        return _embedGames ? const GameListScreen() : const SizedBox.shrink();
      case MainShell.profileTab:
        return const ProfileScreen();
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final index = _tab.value;
    return PopScope(
      // Back from any other tab goes to Discover; back on Discover exits.
      canPop: index == MainShell.discoverTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) selectTab(MainShell.discoverTab);
      },
      child: Scaffold(
        backgroundColor: AppColors.appBackground,
        body: IndexedStack(
          index: index,
          // Hidden tabs keep their state but not their animations: IndexedStack
          // alone leaves their tickers running (frames scheduled while idle).
          children: List.generate(
            4,
            (i) => TickerMode(enabled: i == index, child: _buildTab(i)),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: CustomBottomNav(
              currentIndex: index,
              onTap: selectTab,
            ),
          ),
        ),
      ),
    );
  }
}
