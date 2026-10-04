// lib/screens/profile/widgets/profile_header.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/core/utils/astrology_utils.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/widgets/avatar_story.dart';
import 'package:availchat/widgets/user_avatar.dart';

/// My Profile hero: ringed avatar with a camera button, name/age and a
/// "sign · city · profession" line.
class ProfileHeader extends StatelessWidget {
  final UserModel user;
  final VoidCallback onChangePhoto;

  /// Null hides the "Made from your answers" badge and pill.
  final VoidCallback? onAvatarStoryTap;
  final bool busy;

  const ProfileHeader({
    super.key,
    required this.user,
    required this.onChangePhoto,
    this.onAvatarStoryTap,
    this.busy = false,
  });

  static String? _clean(String? v) {
    final s = v?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  String get _title {
    final name = _clean(user.username) ?? 'You';
    final age = user.age;
    return (age != null && age > 0) ? '$name, $age' : name;
  }

  List<String> get _facts {
    final sign = AstrologyUtils.normalizeSign(user.zodiacSign);
    final emoji = sign == null ? null : AstrologyUtils.zodiacEmoji[sign];
    return [
      if (sign != null) emoji == null ? sign : '$emoji $sign',
      if (_clean(user.location) case final city?) city,
      if (_clean(user.profession) case final job?) job,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final storyTap = onAvatarStoryTap;
    final facts = _facts;
    return Column(
      children: [
        // Taller than the ring so the 48dp buttons stay hit-testable.
        SizedBox(
          width: 144,
          height: 136,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Gradient ring with a background gap around the photo.
              Container(
                width: 124,
                height: 124,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.backgroundDeep,
                  ),
                  child: Semantics(
                    image: true,
                    label: 'Your profile photo',
                    child: UserAvatar(user: user, size: 112, borderRadius: 56),
                  ),
                ),
              ),
              if (busy)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.backgroundDeep.withValues(alpha: 0.55),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandPurpleLight,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              Positioned(right: 0, bottom: -6, child: _cameraButton()),
              if (storyTap != null)
                Positioned(left: 0, bottom: -6, child: _storyButton(storyTap)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            _title,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: AppColors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            facts.join('  ·  '),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.lavender, fontSize: 14),
          ),
        ],
        if (storyTap != null) ...[
          const SizedBox(height: 12),
          AvatarMadeBadge(onTap: storyTap),
        ],
      ],
    );
  }

  // 36px visual inside a 48dp target.
  Widget _cameraButton() {
    return Tooltip(
      message: 'Change photo or avatar',
      child: Semantics(
        button: true,
        label: 'Change photo or avatar',
        excludeSemantics: true,
        child: InkResponse(
          onTap: busy ? null : onChangePhoto,
          radius: 24,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface2,
                  border: Border.all(color: AppColors.backgroundDeep, width: 3),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 16,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _storyButton(VoidCallback onTap) {
    return Tooltip(
      message: 'Why your avatar looks like this',
      child: Semantics(
        button: true,
        label: 'Avatar made from your answers. See why',
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.brandPurpleMid, AppColors.brandPink],
                  ),
                  border: Border.all(color: AppColors.backgroundDeep, width: 3),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
