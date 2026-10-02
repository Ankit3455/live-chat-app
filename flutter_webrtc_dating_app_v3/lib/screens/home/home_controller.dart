import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:availchat/managers/filter_preferences.dart';
import 'package:availchat/managers/profile_completion_manager.dart';
import 'package:availchat/models/user_model.dart';

/// Home Screen ka sara logic yahan hai
/// UI se completely alag
class HomeController extends ChangeNotifier {
  // ===========================================================================
  // Firebase Instances
  // ===========================================================================
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // ===========================================================================
  // Subscriptions
  // ===========================================================================
  StreamSubscription<QuerySnapshot>? _usersSubscription;

  // ===========================================================================
  // State Variables
  // ===========================================================================
  List<UserModel> _allUsers = [];
  List<UserModel> _displayedUsers = [];
  UserModel? _currentUser;

  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  // Profile Completion Banner
  int _profileCompletionPercentage = 100;
  bool _showBanner = false;
  bool _bannerDismissed = false;

  // Filters
  bool _applyFilters = false;
  String _prefShowMeGender = 'everyone';
  int _prefAgeMin = 18;
  int _prefAgeMax = 60;
  int _prefDistanceKm = 100;
  bool _prefOnlineOnly = false;

  // ===========================================================================
  // Getters (UI ke liye read-only access)
  // ===========================================================================
  List<UserModel> get displayedUsers => _displayedUsers;
  List<UserModel> get topUsers => _displayedUsers.take(10).toList();
  UserModel? get currentUser => _currentUser;

  bool get isLoading => _isLoading;
  String? get error => _error;

  int get profileCompletionPercentage => _profileCompletionPercentage;
  bool get showBanner => _showBanner && !_bannerDismissed && _profileCompletionPercentage < 100;

  // ===========================================================================
  // Initialization
  // ===========================================================================

  Future<void> initialize() async {
    await _loadFilters();
    _loadUsers();
    await _checkProfileCompletion();
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // Data Loading
  // ===========================================================================

  void _loadUsers() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      _error = 'Not logged in';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _usersSubscription?.cancel();

    _usersSubscription = _db
        .collection('users')
        .where('discoveryEnabled', isEqualTo: true)
        .limit(120)
        .snapshots()
        .listen(
          (snapshot) {
        final userList = snapshot.docs.map((doc) {
          try {
            return UserModel.fromFirestore(doc);
          } catch (e) {
            debugPrint('❌ Error parsing user ${doc.id}: $e');
            return null;
          }
        }).whereType<UserModel>().toList();

        _currentUser = userList.firstWhere(
              (u) => u.uid == currentUid,
          orElse: () => UserModel(uid: currentUid),
        );
        _allUsers = userList.where((u) => u.uid != currentUid).toList();
        _error = null;

        _applyFiltersToUsers();
      },
      onError: (error) {
        debugPrint('❌ Users stream error: $error');
        _error = 'Failed to load users';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _loadFilters() async {
    try {
      final prefs = await FilterPreferences.getInstance();
      _applyFilters = prefs.applyFilters;
      _prefShowMeGender = prefs.showMeGender;
      _prefAgeMin = prefs.ageMin;
      _prefAgeMax = prefs.ageMax;
      _prefDistanceKm = prefs.distanceKm;
      _prefOnlineOnly = prefs.onlineOnly;
    } catch (e) {
      debugPrint('❌ Error loading filters: $e');
    }
  }

  // ===========================================================================
  // Filtering Logic
  // ===========================================================================

  void _applyFiltersToUsers() {
    final query = _searchQuery.toLowerCase().trim();

    List<UserModel> filtered = _allUsers.where((u) {
      // Skip users with discovery disabled
      if (u.discoveryEnabled == false) return false;

      // Apply filters only if enabled
      if (_applyFilters) {
        // Gender filter
        if (_prefShowMeGender != 'everyone') {
          final g = (u.gender ?? '').toLowerCase();
          if (g != _prefShowMeGender) return false;
        }

        // Age filter
        final age = u.age ?? _ageFromDob(u.dob);
        if (age != null) {
          if (age < _prefAgeMin || age > _prefAgeMax) return false;
        }

        // Online only filter
        if (_prefOnlineOnly && !u.online) return false;

        // Distance filter
        if (_prefDistanceKm > 0 &&
            _currentUser?.userLatitude != null &&
            _currentUser?.userLongitude != null &&
            u.userLatitude != null &&
            u.userLongitude != null) {
          final d = _distanceKm(
            _currentUser!.userLatitude!,
            _currentUser!.userLongitude!,
            u.userLatitude!,
            u.userLongitude!,
          );
          if (d > _prefDistanceKm) return false;
        }
      }

      // Search filter (always applies)
      if (query.isNotEmpty) {
        final searchableText = [
          u.username,
          u.profession ?? '',
          u.location ?? '',
          ...u.interests,
        ].join(' ').toLowerCase();

        if (!searchableText.contains(query)) return false;
      }

      return true;
    }).toList();

    // Sort by distance if location available
    if (_currentUser?.userLatitude != null &&
        _currentUser?.userLongitude != null) {
      filtered.sort((a, b) {
        final da = (a.userLatitude != null && a.userLongitude != null)
            ? _distanceKm(
          _currentUser!.userLatitude!,
          _currentUser!.userLongitude!,
          a.userLatitude!,
          a.userLongitude!,
        )
            : double.infinity;
        final db = (b.userLatitude != null && b.userLongitude != null)
            ? _distanceKm(
          _currentUser!.userLatitude!,
          _currentUser!.userLongitude!,
          b.userLatitude!,
          b.userLongitude!,
        )
            : double.infinity;
        return da.compareTo(db);
      });
    }

    _displayedUsers = filtered;
    _isLoading = false;
    notifyListeners();
  }

  // ===========================================================================
  // Profile Completion
  // ===========================================================================

  Future<void> _checkProfileCompletion() async {
    try {
      final manager = ProfileCompletionManager();
      _profileCompletionPercentage = await manager.getCompletionPercentage();
      _showBanner = await manager.shouldShowBanner();
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking profile completion: $e');
    }
  }

  void dismissBanner() async {
    await ProfileCompletionManager().dismissBanner();
    _bannerDismissed = true;
    _showBanner = false;
    notifyListeners();
  }

  // ===========================================================================
  // Public Actions (UI se call hone wale methods)
  // ===========================================================================

  /// Search query update
  void updateSearchQuery(String query) {
    _searchQuery = query;
    _applyFiltersToUsers();
  }

  /// Refresh all data
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    await _loadFilters();
    _loadUsers();
    await _checkProfileCompletion();
  }

  /// Filters changed (called after DiscoverySettings)
  Future<void> onFiltersChanged() async {
    await _loadFilters();
    _applyFiltersToUsers();
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Check if user ID is valid for chat
  bool isValidUserForChat(UserModel user) {
    return user.uid != null && user.uid!.isNotEmpty;
  }

  // ===========================================================================
  // Helper Methods (Private)
  // ===========================================================================

  int? _ageFromDob(String? dob) {
    if (dob == null || dob.trim().isEmpty) return null;
    try {
      final parts = dob.split(RegExp(r'[/\-]'));
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final birth = DateTime(year, month, day);
        final now = DateTime.now();
        int age = now.year - birth.year;
        if (now.month < birth.month ||
            (now.month == birth.month && now.day < birth.day)) {
          age--;
        }
        return age;
      }
    } catch (_) {}
    return null;
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);
}