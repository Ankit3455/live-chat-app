// lib/feature/games/chat_games/build_our_date/widgets/date_card_tile.dart

import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../date_cards.dart';

/// One pickable card: emoji in a glowing disc, the label and an optional
/// "Made for you" ribbon. [selected] = my pick (lifts and glows); [dimmed] =
/// not picked by me after I chose.
class DateCardTile extends StatelessWidget {
  final DateCard card;
  final bool selected;
  final bool dimmed;
  final String? badge;
  final VoidCallback? onTap;

  static const Color _pink = Color(0xFFFF5F9E);
  static const Color _violet = Color(0xFF9B5CFF);

  const DateCardTile({
    super.key,
    required this.card,
    this.selected = false,
    this.dimmed = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: [card.label, if (badge != null) badge].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: duration,
        opacity: dimmed ? 0.4 : 1,
        child: AnimatedScale(
          duration: duration,
          scale: selected ? 1.05 : 1,
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: duration,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: selected
                  ? const LinearGradient(
                      colors: [_pink, _violet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              border: Border.all(
                color: selected ? Colors.white : Colors.white.withOpacity(0.14),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: _pink.withOpacity(0.5), blurRadius: 22)]
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onTap,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withOpacity(
                                      selected ? 0.35 : 0.16,
                                    ),
                                    Colors.white.withOpacity(0),
                                  ],
                                ),
                              ),
                              child: Text(
                                card.emoji,
                                style: const TextStyle(fontSize: 36),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              card.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white
                                : _pink.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '✨ ${badge!}',
                            style: TextStyle(
                              color: selected ? _pink : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small "emoji label" chip used on the Date card and in the chat bubble.
class DateCardChip extends StatelessWidget {
  final DateCard card;

  const DateCardChip({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${card.emoji} ${card.label}',
        style: const TextStyle(color: AppColors.white, fontSize: 13),
      ),
    );
  }
}
