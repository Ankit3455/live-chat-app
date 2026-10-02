import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:availchat/models/user_model.dart';

import '../../core/services/location_service.dart';
import '../../managers/filter_preferences.dart';

/// Central Firestore data access + in-memory state for user lists / filters.
class FirestoreManager extends ChangeNotifier {
  // --- Single sources of truth ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Singleton used by places like AuthService (for stateless operations).
  /// UI should continue using the Provider<FirestoreManager> instance.
  static final FirestoreManager instance = FirestoreManager();

  // --- In-memory state ---
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  UserModel? _currentUser;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSubscription;
  bool _isLoading = false;
  String? _error;

  // --- Getters ---
  List<UserModel> get allUsers => _allUsers;
  List<UserModel> get filteredUsers => _filteredUsers;
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentUserId => _auth.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Security / cross-device support
  // ---------------------------------------------------------------------------

  /// Writes a server timestamp to users/{uid}.passwordChangedAt and returns
  /// the resolved server time (UTC). Used to sign out other devices.
  Future<DateTime> markPasswordChanged(String uid) async {
    final ref = _firestore.collection('users').doc(uid);
    await ref.set(
      {'passwordChangedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );

    // Fetch to resolve actual server time
    final snap = await ref.get();
    final ts = snap.data()?['passwordChangedAt'] as Timestamp?;
    return (ts?.toDate() ?? DateTime.now()).toUtc();
  }

  // ---------------------------------------------------------------------------
  // Unread counter
  // ---------------------------------------------------------------------------

  /// Unread counter stream (0 if absent or if an error occurs).
  Stream<int> unreadCountStream() async* {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      yield 0;
      return;
    }

    yield* _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) => (s.data()?['unreadCount'] as num? ?? 0).toInt())
        .handleError((_) => 0);
  }

  // ---------------------------------------------------------------------------
  // Loading users (filtered / unfiltered)
  // ---------------------------------------------------------------------------

  /// Entry point: decides based on local filter preference.
  Future<void> loadUsers(BuildContext context) async {
    final filterPrefs = await FilterPreferences.getInstance();
    final isFilterEnabled = filterPrefs.applyFilters;

    if (isFilterEnabled) {
      await loadFilteredUsers(context);
    } else {
      await loadUsersFromFirestore();
    }
  }

  /// Real-time all-users listener (no client-side filters except excluding self).
  Future<void> loadUsersFromFirestore() async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    _setLoading(true);

    try {
      await _usersSubscription?.cancel();

      _usersSubscription = _firestore
          .collection('users')
          .where('discoveryEnabled', isEqualTo: true)
          .snapshots()
          .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
        final userList = <UserModel>[];

        for (final doc in snapshot.docs) {
          final user = _safeUserModelFromDoc(doc);
          if (user == null) continue;

          userList.add(user);
          if (user.uid == currentUid) _currentUser = user;
        }

        _allUsers = userList;
        _filteredUsers = userList.where((u) => u.uid != currentUid).toList();

        _clearErrorAndStopLoading();
      }, onError: (error) {
        _error = 'Error loading users: $error';
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = 'Error loading users';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads users once and applies client-side filters (gender/distance/age/online).
  Future<void> loadFilteredUsers(BuildContext context) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      _error = 'User not authenticated';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _setLoading(true);

    try {
      // Ensure we have the current user loaded
      final currentUserDoc =
      await _firestore.collection('users').doc(currentUid).get();
      if (currentUserDoc.exists) {
        _currentUser = _safeUserModelFromDoc(currentUserDoc);
        if (_currentUser?.profileCompletionPercentage == null) {
          _currentUser = _currentUser!.copyWith(
            profileCompletionPercentage: 30,
          );
        }

      }

      final userLat = _currentUser?.userLatitude;
      final userLng = _currentUser?.userLongitude;

      if (userLat == null || userLng == null) {
        _error = 'Please update your location first';
        _isLoading = false;
        _filteredUsers = [];
        notifyListeners();
        return;
      }

      final filterPrefs = await FilterPreferences.getInstance();
      final preferredGender = (filterPrefs.genderPreference).toLowerCase();
      final maxDistance = filterPrefs.distancePreference.toDouble();
      final minAge = filterPrefs.minAge;
      final maxAge = filterPrefs.maxAge;
      final onlineOnly = filterPrefs.onlineOnly;

      // Gender pre-filter (two-case handling if you store mixed-case)
      if (preferredGender != 'everyone') {
        final capitalized =
            preferredGender[0].toUpperCase() + preferredGender.substring(1);

        final results = await Future.wait([
          _firestore.collection('users')
              .where('discoveryEnabled', isEqualTo: true)
              .where('gender', isEqualTo: preferredGender)
              .get(),
          _firestore.collection('users')
              .where('discoveryEnabled', isEqualTo: true)
              .where('gender', isEqualTo: capitalized)
              .get(),
        ]);

        final merged = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final res in results) {
          for (final d in res.docs) {
            merged[d.id] = d;
          }
        }

        _allUsers = merged.values
            .where((d) => d.id != currentUid)
            .map(_safeUserModelFromDoc)
            .whereType<UserModel>()
            .toList();
      } else {
        final snap = await _firestore.collection('users') .where('discoveryEnabled', isEqualTo: true).get();
        _allUsers = snap.docs
            .where((d) => d.id != currentUid)
            .map(_safeUserModelFromDoc)
            .whereType<UserModel>()
            .toList();
      }

      // Client-side filters
      _filteredUsers = _allUsers.where((user) {
        // Distance filter (exclude users with missing location)
        if (user.userLatitude == null || user.userLongitude == null) return false;
        final distance = LocationUtils.calculateDistance(
          userLat,
          userLng,
          user.userLatitude!,
          user.userLongitude!,
        );
        if (distance > maxDistance) return false;

        // Age filter
        if (user.age != null) {
          if (user.age! < minAge || user.age! > maxAge) return false;
        }

        // Online filter
        if (onlineOnly && !(user.online)) return false;

        return true;
      }).toList();

      // Sort by distance ascending
      _filteredUsers.sort((a, b) {
        final distA = LocationUtils.calculateDistance(
          userLat,
          userLng,
          a.userLatitude ?? 0.0,
          a.userLongitude ?? 0.0,
        );
        final distB = LocationUtils.calculateDistance(
          userLat,
          userLng,
          b.userLatitude ?? 0.0,
          b.userLongitude ?? 0.0,
        );
        return distA.compareTo(distB);
      });

      _isLoading = false;
      _error = _filteredUsers.isEmpty ? 'No users found matching your criteria' : null;
      notifyListeners();
    } catch (e) {
      _error = 'Error loading users';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Search / helpers
  // ---------------------------------------------------------------------------

  /// Case-insensitive search across username, bio, interests, profession, habits.
  List<UserModel> searchUsers(String query) {
    if (query.isEmpty) return _filteredUsers;

    final q = query.toLowerCase().trim();

    bool matches(UserModel u) {
      final username = (u.username).toLowerCase();
      final bio = (u.bio ?? '').toLowerCase();
      final prof = (u.profession ?? '').toLowerCase();
      final habits = (u.habits ?? '').toLowerCase();
      final interests = (u.interests ?? const <String>[]).map((e) => e.toLowerCase());

      return username.contains(q) ||
          bio.contains(q) ||
          prof.contains(q) ||
          habits.contains(q) ||
          interests.any((i) => i.contains(q));
    }

    return _filteredUsers.where(matches).toList();
  }

  /// Top N users for highlights/stories
  List<UserModel> getTopUsers({int limit = 10}) {
    if (limit <= 0) return const [];
    return _filteredUsers.take(limit).toList();
  }

  /// Safe fetch single user
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) return _safeUserModelFromDoc(doc);
    } catch (_) {
      // ignore
    }
    return null;
  }

  /// Update current user doc with partial data and refresh local model.
  Future<void> updateCurrentUser(Map<String, dynamic> data) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).update(data);

      final reloaded = await _firestore.collection('users').doc(uid).get();
      if (reloaded.exists) {
        _currentUser = _safeUserModelFromDoc(reloaded);
        notifyListeners();
      }
    } catch (_) {
      _error = 'Failed to update profile';
      notifyListeners();
    }
  }

  /// Manual refresh using current filter setting.
  Future<void> refreshUsers(BuildContext context) => loadUsers(context);

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  void cleanup() {
    _usersSubscription?.cancel();
    _usersSubscription = null;
  }

  @override
  void dispose() {
    cleanup();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _setLoading(bool v) {
    _isLoading = v;
    _error = null;
    notifyListeners();
  }

  void _clearErrorAndStopLoading() {
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // /// Parses a Firestore doc to UserModel, swallowing per-doc errors safely.
  // UserModel? _safeUserModelFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  //   try {
  //     return UserModel.fromFirestore(doc);
  //   } catch (_) {
  //     // Corrupt/bad doc — ignore just this one.
  //     return null;
  //   }
  // }

  UserModel? _safeUserModelFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return UserModel.fromMap(doc.data() ?? {}, uid: doc.id);
    } catch (_) {
      return null;
    }
  }
}
