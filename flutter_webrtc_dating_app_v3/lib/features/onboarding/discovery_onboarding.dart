import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'tour_prefs.dart';

class DiscoveryOnboarding {
  DiscoveryOnboarding._();

  // ===========================================================================
  // Global Keys - NOW WITH SEPARATE FILTER KEYS
  // ===========================================================================

  static final GlobalKey discoveryToggleKey = GlobalKey(debugLabel: 'discoveryToggle');
  static final GlobalKey filtersToggleKey = GlobalKey(debugLabel: 'filtersToggle');

  // ⭐ NEW: Separate keys for each filter
  static final GlobalKey genderFilterKey = GlobalKey(debugLabel: 'genderFilter');
  static final GlobalKey ageFilterKey = GlobalKey(debugLabel: 'ageFilter');
  static final GlobalKey distanceFilterKey = GlobalKey(debugLabel: 'distanceFilter');
  static final GlobalKey onlineFilterKey = GlobalKey(debugLabel: 'onlineFilter');

  static final GlobalKey locationButtonKey = GlobalKey(debugLabel: 'locationButton');
  static final GlobalKey saveButtonKey = GlobalKey(debugLabel: 'saveButton');

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
      debugPrint('🚫 DiscoveryOnboarding: Already showing');
      return;
    }

    final isCompleted = await TourPrefs.isDiscoveryTourCompleted();
    if (isCompleted) {
      debugPrint('🚫 DiscoveryOnboarding: Tour already completed');
      return;
    }

    await Future.delayed(const Duration(milliseconds: 800));

    if (!context.mounted) {
      debugPrint('⚠️ DiscoveryOnboarding: Context not mounted');
      return;
    }

    if (!_validateKeys()) {
      debugPrint('⚠️ DiscoveryOnboarding: Keys not ready, retrying...');
      await Future.delayed(const Duration(milliseconds: 500));

      if (!_validateKeys()) {
        debugPrint('❌ DiscoveryOnboarding: Keys still not ready, aborting');
        return;
      }
    }

    debugPrint('✅ DiscoveryOnboarding: Starting tutorial');
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
    await TourPrefs.resetDiscoveryTour();
    debugPrint('🔄 DiscoveryOnboarding: Tour reset');
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
      paddingFocus: 8,
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
        debugPrint('✅ DiscoveryOnboarding: Tutorial FINISHED');
        _onTourCompleted(context);
      },
      onSkip: () {
        debugPrint('⏭️ DiscoveryOnboarding: Tutorial SKIPPED');
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
    const int totalSteps = 8; // ⭐ Now 8 steps

    final topPadding = MediaQuery.of(context).padding.top;

    // =========================================================================
    // Step 1: Discovery Toggle
    // =========================================================================
    if (discoveryToggleKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "step_1_discovery_toggle",
          keyTarget: discoveryToggleKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          enableOverlayTab: true,
          enableTargetTab: true,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              builder: (context, controller) {
                return _buildCompactTooltip(
                  stepNumber: 1,
                  totalSteps: totalSteps,
                  icon: Icons.visibility_rounded,
                  iconColor: const Color(0xFF00E676),
                  title: "Your Visibility 👁️",
                  description: "Turn ON to appear in others' Discover feed",
                  onNext: () {
                    HapticFeedback.selectionClick();
                    controller.next();
                  },
                  onSkip: () => _tutorialCoachMark?.skip(),
                );
              },
            ),
          ],
        ),
      );
    }

    // =========================================================================
    // Step 2: Apply Filters Toggle
    // =========================================================================
    if (filtersToggleKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "step_2_filters_toggle",
          keyTarget: filtersToggleKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          enableOverlayTab: true,
          enableTargetTab: true,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              builder: (context, controller) {
                return _buildCompactTooltip(
                  stepNumber: 2,
                  totalSteps: totalSteps,
                  icon: Icons.filter_alt_rounded,
                  iconColor: const Color(0xFFFFD700),
                  title: "Enable Filters 🎯",
                  description: "Turn ON to filter by preferences below",
                  onNext: () {
                    HapticFeedback.selectionClick();
                    controller.next();
                  },
                  onSkip: () => _tutorialCoachMark?.skip(),
                );
              },
            ),
          ],
        ),
      );
    }

    // =========================================================================
    // Step 3: Gender Filter
    // =========================================================================
    if (genderFilterKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "step_3_gender",
          keyTarget: genderFilterKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          enableOverlayTab: true,
          enableTargetTab: true,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              builder: (context, controller) {
                return _buildCompactTooltip(
                  stepNumber: 3,
                  totalSteps: totalSteps,
                  icon: Icons.people_rounded,
                  iconColor: const Color(0xFFE91E63),
                  title: "Gender Preference 👥",
                  description: "Choose: Everyone, Men, or Women",
                  onNext: () {
                    HapticFeedback.selectionClick();
                    controller.next();
                  },
                  onSkip: () => _tutorialCoachMark?.skip(),
                );
              },
            ),
          ],
        ),
      );
    }

    // =========================================================================
    // Step 4: Age Filter
    // =========================================================================
    if (ageFilterKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "step_4_age",
          keyTarget: ageFilterKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          enableOverlayTab: true,
          enableTargetTab: true,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              builder: (context, controller) {
                return _buildCompactTooltip(
                  stepNumber: 4,
                  totalSteps: totalSteps,
                  icon: Icons.cake_rounded,
                  iconColor: const Color(0xFF64B5F6),
                  title: "Age Range 🎂",
                  description: "Set minimum and maximum age (18-60)",
                  onNext: () {
                    HapticFeedback.selectionClick();
                    controller.next();
                  },
                  onSkip: () => _tutorialCoachMark?.skip(),
                );
              },
            ),
          ],
        ),
      );
    }

    // =========================================================================
    // Step 5: Distance Filter
    // =========================================================================
    if (distanceFilterKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "step_5_distance",
          keyTarget: distanceFilterKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          enableOverlayTab: true,
          enableTargetTab: true,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              builder: (context, controller) {
                return _buildCompactTooltip(
                  stepNumber: 5,
                  totalSteps: totalSteps,
                  icon: Icons.social_distance_rounded,
                  iconColor: const Color(0xFFFF9800),
                  title: "Distance Limit 📏",
                  description: "Max distance to find matches (5-100 km)",
                  onNext: () {
                    HapticFeedback.selectionClick();
                    controller.next();
                  },
                  onSkip: () => _tutorialCoachMark?.skip(),
                );
              },
            ),
          ],
        ),
      );
    }

    // =========================================================================
    // Step 6: Online Only Filter
    // =========================================================================
    if (onlineFilterKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "step_6_online",
          keyTarget: onlineFilterKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          enableOverlayTab: true,
          enableTargetTab: true,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              builder: (context, controller) {
                return _buildCompactTooltip(
                  stepNumber: 6,
                  totalSteps: totalSteps,
                  icon: Icons.circle,
                  iconColor: const Color(0xFF4CAF50),
                  title: "Online Only 🟢",
                  description: "Show only users who are currently online",
                  onNext: () {
                    HapticFeedback.selectionClick();
                    controller.next();
                  },
                  onSkip: () => _tutorialCoachMark?.skip(),
                );
              },
            ),
          ],
        ),
      );
    }

    // =========================================================================
    // Step 7: Location Button
    // =========================================================================
    if (locationButtonKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "step_7_location",
          keyTarget: locationButtonKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          enableOverlayTab: true,
          enableTargetTab: true,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: topPadding + 16,
                bottom: 12,
              ),
              builder: (context, controller) {
                return _buildCompactTooltip(
                  stepNumber: 7,
                  totalSteps: totalSteps,
                  icon: Icons.my_location_rounded,
                  iconColor: const Color(0xFFFF6B6B),
                  title: "Update Location 📍",
                  description: "Tap to use your current location",
                  onNext: () {
                    HapticFeedback.selectionClick();
                    controller.next();
                  },
                  onSkip: () => _tutorialCoachMark?.skip(),
                );
              },
            ),
          ],
        ),
      );
    }

    // =========================================================================
    // Step 8: Save Button (FINAL)
    // =========================================================================
    if (saveButtonKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "step_8_save",
          keyTarget: saveButtonKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          enableOverlayTab: true,
          enableTargetTab: true,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: topPadding + 16,
                bottom: 12,
              ),
              builder: (context, controller) {
                return _buildCompactTooltip(
                  stepNumber: 8,
                  totalSteps: totalSteps,
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF00E676),
                  title: "Save Settings ✅",
                  description: "Don't forget to save your changes!",
                  isLastStep: true,
                  onNext: () {
                    HapticFeedback.heavyImpact();
                    controller.next();
                  },
                  onSkip: null,
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
  // Compact Tooltip Builder - Smaller, fits on mobile screens
  // ===========================================================================

  static Widget _buildCompactTooltip({
    required int stepNumber,
    required int totalSteps,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onNext,
    VoidCallback? onSkip,
    bool isLastStep = false,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D1B4E),
            Color(0xFF1A0E2E),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF7B2CBF).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Row (Compact)
          Row(
            children: [
              // Compact step dots
              Row(
                children: List.generate(totalSteps, (index) {
                  final isCompleted = index < stepNumber;
                  final isCurrent = index == stepNumber - 1;

                  return Container(
                    margin: const EdgeInsets.only(right: 3),
                    width: isCurrent ? 14 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: isCompleted
                          ? const LinearGradient(
                        colors: [Color(0xFF7B2CBF), Color(0xFF9C27B0)],
                      )
                          : null,
                      color: isCompleted
                          ? null
                          : const Color(0xFF7B2CBF).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const Spacer(),
              Text(
                "$stepNumber/$totalSteps",
                style: const TextStyle(
                  color: Color(0xFFB39DDB),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Icon + Title (Compact Row)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Description (Short)
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          // Buttons Row (Compact)
          Row(
            children: [
              if (onSkip != null)
                GestureDetector(
                  onTap: onSkip,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      "Skip",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: onNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLastStep
                          ? [const Color(0xFF00E676), const Color(0xFF00C853)]
                          : [const Color(0xFF7B2CBF), const Color(0xFF9C27B0)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isLastStep
                            ? const Color(0xFF00E676)
                            : const Color(0xFF7B2CBF))
                            .withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLastStep ? "Done!" : "Next",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isLastStep
                            ? Icons.celebration_rounded
                            : Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 14,
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
    final discoveryOk = discoveryToggleKey.currentContext != null;
    final saveOk = saveButtonKey.currentContext != null;

    debugPrint('🔍 Discovery Keys: discovery=$discoveryOk, save=$saveOk');

    return discoveryOk && saveOk;
  }

  static void _cleanup() {
    _tutorialCoachMark = null;
    _isShowing = false;
  }

  static Future<void> _onTourCompleted(BuildContext context) async {
    _cleanup();
    await TourPrefs.setDiscoveryTourCompleted(true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF00E676)),
              SizedBox(width: 10),
              Text(
                'Discovery tutorial complete!',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2D1B4E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  static Future<void> _onTourSkipped(BuildContext context) async {
    _cleanup();
    await TourPrefs.setDiscoveryTourCompleted(true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Tap help button anytime to see tutorial',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF2D1B4E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}