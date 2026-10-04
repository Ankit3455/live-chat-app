import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:availchat/models/public_profile.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/core/utils/astrology_utils.dart';
import '../../../core/constants/app_colors.dart';

class AstrologyCompatibilityCard extends StatefulWidget {
  final UserModel user;

  /// Optional: opens the astrology questionnaire.
  final VoidCallback? onTap;

  const AstrologyCompatibilityCard({super.key, required this.user, this.onTap});

  @override
  State<AstrologyCompatibilityCard> createState() =>
      _AstrologyCompatibilityCardState();
}

class _AstrologyCompatibilityCardState
    extends State<AstrologyCompatibilityCard> {
  // Fetched once per user object, not on every rebuild.
  late Future<Map<String, dynamic>?> _astrologyData = _getAstrologyData();

  @override
  void didUpdateWidget(AstrologyCompatibilityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.user, widget.user)) {
      _astrologyData = _getAstrologyData();
    }
  }

  Future<Map<String, dynamic>?> _getAstrologyData() async {
    final user = widget.user;
    try {
      // Own doc for me; other users only expose public_profiles.
      final isMe = user.uid == FirebaseAuth.instance.currentUser?.uid;
      final doc = await FirebaseFirestore.instance
          .collection(isMe ? 'users' : PublicProfile.collection)
          .doc(user.uid)
          .get();

      return doc.data();
    } catch (e) {
      return null;
    }
  }

  String _getZodiacEmoji(String? sign) {
    final emojis = {
      'aries': '♈',
      'taurus': '♉',
      'gemini': '♊',
      'cancer': '♋',
      'leo': '♌',
      'virgo': '♍',
      'libra': '♎',
      'scorpio': '♏',
      'sagittarius': '♐',
      'capricorn': '♑',
      'aquarius': '♒',
      'pisces': '♓',
    };
    return emojis[sign?.toLowerCase()] ?? '✨';
  }

  static String _signName(String sign) =>
      AstrologyUtils.normalizeSign(sign) ?? sign;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final onTap = widget.onTap;
    return FutureBuilder<Map<String, dynamic>?>(
      future: _astrologyData,
      builder: (context, snapshot) {
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        final data = snapshot.data;
        final zodiacSign = user.zodiacSign;
        final preferredSigns =
            (data?['preferredSigns'] as List?)?.toList() ?? const [];
        final dynamic beliefRaw = data?['believesInAstrology'];
        final String? believesInAstrology = beliefRaw == null
            ? null
            : (beliefRaw is bool
                ? (beliefRaw ? 'Believes in astrology' : 'Not into astrology')
                : 'Believes in astrology: $beliefRaw');
        final hasCompat = preferredSigns.isNotEmpty;
        final empty =
            zodiacSign == null && !hasCompat && believesInAstrology == null;

        final card = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35),
                  ),
                ),
                child: ExcludeSemantics(
                  child: Text(
                    _getZodiacEmoji(zodiacSign),
                    style: const TextStyle(fontSize: 28, color: AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  child: waiting
                      ? const Align(
                          key: ValueKey('astro-loading'),
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.gold,
                            ),
                          ),
                        )
                      : Column(
                          key: const ValueKey('astro-content'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              zodiacSign != null
                                  ? '${_signName(zodiacSign)} sun'
                                  : 'Cosmic profile',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (hasCompat) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Most compatible with ${preferredSigns.map((s) => '${_getZodiacEmoji(s.toString())} ${_signName(s.toString())}').join(', ')}',
                                style: const TextStyle(
                                  color: AppColors.lavender,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            if (believesInAstrology != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                believesInAstrology,
                                style: const TextStyle(
                                  color: AppColors.textSubtle,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (empty) ...[
                              const SizedBox(height: 2),
                              const Text(
                                'Answer a few astrology questions to see your cosmic compatibility.',
                                style: TextStyle(
                                  color: AppColors.lavender,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSubtle,
                ),
            ],
          ),
        );

        final tap = onTap;
        if (tap == null) return card;
        return Semantics(
          button: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: tap,
              borderRadius: BorderRadius.circular(20),
              child: card,
            ),
          ),
        );
      },
    );
  }
}
