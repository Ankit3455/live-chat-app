import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';

// If this file lives at lib/services/chat_service.dart, use this import:
import '_helpers/batch_delete.dart'; // <-- correct relative path

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // --------------------------------------------
  // Conversations (sorted by lastMessageAt)
  // --------------------------------------------
  Stream<List<Conversation>> getConversations() {
    if (currentUserId.isEmpty) return const Stream.empty();
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Conversation.fromFirestore(d)).toList());
  }

  // Optional: Active/New streams if your UI uses tabs
  Stream<List<Conversation>> streamActive(String uid) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .where('statePerUser.$uid', isEqualTo: 'active')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Conversation.fromFirestore(d)).toList());
  }

  Stream<List<Conversation>> streamNew(String uid) {
    return _firestore
        .collection('conversations')
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
    return _firestore
        .collection('conversations')
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
    var q = _firestore
        .collection('conversations')
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
    final snap = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first : null;
  }

  // --------------------------------------------
  // Create or get 1-1 conversation
  // --------------------------------------------
  Future<String> getOrCreateConversation(String otherUserId) async {
    if (currentUserId.isEmpty) return '';

    final participants = [currentUserId, otherUserId]..sort();

    final q = await _firestore
        .collection('conversations')
        .where('participants', isEqualTo: participants)
        .where('isGroup', isEqualTo: false)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) return q.docs.first.id;

    final ref = _firestore.collection('conversations').doc();

    final participantData = {
      currentUserId: {
        'unreadCount': 0,
        'lastReadAt': FieldValue.serverTimestamp(),
        'hasReplied': true,
        'muted': false,
        'status': 'new',
      },
      otherUserId: {
        'unreadCount': 0,
        'lastReadAt': null,
        'hasReplied': false,
        'muted': false,
        'status': 'new',
      },
    };

    final statePerUser = {
      currentUserId: 'active',
      otherUserId: 'new',
    };

    await ref.set({
      'conversationId': ref.id,
      'participants': participants,
      'isGroup': false,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageText': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSender': '',
      'participantData': participantData,
      // legacy fallback (safe)
      'unreadCount': {currentUserId: 0, otherUserId: 0},
      'isTyping': {},
      'statePerUser': statePerUser,
    });

    return ref.id;
  }

  // --------------------------------------------
  // Send message (SERVER TIMESTAMPS)
  // --------------------------------------------
  Future<String?> sendMessage({
    required String conversationId,
    required String receiverId,
    required String message,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
    String? replyToMessageId,
  }) async {
    if (currentUserId.isEmpty) return null;

    final convRef = _firestore.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    final messageData = <String, dynamic>{
      'id': msgRef.id,
      'senderId': currentUserId,
      'receiverId': receiverId,
      'conversationId': conversationId,
      'message': message,
      'type': type.name,
      'status': 'sent',
      'timestamp': FieldValue.serverTimestamp(), // CRITICAL
      'metadata': metadata,
      'replyToMessageId': replyToMessageId,
      'isDeleted': false,
      'editedAt': null,
      'readAt': null,
      'deliveredAt': null,
    };

    // Merge participantData/state
    final snap = await convRef.get();
    final convData = (snap.data() ?? {});

    final Map<String, dynamic> pData =
    (convData['participantData'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k.toString(), (v ?? {}) as Map));

    Map<String, dynamic> ensure(String uid) {
      final m =
          (pData[uid] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
      m.putIfAbsent('unreadCount', () => 0);
      m.putIfAbsent('lastReadAt', () => null);
      m.putIfAbsent('hasReplied', () => false);
      m.putIfAbsent('muted', () => false);
      return m;
    }

    final sEntry = ensure(currentUserId);
    final rEntry = ensure(receiverId);

    sEntry['hasReplied'] = true; // sender replied
    rEntry['unreadCount'] = (rEntry['unreadCount'] as int) + 1;

    pData[currentUserId] = sEntry;
    pData[receiverId] = rEntry;

    final Map<String, String> statePerUser =
    (convData['statePerUser'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k.toString(), (v ?? 'new').toString()));

    statePerUser[currentUserId] = 'active';
    statePerUser[receiverId] =
    (rEntry['hasReplied'] == true) ? 'active' : 'new';

    final batch = _firestore.batch();

    // Add message
    batch.set(msgRef, messageData);

    // Update summary (server timestamp!)
    batch.update(convRef, {
      'lastMessageText': message,
      'lastMessageAt': FieldValue.serverTimestamp(), // CRITICAL
      'lastMessageSender': currentUserId,

      // legacy (safe to keep)
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUserId,

      'participantData': pData,
      'statePerUser': statePerUser,
      'isTyping.$currentUserId': false,
    });

    await batch.commit();
    return msgRef.id;
  }

  // --------------------------------------------
  // Read / Unread
  // --------------------------------------------
  Future<void> markMessagesAsRead(
      String conversationId, String senderId) async {
    if (currentUserId.isEmpty) return;

    try {
      final convRef =
      _firestore.collection('conversations').doc(conversationId);
      final snap = await convRef.get();
      if (!snap.exists) return;

      final batch = _firestore.batch();

      batch.update(convRef, {
        'participantData.$currentUserId.unreadCount': 0,
        'participantData.$currentUserId.lastReadAt':
        FieldValue.serverTimestamp(),
      });

      final unread = await convRef
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .where('status', whereIn: ['sent', 'delivered'])
          .get();

      for (final d in unread.docs) {
        batch.update(d.reference, {
          'status': 'read',
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (_) {}
  }

  // --------------------------------------------
  // Clear Chat (for me)

  /// Clear Chat (WhatsApp-style):
  /// - DOES NOT delete messages from server.
  /// - Marks participantData.{uid}.clearedBefore = now.
  /// - UI should hide messages <= clearedBefore for this user.
  Future<void> clearChat(String conversationId, {String? myUid}) async {
    final uid = myUid ?? _auth.currentUser?.uid;
    if (uid == null || conversationId.isEmpty) return;

    final convoRef = _firestore.collection('conversations').doc(conversationId);

    await convoRef.set({
      'participantData': {
        uid: {
          'unreadCount': 0,
          'lastReadAt': FieldValue.serverTimestamp(),
          'clearedBefore': FieldValue.serverTimestamp(), // <-- key flag
        },
      },
    }, SetOptions(merge: true));
  }

  // --------------------------------------------
  // Delete chat FOR ME (soft delete)
  // --------------------------------------------
  /// - statePerUser.{uid} = 'deleted'
  /// - participantData.{uid}.unreadCount = 0, lastReadAt = now
  /// NOTE: Does NOT affect the other participant or delete messages.
  Future<void> deleteForUser(String conversationId, String uid) async {
    if (conversationId.isEmpty || uid.isEmpty) return;

    final convoRef =
    FirebaseFirestore.instance.collection('conversations').doc(conversationId);

    await convoRef.update({
      'statePerUser.$uid': 'deleted',
      'participantData.$uid.unreadCount': 0,
      'participantData.$uid.lastReadAt': FieldValue.serverTimestamp(),
    });
  }

  // (Optional internal) reuse elsewhere if needed
  Future<void> _deleteMessagesInBatches(
      String conversationId, {
        int batchSize = 400,
      }) async {
    final convoRef =
    FirebaseFirestore.instance.collection('conversations').doc(conversationId);
    final msgsRef = convoRef.collection('messages');
    await deleteCollectionInBatches(msgsRef, batchSize: batchSize);
  }

  // --------------------------------------------
  // Typing
  // --------------------------------------------
  Future<void> updateTypingStatus(String conversationId, bool isTyping) async {
    if (currentUserId.isEmpty) return;
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update({'isTyping.$currentUserId': isTyping});
  }

  // --------------------------------------------
  // Message ops
  // --------------------------------------------
  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'isDeleted': true, 'message': 'This message was deleted'});
  }

  Future<void> editMessage(
      String conversationId,
      String messageId,
      String newMessage,
      ) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'message': newMessage,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  // --------------------------------------------
  // User helpers
  // --------------------------------------------
  Future<UserModel?> getUserDetails(String userId) async {
    try {
      final d = await _firestore.collection('users').doc(userId).get();
      if (d.exists) return UserModel.fromFirestore(d);
    } catch (_) {}
    return null;
  }

  Stream<UserModel?> streamUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((d) {
      if (!d.exists) return null;
      return UserModel.fromFirestore(d);
    });
  }

  Stream<bool> getTypingStatus(String conversationId, String userId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      final m = data['isTyping'] as Map<String, dynamic>?;
      return (m?[userId] ?? false) == true;
    });
  }

  // --------------------------------------------
  // Mute per user (stored inside participantData)
  // --------------------------------------------
  Future<void> toggleMute(String conversationId, String uid, bool value) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .set({'participantData': {uid: {'muted': value}}}, SetOptions(merge: true));
  }

  // Add at the end of ChatService class

