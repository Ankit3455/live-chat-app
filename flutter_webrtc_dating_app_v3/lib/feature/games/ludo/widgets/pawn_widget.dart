// lib/feature/games/ludo/widgets/pawn_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_ripple_animation/simple_ripple_animation.dart';

import '../constants.dart';
import '../ludo_multiplayer_provider.dart';

class PawnWidget extends StatefulWidget {
  final int index;
  final LudoPlayerType type;
  final int step;
  final bool highlight;

  const PawnWidget(
      this.index,
      this.type, {
        super.key,
        this.highlight = false,
        this.step = -1,
      });

  @override
  State<PawnWidget> createState() => _PawnWidgetState();
}

class _PawnWidgetState extends State<PawnWidget> with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(PawnWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight && !oldWidget.highlight) {
      // Start bounce animation when highlighted
      _bounceController.repeat(reverse: true);
    } else if (!widget.highlight && oldWidget.highlight) {
      // Stop animation when not highlighted
      _bounceController.stop();
      _bounceController.reset();
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (widget.type) {
      case LudoPlayerType.green:
        color = LudoColor.green;
        break;
      case LudoPlayerType.yellow:
        color = LudoColor.yellow;
        break;
      case LudoPlayerType.blue:
        color = LudoColor.blue;
        break;
      case LudoPlayerType.red:
        color = LudoColor.red;
        break;
    }

    return IgnorePointer(
      ignoring: !widget.highlight,
      child: GestureDetector(
        onTap: () => _handleTap(context),
        child: AnimatedBuilder(
          animation: _bounceController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, widget.highlight ? _bounceAnimation.value : 0),
              child: Transform.scale(
                scale: widget.highlight ? _scaleAnimation.value : 1.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow effect when highlighted
                    if (widget.highlight)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.8),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: color.withOpacity(0.6),
                              blurRadius: 20,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),

                    // Ripple animation
                    if (widget.highlight)
                      RippleAnimation(
                        color: Colors.white,
                        minRadius: 15,
                        repeat: true,
                        ripplesCount: 3,
                        child: const SizedBox.shrink(),
                      ),

                    // Arrow indicator pointing down
                    if (widget.highlight)
                      Positioned(
                        top: -20,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 500),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: const Icon(
                                Icons.arrow_downward,
                                color: Colors.white,
                                size: 16,
                              ),
                            );
                          },
                        ),
                      ),

                    // Pawn body with enhanced border when highlighted
                    Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.highlight ? Colors.white : color,
                          width: widget.highlight ? 3 : 2,
                        ),
                        boxShadow: widget.highlight
                            ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                            : null,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          gradient: widget.highlight
                              ? RadialGradient(
                            colors: [
                              color.withOpacity(1),
                              color.withOpacity(0.7),
                            ],
                          )
                              : null,
                        ),
                      ),
                    ),

                    // "TAP" text indicator
                    if (widget.highlight)
                      Positioned(
                        bottom: -18,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'TAP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (!widget.highlight) return;

    final provider = context.read<LudoMultiplayerProvider>();
    if (!provider.isLocalPlayerTurn) return;

    int toStep;
    if (widget.step == -1) {
      toStep = 0;
    } else {
      toStep = widget.step + provider.diceResult;
    }

    provider.move(widget.type, widget.index, toStep);
  }
}