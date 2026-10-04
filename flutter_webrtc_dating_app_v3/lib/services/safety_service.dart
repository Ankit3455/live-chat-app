// lib/services/safety_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'conversations_repository.dart';

/// A user the signed-in user blocked, as stored in users/{me}/blocked/{uid}.
class BlockedUser {
  final String uid;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? blockedAt;

  const BlockedUser({
    required this.uid,
    this.displayName,
    this.avatarUrl,
    this.blockedAt,
  });

  factory BlockedUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final at = d['blockedAt'];
    return BlockedUser(
      uid: doc.id,
      displayName: d['displayName'] as String?,
      avatarUrl: d['avatarUrl'] as String?,
      blockedAt: at is Timestamp ? at.toDate() : null,
    );
  }
}

/// Block and report (DEST-003).
///
/// Data model (both directions are hidden everywhere):
///   users/{me}/blocked/{other}   {blockedAt, displayName?, avatarUrl?}  owner
///   users/{other}/blockedBy/{me} {blockedAt}  written by the blocker
///   reports/{autoId}             {reporterId, reportedUserId, reason, ...}
///
/// Call [start] once at app start. It follows auth state and keeps
/// [ConversationsRepository] hiding chats with blocked users either way.
class SafetyService {
  SafetyService._();
  static final SafetyService instance = SafetyService._();

  static const String blockedCollection = 'blocked';
  static const String blockedByCollection = 'blockedBy';
  static const String reportsCollection = 'reports';

  static const int maxReportDetails = 1000;
  static const int maxReportMessageIds = 50;

  /// Writes wait for the server so success is real; offline they time out.
  static const Duration _writeTimeout = Duration(seconds: 20);

  /// Report reasons shown in the dialog. Stored as-is (<= 100 chars).
  static const List<String> reportReasons = [
    'Harassment or bullying',
    'Spam or scam',
    'Fake profile',
    'Inappropriate content',
    'Underage user',
    'Other',
  ];

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _blockedSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _blockedBySub;
  String? _uid;

  List<BlockedUser>? _blocked;
  Object? _blockedError;
  Set<String> _blockedBy = const {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Idempotent. Safe to call from main and from any screen.
  void start() {
    if (_authSub != null) return;
    _authSub = _auth.authStateChanges().listen((user) {
      if (user == null) {
        _detach();
      } else {
        _attach(user.uid);
      }
    });
  }

  String get _me {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Log in required');
    }
    return uid;
  }

  void _attach(String uid) {
    if (_uid == uid && _blockedSub != null) return;
    _detach();
    _uid = uid;
    final me = _db.collection('users').doc(uid);
    _blockedSub = me
        .collection(blockedCollection)
        .snapshots()
        .listen(
          (snap) {
            _blockedError = null;
            _blocked = snap.docs.map(BlockedUser.fromDoc).toList()
              ..sort(
                (a, b) => (b.blockedAt ?? DateTime(0)).compareTo(
                  a.blockedAt ?? DateTime(0),
                ),
              );
            _publish();
          },
          onError: (Object e) {
            if (kDebugMode) debugPrint('SafetyService blocked error: $e');
            _blockedError = e;
            _publish();
          },
        );
    _blockedBySub = me
        .collection(blockedByCollection)
        .snapshots()
        .listen(
          (snap) {
            _blockedBy = snap.docs.map((d) => d.id).toSet();
            _publish();
          },
          onError: (Object e) {
            if (kDebugMode) debugPrint('SafetyService blockedBy error: $e');
          },
        );
  }

  void _detach() {
    _blockedSub?.cancel();
    _blockedBySub?.cancel();
    _blockedSub = null;
    _blockedBySub = null;
    _uid = null;
    _blocked = null;
    _blockedError = null;
    _blockedBy = const {};
    _publish();
  }

