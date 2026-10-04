// lib/widgets/avatar_story.dart
//
// Shared pieces that tell users their avatar comes from their answers:
// the uniqueness badge, the "Why you look like this" card and the small
// "Made from your answers" pill used on My Profile.

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/user_model.dart';
import '../services/avatar_traits.dart';

/// Traits for [user] when their generated avatar is the image in use;
/// empty for uploaded photos and legacy avatars without stored params.
List<AvatarTrait> avatarTraitsFor(UserModel user) {
  final props = user.avatarProperties;
  if (props == null) return const [];
  final generatedUrl = props['avatarImageUrl']?.toString() ?? '';
  if (generatedUrl.isEmpty || generatedUrl != user.profileImage) {
    return const [];
  }
  return AvatarTraits.explain(props);
}

class AvatarMadeBadge extends StatelessWidget {
  final VoidCallback onTap;

  const AvatarMadeBadge({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Avatar made from your answers. See why',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  AppColors.brandPurple.withOpacity(0.22),
                  AppColors.brandPink.withOpacity(0.14),
                ],
              ),
              border: Border.all(color: AppColors.brandPink.withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: AppColors.gold),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Made from your answers',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'See why',
                  style: TextStyle(
                    color: AppColors.brandPurpleLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.brandPurpleLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AvatarUniqueBadge extends StatelessWidget {
  const AvatarUniqueBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 14, color: AppColors.gold),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'One of a kind · no one else has this face',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AvatarWhyCard extends StatelessWidget {
  final List<AvatarTrait> traits;

  const AvatarWhyCard({super.key, required this.traits});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lavender.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Why you look like this',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'from your answers',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          for (final t in traits)
            Semantics(
              label: '${t.answer}, ${t.source}, gives ${t.effect}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(t.emoji, style: const TextStyle(fontSize: 17)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.answer,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            t.source,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '→',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        t.effect,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.brandPurpleLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
