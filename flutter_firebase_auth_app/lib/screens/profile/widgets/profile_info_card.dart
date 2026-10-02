import 'package:flutter/material.dart';
import 'package:availchat/models/user_model.dart';

class ProfileInfoCard extends StatelessWidget {
  final UserModel user;
  final int completionPercentage;

  const ProfileInfoCard({
    Key? key,
    required this.user,
    required this.completionPercentage,
  }) : super(key: key);

  String _getAvatarEmoji() {
    final List<String> avatars = [
      '😀', '😎', '🥳', '😍', '🤩', '😇',
      '🤓', '😏', '🥰', '😊', '🙂', '😃',
      '😄', '😁', '😆', '🤣', '😂', '🙃',
      '😉', '😌', '😋', '😛', '😝', '😜',
    ];
    
    final avatarIndex = user.avatar ?? 0;
    return avatars[avatarIndex % avatars.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2CBF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF7B2CBF),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    _getAvatarEmoji(),
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (user.profession != null && user.profession!.isNotEmpty)
                      Text(
                        user.profession!,
                        style: const TextStyle(
                          color: Color(0xFFB39DDB),
                          fontSize: 16,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          completionPercentage == 100
                              ? Icons.verified
                              : Icons.pending,
                          color: completionPercentage == 100
                              ? Colors.green
                              : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          completionPercentage == 100
                              ? 'Complete Profile'
                              : '$completionPercentage% Complete',
                          style: TextStyle(
                            color: completionPercentage == 100
                                ? Colors.green
                                : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bio
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF7B2CBF), thickness: 0.5),
            const SizedBox(height: 16),
            Text(
              user.bio!,
              style: const TextStyle(
                color: Color(0xFFB39DDB),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}