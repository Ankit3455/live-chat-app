import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sending, sent, delivered, read, failed }

enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  location,
  sticker,
  gif,

  /// Chat game invite or result card (lib/feature/games/chat_games);
  /// details in metadata.
  game,
}

class ChatMessage {
  /// Maximum text length accepted by ChatService (mirrored in security rules).
  static const int maxLength = 2000;

  static const String deletedText = 'This message was deleted';

  final String id;
  final String senderId;
  final String receiverId;
  final String conversationId;
  final String message;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final bool isDeleted;
  final Map<String, dynamic>? metadata;
  final String? replyToMessageId;

  /// Snapshot of the replied-to message: { id, senderId, text, type }.
  final Map<String, dynamic>? replyTo;
  final DateTime? editedAt;
  final DateTime? readAt;
  final DateTime? deliveredAt;

  // 🆕 MEDIA FIELDS
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? mediaDuration;
  final int? mediaSize;
  final String? fileName;
  final String? mimeType;

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
    this.replyTo,
    this.editedAt,
    this.readAt,
    this.deliveredAt,
    // 🆕 Media fields
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaDuration,
    this.mediaSize,
    this.fileName,
    this.mimeType,
  });

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is DateTime) return v;
    return null;
  }

  static MessageType _typeFrom(dynamic v) {
    if (v is String) {
      for (final t in MessageType.values) {
        if (t.name == v) return t;
      }
    }
    return MessageType.text;
  }

  static MessageStatus _statusFrom(dynamic v) {
    if (v is String) {
      for (final s in MessageStatus.values) {
        if (s.name == v) return s;
      }
    }
    return MessageStatus.sent;
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>? ?? {});
    final ts = _toDate(data['timestamp']) ?? DateTime.now();

    return ChatMessage(
      id: (data['id'] as String?) ?? doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      receiverId: (data['receiverId'] as String?) ?? '',
      conversationId: (data['conversationId'] as String?) ?? '',
      message: (data['message'] as String?) ?? '',
      type: _typeFrom(data['type']),
      status: _statusFrom(data['status']),
      timestamp: ts,
      isDeleted: (data['isDeleted'] ?? false) == true,
      metadata: data['metadata'] as Map<String, dynamic>?,
      replyToMessageId: data['replyToMessageId'] as String?,
      replyTo: data['replyTo'] is Map
          ? Map<String, dynamic>.from(data['replyTo'] as Map)
          : null,
      editedAt: _toDate(data['editedAt']),
      readAt: _toDate(data['readAt']),
      deliveredAt: _toDate(data['deliveredAt']),
      // 🆕 Media fields
      mediaUrl: data['mediaUrl'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      mediaDuration: (data['mediaDuration'] as num?)?.toInt(),
      mediaSize: (data['mediaSize'] as num?)?.toInt(),
      fileName: data['fileName'] as String?,
      mimeType: data['mimeType'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
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
      'replyTo': replyTo,
      'editedAt': editedAt == null ? null : Timestamp.fromDate(editedAt!),
      'readAt': readAt == null ? null : Timestamp.fromDate(readAt!),
      'deliveredAt': deliveredAt == null ? null : Timestamp.fromDate(deliveredAt!),
      // 🆕 Media fields
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'mediaDuration': mediaDuration,
      'mediaSize': mediaSize,
      'fileName': fileName,
      'mimeType': mimeType,
    };
  }

  ChatMessage copyWith({
    MessageStatus? status,
    DateTime? readAt,
    DateTime? deliveredAt,
    String? message,
    DateTime? editedAt,
    bool? isDeleted,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    String? replyToMessageId,
    Map<String, dynamic>? replyTo,
    // 🆕 Media fields
    String? mediaUrl,
    String? thumbnailUrl,
    int? mediaDuration,
    int? mediaSize,
    String? fileName,
    String? mimeType,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      conversationId: conversationId,
      message: message ?? this.message,
      type: type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isDeleted: isDeleted ?? this.isDeleted,
      metadata: metadata ?? this.metadata,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyTo: replyTo ?? this.replyTo,
      editedAt: editedAt ?? this.editedAt,
      readAt: readAt ?? this.readAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      // 🆕 Media fields
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      mediaSize: mediaSize ?? this.mediaSize,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  // 🆕 HELPER GETTERS

  /// Check if this is a media message
  bool get isMedia => type == MessageType.image || type == MessageType.audio || type == MessageType.video;

  /// Snapshot stored on a reply so the quote renders without another read.
  Map<String, dynamic> toReplySnapshot() => {
        'id': id,
        'senderId': senderId,
        // Legacy messages may exceed the rules' 2000-char replyTo.text cap.
        'text': isDeleted
            ? ''
            : (message.length > maxLength
                ? message.substring(0, maxLength)
                : message),
        'type': type.name,
      };

  /// Get display text for conversation list preview
  String get previewText => isDeleted
      ? deletedText
      : previewFor(type, message, fileName: fileName);

  /// Conversation-list preview for a message of [type] with [message] text.
  static String previewFor(MessageType type, String message,
      {String? fileName}) {
    switch (type) {
      case MessageType.image:
        return '📷 Photo${message.isNotEmpty ? ': $message' : ''}';
      case MessageType.audio:
        return '🎤 Voice message';
      case MessageType.video:
        return '🎥 Video${message.isNotEmpty ? ': $message' : ''}';
      case MessageType.file:
        return '📄 ${fileName ?? 'Document'}';
      case MessageType.location:
        return '📍 Location';
      case MessageType.sticker:
        return '🎭 Sticker';
      case MessageType.gif:
        return '🎬 GIF';
      case MessageType.game:
        return message.isNotEmpty ? message : '🎮 Game';
      case MessageType.text:
        return message;
    }
  }

  /// Format duration for audio/video
  String get formattedDuration {
    if (mediaDuration == null) return '0:00';
    final minutes = (mediaDuration! ~/ 60).toString().padLeft(2, '0');
    final seconds = (mediaDuration! % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}