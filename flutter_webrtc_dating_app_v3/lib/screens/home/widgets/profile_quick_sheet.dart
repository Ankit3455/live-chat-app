import 'dart:async';

import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/utils/astrology_utils.dart';
import '../../../core/utils/compatibility_utils.dart';
import '../../../models/user_model.dart';
import '../../../services/audio_manager_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/user_avatar.dart' 
    show BrokenImageUrls, cacheBustedUrl;
import '../../astrology/widgets/compatibility_chip.dart';
import '../../../core/constants/app_colors.dart';

class ProfileQuickSheet extends StatelessWidget {
  const ProfileQuickSheet({
    Key? key,
    required this.currentUser,
    required this.user,
    this.onMessage,
  }) : super(key: key);

  final UserModel? currentUser; // nullable allowed
  final UserModel user;

  /// Shows a Message button that closes the sheet and runs this.
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    // Solid fallback to avoid runtime lookup on AppColors
    final Color sheetColor = AppColors.surfaceRaised;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          minChildSize: 0.50,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                children: [
                  // drag handle
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  _profileHeader(
                    MediaQuery.disableAnimationsOf(context),
                  ),

                  if (onMessage != null) ...[
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Message',
                      leftIcon: Icons.chat_bubble_outline,
                      width: double.infinity,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onMessage!();
                      },
                    ),
                  ],

                  // ✅ Voice intro mini-player (only if present)
                  if (user.voiceIntroUrl != null && user.voiceIntroUrl!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _sectionTitle("Voice Intro"),
                    const SizedBox(height: 8),
                    _VoiceIntroPlayer(
                      url: user.voiceIntroUrl!.trim(),
                      totalSeconds: user.voiceIntroDurationSeconds,
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 22),

                  // ===== BASIC (rows) =====
                  _sectionTitle("Basic Information"),
                  const SizedBox(height: 8),
                  _infoRow("Name", _safe(user.username)),
                  if (user.age != null) _infoRow("Age", "${user.age}"),
                  if (_notEmpty(user.profession)) _infoRow("Profession", user.profession),
                  if (_notEmpty(user.location)) _infoRow("Location", user.location),
                  if (_notEmpty(user.bio)) _infoRow("Bio", user.bio),
                  const SizedBox(height: 18),

                  // ===== INTERESTS (chips) =====
                  if (user.interests.isNotEmpty) ...[
                    _sectionTitle("Interests"),
                    const SizedBox(height: 6),
                    _chipWrap(items: user.interests),
                    const SizedBox(height: 18),
                  ],

                  // ===== LIFESTYLE (chips only) =====
                  if (_hasLifestyleData) ...[
                    _sectionTitle("Lifestyle"),
                    const SizedBox(height: 6),
                    _chipWrap(
                      items: [
                        if (_notEmpty(user.foodPreference)) user.foodPreference!.trim(),
                        if (_notEmpty(user.drinkingHabits)) user.drinkingHabits!.trim(),
                        if (_notEmpty(user.smokingHabits)) user.smokingHabits!.trim(),
                        if (_notEmpty(user.exerciseFrequency)) user.exerciseFrequency!.trim(),
                        if (user.pets?.isNotEmpty == true) ...user.pets!
                            .where((e) => e.trim().isNotEmpty)
                            .map((e) => e.trim()),
                        if (_notEmpty(user.wantsChildren)) user.wantsChildren!.trim(),
                        if (_notEmpty(user.partyingFrequency)) user.partyingFrequency!.trim(),
                        if (_notEmpty(user.tattoos)) user.tattoos!.trim(),
                        if (_notEmpty(user.lifestyle)) user.lifestyle!.trim(),
                        if (_notEmpty(user.sleepSchedule)) user.sleepSchedule!.trim(),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],

                  // ===== PERSONALITY & VIEWS (chips only) =====
                  if (_hasPersonalityData) ...[
                    _sectionTitle("Personality & Views"),
                    const SizedBox(height: 6),
                    _chipWrap(
                      items: [
                        if (_notEmpty(user.personalityType)) user.personalityType!.trim(),
                        if (_notEmpty(user.relationshipGoal)) user.relationshipGoal!.trim(),
                        if (_notEmpty(user.relationshipStatus)) user.relationshipStatus!.trim(),
                        if (user.hereFor?.isNotEmpty == true) ...user.hereFor!
                            .where((e) => e.trim().isNotEmpty)
                            .map((e) => e.trim()),
                        if (_notEmpty(user.personalityPriority)) user.personalityPriority!.trim(),
                        if (_notEmpty(user.relationshipPriority)) user.relationshipPriority!.trim(),
                        if (_notEmpty(user.vibePreference)) user.vibePreference!.trim(),
                        if (_notEmpty(user.politicalViews)) user.politicalViews!.trim(),
                        if (_notEmpty(user.religiousViews)) user.religiousViews!.trim(),
                        if (user.musicGenres?.isNotEmpty == true) ...user.musicGenres!
                            .where((e) => e.trim().isNotEmpty)
                            .map((e) => e.trim()),
                        if (user.movieGenres?.isNotEmpty == true) ...user.movieGenres!
                            .where((e) => e.trim().isNotEmpty)
                            .map((e) => e.trim()),
                        if (user.tvGenres?.isNotEmpty == true) ...user.tvGenres!
                            .where((e) => e.trim().isNotEmpty)
                            .map((e) => e.trim()),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],

                  // ===== ASTROLOGY (chips only) =====
                  if (_hasAstroData) ...[
                    _sectionTitle("Astrology"),
                    const SizedBox(height: 6),
                    _chipWrap(
                      items: [
                        if (_notEmpty(_zodiac)) _zodiac!.trim(),
                        if (user.believesInAstrology) "Believes in astrology",
                        if (_notEmpty(user.astrologyBeliefLevel))
                          "Belief ${user.astrologyBeliefLevel!.trim()}",
                        if (user.preferredSigns.isNotEmpty)
                          ...user.preferredSigns
                              .where((e) => e.trim().isNotEmpty)
                              .map((e) =>
                                  AstrologyUtils.normalizeSign(e) ?? e.trim()),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],

                  // ===== OTHER (no 'Online' here) =====
                  if (user.discoveryEnabled) ...[
                    _sectionTitle("Other"),
                    const SizedBox(height: 6),
                    _chipWrap(items: const ["Discoverable"]),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------- HEADER with AnimatedTextKit ----------
  Widget _profileHeader(bool reduceMotion) {
    const nameStyle = TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.w700,
    );
    final photoUrl = cacheBustedUrl(user.profileImage, user.avatarVersion);
    final hasPhoto =
        photoUrl.isNotEmpty && !BrokenImageUrls.contains(photoUrl);
    final initial = user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U';

    return Column(
      children: [
        Semantics(
          image: true,
          label: '${_safe(user.username)} profile photo',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(80),
            child: hasPhoto
                ? CachedNetworkImage(
              // Same URL as the grid card, so the cached photo is reused.
              imageUrl: photoUrl,
              memCacheWidth: 330,
              width: 110,
              height: 110,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) {
                BrokenImageUrls.add(photoUrl);
                return _initialAvatar(initial);
              },
            )
                : _initialAvatar(initial),
          ),
        ),
        const SizedBox(height: 14),

        // Animated name (static under reduced motion)
        if (reduceMotion)
          Text(
            _safe(user.username),
            textAlign: TextAlign.center,
            style: nameStyle,
          )
        else
          AnimatedTextKit(
            isRepeatingAnimation: false,
            animatedTexts: [
              TypewriterAnimatedText(
                _safe(user.username),
                textStyle: nameStyle,
                speed: const Duration(milliseconds: 70),
              ),
            ],
          ),

        const SizedBox(height: 6),
        // Wrap so large text can flow onto a second line.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (user.online)
              const Text(
                "Online",
                style: TextStyle(color: AppColors.success, fontSize: 14),
              ),
            if (user.online && _hasScore) const SizedBox(width: 10),
            CompatibilityChip(
              currentUser: currentUser,
              user: user,
              dense: false,
            ),
          ],
        ),
      ],
    );
  }

  bool get _hasScore =>
      CompatibilityService.compatibilityScore(currentUser, user) != null;

  Widget _initialAvatar(String initial) => Container(
        width: 110,
        height: 110,
        alignment: Alignment.center,
        color: AppColors.surface2,
        child: Text(
          initial,
          style: const TextStyle(fontSize: 45, fontWeight: FontWeight.w700),
        ),
      );

  // ---------- Section Title ----------
  Widget _sectionTitle(String t) => Semantics(
    header: true,
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );

  // ---------- Key:Value Row (kept for Basic only) ----------
  Widget _infoRow(String key, String? value) {
    if (!_notEmpty(value)) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              "$key:",
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Generic Chip Wrap ----------
  Widget _chipWrap({required List<String> items}) {
    final filtered = items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filtered.map((e) => _tag(e)).toList(),
    );
  }

  // ---------- Tag ----------
  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ---------- Helpers ----------
  bool _notEmpty(String? s) => s != null && s.trim().isNotEmpty;
  String _safe(String? s) => s?.trim().isNotEmpty == true ? s!.trim() : "Unknown";

  String? get _zodiac => _notEmpty(user.zodiacSign)
      ? user.zodiacSign
      : (_notEmpty(user.sunSign) ? user.sunSign : null);

  bool get _hasLifestyleData =>
      _notEmpty(user.foodPreference) ||
          _notEmpty(user.drinkingHabits) ||
          _notEmpty(user.smokingHabits) ||
          _notEmpty(user.exerciseFrequency) ||
          (user.pets?.isNotEmpty ?? false) ||
          _notEmpty(user.wantsChildren) ||
          _notEmpty(user.partyingFrequency) ||
          _notEmpty(user.tattoos) ||
          _notEmpty(user.lifestyle) ||
          _notEmpty(user.sleepSchedule);

  bool get _hasPersonalityData =>
      _notEmpty(user.personalityType) ||
          _notEmpty(user.relationshipGoal) ||
          _notEmpty(user.relationshipStatus) ||
          (user.hereFor?.isNotEmpty ?? false) ||
          _notEmpty(user.personalityPriority) ||
          _notEmpty(user.relationshipPriority) ||
          _notEmpty(user.vibePreference) ||
          _notEmpty(user.politicalViews) ||
          _notEmpty(user.religiousViews) ||
          (user.musicGenres?.isNotEmpty ?? false) ||
          (user.movieGenres?.isNotEmpty ?? false) ||
          (user.tvGenres?.isNotEmpty ?? false);

  bool get _hasAstroData =>
      _notEmpty(_zodiac) ||
          user.believesInAstrology ||
          _notEmpty(user.astrologyBeliefLevel) ||
          user.preferredSigns.isNotEmpty;
}

// ====== INTERNAL MINI PLAYER WIDGET ======
class _VoiceIntroPlayer extends StatefulWidget {
  const _VoiceIntroPlayer({
    required this.url,
    this.totalSeconds,
  });

  final String url;
  final int? totalSeconds;

  @override
  State<_VoiceIntroPlayer> createState() => _VoiceIntroPlayerState();
}

class _VoiceIntroPlayerState extends State<_VoiceIntroPlayer> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    _subs.add(_player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    _subs.add(_player.onPlayerComplete.listen((_) async {
      if (mounted) setState(() => _position = Duration.zero);
      await AudioManagerService.setSpeakerphone(false);
    }));

    // Preload duration if provided
    if (widget.totalSeconds != null && widget.totalSeconds! > 0) {
      _duration = Duration(seconds: widget.totalSeconds!);
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.stop();
    _player.dispose();
    AudioManagerService.setSpeakerphone(false);
    super.dispose();
  }

  Future<void> _toggle() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final state = await _player.state;

      if (state == PlayerState.playing) {
        await _player.pause();
        await AudioManagerService.setSpeakerphone(false);
      } else {
        await AudioManagerService.setCallAudioMode(false);
        await AudioManagerService.setSpeakerphone(true);
        await _player.play(UrlSource(widget.url));
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
      await AudioManagerService.setSpeakerphone(false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final playing = _player.state == PlayerState.playing;
    final progress = (_duration.inMilliseconds > 0)
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: [
          // Play / Pause
          Semantics(
            button: true,
            label: playing ? 'Pause voice intro' : 'Play voice intro',
            child: InkWell(
              onTap: _isLoading ? null : _toggle,
              customBorder: const CircleBorder(),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.borderStrong,
                ),
                child: _isLoading
                    ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Progress + times
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.border,
                  color: Colors.white,
                  minHeight: 5,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_position), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    Text(
                      _fmt(_duration.inMilliseconds > 0 ? _duration : Duration(seconds: widget.totalSeconds ?? 0)),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                if (_hasError)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      "Couldn't play voice intro",
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
