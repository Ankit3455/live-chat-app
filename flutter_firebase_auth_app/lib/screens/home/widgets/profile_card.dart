import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../core/services/location_service.dart';


class ProfileCard extends StatelessWidget {
  final UserModel user;
  final UserModel? currentUser;
  final VoidCallback onTap;

  const ProfileCard({
    super.key,
    required this.user,
    this.currentUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate distance if both users have location
    String? distanceText;
    if (currentUser?.userLatitude != null &&
        currentUser?.userLongitude != null &&
        user.userLatitude != null &&
        user.userLongitude != null) {
      distanceText = LocationUtils.getDistanceText(
        currentUser!.userLatitude,
        currentUser!.userLongitude,
        user.userLatitude,
        user.userLongitude,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2D1B4E).withOpacity(0.8),
              const Color(0xFF1A0E2E).withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF7B2CBF).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B2CBF).withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image
            Stack(
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    image: user.profileImage.isNotEmpty
                        ? DecorationImage(
                      image: NetworkImage(user.profileImage),
                      fit: BoxFit.cover,
                    )
                        : null,
                    gradient: user.profileImage.isEmpty
                        ? const LinearGradient(
                      colors: [Color(0xFF7B2CBF), Color(0xFFC77DFF)],
                    )
                        : null,
                  ),
                  child: user.profileImage.isEmpty
                      ? Center(
                    child: Text(
                      user.username.isNotEmpty
                          ? user.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold),
                    ),
                  )
                      : null,
                ),
                // Online indicator
                if (user.online)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                // Match percentage
                if (user.matchPercentage != null && user.matchPercentage! > 0)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite, color: Colors.pinkAccent, size: 14),
                          const SizedBox(width: 4),
                          Text('${user.matchPercentage}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Age
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.username,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.age != null)
                        Text(
                          ', ${user.age}',
                          style: const TextStyle(color: Color(0xFFB39DDB), fontSize: 14),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Location OR Distance
                  if (distanceText != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFB39DDB), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          distanceText,
                          style: const TextStyle(color: Color(0xFFB39DDB), fontSize: 12),
                        ),
                      ],
                    )
                  else if (user.location != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFB39DDB), size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            user.location!,
                            style: const TextStyle(color: Color(0xFFB39DDB), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  // Profession
                  if (user.profession != null)
                    Row(
                      children: [
                        const Icon(Icons.work_outline, color: Color(0xFFB39DDB), size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            user.profession!,
                            style: const TextStyle(color: Color(0xFFB39DDB), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  // Interests
                  if (user.interests.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: user.interests.take(2).map((interest) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B2CBF).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF7B2CBF).withOpacity(0.5)),
                          ),
                          child: Text(
                            interest,
                            style: const TextStyle(color: Color(0xFFC77DFF), fontSize: 10),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}