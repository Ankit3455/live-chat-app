// // lib/features/onboarding/home_onboarding.dart
//
// import 'package:flutter/material.dart';
// import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
// import 'tour_prefs.dart';
//
// class HomeOnboarding {
//   HomeOnboarding._();
//
//   // ============================================================================
//   // Global Keys (use these in HomeScreen)
//   // ============================================================================
//
//   /// Key for bubbles horizontal list (top matches / recents)
//   static final GlobalKey bubblesKey = GlobalKey();
//
//   /// Key for first grid item (first profile card)
//   static final GlobalKey firstGridItemKey = GlobalKey();
//
//   // ============================================================================
//   // Private State
//   // ============================================================================
//
//   static TutorialCoachMark? _tutorialCoachMark;
//   static bool _isShowing = false;
//
//   // ============================================================================
//   // Public API
//   // ============================================================================
//
//   /// Show onboarding if not completed and flag allows it
//   static Future<void> tryShow(BuildContext context) async {
//     final isCompleted = await TourPrefs.isHomeTourCompleted();
//     final forceShow = await TourPrefs.shouldForceShowAfterSignup();
//
//     if ((isCompleted && !forceShow) || _isShowing) {
//       debugPrint(
//           '🚫 HomeOnboarding: Skipping (completed=$isCompleted, showing=$_isShowing)');
//       return;
//     }
//
//     // Wait a bit for widgets & keys to be attached
//     await Future.delayed(const Duration(milliseconds: 800));
//
//     if (!_areKeysValid()) {
//       debugPrint('⚠️ HomeOnboarding: Keys not attached yet');
//       return;
//     }
//
//     debugPrint('✅ HomeOnboarding: Starting tutorial');
//     _show(context);
//   }
//
//   /// Manually show (for testing)
//   static Future<void> showManually(BuildContext context) async {
//     if (_isShowing) return;
//
//     await Future.delayed(const Duration(milliseconds: 300));
//
//     if (!_areKeysValid()) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please wait for screen to load')),
//       );
//       return;
//     }
//
//     _show(context);
//   }
//
//   /// Dismiss tutorial programmatically
//   static void dismiss() {
//     _tutorialCoachMark?.finish();
//     _tutorialCoachMark = null;
//     _isShowing = false;
//   }
//
//   /// Reset tour flags (useful in debug)
//   static Future<void> reset() async {
//     await TourPrefs.resetAll();
//     debugPrint('🔄 HomeOnboarding: Reset completed');
//   }
//
//   // ============================================================================
//   // Private Methods
//   // ============================================================================
//
//   static void _show(BuildContext context) {
//     _isShowing = true;
//
//     _tutorialCoachMark = TutorialCoachMark(
//       targets: _createTargets(),
//       colorShadow: const Color(0xFF1A0E2E),
//       paddingFocus: 10,
//       opacityShadow: 0.9,
//       textSkip: "SKIP",
//       textStyleSkip: const TextStyle(
//         color: Colors.white,
//         fontSize: 16,
//         fontWeight: FontWeight.bold,
//       ),
//       onFinish: () {
//         debugPrint('✅ HomeOnboarding: Tutorial finished');
//         // async call allowed, we don't need to await here
//         _markCompleted();
//         _isShowing = false;
//       },
//       // 🔴 IMPORTANT: onSkip must RETURN bool
//       onSkip: () {
//         debugPrint('⏭️ HomeOnboarding: Tutorial skipped');
//         _markCompleted();
//         _isShowing = false;
//         return true; // ✅ required by tutorial_coach_mark
//       },
//     );
//
//     // Correct usage for tutorial_coach_mark ^1.3.3
//     _tutorialCoachMark!.show(context: context);
//   }
//
//   static List<TargetFocus> _createTargets() {
//     return [
//       // ========================================================================
//       // Step 1: Bubbles (Top matches / recents)
//       // ========================================================================
//       TargetFocus(
//         identify: "bubbles-list",
//         keyTarget: bubblesKey,
//         shape: ShapeLightFocus.RRect,
//         radius: 12,
//         enableOverlayTab: true,
//         contents: [
//           TargetContent(
//             align: ContentAlign.bottom,
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
//             builder: (context, controller) {
//               return Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF2D1B4E),
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.3),
//                       blurRadius: 10,
//                       offset: const Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Row(
//                       children: const [
//                         Icon(
//                           Icons.people_outline,
//                           color: Color(0xFF7B2CBF),
//                           size: 24,
//                         ),
//                         SizedBox(width: 12),
//                         Expanded(
//                           child: Text(
//                             "Top Matches",
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 22,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 12),
//                     const Text(
//                       "These are your top matches based on compatibility. Scroll to see more!",
//                       style: TextStyle(
//                         color: Colors.white70,
//                         fontSize: 16,
//                         height: 1.4,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.end,
//                       children: const [
//                         Text(
//                           "Tap anywhere to continue",
//                           style: TextStyle(
//                             color: Color(0xFF7B2CBF),
//                             fontSize: 14,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         SizedBox(width: 8),
//                         Icon(
//                           Icons.arrow_forward,
//                           color: Color(0xFF7B2CBF),
//                           size: 16,
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//
//     // ========================================================================
// // Step 2: Tap to Chat (first grid profile)
// // ========================================================================
//     TargetFocus(
//     identify: "first-profile",
//     keyTarget: firstGridItemKey,
//     shape: ShapeLightFocus.Circle,
//     radius: 50,
//     enableOverlayTab: true,
//     contents: [
//     TargetContent(
//     // ⬇️ Yaha change karo: bottom → top
//     align: ContentAlign.top,
//     // Thoda padding bhi kam kar do
//     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
//     builder: (context, controller) {
//     return Container(
//     padding: const EdgeInsets.all(20),
//     decoration: BoxDecoration(
//     color: const Color(0xFF2D1B4E),
//     borderRadius: BorderRadius.circular(12),
//     boxShadow: [
//     BoxShadow(
//     color: Colors.black.withOpacity(0.3),
//     blurRadius: 10,
//     offset: const Offset(0, 4),
//     ),
//     ],
//     ),
//     child: Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     mainAxisSize: MainAxisSize.min,
//     children: [
//     Row(
//     children: const [
//     Icon(
//     Icons.touch_app,
//     color: Color(0xFF7B2CBF),
//     size: 24,
//     ),
//     SizedBox(width: 12),
//     Text(
//     "Tap to Chat",
//     style: TextStyle(
//     color: Colors.white,
//     fontSize: 22,
//     fontWeight: FontWeight.bold,
//     ),
//     ),
//     ],
//     ),
//     const SizedBox(height: 12),
//     const Text(
//     "Tap any profile to start a conversation instantly!",
//     style: TextStyle(
//     color: Colors.white70,
//     fontSize: 16,
//     height: 1.4,
//     ),
//     ),
//     const SizedBox(height: 16),
//     Align(
//     alignment: Alignment.centerRight,
//     child: Container(
//     padding: const EdgeInsets.symmetric(
//     horizontal: 16,
//     vertical: 8,
//     ),
//     decoration: BoxDecoration(
//     color: const Color(0xFF7B2CBF),
//     borderRadius: BorderRadius.circular(20),
//     ),
//     child: Row(
//     mainAxisSize: MainAxisSize.min,
//     children: const [
//     Text(
//     "Got it!",
//     style: TextStyle(
//     color: Colors.white,
//     fontSize: 16,
//     fontWeight: FontWeight.bold,
//     ),
//     ),
//     SizedBox(width: 8),
//     Icon(
//     Icons.check_circle_outline,
//     color: Colors.white,
//     size: 20,
//     ),
//     ],
//     ),
//     ),
//     ),
//     ],
//     ),
//     );
//     },
//     ),
//     ],
//     ),
//     ];
//   }
//
//   static bool _areKeysValid() {
//     final bubblesContext = bubblesKey.currentContext;
//     final gridContext = firstGridItemKey.currentContext;
//
//     final ok = bubblesContext != null && gridContext != null;
//     if (!ok) {
//       debugPrint(
//           '⚠️ HomeOnboarding: _areKeysValid -> bubbles=${bubblesContext != null}, grid=${gridContext != null}');
//     }
//     return ok;
//   }
//
//   static Future<void> _markCompleted() async {
//     await TourPrefs.setHomeTourCompleted(true);
//     await TourPrefs.setForceShowAfterSignup(false);
//   }
// }


