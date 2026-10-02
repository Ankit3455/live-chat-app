import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed
}

enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  location,
  sticker,
  gif
}

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String conversationId;
  final String message;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final bool isDeleted;
  final Map<String, dynamic>? metadata; // For images, files, etc.
  final String? replyToMessageId;
  final DateTime? editedAt;
  final DateTime? readAt;
  final DateTime? deliveredAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.conversationId,
    required this.message,
    this.type = MessageType.text,
    this.status = MessageStatus.sending,
    required this.timestamp,
    this.isDeleted = false,
    this.metadata,
    this.replyToMessageId,
    this.editedAt,
    this.readAt,
    this.deliveredAt,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      conversationId: data['conversationId'] ?? '',
      message: data['message'] ?? '',
      type: MessageType.values.firstWhere(
            (e) => e.name == (data['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
            (e) => e.name == (data['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isDeleted: data['isDeleted'] ?? false,
      metadata: data['metadata'],
      replyToMessageId: data['replyToMessageId'],
      editedAt: data['editedAt'] != null
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
      readAt: data['readAt'] != null
          ? (data['readAt'] as Timestamp).toDate()
          : null,
      deliveredAt: data['deliveredAt'] != null
          ? (data['deliveredAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'conversationId': conversationId,
      'message': message,
      'type': type.name,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'isDeleted': isDeleted,
      'metadata': metadata,
      'replyToMessageId': replyToMessageId,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
    };
  }

  ChatMessage copyWith({
    MessageStatus? status,
    DateTime? readAt,
    DateTime? deliveredAt,
    String? message,
    DateTime? editedAt,
    bool? isDeleted,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      conversationId: conversationId,
      message: message ?? this.message,
      type: type,
      status: status ?? this.status,
      timestamp: timestamp,
      isDeleted: isDeleted ?? this.isDeleted,
      metadata: metadata,
      replyToMessageId: replyToMessageId,
      editedAt: editedAt ?? this.editedAt,
      readAt: readAt ?? this.readAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }
}