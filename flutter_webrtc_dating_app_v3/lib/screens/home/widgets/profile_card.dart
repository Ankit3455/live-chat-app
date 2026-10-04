import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/core/utils/astrology_utils.dart';
import 'package:availchat/core/utils/compatibility_utils.dart';
import 'package:availchat/models/user_model.dart';

import 'profile_quick_sheet.dart';

/// Discover grid card. Tap calls [onTap] (full profile); long-press opens the
/// quick sheet, whose Message button calls [onMessage].
class ProfileCard extends StatefulWidget {
  const ProfileCard({
    super.key,
    required this.user,
    required this.currentUser,
    required this.onTap,
    this.onMessage,
    this.distanceKm,
  });

  final UserModel user;
  final UserModel? currentUser;
  final VoidCallback onTap;
  final VoidCallback? onMessage;

  /// Shown when the user has no city.
  final int? distanceKm;

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard>
    with SingleTickerProviderStateMixin {
  static const _radius = BorderRadius.all(Radius.circular(20));

  late final AnimationController _tapCtrl;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: .96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  void _openQuickSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProfileQuickSheet(
        currentUser: widget.currentUser,
        user: widget.user,
        onMessage: widget.onMessage,
      ),
    );
  }

  String _initial() {
    final name = widget.user.username.trim();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String? _avatarUrl() {
    final url = widget.user.profileImage;
    if (url.isEmpty) return null;
    final v = widget.user.avatarVersion ?? 0;
    return url.contains('?') ? '$url&v=$v' : '$url?v=$v';
  }

  String? _place() {
    final city = widget.user.location?.trim() ?? '';
    if (city.isNotEmpty) return city;
    final km = widget.distanceKm;
    if (km == null) return null;
    return km <= 5 ? 'Nearby' : '~$km km away';
  }

  Widget _photo() {
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
            color: AppColors.white,
            fontSize: 64,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    final url = _avatarUrl();
    if (url == null) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      memCacheWidth: 600,
      fit: BoxFit.cover,
      placeholder: (_, __) => const ColoredBox(color: AppColors.surface2),
      errorWidget: (_, __, ___) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final age = user.age;
    final place = _place();
    final score =
        CompatibilityService.compatibilityScore(widget.currentUser, user);
    final hasVoice = (user.voiceIntroUrl ?? '').isNotEmpty;
    final nameStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: AppColors.white,
        );

    final semanticsLabel = [
      user.username,
      if (age != null) '$age',
      if (place != null) place,
      if (score != null) '$score% compatible',
      if (user.online) 'online',
      if (hasVoice) 'has voice intro',
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticsLabel,
      hint: 'Open profile',
      excludeSemantics: true,
      onTap: widget.onTap,
      onLongPress: _openQuickSheet,
      child: GestureDetector(
        onTapDown: (_) => _tapCtrl.reverse(),
        onTapCancel: () => _tapCtrl.forward(),
        onTapUp: (_) {
          _tapCtrl.forward();
          widget.onTap();
        },
        onLongPress: _openQuickSheet,
        child: ScaleTransition(
          scale: _tapCtrl,
          child: ClipRRect(
            borderRadius: _radius,
            child: ColoredBox(
              color: AppColors.surfaceCard,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _photo(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.45, 1.0],
                        colors: [
                          AppColors.backgroundDeep.withOpacity(0),
                          AppColors.backgroundDeep.withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Row(
                      children: [
                        if (score != null) _CompatChip(score: score, user: user),
                        const Spacer(),
                        if (user.online) const _OnlineDot(),
                      ],
                    ),
                  ),
                  if (hasVoice)
                    Positioned(
                      right: 10,
                      bottom: 54,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.backgroundDeep.withOpacity(0.6),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          size: 15,
                          color: AppColors.pinkLight,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          age != null ? '${user.username}, $age' : user.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle,
                        ),
                        if (place != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 13,
                                  color: AppColors.lavender,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    place,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.lavender,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gold compatibility chip on a glass background (zodiac emoji + score).
class _CompatChip extends StatelessWidget {
  const _CompatChip({required this.score, required this.user});

  final int score;
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final sign = CompatibilityService.signOf(user);
    final emoji = AstrologyUtils.zodiacEmoji[sign] ?? '';
    return Tooltip(
      message: CompatibilityService.tooltip,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      child: Container(
        constraints: const BoxConstraints(minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.backgroundDeep.withOpacity(0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.gold.withOpacity(0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji.isNotEmpty) ...[
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
            ],
            Text(
              '$score%',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.backgroundDeep.withOpacity(0.7),
          width: 2,
        ),
      ),
    );
  }
}