// =========================================================================
// 🆕 MEDIA MESSAGE METHODS
// =========================================================================

  /// Send image message
  Future<void> sendImageMessage({
    required String conversationId,
    required String receiverId,
    required String imageUrl,
    String? caption,
    int? fileSize,
    String? replyToMessageId,
  }) async {
    if (currentUserId.isEmpty) return;

    final convRef = _firestore.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    final messageData = <String, dynamic>{
      'id': msgRef.id,
      'senderId': currentUserId,
      'receiverId': receiverId,
      'conversationId': conversationId,
      'message': caption ?? '',
      'type': 'image',
      'status': 'sent',
      'timestamp': FieldValue.serverTimestamp(),
      'isDeleted': false,
      'replyToMessageId': replyToMessageId,
      'mediaUrl': imageUrl,
      'mediaSize': fileSize,
      'mimeType': 'image/jpeg',
    };

    // Preview text for conversation list
    final previewText = '📷 Photo${caption != null && caption.isNotEmpty ? ': $caption' : ''}';

    await _sendMediaMessage(convRef, msgRef, messageData, previewText, receiverId);
  }

  /// Send voice/audio message
  Future<void> sendVoiceMessage({
    required String conversationId,
    required String receiverId,
    required String audioUrl,
    required int durationSeconds,
    String? replyToMessageId,
  }) async {
    if (currentUserId.isEmpty) return;

    final convRef = _firestore.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    final messageData = <String, dynamic>{
      'id': msgRef.id,
      'senderId': currentUserId,
      'receiverId': receiverId,
      'conversationId': conversationId,
      'message': '',
      'type': 'audio',
      'status': 'sent',
      'timestamp': FieldValue.serverTimestamp(),
      'isDeleted': false,
      'replyToMessageId': replyToMessageId,
      'mediaUrl': audioUrl,
      'mediaDuration': durationSeconds,
      'mimeType': 'audio/m4a',
    };

    const previewText = '🎤 Voice message';

    await _sendMediaMessage(convRef, msgRef, messageData, previewText, receiverId);
  }

  /// Internal helper for sending media messages
  Future<void> _sendMediaMessage(
      DocumentReference convRef,
      DocumentReference msgRef,
      Map<String, dynamic> messageData,
      String previewText,
      String receiverId,
      ) async {
    final snap = await convRef.get();
    final convData = (snap.data() as Map<String, dynamic>? ?? {});

    final Map<String, dynamic> pData =
    (convData['participantData'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k.toString(), (v ?? {}) as Map));

    Map<String, dynamic> ensure(String uid) {
      final m = (pData[uid] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
      m.putIfAbsent('unreadCount', () => 0);
      m.putIfAbsent('lastReadAt', () => null);
      m.putIfAbsent('hasReplied', () => false);
      m.putIfAbsent('muted', () => false);
      return m;
    }

    final sEntry = ensure(currentUserId);
    final rEntry = ensure(receiverId);

    sEntry['hasReplied'] = true;
    rEntry['unreadCount'] = (rEntry['unreadCount'] as int) + 1;

    pData[currentUserId] = sEntry;
    pData[receiverId] = rEntry;

    final Map<String, String> statePerUser =
    (convData['statePerUser'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k.toString(), (v ?? 'new').toString()));

    statePerUser[currentUserId] = 'active';
    statePerUser[receiverId] = (rEntry['hasReplied'] == true) ? 'active' : 'new';

    final batch = _firestore.batch();

    batch.set(msgRef, messageData);

    batch.update(convRef, {
      'lastMessageText': previewText,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSender': currentUserId,
      'lastMessage': previewText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUserId,
      'participantData': pData,
      'statePerUser': statePerUser,
      'isTyping.$currentUserId': false,
    });

    await batch.commit();
  }
}
