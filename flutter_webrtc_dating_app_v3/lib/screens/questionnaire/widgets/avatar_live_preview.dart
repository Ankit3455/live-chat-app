// lib/screens/questionnaire/widgets/avatar_live_preview.dart
//
// Round avatar image used by the signup deck's live avatar.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Round avatar image from a DiceBear URL.
class AvatarFace extends StatelessWidget {
  final String? url;
  final double size;
  final bool ring;

  const AvatarFace(
      {super.key, required this.url, required this.size, this.ring = false});

  @override
  Widget build(BuildContext context) {
    final image = url == null
        ? Container(color: AppColors.surfaceCard)
        : CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            fadeInDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            placeholder: (_, __) => Container(color: AppColors.surfaceCard),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.surfaceCard,
              child: Icon(
                Icons.person_outline,
                color: AppColors.lavender,
                size: size * 0.5,
              ),
            ),
          );
    return Container(
      width: size,
      height: size,
      padding: ring ? const EdgeInsets.all(2) : EdgeInsets.zero,
      decoration: ring
          ? const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.brandPurpleMid, AppColors.brandPink],
              ),
            )
          : null,
      child: ClipOval(child: image),
    );
  }
}
