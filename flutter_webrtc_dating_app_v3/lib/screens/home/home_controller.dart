import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:availchat/managers/filter_preferences.dart';
import 'package:availchat/managers/profile_completion_manager.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/services/discovery_feed_service.dart';
import 'package:availchat/services/location_service.dart';
import 'package:availchat/services/presence_watch.dart';
import 'package:availchat/services/safety_service.dart';

/// Home screen logic, kept out of the UI.
class HomeController extends ChangeNotifier with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _meSubscription;
  StreamSubscription<Set<String>>? _hiddenSubscription;
  bool _disposed = false;

  DiscoveryFeed? _feed;
  DiscoveryFilters _filters = const DiscoveryFilters();
  Set<String> _hiddenUids = const {};

  /// Passed on this device: uid -> epoch ms. Hidden for [_passFor].
  Map<String, int> _passedAt = {};
  static const Duration _passFor = Duration(days: 7);

  List<UserModel> _allUsers = [];
  List<UserModel> _displayedUsers = [];
  UserModel? _currentUser;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  DateTime? _loadMoreFailedAt;
  String? _error;

  // Bumped on every reload so a late page from an older load is dropped.
  int _loadGeneration = 0;

  // Profile Completion Banner
  int _profileCompletionPercentage = 100;
  bool _showBanner = false;
  bool _bannerDismissed = false;
  bool _profileChecked = false;

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

  /// Filters the current feed was loaded with.
  DiscoveryFilters get filters => _filters;

  int get profileCompletionPercentage => _profileCompletionPercentage;

  /// True once the profile-completion check has finished, i.e. whether the
  /// banner above the grid shows is settled. The home tour measures target
  /// positions when it starts, so it waits for this.
  bool get profileChecked => _profileChecked;
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
    // Own profile before the first page so it can apply distance; the saved
    // filters load at the same time.
    final filters = DiscoveryFilters.load();
    await _loadMeOnce(uid);
    _listenToMe(uid);
    _listenToHidden();
    unawaited(LocationService.instance.refreshIfPermitted());
    _filters = await filters;
    await _loadPassed(uid);
    await Future.wait([_reloadFeed(), _checkProfileCompletion()]);
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _meSubscription?.cancel();
    _hiddenSubscription?.cancel();
    PresenceWatch.instance.clear();
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
        _publishUsers();
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
    _publishUsers();
  }

  /// Loads the next page; call when the grid nears its end.
  Future<void> loadMore() async {
    final feed = _feed;
    if (feed == null || _isLoading || _isLoadingMore || !feed.hasMore) return;
    final failedAt = _loadMoreFailedAt;
    if (failedAt != null &&
        DateTime.now().difference(failedAt) < const Duration(seconds: 5)) {
      return;
    }
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
      _loadMoreFailedAt = null;
    } catch (e) {
      debugPrint('Discovery load more error: $e');
      _loadMoreFailedAt = DateTime.now();
    }
    if (_disposed || generation != _loadGeneration) return;
    _isLoadingMore = false;
    _publishUsers();
  }

  void _publishUsers() {
    final cutoff = DateTime.now().subtract(_passFor).millisecondsSinceEpoch;
    _displayedUsers = List.unmodifiable(
      _allUsers.where((u) => (_passedAt[u.uid] ?? 0) < cutoff),
    );
    PresenceWatch.instance.watch(
      _allUsers.map((u) => u.uid).whereType<String>(),
    );
    _notify();
  }

  // ===========================================================================
  // Pass
  // ===========================================================================

  String _passKey(String uid) => 'discover_passed_$uid';

  Future<void> _loadPassed(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_passKey(uid));
      if (raw == null) return;
      final cutoff = DateTime.now().subtract(_passFor).millisecondsSinceEpoch;
      _passedAt = {
        for (final e in (jsonDecode(raw) as Map).entries)
          if (e.value is int && (e.value as int) >= cutoff)
            e.key.toString(): e.value as int,
      };
    } catch (e) {
      debugPrint('Loading passed profiles failed: $e');
    }
  }

  Future<void> _savePassed() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_passKey(uid), jsonEncode(_passedAt));
    } catch (e) {
      debugPrint('Saving passed profiles failed: $e');
    }
  }

  /// Hides [user] from the feed on this device for a week.
  Future<void> pass(UserModel user) async {
    final uid = user.uid;
    if (uid == null) return;
    _passedAt = {..._passedAt, uid: DateTime.now().millisecondsSinceEpoch};
    _publishUsers();
    await _savePassed();
  }

  Future<void> undoPass(UserModel user) async {
    if (_passedAt.remove(user.uid) == null) return;
    _passedAt = {..._passedAt};
    _publishUsers();
    await _savePassed();
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
    } catch (e) {
      debugPrint('Error checking profile completion: $e');
    }
    _profileChecked = true;
    _notify();
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

  /// Pull-to-refresh / retry.
  Future<void> refresh() async {
    _filters = await DiscoveryFilters.load();
    await Future.wait([_reloadFeed(), _checkProfileCompletion()]);
  }

  /// Filters changed (called after DiscoverySettings).
  Future<void> onFiltersChanged() async {
    _filters = await DiscoveryFilters.load();
    await _reloadFeed();
  }

  /// Turns discovery filters off (saved values are kept) and reloads.
  Future<void> clearFilters() async {
    try {
      final prefs = await FilterPreferences.getInstance();
      await prefs.setApplyFilters(false);
    } catch (e) {
      debugPrint('Clear filters failed: $e');
    }
    await onFiltersChanged();
  }

  bool isValidUserForChat(UserModel user) {
    return user.uid != null && user.uid!.isNotEmpty;
  }
}
