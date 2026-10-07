import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:availchat/core/constants/app_colors.dart';
import 'package:availchat/core/utils/astrology_utils.dart';
import 'package:availchat/core/utils/compatibility_utils.dart';
import 'package:availchat/core/utils/discover_picks.dart';
import 'package:availchat/core/utils/haptics.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/screens/questionnaire/deck/deck_widgets.dart';

import 'cosmic_match_card.dart';

/// Today's three most compatible people as face-down cards. Tapping flips a
/// card; tapping a revealed card opens the profile. Flips are remembered for
/// the day on this device.
class TonightsDraw extends StatefulWidget {
  final List<UserModel> picks;
  final UserModel? me;
  final ValueChanged<UserModel> onOpen;
  const TonightsDraw({
    super.key,
    required this.picks,
    required this.me,
    required this.onOpen,
  });

  @override
  State<TonightsDraw> createState() => _TonightsDrawState();
}

class _TonightsDrawState extends State<TonightsDraw> {
  Set<String> _revealed = {};
  late String _day = DiscoverPicks.dayKey(DateTime.now());

  String get _prefsKey => 'discover_draw_revealed';

  @override
  void initState() {
    super.initState();
    _loadRevealed();
  }

  void _onNewDay() => setState(() {
        _day = DiscoverPicks.dayKey(DateTime.now());
        _revealed = {};
      });

  Future<void> _loadRevealed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey) ?? const [];
      // Stored as "<day>|<uid>"; other days are dropped.
      final today = {
        for (final s in saved)
          if (s.startsWith('$_day|')) s.substring(_day.length + 1),
      };
      if (mounted) setState(() => _revealed = today);
    } catch (e) {
      debugPrint('Loading tonight\'s draw failed: $e');
    }
  }

  Future<void> _reveal(UserModel u) async {
    final uid = u.uid;
    if (uid == null) return;
    if (_revealed.contains(uid)) {
      widget.onOpen(u);
      return;
    }
    Haptics.medium();
    setState(() => _revealed = {..._revealed, uid});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKey,
        [for (final r in _revealed) '$_day|$r'],
      );
    } catch (e) {
      debugPrint('Saving tonight\'s draw failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final picks = widget.picks;
    final revealedCount = picks.where((p) => _revealed.contains(p.uid)).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text("Tonight's Draw", style: deckSerif(23)),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Your most compatible people today',
                      style: TextStyle(
                          color: AppColors.textSubtle, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              _Countdown(onNewDay: _onNewDay),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (var i = 0; i < picks.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Transform.translate(
                    offset: Offset(0, i == 1 || picks.length == 1 ? 0 : 6),
                    child: Transform.rotate(
                      angle: picks.length == 3 ? (i - 1) * .07 : 0,
                      child: _DrawCard(
                        index: i,
                        user: picks[i],
                        me: widget.me,
                        revealed: _revealed.contains(picks[i].uid),
                        onTap: () => _reveal(picks[i]),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          revealedCount == 0
              ? 'Tap a card to reveal ✦'
              : revealedCount < picks.length
                  ? '${picks.length - revealedCount} left · tap a revealed card to open it'
                  : 'All revealed. Tap a card to open the profile.',
          style: const TextStyle(color: AppColors.textSubtle, fontSize: 11.5),
        ),
      ],
    );
  }
}

/// "New draw in hh:mm:ss"; ticks on its own so the cards don't rebuild.
class _Countdown extends StatefulWidget {
  final VoidCallback onNewDay;
  const _Countdown({required this.onNewDay});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;
  late String _day = DiscoverPicks.dayKey(DateTime.now());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final day = DiscoverPicks.dayKey(DateTime.now());
      if (day != _day) {
        _day = day;
        widget.onNewDay();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = DiscoverPicks.untilNextDraw(DateTime.now());
    String two(int v) => v.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withOpacity(.3)),
      ),
      child: Text(
        'New draw in ${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}',
        style: const TextStyle(
          color: deckGoldLight,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _DrawCard extends StatelessWidget {
  final int index;
  final UserModel user;
  final UserModel? me;
  final bool revealed;
  final VoidCallback onTap;
  const _DrawCard({
    required this.index,
    required this.user,
    required this.me,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final score = CompatibilityService.compatibilityScore(me, user);
    final sign = CompatibilityService.signOf(user);
    final age = user.age;
    return Semantics(
      button: true,
      label: revealed
          ? '${user.username}${age != null ? ', $age' : ''}. Open profile'
          : 'Card ${index + 1}, face down. Reveal',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: revealed ? 1 : 0),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
          builder: (context, t, _) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0012)
              ..rotateY(t * math.pi),
            child: SizedBox(
              height: 196,
              child: t < .5
                  ? TarotFrame(
                      radius: 18,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.gold.withOpacity(.45),
                              ),
                            ),
                            child: const Text(
                              '✦',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 22,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            deckNumerals[index],
                            style: deckSerif(
                              13,
                              color: deckGoldLight,
                              italic: true,
                            ).copyWith(letterSpacing: 2),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'tap to reveal',
                            style: TextStyle(
                              color: AppColors.textSubtle,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.gold.withOpacity(.55),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DiscoverPhoto(user: user, memCacheWidth: 300),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [.4, 1],
                                  colors: [
                                    Color(0x000B0614),
                                    Color(0xF20B0614),
                                  ],
                                ),
                              ),
                            ),
                            if (score != null)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: CompatRing(
                                  score: score,
                                  size: 36,
                                  stroke: 3.5,
                                ),
                              ),
                            Positioned(
                              left: 6,
                              right: 6,
                              bottom: 8,
                              child: Column(
                                children: [
                                  Text(
                                    age == null
                                        ? user.username
                                        : '${user.username}, $age',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: deckSerif(16),
                                  ),
                                  if (sign != null)
                                    Text(
                                      '${AstrologyUtils.zodiacEmoji[sign] ?? ''} $sign',
                                      style: const TextStyle(
                                        color: AppColors.lavender,
                                        fontSize: 10,
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
        ),
      ),
    );
  }
}
