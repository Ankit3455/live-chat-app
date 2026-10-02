import 'package:shared_preferences/shared_preferences.dart';

/// Manages profile completion progress
/// Converted from ProfileCompletionManager.kt
class ProfileCompletionManager {
  static const String _keySignupComplete = 'signup_complete';
  static const String _keyMandatoryComplete = 'mandatory_complete';
  static const String _keyLifestyleComplete = 'lifestyle_complete';
  static const String _keyPersonalityComplete = 'personality_complete';
  static const String _keyBannerDismissed = 'banner_dismissed';
  static const String _keyBannerLastShown = 'banner_last_shown';
  static const int _bannerReappearDays = 3;

  late SharedPreferences _prefs;
  bool _initialized = false;

  /// Initialize SharedPreferences
  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  // ==================== COMPLETION STATUS ====================

  Future<void> markSignupComplete() async {
    await init();
    await _prefs.setBool(_keySignupComplete, true);
  }

  Future<bool> isSignupComplete() async {
    await init();
    return _prefs.getBool(_keySignupComplete) ?? false;
  }

  Future<void> markMandatoryComplete() async {
    await init();
    await _prefs.setBool(_keyMandatoryComplete, true);
  }

  Future<bool> isMandatoryComplete() async {
    await init();
    return _prefs.getBool(_keyMandatoryComplete) ?? false;
  }

  Future<void> markLifestyleComplete() async {
    await init();
    await _prefs.setBool(_keyLifestyleComplete, true);
  }

  Future<bool> isLifestyleComplete() async {
    await init();
    return _prefs.getBool(_keyLifestyleComplete) ?? false;
  }

  Future<void> markPersonalityComplete() async {
    await init();
    await _prefs.setBool(_keyPersonalityComplete, true);
  }

  Future<bool> isPersonalityComplete() async {
    await init();
    return _prefs.getBool(_keyPersonalityComplete) ?? false;
  }

  // ==================== BANNER LOGIC ====================

  Future<void> dismissBanner() async {
    await init();
    await _prefs.setBool(_keyBannerDismissed, true);
    await _prefs.setInt(_keyBannerLastShown, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> isBannerDismissed() async {
    await init();
    return _prefs.getBool(_keyBannerDismissed) ?? false;
  }

  Future<bool> shouldShowBanner() async {
    await init();

    // Don't show if profile is complete
    if (await isProfileComplete()) return false;

    // Don't show if mandatory not complete yet
    if (!await isMandatoryComplete()) return false;

    // Check if dismissed and 3 days passed
    if (await isBannerDismissed()) {
      final lastShown = _prefs.getInt(_keyBannerLastShown) ?? 0;
      final threeDaysInMillis = _bannerReappearDays * 24 * 60 * 60 * 1000;
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastShown;

      if (elapsed >= threeDaysInMillis) {
        // Reset dismissed flag after 3 days
        await _prefs.setBool(_keyBannerDismissed, false);
        return true;
      }
      return false;
    }

    return true;
  }

  // ==================== PROFILE COMPLETION ====================

  /// Calculate profile completion percentage
  /// Signup: 40%
  /// Mandatory: +20% = 60%
  /// Lifestyle: +20% = 80%
  /// Personality: +20% = 100%
  Future<int> getCompletionPercentage() async {
    await init();
    int percentage = 0;

    if (await isSignupComplete()) percentage += 40;
    if (await isMandatoryComplete()) percentage += 20;
    if (await isLifestyleComplete()) percentage += 20;
    if (await isPersonalityComplete()) percentage += 20;

    return percentage;
  }

  // ✅ NEW METHOD - Alias for backward compatibility
  Future<int> getProfileCompletionPercentage() async {
    return await getCompletionPercentage();
  }

  Future<bool> isProfileComplete() async {
    return await getCompletionPercentage() == 100;
  }

  Future<String> getNextSection() async {
    await init();

    if (!await isMandatoryComplete()) {
      return 'Basic Details';
    } else if (!await isLifestyleComplete()) {
      return 'Lifestyle Preferences';
    } else if (!await isPersonalityComplete()) {
      return 'Personality & Views';
    } else {
      return 'All Complete!';
    }
  }

  Future<String> getCompletionMessage() async {
    final percentage = await getCompletionPercentage();

    if (percentage >= 100) {
      return 'Your profile is 100% complete! 🎉';
    } else if (percentage >= 80) {
      return 'Almost there! Complete your profile to get 5x more matches!';
    } else if (percentage >= 60) {
      return 'Great start! Add more details to improve your matches.';
    } else if (percentage >= 40) {
      return 'Complete your profile to unlock better matches!';
    } else {
      return 'Let\'s build your profile!';
    }
  }

  Future<void> reset() async {
    await init();
    await _prefs.clear();
  }
}