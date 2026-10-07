import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Browsing filters, stored per account (`<key>_<uid>`) so a second account on
/// the same device starts from defaults. Discovery visibility is not stored
/// here: it lives in `users/{uid}.discoveryEnabled`.
class FilterPreferences {
  static const String _keyApplyFilters = 'apply_discovery_filters';
  static const String _keyShowMeGender = 'show_me_gender';
  static const String _keyAgeMin = 'filter_age_min';
  static const String _keyAgeMax = 'filter_age_max';
  static const String _keyDistanceKm = 'filter_distance_km';
  static const String _keyOnlineOnly = 'filter_online_only';
  static const String _keyMutualOnly = 'filter_mutual_only';

  static const int minAllowedAge = 18;
  static const int maxAllowedAge = 60;
  static const int defaultDistanceKm = 100;

  final SharedPreferences _prefs;
  final String _uid;

  FilterPreferences._(this._prefs, this._uid);

  /// Preferences of the signed-in user (or an anonymous bucket when signed
  /// out, which is never read by the feed).
  static Future<FilterPreferences> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '_signed_out';
    return FilterPreferences._(prefs, uid);
  }

  String _k(String key) => '${key}_$_uid';

  // ==================== GETTERS ====================

  bool get applyFilters => _prefs.getBool(_k(_keyApplyFilters)) ?? false;

  String get showMeGender =>
      _prefs.getString(_k(_keyShowMeGender)) ?? 'everyone';
  String get genderPreference => showMeGender;

  int get ageMin => (_prefs.getInt(_k(_keyAgeMin)) ?? minAllowedAge)
      .clamp(minAllowedAge, maxAllowedAge);
  int get ageMax => (_prefs.getInt(_k(_keyAgeMax)) ?? maxAllowedAge)
      .clamp(minAllowedAge, maxAllowedAge);
  int get minAge => ageMin;
  int get maxAge => ageMax;

  int get distanceKm => _prefs.getInt(_k(_keyDistanceKm)) ?? defaultDistanceKm;
  int get distancePreference => distanceKm;

  bool get onlineOnly => _prefs.getBool(_k(_keyOnlineOnly)) ?? false;

  /// Hide people whose own filters exclude me (on by default).
  bool get mutualOnly => _prefs.getBool(_k(_keyMutualOnly)) ?? true;

  // ==================== SETTERS ====================

  Future<void> setApplyFilters(bool value) async =>
      _prefs.setBool(_k(_keyApplyFilters), value);

  Future<void> setShowMeGender(String value) async =>
      _prefs.setString(_k(_keyShowMeGender), value);

  Future<void> setAgeMin(int value) async =>
      _prefs.setInt(_k(_keyAgeMin), value.clamp(minAllowedAge, maxAllowedAge));

  Future<void> setAgeMax(int value) async =>
      _prefs.setInt(_k(_keyAgeMax), value.clamp(minAllowedAge, maxAllowedAge));

  Future<void> setDistanceKm(int value) async =>
      _prefs.setInt(_k(_keyDistanceKm), value);

  Future<void> setOnlineOnly(bool value) async =>
      _prefs.setBool(_k(_keyOnlineOnly), value);

  Future<void> setMutualOnly(bool value) async =>
      _prefs.setBool(_k(_keyMutualOnly), value);

  /// Saves every filter in one go.
  Future<void> saveAll({
    required bool applyFilters,
    required String showMeGender,
    required int ageMin,
    required int ageMax,
    required int distanceKm,
    required bool onlineOnly,
    required bool mutualOnly,
  }) async {
    await setApplyFilters(applyFilters);
    await setShowMeGender(showMeGender);
    await setAgeMin(ageMin);
    await setAgeMax(ageMax);
    await setDistanceKm(distanceKm);
    await setOnlineOnly(onlineOnly);
    await setMutualOnly(mutualOnly);
  }

  // ==================== RESET ====================

  Future<void> reset() async {
    for (final key in [
      _keyApplyFilters,
      _keyShowMeGender,
      _keyAgeMin,
      _keyAgeMax,
      _keyDistanceKm,
      _keyOnlineOnly,
      _keyMutualOnly,
    ]) {
      await _prefs.remove(_k(key));
    }
  }
}
