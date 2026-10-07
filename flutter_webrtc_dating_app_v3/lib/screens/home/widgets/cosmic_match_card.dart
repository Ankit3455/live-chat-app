import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/core/utils/astrology_utils.dart';
import 'package:availchat/core/utils/compatibility_utils.dart';
import 'package:availchat/core/utils/discover_picks.dart';
import 'package:availchat/core/utils/vibe_line.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/profile/widgets/voice_intro_card.dart';
import 'package:availchat/screens/questionnaire/deck/deck_widgets.dart';
import 'package:availchat/services/presence_watch.dart';
import 'package:availchat/widgets/user_avatar.dart'
    show BrokenImageUrls, cacheBustedUrl;

import 'profile_quick_sheet.dart';

/// Profile photo or avatar, with an initial-letter fallback. With [hero] it
/// shares the hero tag of ProfileDetailsScreen's photo.
class DiscoverPhoto extends StatelessWidget {
  final UserModel user;
  final bool hero;
  final int memCacheWidth;
  const DiscoverPhoto({
    super.key,
    required this.user,
    this.hero = false,
    this.memCacheWidth = 600,
  });

  @override
  Widget build(BuildContext context) {
    final name = user.username.trim();
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
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    final raw = user.profileImage;
    final url = raw.isEmpty ? null : cacheBustedUrl(raw, user.avatarVersion);
    final Widget image = url == null || BrokenImageUrls.contains(url)
        ? fallback
        : CachedNetworkImage(
            imageUrl: url,
            memCacheWidth: memCacheWidth,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -.4),
            placeholder: (_, __) => const ColoredBox(color: AppColors.surface2),
            errorWidget: (_, __, ___) {
              BrokenImageUrls.add(url);
              return fallback;
            },
          );
    final uid = user.uid;
    if (!hero || uid == null || uid.isEmpty) return image;
    return Hero(tag: 'profile-photo-$uid', child: image);
  }
}

/// Compatibility as a gold-to-pink ring with the number inside.
class CompatRing extends StatelessWidget {
  final int score;
  final double size;
  final double stroke;
  final bool caption;
  const CompatRing({
    super.key,
    required this.score,
    this.size = 56,
    this.stroke = 5,
    this.caption = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$score% compatible',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(score / 100, stroke),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  caption ? '$score%' : '$score',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: size * (caption ? .26 : .3),
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                if (caption)
                  Text(
                    'MATCH',
                    style: TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: size * .12,
                      letterSpacing: .6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  _RingPainter(this.value, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withOpacity(.15),
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      2 * math.pi * value.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          colors: [AppColors.gold, AppColors.brandPink, AppColors.gold],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.stroke != stroke;
}

/// Big Discover card: photo, compatibility, vibe line, what you share, voice
/// intro, opening line and Pass / Say hi / View. Long-press opens the quick
/// sheet.
class CosmicMatchCard extends StatelessWidget {
  final UserModel user;
  final UserModel? me;
  final int? distanceKm;
  final VoidCallback onView;
  final VoidCallback onSayHi;
  final VoidCallback onPass;

  const CosmicMatchCard({
    super.key,
    required this.user,
    required this.me,
    required this.distanceKm,
    required this.onView,
    required this.onSayHi,
    required this.onPass,
  });

  void _openQuickSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProfileQuickSheet(
        currentUser: me,
        user: user,
        onMessage: onSayHi,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = CompatibilityService.compatibilityScore(me, user);
    final online = PresenceWatch.instance.isOnline(user.uid);
    final age = user.age;
    final sign = CompatibilityService.signOf(user);
    final glyph = sign == null ? null : AstrologyUtils.zodiacEmoji[sign];
    final vibe = VibeLine.from(user.toMap());
    final shared = DiscoverPicks.sharedAnswers(me, user);
    final voice = (user.voiceIntroUrl ?? '').trim();
    final opening = (user.relationshipGoal ?? '').trim();
    final city = (user.location ?? '').trim();
    final km = distanceKm;
    final place = km != null
        ? (km <= 5 ? 'Nearby' : '$km km')
        : (city.isEmpty ? null : city);
    final meta = [
      if (sign != null) '${glyph ?? ''} $sign'.trim(),
      if ((user.profession ?? '').trim().isNotEmpty) user.profession!.trim(),
    ].join(' · ');

    return Semantics(
      container: true,
      label: [
        user.username,
        if (age != null) '$age',
        if (score != null) '$score% compatible',
        if (online) 'online',
      ].join(', '),
      child: GestureDetector(
        onTap: onView,
        onLongPress: () => _openQuickSheet(context),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 300,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DiscoverPhoto(user: user, hero: true),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, .3, .55, 1],
                          colors: [
                            Color(0x330B0614),
                            Color(0x000B0614),
                            Color(0x001E1531),
                            AppColors.surfaceCard,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _Pill(
                        online ? 'Online now' : 'Active recently',
                        dot: online,
                      ),
                    ),
                    if (place != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _Pill('📍 $place'),
                      ),
                    if (score != null)
                      Positioned(
                        right: 14,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceCard,
                            shape: BoxShape.circle,
                          ),
                          child: CompatRing(score: score, caption: true),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: user.username),
                        if (age != null)
                          TextSpan(
                            text: '  $age',
                            style: deckSerif(24, color: AppColors.lavender),
                          ),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: deckSerif(30),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        style: const TextStyle(
                          color: AppColors.lavender,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    if (vibe != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        '“$vibe”',
                        style: deckSerif(16, color: deckGoldLight, italic: true)
                            .copyWith(height: 1.35),
                      ),
                    ],
                    if (shared.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        '✦ YOU BOTH',
                        style: TextStyle(
                          color: AppColors.brandPink,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in shared)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandPink.withOpacity(.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.brandPink.withOpacity(.3),
                                ),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  color: AppColors.pinkLight,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (voice.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      VoiceIntroCard(
                        url: voice,
                        totalSeconds: user.voiceIntroDurationSeconds,
                      ),
                    ],
                    if (opening.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(colors: [
                            AppColors.brandPurple.withOpacity(.18),
                            AppColors.brandPink.withOpacity(.08),
                          ]),
                          border: Border.all(
                            color: AppColors.gold.withOpacity(.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '💭 THEIR OPENING LINE',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '“$opening”',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _SquareButton(
                          label: 'Pass',
                          onTap: onPass,
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppColors.lavender,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DeckButton(
                            label: '💬  Say hi',
                            height: 50,
                            onPressed: onSayHi,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _SquareButton(
                          label: 'View profile',
                          onTap: onView,
                          child: const Text(
                            '✦',
                            style: TextStyle(
                              color: deckGoldLight,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool dot;
  const _Pill(this.text, {this.dot = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x990B0614),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: const TextStyle(
              color: AppColors.lavenderLight,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget child;
  const _SquareButton({
    required this.label,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          child: SizedBox(width: 50, height: 50, child: Center(child: child)),
        ),
      ),
    );
  }
}
