import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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

  /// Asks for permission if needed and saves the current position.
  /// [force] ignores the refresh interval (explicit user action).
  Future<LocationUpdateResult> updateCurrentLocation(
      {bool force = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return LocationUpdateResult.notSignedIn;

    try {
      if (!force && !await _isStale(uid)) return LocationUpdateResult.fresh;

      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationUpdateResult.serviceDisabled;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationUpdateResult.permanentlyDenied;
      }
      if (permission == LocationPermission.denied) {
        return LocationUpdateResult.denied;
      }

      _lastAttempt = DateTime.now();
      final position = await _currentPosition();
      if (position == null) return LocationUpdateResult.failed;
      await _save(uid, position.latitude, position.longitude, sourceGps);
      return LocationUpdateResult.updated;
    } catch (e) {
      if (kDebugMode) debugPrint('Location update failed: $e');
      return LocationUpdateResult.failed;
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
