  // // lib/features/onboarding/tour_prefs.dart
  //
  // import 'package:shared_preferences/shared_preferences.dart';
  //
  // class TourPrefs {
  //   TourPrefs._();
  //
  //   static const String _keyHomeTourCompleted = 'home_tour_completed';
  //   static const String _keyHomeTourForceShow = 'home_tour_force_show';
  //
  //   /// Check if home tour is completed
  //   static Future<bool> isHomeTourCompleted() async {
  //     final prefs = await SharedPreferences.getInstance();
  //     return prefs.getBool(_keyHomeTourCompleted) ?? false;
  //   }
  //
  //   /// Mark home tour as completed
  //   static Future<void> setHomeTourCompleted(bool value) async {
  //     final prefs = await SharedPreferences.getInstance();
  //     await prefs.setBool(_keyHomeTourCompleted, value);
  //   }
  //
  //   /// Check if should force show after signup
  //   static Future<bool> shouldForceShowAfterSignup() async {
  //     final prefs = await SharedPreferences.getInstance();
  //     return prefs.getBool(_keyHomeTourForceShow) ?? false;
  //   }
  //
  //   /// Set force show flag (call after signup/questionnaire)
  //   static Future<void> setForceShowAfterSignup(bool value) async {
  //     final prefs = await SharedPreferences.getInstance();
  //     await prefs.setBool(_keyHomeTourForceShow, value);
  //   }
  //
  //   /// Reset all (for testing)
  //   static Future<void> resetAll() async {
  //     final prefs = await SharedPreferences.getInstance();
  //     await prefs.setBool(_keyHomeTourCompleted, false);
  //     await prefs.setBool(_keyHomeTourForceShow, false);
  //   }
  // }


  // lib/features/onboarding/tour_prefs.dart

  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:flutter/foundation.dart';

  class TourPrefs {
    TourPrefs._();

    // ===========================================================================
    // Keys - Home Tour
    // ===========================================================================
    static const String _keyHomeTourCompleted = 'home_tour_completed_v2';
    static const String _keyHomeTourSkipCount = 'home_tour_skip_count_v2';
    static const String _keyLastTourShownTime = 'last_tour_shown_time_v2';
    static const String _keyFirstAppOpen = 'first_app_open_v2';
    static const String _keyForceShowAfterSignup = 'force_show_after_signup_v2';

    // ===========================================================================
    // Keys - Discovery Tour (NEW)
    // ===========================================================================
    static const String _keyDiscoveryTourCompleted = 'discovery_tour_completed_v1';

    // ===========================================================================
    // Home Tour - Completed
    // ===========================================================================

    static Future<bool> isHomeTourCompleted() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool(_keyHomeTourCompleted) ?? false;
      } catch (e) {
        debugPrint('❌ TourPrefs error: $e');
        return false;
      }
    }

    static Future<void> setHomeTourCompleted(bool value) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyHomeTourCompleted, value);

        if (value) {
          await prefs.remove(_keyHomeTourSkipCount);
          await prefs.remove(_keyForceShowAfterSignup);
          debugPrint('✅ TourPrefs: Home tour marked COMPLETED');
        }
      } catch (e) {
        debugPrint('❌ TourPrefs setCompleted error: $e');
      }
    }

    // ===========================================================================
    // Home Tour - Force Show After Signup
    // ===========================================================================

    static Future<bool> shouldForceShowAfterSignup() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool(_keyForceShowAfterSignup) ?? false;
      } catch (e) {
        debugPrint('❌ TourPrefs shouldForceShow error: $e');
        return false;
      }
    }

    static Future<void> setForceShowAfterSignup(bool value) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyForceShowAfterSignup, value);
        debugPrint('🚀 TourPrefs: Force show after signup = $value');
      } catch (e) {
        debugPrint('❌ TourPrefs setForceShow error: $e');
      }
    }

    // ===========================================================================
    // Home Tour - Skip Handling
    // ===========================================================================

    static Future<int> getSkipCount() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getInt(_keyHomeTourSkipCount) ?? 0;
      } catch (e) {
        return 0;
      }
    }

    static Future<void> incrementSkipCount() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final current = prefs.getInt(_keyHomeTourSkipCount) ?? 0;
        await prefs.setInt(_keyHomeTourSkipCount, current + 1);
        await prefs.setInt(
            _keyLastTourShownTime, DateTime.now().millisecondsSinceEpoch);
        debugPrint('⏭️ TourPrefs: Skip count = ${current + 1}');
      } catch (e) {
        debugPrint('❌ TourPrefs incrementSkip error: $e');
      }
    }

    static Future<bool> shouldShowAfterSkip() async {
      try {
        final prefs = await SharedPreferences.getInstance();

        final skipCount = prefs.getInt(_keyHomeTourSkipCount) ?? 0;
        final lastShown = prefs.getInt(_keyLastTourShownTime) ?? 0;

        if (skipCount >= 3) {
          debugPrint('🚫 TourPrefs: Skipped 3+ times, stop showing');
          return false;
        }

        if (lastShown > 0) {
          final lastTime = DateTime.fromMillisecondsSinceEpoch(lastShown);
          final hoursPassed = DateTime.now().difference(lastTime).inHours;

          if (hoursPassed < 1) {
            debugPrint('🚫 TourPrefs: Only $hoursPassed hours passed, wait more');
            return false;
          }
        }

        return true;
      } catch (e) {
        return true;
      }
    }

    // ===========================================================================
    // First Open Detection
    // ===========================================================================

    static Future<bool> isFirstAppOpen() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final isFirst = prefs.getBool(_keyFirstAppOpen) ?? true;

        if (isFirst) {
          await prefs.setBool(_keyFirstAppOpen, false);
        }

        return isFirst;
      } catch (e) {
        return true;
      }
    }

    // ===========================================================================
    // Discovery Tour - Completed (NEW)
    // ===========================================================================

    static Future<bool> isDiscoveryTourCompleted() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool(_keyDiscoveryTourCompleted) ?? false;
      } catch (e) {
        debugPrint('❌ TourPrefs discovery error: $e');
        return false;
      }
    }

    static Future<void> setDiscoveryTourCompleted(bool value) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyDiscoveryTourCompleted, value);
        debugPrint('✅ TourPrefs: Discovery tour completed = $value');
      } catch (e) {
        debugPrint('❌ TourPrefs setDiscoveryCompleted error: $e');
      }
    }

    // ===========================================================================
    // Reset Methods
    // ===========================================================================

    static Future<void> resetHomeTour() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyHomeTourCompleted);
        await prefs.remove(_keyHomeTourSkipCount);
        await prefs.remove(_keyLastTourShownTime);
        await prefs.remove(_keyForceShowAfterSignup);
        debugPrint('🔄 TourPrefs: Home tour RESET');
      } catch (e) {
        debugPrint('❌ TourPrefs reset error: $e');
      }
    }

    static Future<void> resetDiscoveryTour() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyDiscoveryTourCompleted);
        debugPrint('🔄 TourPrefs: Discovery tour RESET');
      } catch (e) {
        debugPrint('❌ TourPrefs resetDiscovery error: $e');
      }
    }

    static Future<void> resetAll() async {
      await resetHomeTour();
      await resetDiscoveryTour();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyFirstAppOpen);
        debugPrint('🔄 TourPrefs: ALL tours RESET');
      } catch (e) {
        debugPrint('❌ TourPrefs resetAll error: $e');
      }
    }

    // ===========================================================================
    // Debug Info
    // ===========================================================================

    static Future<Map<String, dynamic>> getDebugInfo() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        return {
          'home_completed': prefs.getBool(_keyHomeTourCompleted) ?? false,
          'discovery_completed': prefs.getBool(_keyDiscoveryTourCompleted) ?? false,
          'skipCount': prefs.getInt(_keyHomeTourSkipCount) ?? 0,
          'lastShown': prefs.getInt(_keyLastTourShownTime) ?? 0,
          'firstOpen': prefs.getBool(_keyFirstAppOpen) ?? true,
          'forceShow': prefs.getBool(_keyForceShowAfterSignup) ?? false,
        };
      } catch (e) {
        return {'error': e.toString()};
      }
    }
  }