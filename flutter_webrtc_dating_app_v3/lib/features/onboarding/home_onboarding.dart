import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'tour_prefs.dart';
import '../../core/constants/app_colors.dart';

/// Tour target keys. Owned by a HomeScreen instance so two mounted
/// HomeScreens never share a GlobalKey (DEST-057).
class HomeTourKeys {
  final GlobalKey bubbles = GlobalKey(debugLabel: 'tourBubbles');
  final GlobalKey firstGridItem = GlobalKey(debugLabel: 'tourFirstGrid');
  final GlobalKey secondGridItem = GlobalKey(debugLabel: 'tourSecondGrid');
}

class HomeOnboarding {
  HomeOnboarding._();

  // ===========================================================================
  // Private State
  // ===========================================================================

  static TutorialCoachMark? _tutorialCoachMark;
  static bool _isShowing = false;
  static HomeTourKeys? _attachedKeys;
  static HomeTourKeys? _showingKeys;
  static VoidCallback? _attachedReplay;

  // ===========================================================================
  // Public API
  // ===========================================================================

  /// Registers the live HomeScreen. [keys] are used when [showManually] is
  /// called without explicit keys; [onReplay] runs on [requestReplay].
  static void attach(HomeTourKeys keys, {VoidCallback? onReplay}) {
    _attachedKeys = keys;
    _attachedReplay = onReplay;
  }

  /// Call from HomeScreen.dispose. Removes a running tour that targets
  /// the disposed screen without marking it completed.
  static void detach(HomeTourKeys keys) {
    if (identical(_showingKeys, keys)) dismiss();
    if (identical(_attachedKeys, keys)) {
      _attachedKeys = null;
      _attachedReplay = null;
    }
  }

  /// Asks the live HomeScreen to replay the tour on its own context.
  /// For screens outside Home (e.g. Settings) after they pop back to Home.
  static bool requestReplay() {
    final replay = _attachedReplay;
    if (replay == null) return false;
    replay();
    return true;
  }

