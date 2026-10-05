import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/services/presence_watch.dart';

/// 60px avatar with presence dot and first name, for the "Online now" strip.
class ProfileBubble extends StatelessWidget {
  const ProfileBubble({
    super.key,
    required this.user,
    required this.onTap,
  });

  static const double size = 60;

  final UserModel user;
  final VoidCallback onTap;

  String _initial() {
    final name = user.username.trim();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String? _avatarUrl() {
    final url = user.profileImage;
    if (url.isEmpty) return null;
    final v = user.avatarVersion ?? 0;
    return url.contains('?') ? '$url&v=$v' : '$url?v=$v';
  }

  Widget _avatar() {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandPurple, AppColors.brandPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _initial(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
      ),
    );

    final url = _avatarUrl();
    return ClipOval(
      child: url == null
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              memCacheWidth: 180,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  const ColoredBox(color: AppColors.surface2),
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = PresenceWatch.instance.isOnline(user.uid);
    final firstName = user.username.trim().split(' ').first;

    return Semantics(
      button: true,
      label: online ? '${user.username}, online' : user.username,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: size,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  children: [
                    Positioned.fill(child: _avatar()),
                    if (online)
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.backgroundDeep,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.lavender,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
