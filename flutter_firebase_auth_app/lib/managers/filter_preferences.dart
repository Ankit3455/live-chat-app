import 'package:shared_preferences/shared_preferences.dart';

class FilterPreferences {
  // Keys
  static const String _keyDiscoveryEnabled = 'discovery_enabled';
  static const String _keyApplyFilters = 'apply_discovery_filters';
  static const String _keyShowMeGender = 'show_me_gender';
  static const String _keyAgeMin = 'filter_age_min';
  static const String _keyAgeMax = 'filter_age_max';
  static const String _keyDistanceKm = 'filter_distance_km';
  static const String _keyOnlineOnly = 'filter_online_only';

  final SharedPreferences _prefs;

  FilterPreferences._(this._prefs);

  static FilterPreferences? _instance;

  static Future<FilterPreferences> getInstance() async {
    _instance ??= FilterPreferences._(
      await SharedPreferences.getInstance(),
    );
    return _instance!;
  }

  // ==================== GETTERS ====================

  // Discovery visibility
  bool get discoveryEnabled => _prefs.getBool(_keyDiscoveryEnabled) ?? true;

  // Apply filters toggle
  bool get applyFilters => _prefs.getBool(_keyApplyFilters) ?? false;

  // Gender preference
  String get showMeGender => _prefs.getString(_keyShowMeGender) ?? 'everyone';
  String get genderPreference => showMeGender; // ✅ Alias for FirestoreManager

  // Age range
  int get ageMin => _prefs.getInt(_keyAgeMin) ?? 18;
  int get ageMax => _prefs.getInt(_keyAgeMax) ?? 60;
  int get minAge => ageMin; // ✅ Alias for FirestoreManager
  int get maxAge => ageMax; // ✅ Alias for FirestoreManager

  // Distance
  int get distanceKm => _prefs.getInt(_keyDistanceKm) ?? 100;
  int get distancePreference => distanceKm; // ✅ Alias for FirestoreManager

  // Online only
  bool get onlineOnly => _prefs.getBool(_keyOnlineOnly) ?? false;

  // ==================== SETTERS ====================

  Future<void> setDiscoveryEnabled(bool value) async =>
      _prefs.setBool(_keyDiscoveryEnabled, value);

  Future<void> setApplyFilters(bool value) async =>
      _prefs.setBool(_keyApplyFilters, value);

  Future<void> setShowMeGender(String value) async =>
      _prefs.setString(_keyShowMeGender, value);

  Future<void> setAgeMin(int value) async =>
      _prefs.setInt(_keyAgeMin, value);

  Future<void> setAgeMax(int value) async =>
      _prefs.setInt(_keyAgeMax, value);

  Future<void> setDistanceKm(int value) async =>
      _prefs.setInt(_keyDistanceKm, value);

  Future<void> setOnlineOnly(bool value) async =>
      _prefs.setBool(_keyOnlineOnly, value);

  // ==================== RESET ====================

  Future<void> reset() async {
    await _prefs.remove(_keyDiscoveryEnabled);
    await _prefs.remove(_keyApplyFilters);
    await _prefs.remove(_keyShowMeGender);
    await _prefs.remove(_keyAgeMin);
    await _prefs.remove(_keyAgeMax);
    await _prefs.remove(_keyDistanceKm);
    await _prefs.remove(_keyOnlineOnly);
  }
}