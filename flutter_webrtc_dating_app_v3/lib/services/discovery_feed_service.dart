import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:availchat/core/utils/auth_validators.dart';
import 'package:availchat/core/utils/geohash.dart';
import 'package:availchat/managers/filter_preferences.dart';
import 'package:availchat/models/public_profile.dart';
import 'package:availchat/models/user_model.dart';

/// Filters applied to the discovery feed. [applyFilters] off means only the
/// always-on rules apply (18+, discoverable, not self, not blocked).
@immutable
class DiscoveryFilters {
  final bool applyFilters;
  final String gender;
  final int ageMin;
  final int ageMax;
  final int distanceKm;
  final bool onlineOnly;

  /// Skip people whose own published filters exclude me (two-way filter).
  final bool mutualOnly;

  const DiscoveryFilters({
    this.applyFilters = false,
    this.gender = 'everyone',
    this.ageMin = FilterPreferences.minAllowedAge,
    this.ageMax = FilterPreferences.maxAllowedAge,
    this.distanceKm = FilterPreferences.defaultDistanceKm,
    this.onlineOnly = false,
    this.mutualOnly = true,
  });

  static Future<DiscoveryFilters> load() async {
    try {
      final p = await FilterPreferences.getInstance();
      return DiscoveryFilters(
        applyFilters: p.applyFilters,
        gender: p.showMeGender.toLowerCase(),
        ageMin: p.ageMin,
        ageMax: p.ageMax,
        distanceKm: p.distanceKm,
        onlineOnly: p.onlineOnly,
        mutualOnly: p.mutualOnly,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Discovery filters load failed: $e');
      return const DiscoveryFilters();
    }
  }
}

/// Paginated discovery feed (DEST-028). Reads `public_profiles` ordered by
/// most recent activity, 30 per page: people in my country first, then
/// everyone else. Until the profile mirror Function is
/// deployed and backfilled, it falls back to `users` and strips every
/// private field through [PublicProfile.fromUserData] before use.
class DiscoveryFeed {
  DiscoveryFeed({required this.myUid});

  static const int pageSize = 30;

  /// Raw pages scanned per [nextPage] call when client-side filters drop
  /// most results.
  static const int _maxScanPages = 4;

  /// Whether public_profiles has data; checked once per app run.
  static bool? _publicReady;

  final String myUid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _exhausted = false;
  bool _ordered = true;

  /// While set, pages are limited to this country; cleared when it runs out.
  String? _countryPhase;
  bool _countryPhaseStarted = false;
  final Set<String> _seen = {};
  final Map<String, int> _distanceKm = {};

  bool get hasMore => !_exhausted;

  /// Approximate distance (5 km buckets) computed when the profile loaded.
  int? distanceKmFor(String uid) => _distanceKm[uid];

  void reset() {
    _cursor = null;
    _exhausted = false;
    _countryPhase = null;
    _countryPhaseStarted = false;
    _seen.clear();
    _distanceKm.clear();
  }

  /// Approximate distance from [me] to [other], or null if either location
  /// is unknown. Uses my own coordinates (private to me) and the other
  /// user's geohash cell.
  static int? approxDistanceKm(UserModel? me, UserModel other) {
    if (me == null) return null;
    double? lat = me.userLatitude;
    double? lng = me.userLongitude;
    if (lat == null || lng == null) {
      final cell = Geohash.decode(me.geohash);
      if (cell == null) return null;
      lat = cell.lat;
      lng = cell.lng;
    }
    final d = Geohash.approxDistanceKm(lat, lng, other.geohash);
    return d < 0 ? null : d;
  }

  /// Next page of profiles that pass [filters]. Empty once exhausted.
  Future<List<UserModel>> nextPage({
    required DiscoveryFilters filters,
    required UserModel? me,
    Set<String> hiddenUids = const {},
  }) async {
    final out = <UserModel>[];
    final usePublic = await _isPublicReady();
    if (!_countryPhaseStarted) {
      _countryPhaseStarted = true;
      final country = me?.countryCode;
      if (usePublic && country != null && country.length == 2) {
        _countryPhase = country;
      }
    }
    var scanned = 0;
    while (!_exhausted && out.length < pageSize && scanned < _maxScanPages) {
      scanned++;
      final snap = await _fetchRaw(filters, usePublic);
      if (snap.docs.isNotEmpty) _cursor = snap.docs.last;
      if (snap.docs.length < pageSize) {
        if (_countryPhase != null) {
          // My country is done: continue with everyone (seen ones skipped).
          _countryPhase = null;
          _cursor = null;
        } else {
          _exhausted = true;
        }
      }

      final batch = <UserModel>[];
      for (final doc in snap.docs) {
        if (!_seen.add(doc.id)) continue;
        final user = _parse(doc, usePublic);
        if (user == null) continue;
        final distance = approxDistanceKm(me, user);
        if (!_passes(user, filters, distance, hiddenUids)) continue;
        if (filters.mutualOnly && !wouldShowMe(user, me, distance)) continue;
        if (distance != null) _distanceKm[doc.id] = distance;
        batch.add(user);
      }
      if (!_ordered) {
        batch.sort((a, b) =>
            (b.lastSeen ?? DateTime(0)).compareTo(a.lastSeen ?? DateTime(0)));
      }
      out.addAll(batch);
    }
    return out;
  }

