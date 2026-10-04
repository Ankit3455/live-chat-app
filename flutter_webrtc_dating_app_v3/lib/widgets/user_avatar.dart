import '../core/constants/app_colors.dart';
  // lib/widgets/user_avatar.dart
  import 'package:flutter/material.dart';
  import 'package:cached_network_image/cached_network_image.dart';
  import 'package:availchat/models/user_model.dart';

  String cacheBustedUrl(String url, int? version) {
    if (url.isEmpty) return url;
    final v = version ?? 0;
    return url.contains('?') ? '$url&v=$v' : '$url?v=$v';
  }

  class UserAvatar extends StatelessWidget {
    final UserModel user;
    final double size;
    final double borderRadius;
    final VoidCallback? onTap;

    const UserAvatar({
      super.key,
      required this.user,
      this.size = 72,
      this.borderRadius = 16,
      this.onTap,
    });

    // profileImage is the current photo (custom or generated); fall back to
    // the stored generated avatar if it is empty.
    String? _bestUrl(UserModel u) {
      final profile = u.profileImage.trim();
      final avatarUrl =
          (u.avatarProperties?['avatarImageUrl'] as String?)?.trim() ?? '';
      final chosen = profile.isNotEmpty
          ? profile
          : (avatarUrl.isNotEmpty ? avatarUrl : null);
      if (chosen == null) return null;
      return cacheBustedUrl(chosen, u.avatarVersion);
    }

    String _initials(UserModel u) {
      final name = (u.username).trim();
      if (name.isEmpty) return 'U';
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length == 1) {
        return parts.first.characters.take(1).toString().toUpperCase();
      }
      final a = parts.first.characters.take(1).toString();
      final b = parts.last.characters.take(1).toString();
      return (a + b).toUpperCase();
    }

    @override
    Widget build(BuildContext context) {
      final url = _bestUrl(user);

      Widget content;
      if (url != null && (url.startsWith('http://') || url.startsWith('https://'))) {
        content = ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: CachedNetworkImage(
            imageUrl: url,
            memCacheWidth: (size * 3).round(),
            width: size,
            height: size,
            fit: BoxFit.cover,
            useOldImageOnUrlChange: true,
            placeholder: (_, __) => _skeleton(),
            errorWidget: (_, __, ___) => _fallback(),
          ),
        );
      } else {
        content = _fallback();
      }

      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.brandPurple, width: 2),
          ),
          child: content,
        ),
      );
    }

    Widget _fallback() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(
          child: Text(
            _initials(user),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.36,
            ),
          ),
        ),
      );
    }

    Widget _skeleton() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }
  }
