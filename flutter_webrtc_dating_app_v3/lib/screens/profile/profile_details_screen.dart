import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/core/utils/astrology_utils.dart';
import 'package:availchat/core/utils/compatibility_utils.dart';
import 'package:availchat/core/utils/haptics.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/chat/chat_screen.dart';
import 'package:availchat/screens/chat/widgets/report_dialog.dart';
import 'package:availchat/screens/profile/widgets/voice_intro_card.dart';
import 'package:availchat/widgets/custom_button.dart';

/// Full-screen profile of another user (replaces the quick sheet).
class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

enum _MoreAction { block, report }

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  static const double _heroHeight = 420;

  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;
  UserModel? _me;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMe());
  }

  // Own doc, only for my sun sign / preferred signs. Failure hides the card.
  Future<void> _loadMe() async {
    final uid = _myUid;
    if (uid == null || uid.isEmpty || uid == widget.user.uid) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted || !doc.exists) return;
      setState(() => _me = UserModel.fromFirestore(doc));
    } catch (_) {
      // Keep rendering without the compatibility card.
    }
  }

  // ---------- Data helpers ----------

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static List<String> _cleanList(Iterable<String>? items) {
    if (items == null) return const [];
    final seen = <String>{};
    final out = <String>[];
    for (final raw in items) {
      final t = raw.trim();
      if (t.isNotEmpty && seen.add(t.toLowerCase())) out.add(t);
    }
    return out;
  }

  String get _otherUid => widget.user.uid ?? '';

  bool get _isSelf {
    final me = _myUid;
    return me != null && me.isNotEmpty && me == widget.user.uid;
  }

  String get _name => _clean(widget.user.username) ?? 'Unknown';

  String get _firstName => _name.split(RegExp(r'\s+')).first;

  /// Photo, else generated avatar, else legacy http avatar.
  String? get _photoUrl {
    final u = widget.user;
    final photo = u.profileImage.trim();
    if (photo.isNotEmpty) {
      final v = u.avatarVersion ?? 0;
      return photo.contains('?') ? '$photo&v=$v' : '$photo?v=$v';
    }
    final generated = u.avatarProperties?['avatarImageUrl'];
    if (generated is String && generated.trim().isNotEmpty) {
      return generated.trim();
    }
    final legacy = u.avatarString;
    return (legacy != null && legacy.startsWith('http')) ? legacy : null;
  }

  static String _signLabel(String sign) {
    final emoji = AstrologyUtils.zodiacEmoji[sign];
    return emoji == null ? sign : '$emoji $sign';
  }

  // ---------- Actions ----------

  void _openChat() {
    final uid = _otherUid;
    if (uid.isEmpty) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(otherUserId: uid, initialUser: widget.user),
        ),
      ),
    );
  }

  Future<void> _block() async {
    final uid = _otherUid;
    if (uid.isEmpty) return;
    Haptics.warning();
    final blocked = await confirmAndBlockUser(
      context,
      otherUid: uid,
      displayName: _name,
      avatarUrl: _photoUrl,
    );
    if (blocked && mounted) Navigator.of(context).pop();
  }

  Future<void> _report() async {
    final uid = _otherUid;
    if (uid.isEmpty) return;
    await ReportDialog.show(
      context,
      reportedUserId: uid,
      reportedName: _name,
      source: 'profile',
    );
  }

  void _showCompatInfo() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text(
            'How compatibility works',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: const Text(
            CompatibilityService.tooltip,
            style: TextStyle(color: AppColors.lavender, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Got it',
                style: TextStyle(color: AppColors.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final showActions = !_isSelf && _otherUid.isNotEmpty;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Centre a 560dp column on tablets.
    final width = MediaQuery.of(context).size.width;
    final hPad = width > 600 ? (width - 560) / 2 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _hero()),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  8,
                  hPad,
                  (showActions ? 120 : 32) + bottomInset,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(_sections(showActions)),
                ),
              ),
            ],
          ),
          // Floating top bar over the hero.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    _circleButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    if (showActions) _moreMenu(),
                  ],
                ),
              ),
            ),
          ),
          if (showActions)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _stickyCta(bottomInset),
            ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: AppColors.backgroundDeep.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, color: AppColors.textPrimary),
        tooltip: tooltip,
        iconSize: 22,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        onPressed: onPressed,
      ),
    );
  }

  Widget _moreMenu() {
    return Material(
      color: AppColors.backgroundDeep.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<_MoreAction>(
        tooltip: 'Block or report',
        icon: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
        color: AppColors.surfaceCard,
        onSelected: (action) {
          switch (action) {
            case _MoreAction.block:
              unawaited(_block());
            case _MoreAction.report:
              unawaited(_report());
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _MoreAction.block,
            child: ListTile(
              leading: Icon(Icons.block_rounded, color: AppColors.lavender),
              title: Text(
                'Block',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: _MoreAction.report,
            child: ListTile(
              leading: Icon(Icons.flag_outlined, color: AppColors.lavender),
              title: Text(
                'Report',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Hero ----------

  Widget _hero() {
    final u = widget.user;
    final url = _photoUrl;
    final age = u.age;
    final city = _clean(u.location);
    final profession = _clean(u.profession);
    final height = _clean(u.height);

    final fallback = DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Center(
        child: Text(
          _name.substring(0, 1).toUpperCase(),
          style: GoogleFonts.montserrat(
            color: AppColors.white,
            fontSize: 96,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    return SizedBox(
      height: _heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            image: true,
            label: 'Profile photo of $_name',
            excludeSemantics: true,
            // Matches the Discover card photo (tag 'profile-photo-<uid>').
            child: HeroMode(
              enabled: _otherUid.isNotEmpty,
              child: Hero(
                tag: 'profile-photo-$_otherUid',
                child: url == null
                    ? fallback
                    : CachedNetworkImage(
                        imageUrl: url,
                        memCacheWidth: 1080,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const ColoredBox(color: AppColors.surfaceCard),
                        errorWidget: (_, __, ___) => fallback,
                      ),
              ),
            ),
          ),
          // Scrim: darken top for buttons, fade bottom into background.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.25, 0.55, 1.0],
                colors: [
                  AppColors.backgroundDeep.withValues(alpha: 0.45),
                  AppColors.backgroundDeep.withValues(alpha: 0.0),
                  AppColors.backgroundDeep.withValues(alpha: 0.0),
                  AppColors.backgroundDeep,
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (u.online) ...[_onlinePill(), const SizedBox(height: 6)],
                Semantics(
                  header: true,
                  child: Text(
                    age != null ? '$_name, $age' : _name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
                if (city != null || profession != null || height != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      if (city != null) _fact(Icons.place_outlined, city),
                      if (profession != null)
                        _fact(Icons.work_outline_rounded, profession),
                      if (height != null)
                        _fact(Icons.straighten_rounded, height),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _onlinePill() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.online,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Online now',
          style: TextStyle(
            color: AppColors.online,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _fact(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.lavender),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.lavender, fontSize: 14),
          ),
        ),
      ],
    );
  }

  // ---------- Sections ----------

  List<Widget> _sections(bool showActions) {
    final u = widget.user;
    final children = <Widget>[];

    final compat = _compatibilityCard();
    if (compat != null) {
      // Fades in once my profile has loaded.
      children.add(
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          builder: (_, t, child) => Opacity(opacity: t, child: child),
          child: compat,
        ),
      );
    }

    final voiceUrl = _clean(u.voiceIntroUrl);
    if (voiceUrl != null) {
      children
        ..add(_sectionTitle('Voice intro'))
        ..add(
          VoiceIntroCard(
            url: voiceUrl,
            totalSeconds: u.voiceIntroDurationSeconds,
          ),
        );
    }

    final bio = _clean(u.bio);
    if (bio != null) {
      children
        ..add(_sectionTitle('About'))
        ..add(
          Text(
            bio,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        );
    }

    final lookingFor = _cleanList([
      ...?u.hereFor,
      if (_clean(u.relationshipGoal) case final goal?) goal,
      if (_clean(u.relationshipPriority) case final p?) p,
      if (_clean(u.personalityPriority) case final p?) p,
      if (_clean(u.vibePreference) case final v?) v,
    ]);
    if (lookingFor.isNotEmpty) {
      children
        ..add(_sectionTitle('Looking for'))
        ..add(_chipWrap(lookingFor.map((t) => _Chip(t)).toList()));
    }

    final basics = <(String, String)>[
      if (_clean(u.education) case final v?) ('Education', v),
      if (_clean(u.relationshipStatus) case final v?) ('Relationship', v),
      if (_clean(u.bodyType) case final v?) ('Body type', v),
      if (_clean(u.sleepSchedule) ?? _clean(u.lifestyle) case final v?)
        ('Sleep', v),
      if (_clean(u.habits) case final v?) ('Habits', v),
      if (_clean(u.personalityType) case final v?) ('Personality', v),
      if (_clean(u.religiousViews) case final v?) ('Religion', v),
      if (_clean(u.politicalViews) case final v?) ('Politics', v),
      if (_clean(u.idealDate) case final v?) ('Ideal date', v),
    ];
    if (basics.isNotEmpty) {
      children
        ..add(_sectionTitle('Basics'))
        ..add(_basicsGrid(basics));
    }

    final interests = _cleanList(u.interests);
    if (interests.isNotEmpty) {
      children
        ..add(_sectionTitle('Interests'))
        ..add(_chipWrap(interests.map((t) => _Chip(t)).toList()));
    }

    final genres = _cleanList([
      ...?u.musicGenres,
      ...?u.movieGenres,
      ...?u.tvGenres,
    ]);
    if (genres.isNotEmpty) {
      children
        ..add(_sectionTitle('Music, movies & TV'))
        ..add(_chipWrap(genres.map((t) => _Chip(t)).toList()));
    }

    final lifestyle = <_Chip>[
      if (_clean(u.foodPreference) case final v?)
        _Chip(v, icon: Icons.restaurant_outlined),
      if (_clean(u.drinkingHabits) case final v?)
        _Chip(v, icon: Icons.local_bar_outlined),
      if (_clean(u.smokingHabits) case final v?)
        _Chip(v, icon: Icons.smoke_free_outlined),
      if (_clean(u.exerciseFrequency) case final v?)
        _Chip(v, icon: Icons.fitness_center_outlined),
      for (final pet in _cleanList(u.pets)) _Chip(pet, icon: Icons.pets),
      if (_clean(u.wantsChildren) case final v?)
        _Chip(v, icon: Icons.child_friendly_outlined),
      if (_clean(u.partyingFrequency) case final v?)
        _Chip(v, icon: Icons.celebration_outlined),
      if (_clean(u.tattoos) case final v?) _Chip(v, icon: Icons.brush_outlined),
    ];
    if (lifestyle.isNotEmpty) {
      children
        ..add(_sectionTitle('Lifestyle'))
        ..add(_chipWrap(lifestyle));
    }

    final astro = _astrologyChips();
    if (astro.isNotEmpty) {
      children
        ..add(_sectionTitle('Astrology'))
        ..add(_chipWrap(astro));
    }

    if (showActions) {
      children
        ..add(const SizedBox(height: 32))
        ..add(
          Row(
            children: [
              Expanded(
                child: _safetyButton(Icons.block_rounded, 'Block', _block),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _safetyButton(Icons.flag_outlined, 'Report', _report),
              ),
            ],
          ),
        );
    }

    return children;
  }

  Widget? _compatibilityCard() {
    final me = _me;
    if (me == null) return null;
    final score = CompatibilityService.compatibilityScore(me, widget.user);
    final mySign = CompatibilityService.signOf(me);
    final theirSign = CompatibilityService.signOf(widget.user);
    if (score == null || mySign == null || theirSign == null) return null;

    final String headline;
    final String verdict;
    if (score >= 80) {
      headline = 'You’re a cosmic match';
      verdict = 'score high together';
    } else if (score >= 60) {
      headline = 'Good cosmic chemistry';
      verdict = 'get along well';
    } else {
      headline = 'Opposites can attract';
      verdict = 'have differences to explore';
    }
    final reason = 'Your ${_signLabel(mySign)} and their '
        '${_signLabel(theirSign)} sun signs $verdict.';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withValues(alpha: 0.12),
            AppColors.brandPink.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '$score percent compatible',
            excludeSemantics: true,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 5,
                    color: AppColors.gold,
                    backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  ),
                  Center(
                    child: Text(
                      '$score%',
                      style: GoogleFonts.montserrat(
                        color: AppColors.gold,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: const TextStyle(
                    color: AppColors.lavender,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                TextButton(
                  onPressed: _showCompatInfo,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 48),
                    alignment: Alignment.centerLeft,
                  ),
                  child: const Text(
                    'How it works',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_Chip> _astrologyChips() {
    final u = widget.user;
    final sign = CompatibilityService.signOf(u);
    final preferred = <String>[];
    for (final s in u.preferredSigns) {
      final n = AstrologyUtils.normalizeSign(s);
      if (n != null && !preferred.contains(n)) preferred.add(n);
    }
    // Belief level 6 is the "Somewhat" answer.
    final somewhat = _clean(u.astrologyBeliefLevel) == '6';

    return [
      if (sign != null) _Chip(_signLabel(sign), gold: true),
      if (u.believesInAstrology)
        _Chip(
          somewhat ? 'Somewhat believes in astrology' : 'Believes in astrology',
        ),
      if (preferred.isNotEmpty)
        _Chip(
          'Likes ${preferred.map((s) => AstrologyUtils.zodiacEmoji[s] ?? s).join(' ')}',
          semanticLabel: 'Likes ${preferred.join(', ')}',
        ),
    ];
  }

  // ---------- Building blocks ----------

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: GoogleFonts.montserrat(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _chipWrap(List<_Chip> chips) {
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _basicsGrid(List<(String, String)> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value) in items)
              SizedBox(
                width: tileWidth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.textSubtle,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _safetyButton(IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.lavender,
        backgroundColor: AppColors.surfaceCard,
        side: const BorderSide(color: AppColors.borderStrong),
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _stickyCta(double bottomInset) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 16 + bottomInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.35],
          colors: [
            AppColors.backgroundDeep.withValues(alpha: 0.0),
            AppColors.backgroundDeep,
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: CustomButton(
            text: 'Message $_firstName',
            leftIcon: Icons.chat_bubble_outline,
            size: ButtonSize.large,
            width: double.infinity,
            onPressed: _openChat,
          ),
        ),
      ),
    );
  }
}

/// Pill chip; gold variant is reserved for zodiac.
class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.icon, this.gold = false, this.semanticLabel});

  final String text;
  final IconData? icon;
  final bool gold;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final fg = gold ? AppColors.gold : AppColors.textPrimary;
    final chipIcon = icon;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: gold
              ? AppColors.gold.withValues(alpha: 0.12)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: gold
                ? AppColors.gold.withValues(alpha: 0.45)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chipIcon != null) ...[
              Icon(chipIcon, size: 14, color: AppColors.lavender),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: gold ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