  /// Always-on rules plus the user's filters.
  bool _passes(
    UserModel u,
    DiscoveryFilters f,
    int? distance,
    Set<String> hiddenUids,
  ) {
    if (u.uid == null || u.uid == myUid) return false;
    if (hiddenUids.contains(u.uid)) return false;
    if (!u.discoveryEnabled) return false;
    final age = u.age;
    if (age == null || age < AgePolicy.minAge) return false;

    if (!f.applyFilters) return true;
    if (f.gender != 'everyone' && (u.gender ?? '').toLowerCase() != f.gender) {
      return false;
    }
    if (age < f.ageMin || age > f.ageMax) return false;
    // Unknown distance on either side does not hide the profile.
    if (f.distanceKm > 0 && distance != null && distance > f.distanceKm) {
      return false;
    }
    return true;
  }

  /// Whether [other]'s published filters (gender, age range, max distance)
  /// include [me]. Missing filters, or my missing data, count as a yes.
  static bool wouldShowMe(UserModel other, UserModel? me, int? distanceKm) {
    if (me == null) return true;
    final wantGender = (other.prefGender ?? 'everyone').toLowerCase();
    final myGender = (me.gender ?? '').toLowerCase();
    if (wantGender != 'everyone' &&
        myGender.isNotEmpty &&
        myGender != wantGender) {
      return false;
    }
    final myAge = me.age;
    if (myAge != null) {
      if (other.prefAgeMin != null && myAge < other.prefAgeMin!) return false;
      if (other.prefAgeMax != null && myAge > other.prefAgeMax!) return false;
    }
    final maxKm = other.prefMaxKm;
    if (maxKm != null &&
        maxKm > 0 &&
        distanceKm != null &&
        distanceKm > maxKm) {
      return false;
    }
    return true;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchRaw(
    DiscoveryFilters f,
    bool usePublic,
  ) async {
    try {
      return await _buildQuery(f, usePublic).get();
    } on FirebaseException catch (e) {
      // Composite index not deployed yet: retry unordered.
      if (e.code == 'failed-precondition' && _ordered) {
        if (kDebugMode) debugPrint('Discovery index missing, unordered: $e');
        _ordered = false;
        _cursor = null;
        return _buildQuery(f, usePublic).get();
      }
      rethrow;
    }
  }

  Query<Map<String, dynamic>> _buildQuery(DiscoveryFilters f, bool usePublic) {
    Query<Map<String, dynamic>> q = _db
        .collection(usePublic ? PublicProfile.collection : 'users')
        .where('discoveryEnabled', isEqualTo: true);
    // public_profiles stores gender lowercased; legacy users docs may not.
    if (usePublic && f.applyFilters && f.gender != 'everyone') {
      q = q.where('gender', isEqualTo: f.gender);
    }
    final country = _countryPhase;
    if (country != null) q = q.where('countryCode', isEqualTo: country);
    // Old users docs may lack lastSeen, and orderBy drops docs without the
    // field, so only the public feed is ordered by recent activity.
    if (_ordered && usePublic) q = q.orderBy('lastSeen', descending: true);
    q = q.limit(pageSize);
    final cursor = _cursor;
    if (cursor != null) q = q.startAfterDocument(cursor);
    return q;
  }

  UserModel? _parse(
    DocumentSnapshot<Map<String, dynamic>> doc,
    bool usePublic,
  ) {
    final data = doc.data();
    if (data == null) return null;
    try {
      final map = usePublic ? data : PublicProfile.fromUserData(doc.id, data);
      return UserModel.fromMap(map, uid: doc.id);
    } catch (e) {
      if (kDebugMode) debugPrint('Skipping profile ${doc.id}: $e');
      return null;
    }
  }

  /// public_profiles is written by each user's own app (no Cloud Functions on
  /// the free plan). Every account since the 7 Oct 2026 reset has one, so the
  /// feed reads it; the sanitised `users` fallback only runs while it is
  /// empty. Once this build is out, set config/rules.legacyUsersRead to false
  /// so other users' private docs are no longer readable at all.
  static const bool _publicFeedEnabled = true;

  Future<bool> _isPublicReady() async {
    if (!_publicFeedEnabled) return false;
    final cached = _publicReady;
    if (cached != null) return cached;
    try {
      final snap = await _db
          .collection(PublicProfile.collection)
          .where('discoveryEnabled', isEqualTo: true)
          .limit(1)
          .get();
      _publicReady = snap.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('public_profiles unavailable: $e');
      _publicReady = false;
    }
    return _publicReady!;
  }

  /// One profile for display: own doc for me, else the public profile,
  /// else (interim) the sanitized users doc.
  static Future<UserModel?> fetchProfile(String uid,
      {required String myUid}) async {
    final db = FirebaseFirestore.instance;
    try {
      if (uid == myUid) {
        final own = await db.collection('users').doc(uid).get();
        return own.exists ? UserModel.fromFirestore(own) : null;
      }
      final pub = await db.collection(PublicProfile.collection).doc(uid).get();
      if (pub.exists) return UserModel.fromFirestore(pub);
      final legacy = await db.collection('users').doc(uid).get();
      final data = legacy.data();
      if (data == null) return null;
      return UserModel.fromMap(PublicProfile.fromUserData(uid, data), uid: uid);
    } catch (e) {
      if (kDebugMode) debugPrint('fetchProfile $uid failed: $e');
      return null;
    }
  }
}
