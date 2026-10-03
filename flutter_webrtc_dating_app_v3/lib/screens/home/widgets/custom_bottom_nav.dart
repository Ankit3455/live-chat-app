import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../managers/unread_manager.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  /// Optional per-tab keys (e.g. onboarding targets), indexed like the tabs.
  /// Owned by the parent State so keys are never shared between instances.
  final List<GlobalKey>? itemKeys;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.itemKeys,
  });

  GlobalKey? _keyAt(int index) {
    final keys = itemKeys;
    return (keys != null && index < keys.length) ? keys[index] : null;
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<UnreadManager>().totalUnread;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2D1B4E).withOpacity(0.95),
            const Color(0xFF1A0E2E).withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: const Color(0xFF7B2CBF).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.explore,
            label: 'Discover',
            isSelected: currentIndex == 0,
            itemKey: _keyAt(0),
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.chat_bubble,
            label: 'Chats',
            isSelected: currentIndex == 1,
            badgeCount: unread,
            itemKey: _keyAt(1),
            onTap: () => onTap(1),
          ),
          _NavItem(
            icon: Icons.games,
            label: 'Games',
            isSelected: currentIndex == 2,
            itemKey: _keyAt(2),
            onTap: () => onTap(2),
          ),
          _NavItem(
            icon: Icons.tune,
            label: 'Filters',
            isSelected: currentIndex == 3,
            itemKey: _keyAt(3),
            onTap: () => onTap(3),
          ),
          _NavItem(
            icon: Icons.person,
            label: 'Profile',
            isSelected: currentIndex == 4,
            itemKey: _keyAt(4),
            onTap: () => onTap(4),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final int badgeCount;
  final GlobalKey? itemKey;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.badgeCount = 0,
    this.itemKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: itemKey,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
            colors: [Color(0xFF7B2CBF), Color(0xFFC77DFF)],
          )
              : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFB39DDB),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          icon,
          color: isSelected ? Colors.white : const Color(0xFFB39DDB),
          size: 22,
        ),
        if (badgeCount > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}