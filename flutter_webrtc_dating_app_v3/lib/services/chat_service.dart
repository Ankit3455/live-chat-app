import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';
import 'conversations_repository.dart';

import '_helpers/batch_delete.dart';

/// Chat data layer. Conversation schema is documented on [Conversation].
///
/// All conversation-level writes use field paths / merges so concurrent
/// sends, reads, mutes and clears never overwrite each other.
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Firestore allows 500 writes per batch; stay below it.
  static const int _batchLimit = 450;

  /// A typing heartbeat older than this is ignored.
  static const Duration typingStaleAfter = Duration(seconds: 5);

  String get currentUserId => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  void _log(String where, Object e) {
    if (kDebugMode) debugPrint('ChatService.$where failed: $e');
  }

  // --------------------------------------------
  // Conversations (sorted by lastMessageAt)
  // --------------------------------------------

  /// Conversations visible to the current user (not deleted for them, not
  /// empty), newest first. Shared with UnreadManager.
  Stream<List<Conversation>> getConversations() {
    if (currentUserId.isEmpty) return const Stream.empty();
    return ConversationsRepository.instance.watch(currentUserId);
  }

  // Optional: Active/New streams if your UI uses tabs
  Stream<List<Conversation>> streamActive(String uid) {
    return _conversations
        .where('participants', arrayContains: uid)
        .where('statePerUser.$uid', isEqualTo: 'active')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Conversation.fromFirestore(d)).toList());
  }

  Stream<List<Conversation>> streamNew(String uid) {
    return _conversations
        .where('participants', arrayContains: uid)
        .where('statePerUser.$uid', isEqualTo: 'new')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Conversation.fromFirestore(d)).toList());
  }

  // --------------------------------------------
  // Messages
  // --------------------------------------------
  Stream<List<ChatMessage>> getMessages(String conversationId) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  // Paginated (optional)
  Stream<List<ChatMessage>> getMessagesPaginated(
      String conversationId, {
        int limit = 50,
        DocumentSnapshot? startAfter,
      }) {
    var q = _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfter != null) q = q.startAfterDocument(startAfter);

    return q.snapshots().map(
          (snap) => snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList(),
    );
  }

  Future<DocumentSnapshot?> getOldestMessage(String conversationId) async {
    final snap = await _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first : null;
  }

  // --------------------------------------------
  // Resolve 1-1 conversation id
  // --------------------------------------------

  /// Returns the conversation id for a chat with [otherUserId] WITHOUT
  /// creating anything. The document is created by the first message.
  ///
  /// Order: deterministic id `sorted[0]_sorted[1]` if it exists, then a legacy
  /// random-id conversation for the same pair, otherwise the deterministic id.
  Future<String> getOrCreateConversation(String otherUserId) async {
    final me = currentUserId;
    if (me.isEmpty || otherUserId.isEmpty) return '';

    final id = Conversation.idFor(me, otherUserId);

    try {
      final snap = await _conversations.doc(id).get();
      if (snap.exists) return id;
    } catch (e) {
      _log('getOrCreateConversation(get)', e);
    }

    try {
      final participants = [me, otherUserId]..sort();
      final q = await _conversations
          .where('participants', isEqualTo: participants)
          .where('isGroup', isEqualTo: false)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return q.docs.first.id;
    } catch (e) {
      _log('getOrCreateConversation(legacy lookup)', e);
    }

    return id;
  }

  // --------------------------------------------
  // Send (SERVER TIMESTAMPS)
  // --------------------------------------------

  /// Sends a text message and returns its id. The Cloud Function push relies
  /// on the message's senderId/receiverId/message and conversation
  /// participants written here.
  Future<String?> sendMessage({
    required String conversationId,
    required String receiverId,
    required String message,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
    String? replyToMessageId,
    Map<String, dynamic>? replyTo,
  }) async {
    if (message.length > ChatMessage.maxLength) {
      throw ArgumentError(
          'Message is longer than ${ChatMessage.maxLength} characters');
    }
    return _writeMessage(
      conversationId: conversationId,
      receiverId: receiverId,
      type: type,
      previewText: ChatMessage.previewFor(type, message),
      fields: {
        'message': message,
        'metadata': metadata,
      },
      replyToMessageId: replyToMessageId,
      replyTo: replyTo,
    );
  }

  /// Send image message. Returns the message id.
  Future<String?> sendImageMessage({
    required String conversationId,
    required String receiverId,
    required String imageUrl,
    String? caption,
    int? fileSize,
    String? replyToMessageId,
    Map<String, dynamic>? replyTo,
  }) {
    final text = caption ?? '';
    return _writeMessage(
      conversationId: conversationId,
      receiverId: receiverId,
      type: MessageType.image,
      previewText: ChatMessage.previewFor(MessageType.image, text),
      fields: {
        'message': text,
        'mediaUrl': imageUrl,
        'mediaSize': fileSize,
        'mimeType': 'image/jpeg',
      },
      replyToMessageId: replyToMessageId,
      replyTo: replyTo,
    );
  }

  /// Send voice/audio message. Returns the message id.
  Future<String?> sendVoiceMessage({
    required String conversationId,
    required String receiverId,
    required String audioUrl,
    required int durationSeconds,
    String? replyToMessageId,
    Map<String, dynamic>? replyTo,
  }) {
    return _writeMessage(
      conversationId: conversationId,
      receiverId: receiverId,
      type: MessageType.audio,
      previewText: ChatMessage.previewFor(MessageType.audio, ''),
      fields: {
        'message': '',
        'mediaUrl': audioUrl,
        'mediaDuration': durationSeconds,
        'mimeType': 'audio/m4a',
      },
      replyToMessageId: replyToMessageId,
      replyTo: replyTo,
    );
  }

  /// Single writer for every message type: one batch with the message and a
  /// merge of the conversation summary. Creates the conversation on first send.
  Future<String?> _writeMessage({
    required String conversationId,
    required String receiverId,
    required MessageType type,
    required String previewText,
    required Map<String, dynamic> fields,
    String? replyToMessageId,
    Map<String, dynamic>? replyTo,
  }) async {
    final me = currentUserId;
    if (me.isEmpty ||
        conversationId.isEmpty ||
        receiverId.isEmpty ||
        receiverId == me) {
      return null;
    }

    final convRef = _conversations.doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    // Only used to decide createdAt and whether the receiver's state needs a
    // reset; counters are increments, so a stale read cannot lose updates.
    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await convRef.get();
    } catch (e) {
      _log('send(read conversation)', e);
    }
    final bool? exists = snap?.exists;
    final data = snap?.data() ?? const <String, dynamic>{};
    final receiverState = (data['statePerUser'] as Map?)?[receiverId];
    final receiverHasReplied =
        ((data['participantData'] as Map?)?[receiverId] as Map?)?['hasReplied'] ==
            true;

    final now = FieldValue.serverTimestamp();
    final participants = [me, receiverId]..sort();

    final batch = _firestore.batch();

    batch.set(msgRef, <String, dynamic>{
      'id': msgRef.id,
      'senderId': me,
      'receiverId': receiverId,
      'conversationId': conversationId,
      'type': type.name,
      'status': 'sent',
      'timestamp': now,
      'isDeleted': false,
      'editedAt': null,
      'readAt': null,
      'deliveredAt': null,
      'replyToMessageId': replyToMessageId,
      if (replyTo != null) 'replyTo': replyTo,
      ...fields,
    });

    batch.set(
      convRef,
      <String, dynamic>{
        'conversationId': conversationId,
        'participants': participants,
        'isGroup': false,
        if (exists == false) 'createdAt': now,
        'lastMessage': {
          'text': previewText,
          'type': type.name,
          'senderId': me,
          'messageId': msgRef.id,
          'at': now,
        },
        'lastMessageAt': now,
        'participantData': {
          me: {'hasReplied': true},
          receiverId: {'unreadCount': FieldValue.increment(1)},
        },
        'statePerUser': {
          me: 'active',
          if (exists != null &&
              (receiverState == null || receiverState == 'deleted'))
            receiverId: receiverHasReplied ? 'active' : 'new',
        },
        'typingAt': {me: FieldValue.delete()},
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    return msgRef.id;
  }

  // --------------------------------------------
  // Read / Delivered receipts
  // --------------------------------------------

  /// Marks [senderId]'s messages as read and resets my unread counter.
  Future<void> markMessagesAsRead(
      String conversationId, String senderId) async {
    final me = currentUserId;
    if (me.isEmpty || conversationId.isEmpty) return;

    try {
      final convRef = _conversations.doc(conversationId);
      final snap = await convRef.get();
      if (!snap.exists) return;

      final unread = await convRef
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .where('status', whereIn: ['sent', 'delivered'])
          .get();

      final myUnread = Conversation.fromFirestore(snap).unreadFor(me);
      if (unread.docs.isEmpty && myUnread == 0) return;

      await convRef.update({
        'participantData.$me.unreadCount': 0,
        'participantData.$me.lastReadAt': FieldValue.serverTimestamp(),
      });

      await _updateInChunks(
        unread.docs.map((d) => d.reference).toList(),
        {
          'status': 'read',
          'readAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      _log('markMessagesAsRead', e);
    }
  }

  /// Marks [senderId]'s 'sent' messages as delivered (call when they reach
  /// this device, e.g. from the chat list or a push handler).
  Future<void> markDelivered(String conversationId, String senderId) async {
    final me = currentUserId;
    if (me.isEmpty || conversationId.isEmpty || senderId.isEmpty) return;

    try {
      final pending = await _conversations
          .doc(conversationId)
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .where('status', isEqualTo: 'sent')
          .get();

      await _updateInChunks(
        pending.docs.map((d) => d.reference).toList(),
        {
          'status': 'delivered',
          'deliveredAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      _log('markDelivered', e);
    }
  }

  Future<void> _updateInChunks(
    List<DocumentReference<Map<String, dynamic>>> refs,
    Map<String, dynamic> update,
  ) async {
    for (var i = 0; i < refs.length; i += _batchLimit) {
      final end = (i + _batchLimit < refs.length) ? i + _batchLimit : refs.length;
      final batch = _firestore.batch();
      for (final ref in refs.sublist(i, end)) {
        batch.update(ref, update);
      }
      await batch.commit();
    }
  }

  // --------------------------------------------
  // Clear Chat (for me)
  // --------------------------------------------

  /// Clear Chat (WhatsApp-style): messages stay on the server; messages at or
  /// before participantData.{uid}.clearedBefore are hidden for this user.
  Future<void> clearChat(String conversationId, {String? myUid}) async {
    final uid = myUid ?? _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || conversationId.isEmpty) return;

    final now = FieldValue.serverTimestamp();
    try {
      await _conversations.doc(conversationId).update({
        'participantData.$uid.unreadCount': 0,
        'participantData.$uid.lastReadAt': now,
        'participantData.$uid.clearedBefore': now,
      });
    } on FirebaseException catch (e) {
      // Nothing to clear if no message was ever sent.
      if (e.code != 'not-found') rethrow;
    }
  }

  // --------------------------------------------
  // Delete chat FOR ME (soft delete)
  // --------------------------------------------

  /// WhatsApp-style delete for [uid] only: hides the conversation and sets
  /// clearedBefore so the old history stays hidden if it is reopened or a new
  /// message arrives. Does not affect the other participant.
  Future<void> deleteForUser(String conversationId, String uid) async {
    if (conversationId.isEmpty || uid.isEmpty) return;

    final now = FieldValue.serverTimestamp();
    try {
      await _conversations.doc(conversationId).update({
        'statePerUser.$uid': 'deleted',
        'participantData.$uid.unreadCount': 0,
        'participantData.$uid.lastReadAt': now,
        'participantData.$uid.clearedBefore': now,
      });
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') rethrow;
    }
  }

  // (Optional internal) reuse elsewhere if needed
  // ignore: unused_element
  Future<void> _deleteMessagesInBatches(
      String conversationId, {
        int batchSize = 400,
      }) async {
    final msgsRef = _conversations.doc(conversationId).collection('messages');
    await deleteCollectionInBatches(msgsRef, batchSize: batchSize);
  }

  // --------------------------------------------
  // Typing
  // --------------------------------------------

  /// Writes a typing heartbeat (`typingAt.{me}`) or removes it. Best effort:
  /// callers should refresh it every few seconds while the user keeps typing.
  Future<void> updateTypingStatus(String conversationId, bool isTyping) async {
    final me = currentUserId;
    if (me.isEmpty || conversationId.isEmpty) return;
    try {
      await _conversations.doc(conversationId).update({
        'typingAt.$me':
            isTyping ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });
    } on FirebaseException catch (e) {
      // not-found: conversation not created yet (no message sent).
      if (e.code != 'not-found') _log('updateTypingStatus', e);
    } catch (e) {
      _log('updateTypingStatus', e);
    }
  }

  /// True while [userId] has a typing heartbeat younger than
  /// [typingStaleAfter]; flips to false on its own when it goes stale (e.g.
  /// the other app was killed mid-typing).
  Stream<bool> getTypingStatus(String conversationId, String userId) {
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
    Timer? expiry;
    bool? last;
    DateTime? lastSeen;
    var first = true;

    late final StreamController<bool> controller;

    void emit(bool v) {
      if (v == last || controller.isClosed) return;
      last = v;
      controller.add(v);
    }

    controller = StreamController<bool>(
      onListen: () {
        sub = _conversations.doc(conversationId).snapshots().listen((doc) {
          final raw = (doc.data()?['typingAt'] as Map?)?[userId];
          final at = raw is Timestamp ? raw.toDate() : null;
          final isFirst = first;
          first = false;

          if (!isFirst && at == lastSeen) return; // unrelated doc change
          lastSeen = at;
          expiry?.cancel();

          if (at == null) {
            emit(false);
            return;
          }

          // A heartbeat that changed while listening is fresh as of now; this
          // avoids depending on clock skew between the two devices.
          final remaining = isFirst
              ? typingStaleAfter - DateTime.now().difference(at)
              : typingStaleAfter;
          if (remaining <= Duration.zero) {
            emit(false);
            return;
          }
          emit(true);
          expiry = Timer(remaining, () => emit(false));
        }, onError: (Object e) {
          _log('getTypingStatus', e);
          emit(false);
        });
      },
      onCancel: () async {
        expiry?.cancel();
        await sub?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  // --------------------------------------------
  // Message ops
  // --------------------------------------------

  /// Deletes my message for everyone: scrubs text and media URL and updates
  /// the conversation preview if it was the latest message. The Cloudinary
  /// asset is destroyed server-side from the previous mediaUrl.
  Future<void> deleteMessage(String conversationId, String messageId) async {
    final me = currentUserId;
    if (me.isEmpty || conversationId.isEmpty || messageId.isEmpty) return;

    final convRef = _conversations.doc(conversationId);
    final msgRef = convRef.collection('messages').doc(messageId);

    final msgSnap = await msgRef.get();
    final data = msgSnap.data();
    if (data == null || data['isDeleted'] == true) return;
    if (data['senderId'] != me) {
      throw StateError('Only the sender can delete this message');
    }

    final batch = _firestore.batch();
    batch.update(msgRef, {
      'isDeleted': true,
      'message': '',
      'mediaUrl': FieldValue.delete(),
    });

    if (await _isLatestMessage(convRef, messageId)) {
      batch.update(convRef, {
        'lastMessage': _summaryFor(
          messageId: messageId,
          data: data,
          text: ChatMessage.deletedText,
          isDeleted: true,
        ),
      });
    }

    await batch.commit();
  }

  /// Edits my text message in place (sets editedAt) and updates the
  /// conversation preview if it is the latest message. No push is sent.
  Future<void> editMessage(
      String conversationId,
      String messageId,
      String newMessage,
      ) async {
    final me = currentUserId;
    if (me.isEmpty || conversationId.isEmpty || messageId.isEmpty) return;

    final text = newMessage.trim();
    if (text.isEmpty) throw ArgumentError('Message cannot be empty');
    if (text.length > ChatMessage.maxLength) {
      throw ArgumentError(
          'Message is longer than ${ChatMessage.maxLength} characters');
    }

    final convRef = _conversations.doc(conversationId);
    final msgRef = convRef.collection('messages').doc(messageId);

    final msgSnap = await msgRef.get();
    final data = msgSnap.data();
    if (data == null) throw StateError('Message not found');
    if (data['senderId'] != me) {
      throw StateError('Only the sender can edit this message');
    }
    if (data['isDeleted'] == true) {
      throw StateError('A deleted message cannot be edited');
    }
    if ((data['type'] ?? MessageType.text.name) != MessageType.text.name) {
      throw StateError('Only text messages can be edited');
    }
    if (data['message'] == text) return;

    final batch = _firestore.batch();
    batch.update(msgRef, {
      'message': text,
      'editedAt': FieldValue.serverTimestamp(),
    });

    if (await _isLatestMessage(convRef, messageId)) {
      batch.update(convRef, {
        'lastMessage': _summaryFor(messageId: messageId, data: data, text: text),
      });
    }

    await batch.commit();
  }

  Future<bool> _isLatestMessage(
    DocumentReference<Map<String, dynamic>> convRef,
    String messageId,
  ) async {
    try {
      final latest = await convRef
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      return latest.docs.isNotEmpty && latest.docs.first.id == messageId;
    } catch (e) {
      _log('isLatestMessage', e);
      return false;
    }
  }

  /// Full lastMessage map (not dotted paths) so legacy string summaries are
  /// replaced cleanly. lastMessageAt is left alone to keep list ordering.
  Map<String, dynamic> _summaryFor({
    required String messageId,
    required Map<String, dynamic> data,
    required String text,
    bool isDeleted = false,
  }) {
    return {
      'text': text,
      'type': data['type'] ?? MessageType.text.name,
      'senderId': data['senderId'],
      'messageId': messageId,
      'at': data['timestamp'],
      if (isDeleted) 'isDeleted': true,
    };
  }

  // --------------------------------------------
  // User helpers
  // --------------------------------------------
  Future<UserModel?> getUserDetails(String userId) async {
    try {
      final d = await _firestore.collection('users').doc(userId).get();
      if (d.exists) return UserModel.fromFirestore(d);
    } catch (e) {
      _log('getUserDetails', e);
    }
    return null;
  }

  Stream<UserModel?> streamUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((d) {
      if (!d.exists) return null;
      return UserModel.fromFirestore(d);
    });
  }

  // --------------------------------------------
  // Mute per user (stored inside participantData)
  // --------------------------------------------
  Future<void> toggleMute(String conversationId, String uid, bool value) async {
    if (conversationId.isEmpty || uid.isEmpty) return;
    await _conversations
        .doc(conversationId)
        .update({'participantData.$uid.muted': value});
  }
}