  /// Re-subscribes after a listener error (e.g. Retry on the list screen).
  void retry() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _detach();
    _attach(uid);
  }

  void _publish() {
    ConversationsRepository.instance.setHiddenUserIds(hiddenUserIdsNow);
    _changes.add(null);
  }

  /// Users I blocked plus users who blocked me (last known value).
  Set<String> get hiddenUserIdsNow => {
    ...?_blocked?.map((b) => b.uid),
    ..._blockedBy,
  };

  /// Replays the current value, then every change.
  Stream<T> _watch<T>(T Function() read) {
    start();
    return Stream<T>.multi((c) {
      void emit() {
        try {
          c.add(read());
        } catch (e) {
          c.addError(e);
        }
      }

      emit();
      final s = _changes.stream.listen((_) => emit());
      c.onCancel = s.cancel;
    });
  }

  /// Users to hide in discovery, chat lists and calls (both directions).
  Stream<Set<String>> watchHiddenUserIds() => _watch(() => hiddenUserIdsNow);

  /// Users I blocked, newest first (Blocked Users screen). Emits null until
  /// the first snapshot arrives and an error if the listener failed.
  Stream<List<BlockedUser>?> watchBlockedUsers() => _watch(() {
    final error = _blockedError;
    if (error != null) throw error;
    final list = _blocked;
    return list == null ? null : List<BlockedUser>.unmodifiable(list);
  });

  /// Whether either user blocked the other (chat screen: hide input/calls).
  Stream<bool> watchIsBlockedBetween(String otherUid) =>
      _watch(() => hiddenUserIdsNow.contains(otherUid)).distinct();

  /// Whether I blocked [otherUid] (as opposed to being blocked by them).
  bool hasBlocked(String otherUid) =>
      _blocked?.any((b) => b.uid == otherUid) ?? false;

  /// One-off server check, for flows that cannot wait for the listener.
  Future<bool> isBlockedBetween(String otherUid) async {
    final me = _db.collection('users').doc(_me);
    final results = await Future.wait([
      me.collection(blockedCollection).doc(otherUid).get(),
      me.collection(blockedByCollection).doc(otherUid).get(),
    ]);
    return results.any((s) => s.exists);
  }

  /// Blocks [otherUid]. Completes only after the server accepted both docs,
  /// so callers show success afterwards. Name/avatar are a display snapshot
  /// for the Blocked Users list.
  Future<void> block(
    String otherUid, {
    String? displayName,
    String? avatarUrl,
  }) async {
    final me = _me;
    if (otherUid.isEmpty || otherUid == me) {
      throw ArgumentError.value(otherUid, 'otherUid', 'Invalid user');
    }
    final batch = _db.batch();
    batch.set(
      _db
          .collection('users')
          .doc(me)
          .collection(blockedCollection)
          .doc(otherUid),
      {
        'blockedAt': FieldValue.serverTimestamp(),
        if (displayName != null && displayName.isNotEmpty)
          'displayName': _clip(displayName, 100),
        if (avatarUrl != null && avatarUrl.isNotEmpty)
          'avatarUrl': _clip(avatarUrl, 2048),
      },
    );
    batch.set(
      _db
          .collection('users')
          .doc(otherUid)
          .collection(blockedByCollection)
          .doc(me),
      {'blockedAt': FieldValue.serverTimestamp()},
    );
    await batch.commit().timeout(_writeTimeout);
    unawaited(_dropPendingCalls(me, callerId: otherUid));
  }

  /// Removes ringing calls from [callerId] in my inbox (was onBlockWritten).
  /// My own entries in their inbox can't be found: rules let a caller read
  /// only an entry whose id it knows, not list the inbox. Best-effort.
  Future<void> _dropPendingCalls(String me, {required String callerId}) async {
    try {
      final ref = FirebaseDatabase.instance.ref('incoming_calls/$me');
      final snap = await ref.get().timeout(const Duration(seconds: 10));
      final updates = <String, Object?>{};
      for (final call in snap.children) {
        final value = call.value;
        final key = call.key;
        if (key != null && value is Map && value['callerId'] == callerId) {
          updates[key] = null;
        }
      }
      if (updates.isNotEmpty) {
        await ref.update(updates).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      if (kDebugMode) {
        final code = e is FirebaseException ? e.code : e.runtimeType;
        debugPrint('SafetyService call cleanup skipped: $code');
      }
    }
  }

  Future<void> unblock(String otherUid) async {
    final me = _me;
    final batch = _db.batch();
    batch.delete(
      _db
          .collection('users')
          .doc(me)
          .collection(blockedCollection)
          .doc(otherUid),
    );
    batch.delete(
      _db
          .collection('users')
          .doc(otherUid)
          .collection(blockedByCollection)
          .doc(me),
    );
    await batch.commit().timeout(_writeTimeout);
  }

  /// Files a report for the owner to review in the console. Completes after
  /// the server write; throws on failure.
  Future<void> report({
    required String reportedUserId,
    required String reason,
    String? details,
    String? conversationId,
    List<String> messageIds = const [],
    String source = 'chat',
  }) async {
    final me = _me;
    if (reportedUserId.isEmpty || reportedUserId == me) {
      throw ArgumentError.value(reportedUserId, 'reportedUserId');
    }
    final trimmedDetails = details?.trim() ?? '';
    await _db
        .collection(reportsCollection)
        .add({
          'reporterId': me,
          'reportedUserId': reportedUserId,
          'reason': _clip(reason, 100),
          if (trimmedDetails.isNotEmpty)
            'details': _clip(trimmedDetails, maxReportDetails),
          if (conversationId != null && conversationId.isNotEmpty)
            'conversationId': conversationId,
          if (messageIds.isNotEmpty)
            'messageIds': messageIds.take(maxReportMessageIds).toList(),
          'source': source,
          'platform': defaultTargetPlatform.name,
          'createdAt': FieldValue.serverTimestamp(),
        })
        .timeout(_writeTimeout);
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);
}