// lib/features/onboarding/home_onboarding.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'tour_prefs.dart';

class HomeOnboarding {
  HomeOnboarding._();

  // ===========================================================================
  // Global Keys
  // ===========================================================================

  static final GlobalKey bubblesKey = GlobalKey(debugLabel: 'bubbles');
  static final GlobalKey firstGridItemKey = GlobalKey(debugLabel: 'firstGrid');
  static final GlobalKey secondGridItemKey = GlobalKey(debugLabel: 'secondGrid');

  // ===========================================================================
  // Private State
  // ===========================================================================

  static TutorialCoachMark? _tutorialCoachMark;
  static bool _isShowing = false;

  // ===========================================================================
  // Public API
  // ===========================================================================

  static Future<void> tryShow(BuildContext context) async {
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

    if (!forceShow) {
      final shouldShow = await TourPrefs.shouldShowAfterSkip();
      if (!shouldShow) {
        debugPrint('🚫 HomeOnboarding: Skip cooldown active');
        return;
      }
    }

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!context.mounted) {
      debugPrint('⚠️ HomeOnboarding: Context not mounted');
      return;
    }

    if (!_validateKeys()) {
      debugPrint('⚠️ HomeOnboarding: Keys not ready, retrying...');
      await Future.delayed(const Duration(milliseconds: 800));

      if (!_validateKeys()) {
        debugPrint('❌ HomeOnboarding: Keys still not ready, aborting');
        return;
      }
    }

