import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Stream of conversations for current user
  Stream<List<Conversation>> getConversations() {
    if (currentUserId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Conversation.fromFirestore(doc))
          .toList();
    });
  }

  // Stream of messages for a conversation
  Stream<List<ChatMessage>> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .toList();
    });
  }

  // Send a message
  Future<void> sendMessage({
    required String conversationId,
    required String receiverId,
    required String message,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
    String? replyToMessageId,
  }) async {
    if (currentUserId.isEmpty) return;

    final timestamp = DateTime.now();
    final messageDoc = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    final chatMessage = ChatMessage(
      id: messageDoc.id,
      senderId: currentUserId,
      receiverId: receiverId,
      conversationId: conversationId,
      message: message,
      type: type,
      status: MessageStatus.sent,
      timestamp: timestamp,
      metadata: metadata,
      replyToMessageId: replyToMessageId,
    );

    // Use batch write for atomicity
    final batch = _firestore.batch();

    // Add message
    batch.set(messageDoc, chatMessage.toFirestore());

    // Update conversation
    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId);

    batch.update(conversationRef, {
      'lastMessage': message,
      'lastMessageTime': Timestamp.fromDate(timestamp),
      'lastMessageSenderId': currentUserId,
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // Create or get conversation
  Future<String> getOrCreateConversation(String otherUserId) async {
    if (currentUserId.isEmpty) return '';

    // Check if conversation exists
    final participants = [currentUserId, otherUserId]..sort();
    final query = await _firestore
        .collection('conversations')
        .where('participants', isEqualTo: participants)
        .where('isGroup', isEqualTo: false)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }

    // Create new conversation
    final conversationRef = _firestore.collection('conversations').doc();
    final conversation = Conversation(
      id: conversationRef.id,
      participants: participants,
      createdAt: DateTime.now(),
      unreadCount: {
        currentUserId: 0,
        otherUserId: 0,
      },
      lastReadTime: {
        currentUserId: null,
        otherUserId: null,
      },
    );

    await conversationRef.set(conversation.toFirestore());
    return conversationRef.id;
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId, String senderId) async {
    if (currentUserId.isEmpty) return;

    final batch = _firestore.batch();

    // Update conversation unread count
    batch.update(
      _firestore.collection('conversations').doc(conversationId),
      {
        'unreadCount.$currentUserId': 0,
        'lastReadTime.$currentUserId': Timestamp.now(),
      },
    );

    // Update message statuses
    final unreadMessages = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('senderId', isEqualTo: senderId)
        .where('status', whereIn: ['sent', 'delivered'])
        .get();

    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {
        'status': MessageStatus.read.name,
        'readAt': Timestamp.now(),
      });
    }

    await batch.commit();
  }

  // Update typing status
  Future<void> updateTypingStatus(String conversationId, bool isTyping) async {
    if (currentUserId.isEmpty) return;

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update({
      'isTyping.$currentUserId': isTyping,
    });
  }

  // Delete message
  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'isDeleted': true,
      'message': 'This message was deleted',
    });
  }

  // Edit message
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
      'editedAt': Timestamp.now(),
    });
  }

  // Get user details for chat
  Future<UserModel?> getUserDetails(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting user details: $e');
    }
    return null;
  }

  // Stream for online status of a user
  Stream<bool> getUserOnlineStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data();
        return data?['isOnline'] ?? false;
      }
      return false;
    });
  }

  // Stream for typing status
  Stream<bool> getTypingStatus(String conversationId, String userId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final typingMap = data['isTyping'] as Map<String, dynamic>?;
        return typingMap?[userId] ?? false;
      }
      return false;
    });
  }
}