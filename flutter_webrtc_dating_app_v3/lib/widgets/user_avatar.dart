  // lib/widgets/user_avatar.dart
  import 'package:flutter/material.dart';
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

    String? _bestUrl(UserModel u) {
      final propUrl = (u.avatarProperties?['avatarPngUrl'] as String?);
      final profile = u.profileImage;
      String? chosen = (propUrl != null && propUrl.trim().isNotEmpty) ? propUrl : (profile.isNotEmpty ? profile : null);
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
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return _skeleton();
            },
            errorBuilder: (ctx, err, stack) => _fallback(),
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
            border: Border.all(color: const Color(0xFF7B2CBF), width: 2),
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
          color: const Color(0xFF2D1B4E),
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
          color: const Color(0xFF2D1B4E),
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
