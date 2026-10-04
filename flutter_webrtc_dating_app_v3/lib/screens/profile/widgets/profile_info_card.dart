// lib/screens/profile/widgets/profile_info_card.dart
import 'package:flutter/material.dart';
import 'package:availchat/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/avatar_story.dart';

class ProfileInfoCard extends StatelessWidget {
  final UserModel user;
  final int completionPercentage;

  /// Opens "Why you look like this". Null hides the avatar badge (uploaded
  /// photo or an avatar without stored params).
  final VoidCallback? onAvatarStoryTap;

  const ProfileInfoCard({
    super.key,
    required this.user,
    required this.completionPercentage,
    this.onAvatarStoryTap,
  });

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
    final avatarUrl = hasImage
        ? _cacheBustedUrl(user.profileImage, user.avatarVersion)
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceCard,
            AppColors.surfaceCard.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar / Placeholder
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.brandPurple.withValues(alpha: 0.2),
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
                  if (onAvatarStoryTap != null)
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: GestureDetector(
                        onTap: onAvatarStoryTap,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.brandPurpleMid,
                                AppColors.brandPink,
                              ],
                            ),
                            border: Border.all(
                              color: AppColors.surfaceCard,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
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
                          color: AppColors.lavender,
                          fontSize: 16,
                        ),
                      ),
                    // No badge at 100%: it read as ID verification.
                    if (completionPercentage < 100) ...[
                      const SizedBox(height: 8),
                      Text(
                        '$completionPercentage% complete',
                        style: const TextStyle(
                          color: AppColors.lavender,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (onAvatarStoryTap != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: AvatarMadeBadge(onTap: onAvatarStoryTap!),
            ),
          ],

          // Bio
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, thickness: 1),
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
          color: AppColors.textSubtle,
          size: 42,
        ),
      ),
    );
  }
}
