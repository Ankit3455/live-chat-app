// lib/services/conversations_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/conversation_model.dart';

/// One shared Firestore listener on the signed-in user's conversations.
/// ChatService (chat list) and UnreadManager (badges) both read from here so
/// the query is subscribed once and visibility rules are applied the same way.
class ConversationsRepository {
  ConversationsRepository._();
  static final ConversationsRepository instance = ConversationsRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StreamController<List<Conversation>> _controller =
      StreamController<List<Conversation>>.broadcast();

  String? _uid;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<Conversation>? _all;
  Object? _error;
  Set<String> _hiddenUserIds = const {};

  /// Users whose conversations must be hidden (e.g. blocked either way).
  void setHiddenUserIds(Set<String> ids) {
    _hiddenUserIds = Set.unmodifiable(ids);
    if (_all != null) _controller.add(_visible());
  }

  /// Visible conversations of [uid], newest first. Replays the latest value
  /// to new listeners. After an error, calling watch again re-subscribes.
  Stream<List<Conversation>> watch(String uid) {
    if (uid.isEmpty) return const Stream.empty();
    _attach(uid);
    return Stream<List<Conversation>>.multi((c) {
      if (_all != null) {
        c.add(_visible());
      } else if (_error != null) {
        c.addError(_error!);
      }
      final s = _controller.stream.listen(c.add, onError: c.addError);
      c.onCancel = s.cancel;
    });
  }

  /// Drops the listener and cached data (call on sign-out).
  void reset() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _all = null;
    _error = null;
  }

  void _attach(String uid) {
    if (_uid == uid && _sub != null) return;
    reset();
    _uid = uid;
    _sub = _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .listen((snap) {
      _error = null;
      _all = snap.docs.map(Conversation.fromFirestore).toList();
      _controller.add(_visible());
    }, onError: (Object e) {
      if (kDebugMode) debugPrint('ConversationsRepository error: $e');
      _error = e;
      _all = null;
      _sub = null; // next watch() re-subscribes
      _controller.addError(e);
    });
  }

  List<Conversation> _visible() {
    final uid = _uid;
    if (uid == null) return const [];
    return (_all ?? const <Conversation>[])
        .where((c) =>
            c.isVisibleTo(uid) &&
            !_hiddenUserIds.contains(c.getOtherParticipantId(uid)))
        .toList(growable: false);
  }
}
