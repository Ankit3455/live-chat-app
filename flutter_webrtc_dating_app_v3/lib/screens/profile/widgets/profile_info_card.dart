// lib/screens/profile/widgets/profile_info_card.dart
import 'package:flutter/material.dart';
import 'package:availchat/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';

class ProfileInfoCard extends StatelessWidget {
  final UserModel user;
  final int completionPercentage;

  const ProfileInfoCard({
    Key? key,
    required this.user,
    required this.completionPercentage,
  }) : super(key: key);

  bool _hasProfileImage() {
    return user.profileImage.isNotEmpty &&
        (user.profileImage.startsWith('http://') ||
            user.profileImage.startsWith('https://'));
  }

  /// SAFE cache-busting
  String _cacheBustedUrl(String url, int? version) {
    if (url.isEmpty) return url;
    final v = version ?? 0;
    return url.contains('?') ? '$url&v=$v' : '$url?v=$v';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _hasProfileImage();
    final avatarUrl =
    hasImage ? _cacheBustedUrl(user.profileImage, user.avatarVersion) : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceCard,
            AppColors.surfaceCard.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.brandPurple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar / Placeholder
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.brandPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.brandPurple,
                    width: 3,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: hasImage
                      ? CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    memCacheWidth: 300,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _placeholder(),
                  )
                      : _placeholder(),
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
                    if (user.profession != null &&
                        user.profession!.isNotEmpty)
                      Text(
                        user.profession!,
                        style: const TextStyle(
                          color: AppColors.lavender,
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
            const Divider(color: AppColors.brandPurple, thickness: 0.5),
            const SizedBox(height: 16),
            Text(
              user.bio!,
              style: const TextStyle(
                color: AppColors.lavender,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surfaceCard,
      child: const Center(
        child: Icon(
          Icons.person_outline_rounded,
          color: Colors.white38,
          size: 42,
        ),
      ),
    );
  }
}
