import 'package:flutter/material.dart';
import '../../../models/user_model.dart';

class ProfileBubble extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const ProfileBubble({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const double avatarSize = 60;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2D1B4E),
              const Color(0xFF2D1B4E).withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF7B2CBF).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF7B2CBF), Color(0xFFC77DFF)],
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1A0E2E),
                  image: user.profileImage.isNotEmpty
                      ? DecorationImage(
                    image: NetworkImage(user.profileImage),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: user.profileImage.isEmpty
                    ? Center(
                  child: Text(
                    (user.username.isNotEmpty
                        ? user.username[0]
                        : '?')
                        .toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                )
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 16,
              child: Text(
                user.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            if (user.online)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Online',
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 8,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