    debugPrint('✅ HomeOnboarding: Starting tutorial (forceShow=$forceShow)');
    _show(context);
  }

  static Future<void> showManually(BuildContext context) async {
    if (_isShowing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tutorial is already running'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await Future.delayed(const Duration(milliseconds: 300));

    if (!context.mounted) return;

    if (!_validateKeys()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the screen to load'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _show(context);
  }

  static void dismiss() {
    _tutorialCoachMark?.finish();
    _cleanup();
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

  static void _show(BuildContext context) {
    _isShowing = true;

    HapticFeedback.mediumImpact();

    final targets = _createTargets(context);

    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: const Color(0xFF0D0221),
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

  static List<TargetFocus> _createTargets(BuildContext context) {
    final List<TargetFocus> targets = [];

    // Get screen dimensions for smart positioning
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    // =========================================================================
    // Step 1: Top Matches (Bubbles) - Tooltip BELOW the bubbles
    // =========================================================================
    if (bubblesKey.currentContext != null) {
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
                  totalSteps: 3,
                  icon: Icons.auto_awesome_rounded,
                  iconColor: const Color(0xFFFFD700),
                  title: "Your Top Matches ✨",
                  description:
                  "These are your best matches based on compatibility! Scroll horizontally to discover amazing people.",
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
                  stepNumber: 2,
                  totalSteps: 3,
                  icon: Icons.touch_app_rounded,
                  iconColor: const Color(0xFF00E676),
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
                  stepNumber: 3,
                  totalSteps: 3,
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
            Color(0xFF2D1B4E),
            Color(0xFF1A0E2E),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF7B2CBF).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.25),
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
                        colors: [Color(0xFF7B2CBF), Color(0xFF9C27B0)],
                      )
                          : null,
                      color: isCompleted
                          ? null
                          : const Color(0xFF7B2CBF).withOpacity(0.25),
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
                  color: const Color(0xFF7B2CBF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$stepNumber/$totalSteps",
                  style: const TextStyle(
                    color: Color(0xFFB39DDB),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "Skip",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
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
                          ? [const Color(0xFF00E676), const Color(0xFF00C853)]
                          : [const Color(0xFF7B2CBF), const Color(0xFF9C27B0)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isLastStep
                            ? const Color(0xFF00E676)
                            : const Color(0xFF7B2CBF))
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

  static bool _validateKeys() {
    final bubblesOk = bubblesKey.currentContext != null;
    final firstGridOk = firstGridItemKey.currentContext != null;

    debugPrint('🔍 Keys: bubbles=$bubblesOk, firstGrid=$firstGridOk');

    return bubblesOk && firstGridOk;
  }

  static void _cleanup() {
    _tutorialCoachMark = null;
    _isShowing = false;
  }

  static Future<void> _onTourCompleted(BuildContext context) async {
    _cleanup();
    await TourPrefs.setHomeTourCompleted(true);
    await TourPrefs.setForceShowAfterSignup(false);

    if (context.mounted) {
      _showCompletionCelebration(context);
    }
  }

  static Future<void> _onTourSkipped(BuildContext context) async {
    _cleanup();
    await TourPrefs.incrementSkipCount();
    await TourPrefs.setForceShowAfterSignup(false);

    if (context.mounted) {
      final skipCount = await TourPrefs.getSkipCount();
      if (skipCount < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'You can view the tutorial anytime from the menu',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF2D1B4E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

    // Auto close after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
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
              colors: [Color(0xFF2D1B4E), Color(0xFF1A0E2E)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF00E676).withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E676).withOpacity(0.3),
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
                  color: const Color(0xFF00E676).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: Color(0xFF00E676),
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
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E676), Color(0xFF00C853)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676).withOpacity(0.4),
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