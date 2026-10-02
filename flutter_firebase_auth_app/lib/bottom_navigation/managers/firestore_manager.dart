import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:availchat/models/user_model.dart';

import '../../core/services/location_service.dart';
import '../../managers/filter_preferences.dart';

class FirestoreManager extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  UserModel? _currentUser;
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<UserModel> get allUsers => _allUsers;
  List<UserModel> get filteredUsers => _filteredUsers;
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentUserId => _auth.currentUser?.uid;

  /// Load users based on filter preference
  Future<void> loadUsers(BuildContext context) async {
    final filterPrefs = await FilterPreferences.getInstance();
    final isFilterEnabled = filterPrefs.applyFilters; // ✅ No await (synchronous)

    if (isFilterEnabled) {
      await loadFilteredUsers(context);
    } else {
      await loadUsersFromFirestore();
    }
  }

  /// Load all users without filters (real-time)
  Future<void> loadUsersFromFirestore() async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cancel existing subscription
      await _usersSubscription?.cancel();

      // Real-time listener
      _usersSubscription = _firestore
          .collection('users')
          .snapshots()
          .listen(
            (snapshot) async {
          final userList = <UserModel>[];

          for (var doc in snapshot.docs) {
            try {
              final user = UserModel.fromFirestore(doc);
              userList.add(user);

              // Store current user
              if (user.uid == currentUid) {
                _currentUser = user;
              }
            } catch (e) {
              print('Error parsing user ${doc.id}: $e');
            }
          }

          _allUsers = userList;

          // Exclude current user from filtered list
          _filteredUsers = userList
              .where((user) => user.uid != currentUid)
              .toList();

          _isLoading = false;
          _error = null;
          notifyListeners();
        },
        onError: (error) {
          print('Error loading users: $error');
          _error = 'Error loading users: $error';
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      print('Error setting up user listener: $e');
      _error = 'Error loading users';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load filtered users based on preferences
  Future<void> loadFilteredUsers(BuildContext context) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      _error = 'User not authenticated';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load current user first
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUid)
          .get();

      if (currentUserDoc.exists) {
        _currentUser = UserModel.fromFirestore(currentUserDoc);
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

      // Get filter preferences
      final filterPrefs = await FilterPreferences.getInstance();

      // ✅ FIX: Remove await - these getters are synchronous
      final preferredGender = filterPrefs.genderPreference;
      final maxDistance = filterPrefs.distancePreference.toDouble();
      final minAge = filterPrefs.minAge;
      final maxAge = filterPrefs.maxAge;
      final onlineOnly = filterPrefs.onlineOnly;

      Query query = _firestore.collection('users');

      // Apply gender filter (case-insensitive)
      if (preferredGender.toLowerCase() != 'everyone') {
        // Query for both lowercase and capitalized versions
        final genderLower = preferredGender.toLowerCase();
        final genderCapitalized = genderLower[0].toUpperCase() +
            genderLower.substring(1);

        // Try both variations
        final futures = [
          _firestore
              .collection('users')
              .where('gender', isEqualTo: genderLower)
              .get(),
          _firestore
              .collection('users')
              .where('gender', isEqualTo: genderCapitalized)
              .get(),
        ];

        final results = await Future.wait(futures);
        final mergedDocs = <String, DocumentSnapshot>{};

        for (var result in results) {
          for (var doc in result.docs) {
            mergedDocs[doc.id] = doc;
          }
        }

        final userList = mergedDocs.values
            .where((doc) => doc.id != currentUid)
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();

        _allUsers = userList;
      } else {
        // Load all users if gender is "everyone"
        final snapshot = await _firestore.collection('users').get();
        _allUsers = snapshot.docs
            .where((doc) => doc.id != currentUid)
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();
      }

      // Apply additional filters in memory
      _filteredUsers = _allUsers.where((user) {
        // Distance filter
        if (user.userLatitude != null && user.userLongitude != null) {
          final distance = LocationUtils.calculateDistance(
            userLat,
            userLng,
            user.userLatitude!,
            user.userLongitude!,
          );
          if (distance > maxDistance) return false;
        } else {
          return false; // Exclude users without location
        }

        // Age filter
        if (user.age != null) {
          if (user.age! < minAge || user.age! > maxAge) return false;
        }

        // Online filter
        if (onlineOnly && !(user.online)) return false;

        return true;
      }).toList();

      // Sort by distance (nearest first)
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
      print('Error loading filtered users: $e');
      _error = 'Error loading users';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get top users for stories/highlights (max 10)
  List<UserModel> getTopUsers({int limit = 10}) {
    return _filteredUsers.take(limit).toList();
  }

  /// Search users by name
  List<UserModel> searchUsers(String query) {
    if (query.isEmpty) return _filteredUsers;

    final lowerQuery = query.toLowerCase();
    return _filteredUsers.where((user) {
      final username = user.username.toLowerCase();
      final bio = user.bio?.toLowerCase() ?? '';
      return username.contains(lowerQuery) || bio.contains(lowerQuery);
    }).toList();
  }

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting user: $e');
    }
    return null;
  }

  /// Update current user data
  Future<void> updateCurrentUser(Map<String, dynamic> data) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    try {
      await _firestore.collection('users').doc(currentUid).update(data);

      // Reload current user
      final doc = await _firestore.collection('users').doc(currentUid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating user: $e');
      _error = 'Failed to update profile';
      notifyListeners();
    }
  }

  /// Refresh users manually
  Future<void> refreshUsers(BuildContext context) async {
    await loadUsers(context);
  }

  /// Clean up resources
  void cleanup() {
    _usersSubscription?.cancel();
    _usersSubscription = null;
  }

  @override
  void dispose() {
    cleanup();
    super.dispose();
  }
}