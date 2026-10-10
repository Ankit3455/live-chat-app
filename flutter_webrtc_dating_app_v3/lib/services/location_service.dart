import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:availchat/core/utils/geohash.dart';

enum LocationUpdateResult {
  updated,

  /// Skipped because the last update is recent enough.
  fresh,
  serviceDisabled,
  denied,

  /// Denied with "don't ask again"; only the system settings can fix it.
  permanentlyDenied,
  notSignedIn,
  failed,
}

/// Single place that captures the user's location (DEST-081).
/// Writes to the user's own doc only: coordinates rounded to ~1 km plus a
/// precision-5 geohash. The public mirror publishes only the geohash.
///
/// A device fix ('gps') wins over a typed city ('city'): the city's centre
/// only fills in when there is no recent device fix.
///
/// Each saved position is reverse-geocoded on the device (no API key) into
/// `geoCity` (private, for the user's own labels) and `countryCode` (ISO,
/// public: coarse enough to share).
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Background refreshes (e.g. on resume) run at most this often.
  static const Duration refreshInterval = Duration(minutes: 30);

  /// A device fix younger than this is not replaced by a typed city.
  static const Duration gpsTrumpsCityFor = Duration(days: 7);

  static const String sourceGps = 'gps';
  static const String sourceCity = 'city';

  DateTime? _lastAttempt;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const String _askedKey = 'location_permission_asked';

  /// Shows the location prompt once per install (right after the
  /// notification prompt, when the user first reaches the app), then saves
  /// a first position if allowed. Marked as asked only once the prompt has
  /// completed, so a failed attempt is retried on the next launch.
  Future<void> requestOnce() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) ?? false) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      await prefs.setBool(_askedKey, true);
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        await updateCurrentLocation(force: true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Location prompt failed: $e');
    }
  }

  /// Asks for permission if needed and saves the current position.
  /// [force] ignores the refresh interval (explicit user action).
  Future<LocationUpdateResult> updateCurrentLocation(
      {bool force = false}) async {
    return (await _capture(force: force)).result;
  }

  /// "Use my current location": saves the device position like
  /// [updateCurrentLocation] and returns the city it is in (null when the
  /// position or the city can't be found).
  Future<({LocationUpdateResult result, String? city})> currentCity() async {
    final (:result, :position) = await _capture(force: true);
    if (position == null) return (result: result, city: null);
    final place = await placeOf(position.latitude, position.longitude);
    return (result: result, city: place.city);
  }

  Future<({LocationUpdateResult result, Position? position})> _capture(
      {required bool force}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return (result: LocationUpdateResult.notSignedIn, position: null);
    }

    try {
      if (!force && !await _isStale(uid)) {
        return (result: LocationUpdateResult.fresh, position: null);
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        return (result: LocationUpdateResult.serviceDisabled, position: null);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return (result: LocationUpdateResult.permanentlyDenied, position: null);
      }
      if (permission == LocationPermission.denied) {
        return (result: LocationUpdateResult.denied, position: null);
      }

      _lastAttempt = DateTime.now();
      final position = await _currentPosition();
      if (position == null) {
        return (result: LocationUpdateResult.failed, position: null);
      }
      await _save(uid, position.latitude, position.longitude, sourceGps);
      unawaited(_savePlace(uid, position.latitude, position.longitude));
      return (result: LocationUpdateResult.updated, position: position);
    } catch (e) {
      if (kDebugMode) debugPrint('Location update failed: $e');
      return (result: LocationUpdateResult.failed, position: null);
    }
  }

  /// Silent refresh for app resume: never prompts, throttled.
  Future<void> refreshIfPermitted() async {
    final last = _lastAttempt;
    if (last != null && DateTime.now().difference(last) < refreshInterval) {
      return;
    }
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      await updateCurrentLocation();
    } catch (e) {
      if (kDebugMode) debugPrint('Location refresh skipped: $e');
    }
  }

  /// Geocodes a typed city and saves its centre, unless a device fix from the
  /// last [gpsTrumpsCityFor] exists (the device knows better than a city
  /// name). Returns false when the city cannot be resolved; the city text is
  /// still kept by the caller.
  Future<bool> updateFromCity(String city) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final query = city.trim();
    if (uid == null || query.isEmpty) return false;
    try {
      if (await _hasRecentGpsFix(uid)) return true;
      final results = await locationFromAddress(query);
      if (results.isEmpty) return false;
      await _save(
        uid,
        results.first.latitude,
        results.first.longitude,
        sourceCity,
      );
      unawaited(
        _savePlace(uid, results.first.latitude, results.first.longitude),
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Geocoding "$query" failed: $e');
      return false;
    }
  }

  /// Fields to merge into users/{uid} for a position. Also usable by screens
  /// that save the profile in one write.
  static Map<String, dynamic> locationFields(
    double lat,
    double lng, {
    String source = sourceGps,
  }) {
    return {
      'userLatitude': _round(lat),
      'userLongitude': _round(lng),
      'geohash': Geohash.encode(lat, lng),
      'lastLocationUpdate': DateTime.now().millisecondsSinceEpoch,
      'locationSource': source,
    };
  }

  /// A balanced (cell/Wi-Fi, ~100 m) fix, falling back to the last known
  /// position when a fresh one times out (e.g. indoors). Low-power accuracy
  /// can be several km off, enough to land in the wrong 5 km cell.
  Future<Position?> _currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      if (kDebugMode)
        debugPrint('Fresh position failed, trying last known: $e');
      return Geolocator.getLastKnownPosition();
    }
  }

  /// City and country of a position from the platform geocoder, or nulls.
  static Future<({String? city, String? countryCode})> placeOf(
    double lat,
    double lng,
  ) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 8));
      if (marks.isEmpty) return (city: null, countryCode: null);
      final m = marks.first;
      String? clean(String? v) {
        final t = v?.trim() ?? '';
        return t.isEmpty ? null : t;
      }

      final code = clean(m.isoCountryCode)?.toUpperCase();
      return (
        city: clean(m.locality) ?? clean(m.subAdministrativeArea),
        countryCode: code != null && code.length == 2 ? code : null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Reverse geocoding failed: $e');
      return (city: null, countryCode: null);
    }
  }

  Future<void> _savePlace(String uid, double lat, double lng) async {
    final place = await placeOf(lat, lng);
    final fields = <String, dynamic>{
      if (place.city != null) 'geoCity': place.city,
      if (place.countryCode != null) 'countryCode': place.countryCode,
    };
    if (fields.isEmpty) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .set(fields, SetOptions(merge: true))
          .timeout(const Duration(seconds: 6), onTimeout: () {});
    } catch (e) {
      if (kDebugMode) debugPrint('Saving place failed: $e');
    }
  }

  Future<bool> _hasRecentGpsFix(String uid) async {
    try {
      final data = (await _db.collection('users').doc(uid).get()).data();
      final ms = data?['lastLocationUpdate'];
      if (data?['locationSource'] != sourceGps || ms is! num) return false;
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ms.toInt()));
      return age < gpsTrumpsCityFor;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> _isStale(String uid) async {
    final last = _lastAttempt;
    if (last != null && DateTime.now().difference(last) < refreshInterval) {
      return false;
    }
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
      final ms = snap.data()?['lastLocationUpdate'];
      if (ms is num) {
        final age = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(ms.toInt()));
        return age >= refreshInterval;
      }
    } catch (_) {
      // Not cached: treat as stale.
    }
    return true;
  }

  Future<void> _save(String uid, double lat, double lng, String source) async {
    // Offline writes resolve only on server ack; the local cache is updated
    // immediately, so do not block the UI for long.
    await _db
        .collection('users')
        .doc(uid)
        .set(
          locationFields(lat, lng, source: source),
          SetOptions(merge: true),
        )
        .timeout(const Duration(seconds: 6), onTimeout: () {});
  }

  // Two decimals is about 1 km: enough for 5 km distance buckets.
  static double _round(double v) => (v * 100).roundToDouble() / 100;
}
