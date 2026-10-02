import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
final int currentIndex;
final Function(int) onTap;

const CustomBottomNav({
super.key,
required this.currentIndex,
required this.onTap,
});

@override
Widget build(BuildContext context) {
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
_buildNavItem(Icons.explore, 'Discover', 0),
_buildNavItem(Icons.chat_bubble, 'Chats', 1),
_buildNavItem(Icons.games, 'Games', 2),
_buildNavItem(Icons.person, 'Profile', 3),
],
),
);
}

Widget _buildNavItem(IconData icon, String label, int index) {
final isSelected = currentIndex == index;

return GestureDetector(
  onTap: () => onTap(index),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      gradient: isSelected
          ? const LinearGradient(
              colors: [Color(0xFF7B2CBF), Color(0xFFC77DFF)],
            )
          : null,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isSelected ? Colors.white : const Color(0xFFB39DDB),
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFB39DDB),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  ),
);
}
}