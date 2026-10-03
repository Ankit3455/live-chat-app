import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:availchat/managers/profile_completion_manager.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/services/discovery_feed_service.dart';
import 'package:availchat/services/location_service.dart';
import 'package:availchat/services/safety_service.dart';
import 'package:availchat/services/session_service.dart';

/// Home screen logic, kept out of the UI.
class HomeController extends ChangeNotifier with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  static const Duration _searchDebounce = Duration(milliseconds: 300);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _meSubscription;
  StreamSubscription<Set<String>>? _hiddenSubscription;
  Timer? _searchTimer;
  bool _disposed = false;

  DiscoveryFeed? _feed;
  DiscoveryFilters _filters = const DiscoveryFilters();
  Set<String> _hiddenUids = const {};

  List<UserModel> _allUsers = [];
  List<UserModel> _displayedUsers = [];
  UserModel? _currentUser;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  String _searchQuery = '';

  // Bumped on every reload so a late page from an older load is dropped.
  int _loadGeneration = 0;

  // Profile Completion Banner
  int _profileCompletionPercentage = 100;
  bool _showBanner = false;
  bool _bannerDismissed = false;

  // ===========================================================================
  // Getters
  // ===========================================================================
  List<UserModel> get displayedUsers => _displayedUsers;
  List<UserModel> get topUsers => _displayedUsers.take(10).toList();

  /// Loaded from the user's own `users/{uid}` doc, independent of the feed.
  UserModel? get currentUser => _currentUser;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _feed?.hasMore ?? false;
  String? get error => _error;

  int get profileCompletionPercentage => _profileCompletionPercentage;
  bool get showBanner =>
      _showBanner && !_bannerDismissed && _profileCompletionPercentage < 100;

  /// Approximate distance in 5 km buckets, or null when unknown.
  int? distanceKmFor(UserModel user) {
    final uid = user.uid;
    if (uid == null) return null;
    return _feed?.distanceKmFor(uid) ??
        DiscoveryFeed.approxDistanceKm(_currentUser, user);
  }

  // ===========================================================================
  // Initialization
  // ===========================================================================

  Future<void> initialize() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _error = 'Not logged in';
      _isLoading = false;
      _notify();
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _feed = DiscoveryFeed(myUid: uid);
    // Own profile first so the first page can apply distance.
    await _loadMeOnce(uid);
    _listenToMe(uid);
    _listenToHidden();
    unawaited(LocationService.instance.refreshIfPermitted());
    _filters = await DiscoveryFilters.load();
    await _reloadFeed();
    await _checkProfileCompletion();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _meSubscription?.cancel();
    _hiddenSubscription?.cancel();
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(LocationService.instance.refreshIfPermitted());
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ===========================================================================
  // Data Loading
  // ===========================================================================

  Future<void> _loadMeOnce(String uid) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (!_disposed) _currentUser = UserModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Own profile load failed: $e');
    }
  }

  void _listenToMe(String uid) {
    _meSubscription?.cancel();
    _meSubscription = _db.collection('users').doc(uid).snapshots().listen(
      (doc) {
        final previous = _currentUser;
        _currentUser = UserModel.fromFirestore(doc);
        final moved = previous != null &&
            (previous.userLatitude != _currentUser!.userLatitude ||
                previous.userLongitude != _currentUser!.userLongitude ||
                previous.geohash != _currentUser!.geohash);
        if (moved && _filters.applyFilters && _filters.distanceKm > 0) {
          unawaited(_reloadFeed());
        } else {
          _notify();
        }
      },
      onError: (Object e) => debugPrint('Own profile stream error: $e'),
    );
  }

  void _listenToHidden() {
    _hiddenSubscription?.cancel();
    _hiddenSubscription =
        SafetyService.instance.watchHiddenUserIds().listen((ids) {
      _hiddenUids = ids;
      if (_allUsers.any((u) => ids.contains(u.uid))) {
        _allUsers = _allUsers.where((u) => !ids.contains(u.uid)).toList();
        _applySearch();
      }
    });
  }

  Future<void> _reloadFeed() async {
    final feed = _feed;
    if (feed == null) return;
    final generation = ++_loadGeneration;
    feed.reset();
    _isLoading = true;
    _isLoadingMore = false;
    _notify();
    try {
      final page = await feed.nextPage(
        filters: _filters,
        me: _currentUser,
        hiddenUids: _hiddenUids,
      );
      if (_disposed || generation != _loadGeneration) return;
      _allUsers = page;
      _error = null;
    } catch (e) {
      if (_disposed || generation != _loadGeneration) return;
      debugPrint('Discovery load error: $e');
      _error = 'Failed to load users';
    }
    _isLoading = false;
    _applySearch();
  }

  /// Loads the next page; call when the grid nears its end.
  Future<void> loadMore() async {
    final feed = _feed;
    if (feed == null || _isLoading || _isLoadingMore || !feed.hasMore) return;
    final generation = _loadGeneration;
    _isLoadingMore = true;
    _notify();
    try {
      final page = await feed.nextPage(
        filters: _filters,
        me: _currentUser,
        hiddenUids: _hiddenUids,
      );
      if (_disposed || generation != _loadGeneration) return;
      _allUsers = [..._allUsers, ...page];
    } catch (e) {
      debugPrint('Discovery load more error: $e');
    }
    if (_disposed || generation != _loadGeneration) return;
    _isLoadingMore = false;
    _applySearch();
  }

  // ===========================================================================
  // Search (client-side over loaded profiles)
  // ===========================================================================

  void _applySearch() {
    final query = _searchQuery.toLowerCase().trim();
    _displayedUsers = query.isEmpty
        ? List.unmodifiable(_allUsers)
        : _allUsers.where((u) {
            final text = [
              u.username,
              u.profession ?? '',
              u.location ?? '',
              ...u.interests,
            ].join(' ').toLowerCase();
            return text.contains(query);
          }).toList();
    _notify();
  }

  // ===========================================================================
  // Profile Completion
  // ===========================================================================

  Future<void> _checkProfileCompletion() async {
    try {
      final manager = ProfileCompletionManager();
      final percentage = await manager.getCompletionPercentage();
      final show = await manager.shouldShowBanner();
      if (_disposed) return;
      _profileCompletionPercentage = percentage;
      _showBanner = show;
      _notify();
    } catch (e) {
      debugPrint('Error checking profile completion: $e');
    }
  }

  Future<void> dismissBanner() async {
    _bannerDismissed = true;
    _showBanner = false;
    _notify();
    await ProfileCompletionManager().dismissBanner();
  }

  // ===========================================================================
  // Public Actions
  // ===========================================================================

  /// Debounced search query update.
  void updateSearchQuery(String query) {
    _searchQuery = query;
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, _applySearch);
  }

  /// Pull-to-refresh / retry.
  Future<void> refresh() async {
    _filters = await DiscoveryFilters.load();
    await _reloadFeed();
    await _checkProfileCompletion();
  }

  /// Filters changed (called after DiscoverySettings).
  Future<void> onFiltersChanged() async {
    _filters = await DiscoveryFilters.load();
    await _reloadFeed();
  }

  Future<void> signOut() => SessionService.instance.signOut();

  bool isValidUserForChat(UserModel user) {
    return user.uid != null && user.uid!.isNotEmpty;
  }
}
