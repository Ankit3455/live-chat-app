import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/vibe_line.dart';
import '../../managers/profile_completion_manager.dart';
import 'deck/deck_models.dart';
import 'deck/deck_widgets.dart';
import 'deck/destiny_deck_screen.dart';

/// "Complete your profile": the Lifestyle and Personality decks, profile
/// strength and the vibe line.
class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({Key? key}) : super(key: key);

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final Map<String, dynamic> _answers = {};
  bool _loading = true;
  int? _percent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        _answers
          ..clear()
          ..addAll(doc.data() ?? const {});
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
    if (mounted) setState(() => _loading = false);
    unawaited(_refreshPercent());
  }

  Future<void> _refreshPercent() async {
    try {
      final pct = await ProfileCompletionManager().getCompletionPercentage();
      if (mounted) setState(() => _percent = pct);
    } catch (e) {
      debugPrint('Error loading completion: $e');
    }
  }

  Future<void> _open(DeckSection section) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DestinyDeckScreen(
          section: section,
          answers: _answers,
          startPercent: _percent ?? 0,
          startIndex: DestinyDeckScreen.firstOpen(section, _answers),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
    unawaited(_refreshPercent());
  }

  @override
  Widget build(BuildContext context) {
    final pct = _percent;
    final vibe = VibeLine.from(_answers);
    return Scaffold(
      backgroundColor: AppColors.backgroundDarkest,
      body: DeckBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Row(
                  children: [
                    DeckIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      label: 'Back',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Complete your profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brandPurpleLight,
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                            children: [
                              Text(
                                'Draw your cards',
                                textAlign: TextAlign.center,
                                style: deckSerif(32),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Two short decks. Answer what feels right, skip the rest.\nEach card lights a star in your constellation.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.lavender,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 26),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final s in DeckSection.values)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7),
                                      child: _DeckStack(
                                        section: s,
                                        answers: _answers,
                                        onTap: () => _open(s),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _StrengthCard(percent: pct),
                              const SizedBox(height: 12),
                              _VibeCard(vibe: vibe),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckStack extends StatelessWidget {
  final DeckSection section;
  final Map<String, dynamic> answers;
  final VoidCallback onTap;
  const _DeckStack({
    required this.section,
    required this.answers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cards = section.cards;
    final lit = cards.where((c) => c.isDone(answers)).length;
    final done = section.isComplete(answers);
    const card = SizedBox(
        width: 132,
        height: 180,
        child: TarotFrame(radius: 16, child: SizedBox.expand()));
    return Semantics(
      button: true,
      label: '${section.title} deck, $lit of ${cards.length} answered',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 150,
          child: Column(
            children: [
              SizedBox(
                height: 196,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Transform.translate(
                      offset: const Offset(-14, 0),
                      child: Transform.rotate(angle: -.157, child: card),
                    ),
                    Transform.translate(
                      offset: const Offset(14, 0),
                      child: Transform.rotate(angle: .122, child: card),
                    ),
                    SizedBox(
                      width: 132,
                      height: 180,
                      child: TarotFrame(
                        radius: 16,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              section.roman,
                              style: deckSerif(12,
                                      color: AppColors.gold, italic: true)
                                  .copyWith(letterSpacing: 1.6),
                            ),
                            const SizedBox(height: 8),
                            Text(section.emoji,
                                style: const TextStyle(fontSize: 38)),
                            const SizedBox(height: 8),
                            Text(section.title, style: deckSerif(20)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                lit == 0
                    ? TextSpan(text: '${cards.length} cards · ~1 min')
                    : TextSpan(children: [
                        TextSpan(
                          text: '$lit/${cards.length}',
                          style: const TextStyle(
                            color: deckGoldLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ' stars lit${done ? ' · ✓ done' : ''}'),
                      ]),
                style: const TextStyle(color: AppColors.lavender, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrengthCard extends StatelessWidget {
  final int? percent;
  const _StrengthCard({required this.percent});

  @override
  Widget build(BuildContext context) {
    final p = percent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              p == null ? '–' : '$p%',
              semanticsLabel: p == null ? null : 'Profile $p% complete',
              style: deckSerif(34),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p == 100
                      ? 'Your profile is complete. It stands out in Discover.'
                      : 'Profile strength. Complete profiles stand out in Discover.',
                  style: const TextStyle(
                      color: AppColors.lavender, fontSize: 12, height: 1.45),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (p ?? 0) / 100),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      backgroundColor: AppColors.surface2,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.brandMagenta),
                    ),
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

class _VibeCard extends StatelessWidget {
  final String? vibe;
  const _VibeCard({required this.vibe});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandPurple.withOpacity(.2),
            AppColors.surfaceCard.withOpacity(.85),
          ],
        ),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✦ YOUR VIBE LINE',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            vibe ?? 'Draw a deck to reveal it…',
            style: deckSerif(18, italic: true).copyWith(height: 1.3),
          ),
        ],
      ),
    );
  }
}
