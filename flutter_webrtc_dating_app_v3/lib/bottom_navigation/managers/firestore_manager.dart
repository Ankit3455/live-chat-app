import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:availchat/models/user_model.dart';
import 'package:availchat/services/discovery_feed_service.dart';
import 'package:availchat/services/safety_service.dart';

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
  DiscoveryFeed? _feed;
  DiscoveryFilters _filters = const DiscoveryFilters();
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
  // Loading users (paginated public profiles, see DiscoveryFeed)
  // ---------------------------------------------------------------------------

  /// Loads the first discovery page with the user's saved filters.
  Future<void> loadUsers(BuildContext context) => _loadFirstPage();

  /// First page without the user's filters (18+/blocked rules still apply).
  Future<void> loadUsersFromFirestore() =>
      _loadFirstPage(filters: const DiscoveryFilters());

  /// First page with the user's saved filters applied.
  Future<void> loadFilteredUsers(BuildContext context) => _loadFirstPage();

  bool get hasMore => _feed?.hasMore ?? false;

  /// Next page, appended to [filteredUsers].
  Future<void> loadMoreUsers() async {
    final feed = _feed;
    if (feed == null || _isLoading || !feed.hasMore) return;
    try {
      final page = await feed.nextPage(
        filters: _filters,
        me: _currentUser,
        hiddenUids: SafetyService.instance.hiddenUserIdsNow,
      );
      _allUsers = [..._allUsers, ...page];
      _filteredUsers = _allUsers;
      notifyListeners();
    } catch (_) {
      _error = 'Error loading users';
      notifyListeners();
    }
  }

  Future<void> _loadFirstPage({DiscoveryFilters? filters}) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      _error = 'User not authenticated';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      // Current user always comes from the own doc, never from the feed.
      final me = await _firestore.collection('users').doc(currentUid).get();
      _currentUser = me.exists ? _safeUserModelFromDoc(me) : null;

      _filters = filters ?? await DiscoveryFilters.load();
      if (_feed?.myUid != currentUid) _feed = DiscoveryFeed(myUid: currentUid);
      _feed!.reset();
      _allUsers = await _feed!.nextPage(
        filters: _filters,
        me: _currentUser,
        hiddenUids: SafetyService.instance.hiddenUserIdsNow,
      );
      _filteredUsers = _allUsers;
      _isLoading = false;
      _error = _filteredUsers.isEmpty && _filters.applyFilters
          ? 'No users found matching your criteria'
          : null;
      notifyListeners();
    } catch (e) {
      _error = 'Error loading users';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Approximate distance (5 km buckets) to a loaded profile.
  int? distanceKmFor(UserModel user) => user.uid == null
      ? null
      : _feed?.distanceKmFor(user.uid!) ??
          DiscoveryFeed.approxDistanceKm(_currentUser, user);

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
      final interests = u.interests.map((e) => e.toLowerCase());

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

  /// Own profile for me, the public profile for anyone else.
  Future<UserModel?> getUserById(String userId) async {
    final me = _auth.currentUser?.uid;
    if (me == null) return null;
    return DiscoveryFeed.fetchProfile(userId, myUid: me);
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
    _feed = null;
    _allUsers = [];
    _filteredUsers = [];
    _currentUser = null;
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

  UserModel? _safeUserModelFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return UserModel.fromMap(doc.data() ?? {}, uid: doc.id);
    } catch (_) {
      return null;
    }
  }
}