  /// Automatic first-run tour. Call once the discovery grid has data.
  static Future<void> tryShow(BuildContext context, HomeTourKeys keys) async {
    if (_isShowing) {
      debugPrint('🚫 HomeOnboarding: Already showing');
      return;
    }

    final isCompleted = await TourPrefs.isHomeTourCompleted();
    final forceShow = await TourPrefs.shouldForceShowAfterSignup();

    if (isCompleted && !forceShow) {
      debugPrint('🚫 HomeOnboarding: Tour already completed');
      return;
    }

    // Give the first frame with data a moment to lay out.
    for (var attempt = 0; attempt < 5; attempt++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!context.mounted) return;
      if (_isShowing) return;
      if (_validateKeys(keys)) {
        debugPrint('✅ HomeOnboarding: Starting tutorial (forceShow=$forceShow)');
        _show(context, keys);
        return;
      }
    }
    debugPrint('❌ HomeOnboarding: Keys not ready, will retry on next data load');
  }

  static Future<void> showManually(
    BuildContext context, {
    HomeTourKeys? keys,
  }) async {
    if (_isShowing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tutorial is already running'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Let a closing drawer, sheet or popped route finish animating.
    await Future.delayed(const Duration(milliseconds: 400));

    if (!context.mounted) return;

    final targetKeys = keys ?? _attachedKeys;
    if (targetKeys == null || !_validateKeys(targetKeys)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Please wait for profiles to load'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _show(context, targetKeys);
  }

  /// Removes the overlay without recording completion.
  static void dismiss() {
    final coachMark = _tutorialCoachMark;
    _cleanup();
    if (coachMark != null && coachMark.isShowing) {
      coachMark.removeOverlayEntry();
    }
  }

  static Future<void> reset() async {
    dismiss();
    await TourPrefs.resetHomeTour();
    debugPrint('🔄 HomeOnboarding: Tour reset - will show again');
  }

  static bool get isShowing => _isShowing;

  // ===========================================================================
  // Private Methods
  // ===========================================================================

  static void _show(BuildContext context, HomeTourKeys keys) {
    _isShowing = true;
    _showingKeys = keys;

    HapticFeedback.mediumImpact();

    final targets = _createTargets(context, keys);

    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: AppColors.backgroundDarkest,
      paddingFocus: 10,
      opacityShadow: 0.9,
      hideSkip: false,
      textSkip: "SKIP",
      alignSkip: Alignment.topRight,
      textStyleSkip: const TextStyle(
        color: Colors.white60,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 1,
      ),
      onFinish: () {
        debugPrint('✅ HomeOnboarding: Tutorial FINISHED');
        _onTourCompleted(context);
      },
      onSkip: () {
        debugPrint('⏭️ HomeOnboarding: Tutorial SKIPPED');
        _onTourSkipped(context);
        return true;
      },
      onClickTarget: (target) {
        debugPrint('👆 Clicked target: ${target.identify}');
        HapticFeedback.lightImpact();
      },
      onClickOverlay: (target) {
        debugPrint('👆 Overlay clicked: ${target.identify}');
      },
    );

    _tutorialCoachMark!.show(context: context);
  }

  static List<TargetFocus> _createTargets(
    BuildContext context,
    HomeTourKeys keys,
  ) {
    final List<TargetFocus> targets = [];
    final bubblesKey = keys.bubbles;
    final firstGridItemKey = keys.firstGridItem;
    final secondGridItemKey = keys.secondGridItem;
    final hasBubbles = bubblesKey.currentContext != null;
    final totalSteps = hasBubbles ? 3 : 2;
    final stepOffset = hasBubbles ? 0 : -1;

    // Get screen dimensions for smart positioning
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    // =========================================================================
    // Step 1: Online now strip - tooltip below it
    // =========================================================================
    if (hasBubbles) {
      targets.add(
        TargetFocus(
          identify: "step_1_bubbles",
          keyTarget: bubblesKey,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          enableOverlayTab: true,
          enableTargetTab: true,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              builder: (context, controller) {
                return _buildTooltipCard(
                  context: context,
                  stepNumber: 1,
                  totalSteps: totalSteps,
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.gold,
                  title: "Online now ✨",
                  description:
                  "People who are online right now. Scroll sideways and tap someone to start a chat.",
                  buttonText: "Next",
                  isLastStep: false,
                  onButtonTap: () {
                    HapticFeedback.selectionClick();
                    controller.next();
                  },
                  onSkipTap: () => _tutorialCoachMark?.skip(),
                );
              },
            ),
          ],
        ),
      );
    }

    // =========================================================================
    // Step 2: Tap to Chat - Tooltip ABOVE the card (not below)
    // =========================================================================
    if (firstGridItemKey.currentContext != null) {
      // Get the position of the first grid item
      final RenderBox? renderBox =
      firstGridItemKey.currentContext?.findRenderObject() as RenderBox?;
      final position = renderBox?.localToGlobal(Offset.zero);
      final itemTop = position?.dy ?? 0;

      // Decide: if item is in upper half of screen, show tooltip below
      // if item is in lower half, show tooltip above
      final showBelow = itemTop < (screenHeight / 2);

      targets.add(
        TargetFocus(
          identify: "step_2_tap_chat",
          keyTarget: firstGridItemKey,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          enableOverlayTab: true,
          enableTargetTab: true,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: showBelow ? ContentAlign.bottom : ContentAlign.top,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              builder: (context, controller) {
                return _buildTooltipCard(
                  context: context,
                  stepNumber: 2 + stepOffset,
                  totalSteps: totalSteps,
                  icon: Icons.touch_app_rounded,
                  iconColor: AppColors.online,
                  title: "Tap to Start Chatting 💬",
                  description:
                  "Single tap on any profile to instantly open a chat. Break the ice and say hello!",
                  buttonText: "Next",
                  isLastStep: false,
                  onButtonTap: () {
                    HapticFeedback.selectionClick();
                    controller.next();
                  },
                  onSkipTap: () => _tutorialCoachMark?.skip(),
                );
              },
            ),
          ],
        ),
      );
    }

    // =========================================================================
    // Step 3: Hold for Details - Use second grid item, tooltip ABOVE
    // =========================================================================
    final holdKey = secondGridItemKey.currentContext != null
        ? secondGridItemKey
        : firstGridItemKey;

    if (holdKey.currentContext != null) {
      // Get position of the hold target
      final RenderBox? renderBox =
      holdKey.currentContext?.findRenderObject() as RenderBox?;
      final position = renderBox?.localToGlobal(Offset.zero);
      final itemTop = position?.dy ?? 0;

      // For step 3, prefer showing ABOVE if possible (since cards are usually lower)
      final showBelow = itemTop < (screenHeight * 0.35);

      targets.add(
        TargetFocus(
          identify: "step_3_hold_details",
          keyTarget: holdKey,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          enableOverlayTab: true,
          enableTargetTab: true,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: showBelow ? ContentAlign.bottom : ContentAlign.top,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: showBelow ? 20 : (topPadding + 10),
                bottom: showBelow ? 20 : 20,
              ),
              builder: (context, controller) {
                return _buildTooltipCard(
                  context: context,
                  stepNumber: 3 + stepOffset,
                  totalSteps: totalSteps,
                  icon: Icons.pan_tool_rounded,
                  iconColor: const Color(0xFFFF6B6B),
                  title: "Hold for More Details 📋",
                  description:
                  "Press and hold any profile to see detailed info like interests, bio, and compatibility!",
                  buttonText: "Got it! 🎉",
                  isLastStep: true,
                  onButtonTap: () {
                    HapticFeedback.heavyImpact();
                    controller.next();
                  },
                  onSkipTap: null, // No skip on last step
                );
              },
            ),
          ],
        ),
      );
    }

    return targets;
  }

  // ===========================================================================
  // Tooltip Card Builder - Compact Design
  // ===========================================================================

  static Widget _buildTooltipCard({
    required BuildContext context,
    required int stepNumber,
    required int totalSteps,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String buttonText,
    required bool isLastStep,
    required VoidCallback onButtonTap,
    VoidCallback? onSkipTap,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceCard,
            AppColors.backgroundDeep,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brandPurple.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPurple.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Row
          Row(
            children: [
              // Step dots
              Row(
                children: List.generate(totalSteps, (index) {
                  final isCompleted = index < stepNumber;
                  final isCurrent = index == stepNumber - 1;

                  return Container(
                    margin: const EdgeInsets.only(right: 5),
                    width: isCurrent ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: isCompleted
                          ? const LinearGradient(
                        colors: [AppColors.brandPurple, AppColors.brandMagenta],
                      )
                          : null,
                      color: isCompleted
                          ? null
                          : AppColors.brandPurple.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const Spacer(),
              // Step counter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brandPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$stepNumber/$totalSteps",
                  style: const TextStyle(
                    color: AppColors.lavender,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Icon + Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Description
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Buttons Row
          Row(
            children: [
              // Skip button (optional)
              if (onSkipTap != null)
                GestureDetector(
                  onTap: onSkipTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 8),
                    child: Text(
                      "Skip",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              // Main button
              GestureDetector(
                onTap: onButtonTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLastStep
                          ? [AppColors.online, AppColors.onlineDeep]
                          : [AppColors.brandPurple, AppColors.brandMagenta],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isLastStep
                            ? AppColors.online
                            : AppColors.brandPurple)
                            .withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        buttonText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isLastStep
                            ? Icons.celebration_rounded
                            : Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Bubbles are optional (hidden when nobody is online);
  // the first grid card is required.
  static bool _validateKeys(HomeTourKeys keys) {
    final bubblesOk = keys.bubbles.currentContext != null;
    final firstGridOk = keys.firstGridItem.currentContext != null;

    debugPrint('🔍 Keys: bubbles=$bubblesOk, firstGrid=$firstGridOk');

    return firstGridOk;
  }

  static void _cleanup() {
    _tutorialCoachMark = null;
    _showingKeys = null;
    _isShowing = false;
  }

  static Future<void> _onTourCompleted(BuildContext context) async {
    _cleanup();
    await TourPrefs.setHomeTourCompleted(true);

    if (context.mounted) {
      _showCompletionCelebration(context);
    }
  }

  // Skip ends the tour permanently (DEST-098); it can be replayed manually.
  static Future<void> _onTourSkipped(BuildContext context) async {
    _cleanup();
    await TourPrefs.setHomeTourCompleted(true);

    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text(
            'You can replay the tutorial anytime from Settings',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.surfaceCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  static void _showCompletionCelebration(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => _CompletionDialog(),
    );
  }
}

// =============================================================================
// Completion Celebration Dialog
// =============================================================================

class _CompletionDialog extends StatefulWidget {
  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // Auto close after 3 seconds, unless the user already closed it.
    Future.delayed(const Duration(seconds: 3), _close);
  }

  void _close() {
    if (_closed || !mounted) return;
    // Barrier tap may already have popped this route.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surfaceCard, AppColors.backgroundDeep],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.online.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.online.withOpacity(0.3),
                blurRadius: 25,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.online.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: AppColors.online,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                "You're All Set! 🎉",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                "Start exploring and find your match!",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Button
              GestureDetector(
                onTap: _close,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.online, AppColors.onlineDeep],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.online.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    "Let's Go!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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