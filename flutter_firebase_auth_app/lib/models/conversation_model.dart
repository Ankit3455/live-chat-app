import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCount;
  final Map<String, DateTime?> lastReadTime;
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;
  final DateTime createdAt;
  final Map<String, bool> isTyping;
  final Map<String, bool> isOnline;

  Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    Map<String, int>? unreadCount,
    Map<String, DateTime?>? lastReadTime,
    this.isGroup = false,
    this.groupName,
    this.groupPhoto,
    required this.createdAt,
    Map<String, bool>? isTyping,
    Map<String, bool>? isOnline,
  })  : unreadCount = unreadCount ?? {},
        lastReadTime = lastReadTime ?? {},
        isTyping = isTyping ?? {},
        isOnline = isOnline ?? {};

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : null,
      lastMessageSenderId: data['lastMessageSenderId'],
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      lastReadTime: (data['lastReadTime'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
          key,
          value != null ? (value as Timestamp).toDate() : null,
        ),
      ) ?? {},
      isGroup: data['isGroup'] ?? false,
      groupName: data['groupName'],
      groupPhoto: data['groupPhoto'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isTyping: Map<String, bool>.from(data['isTyping'] ?? {}),
      isOnline: Map<String, bool>.from(data['isOnline'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'lastReadTime': lastReadTime.map(
            (key, value) => MapEntry(
          key,
          value != null ? Timestamp.fromDate(value!) : null,
        ),
      ),
      'isGroup': isGroup,
      'groupName': groupName,
      'groupPhoto': groupPhoto,
      'createdAt': Timestamp.fromDate(createdAt),
      'isTyping': isTyping,
      'isOnline': isOnline,
    };
  }

  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere(
          (id) => id != currentUserId,
      orElse: () => '',
    );
  }
}