// // lib/managers/unread_manager.dart
// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// /// 🔔 Lightweight unread counter that does NOT touch ChatService.
// class UnreadManager extends ChangeNotifier {
//   final _db = FirebaseFirestore.instance;
//   final _auth = FirebaseAuth.instance;
//
//   StreamSubscription? _sub;
//   int _totalUnread = 0;
//   int get totalUnread => _totalUnread;
//
//   /// conversationId -> unreadCount (for current user)
//   final Map<String, int> _convUnread = {};
//   Map<String, int> get convUnread => Map.unmodifiable(_convUnread);
//
//   bool _inited = false;
//
//   void init() {
//     if (_inited) return;
//     _inited = true;
//
//     final uid = _auth.currentUser?.uid;
//     if (uid == null) return;
//
//     _sub = _db
//         .collection('conversations')
//         .where('participants', arrayContains: uid)
//         .snapshots()
//         .listen((snap) {
//       int total = 0;
//       _convUnread.clear();
//
//       for (final d in snap.docs) {
//         final data = d.data();
//         final pd = (data['participantData'] as Map?) ?? {};
//         final me = (pd[uid] as Map?) ?? {};
//         final count = (me['unreadCount'] ?? 0) as int;
//         // optionally skip muted:
//         // final status = (me['status'] ?? 'active') as String;
//         // if (status == 'muted') continue;
//
//         _convUnread[d.id] = count;
//         total += count;
//       }
//
//       _totalUnread = total;
//       notifyListeners();
//     }, onError: (e) {
//       debugPrint('Unread listener error: $e');
//     });
//   }
//
//   /// manual reset (used after opening a chat)
//   Future<void> resetForConversation(String conversationId) async {
//     final uid = _auth.currentUser?.uid;
//     if (uid == null) return;
//
//     await _db.collection('conversations').doc(conversationId).update({
//       'participantData.$uid.unreadCount': 0,
//       'participantData.$uid.lastReadAt': DateTime.now().millisecondsSinceEpoch,
//     });
//   }
//
//   @override
//   void dispose() {
//     _sub?.cancel();
//     super.dispose();
//   }
// }



// lib/managers/unread_manager.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/conversation_model.dart';
import '../services/conversations_repository.dart';

/// Unread counter for UI badges. Reads the shared conversations stream, so
/// deleted, cleared and empty conversations are not counted.
class UnreadManager extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ConversationsRepository _repo = ConversationsRepository.instance;

  StreamSubscription<List<Conversation>>? _convSub;
  StreamSubscription<User?>? _authSub;

  int _totalUnread = 0;
  int get totalUnread => _totalUnread;

  /// conversationId -> unreadCount for the current user
  final Map<String, int> _convUnread = {};
  Map<String, int> get convUnread => Map.unmodifiable(_convUnread);

  bool _inited = false;

  /// Called from main.dart: `UnreadManager()..init()`
  void init() {
    if (_inited) return;
    _inited = true;
    _authSub = _auth.authStateChanges().listen(_handleUserChange);
  }

  void _handleUserChange(User? user) {
    _convSub?.cancel();
    _convSub = null;
    _convUnread.clear();
    _setTotalUnread(0);

    if (user == null) {
      _repo.reset();
      return;
    }

    final uid = user.uid;
    _convSub = _repo.watch(uid).listen(
      (convs) {
        int total = 0;
        _convUnread.clear();
        for (final c in convs) {
          final count = c.visibleUnreadFor(uid);
          _convUnread[c.id] = count;
          total += count;
        }
        _setTotalUnread(total);
      },
      onError: (Object e) {
        if (kDebugMode) debugPrint('UnreadManager error: $e');
      },
    );
  }

  void _setTotalUnread(int value) {
    if (_totalUnread != value) {
      _totalUnread = value;
      notifyListeners();
    }
  }

  /// Manual reset after opening a chat.
  Future<void> resetForConversation(String conversationId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('conversations').doc(conversationId).update({
      'participantData.$uid.unreadCount': 0,
      'participantData.$uid.lastReadAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _convSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
