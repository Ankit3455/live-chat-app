import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Tour flags are stored per signed-in user (uid suffix), so a second
/// account on the same device gets its own first-run tour.
class TourPrefs {
  TourPrefs._();

  // ===========================================================================
  // Keys - Home Tour
  // ===========================================================================
  static const String _keyHomeTourCompleted = 'home_tour_completed_v2';
  static const String _keyFirstAppOpen = 'first_app_open_v2';
  static const String _keyForceShowAfterSignup = 'force_show_after_signup_v2';

  // Device-wide keys from older builds; cleared on reset.
  static const String _legacyKeyHomeTourSkipCount = 'home_tour_skip_count_v2';
  static const String _legacyKeyLastTourShownTime = 'last_tour_shown_time_v2';

  // ===========================================================================
  // Keys - Discovery Tour
  // ===========================================================================
  static const String _keyDiscoveryTourCompleted = 'discovery_tour_completed_v1';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static String _userKey(String base) {
    final uid = _uid;
    return uid == null ? base : '${base}_$uid';
  }

  /// Reads a per-user "completed" flag. Falls back to the old device-wide
  /// value so users who finished the tour before uid-keying don't see it again.
  static bool _readCompleted(SharedPreferences prefs, String base) {
    final perUser = prefs.getBool(_userKey(base));
    if (perUser != null) return perUser;
    return prefs.getBool(base) ?? false;
  }

  // ===========================================================================
  // Home Tour - Completed
  // ===========================================================================

  static Future<bool> isHomeTourCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _readCompleted(prefs, _keyHomeTourCompleted);
    } catch (e) {
      debugPrint('❌ TourPrefs error: $e');
      return false;
    }
  }

  /// Finishing or skipping the tour both end it for good (DEST-098).
  static Future<void> setHomeTourCompleted(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userKey(_keyHomeTourCompleted), value);

      if (value) {
        await prefs.remove(_userKey(_keyForceShowAfterSignup));
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
      return prefs.getBool(_userKey(_keyForceShowAfterSignup)) ?? false;
    } catch (e) {
      debugPrint('❌ TourPrefs shouldForceShow error: $e');
      return false;
    }
  }

  /// Call once, from the signup completion path, while the new user is signed in.
  static Future<void> setForceShowAfterSignup(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userKey(_keyForceShowAfterSignup), value);
      debugPrint('🚀 TourPrefs: Force show after signup = $value');
    } catch (e) {
      debugPrint('❌ TourPrefs setForceShow error: $e');
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
  // Discovery Tour - Completed
  // ===========================================================================

  static Future<bool> isDiscoveryTourCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _readCompleted(prefs, _keyDiscoveryTourCompleted);
    } catch (e) {
      debugPrint('❌ TourPrefs discovery error: $e');
      return false;
    }
  }

  static Future<void> setDiscoveryTourCompleted(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userKey(_keyDiscoveryTourCompleted), value);
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
      // Explicit false so the legacy device-wide flag can't re-mark it completed.
      await prefs.setBool(_userKey(_keyHomeTourCompleted), false);
      await prefs.remove(_keyHomeTourCompleted);
      await prefs.remove(_userKey(_keyForceShowAfterSignup));
      await prefs.remove(_keyForceShowAfterSignup);
      await prefs.remove(_legacyKeyHomeTourSkipCount);
      await prefs.remove(_legacyKeyLastTourShownTime);
      debugPrint('🔄 TourPrefs: Home tour RESET');
    } catch (e) {
      debugPrint('❌ TourPrefs reset error: $e');
    }
  }

  static Future<void> resetDiscoveryTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userKey(_keyDiscoveryTourCompleted), false);
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
}
