// lib/models/conversation_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participants;

  // New (canonical) summary fields
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final String? lastMessageSender;

  // Legacy summary fields (कुछ पुरानी जगहों पर अब भी यूज़ हो सकती हैं)
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;

  /// participantData:
  /// {
  ///   "<uid>": {
  ///     "unreadCount": int,
  ///     "lastReadAt": Timestamp|int|null,
  ///     "hasReplied": bool,
  ///     "muted": bool
  ///   }
  /// }
  final Map<String, dynamic> participantData;

  /// statePerUser: { "<uid>": "active" | "new" | "deleted" }
  final Map<String, String> statePerUser;

  // Optional group meta
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;

  // Timestamps / presence
  final DateTime createdAt;
  final Map<String, bool> isTyping;
  final Map<String, bool> isOnline;

  // Top-level muted map (legacy/alt storage): { "<uid>": bool }
  final Map<String, bool> muted;

  Conversation({
    required this.id,
    required this.participants,
    this.lastMessageText,
    this.lastMessageAt,
    this.lastMessageSender,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    Map<String, dynamic>? participantData,
    Map<String, String>? statePerUser,
    this.isGroup = false,
    this.groupName,
    this.groupPhoto,
    required this.createdAt,
    Map<String, bool>? isTyping,
    Map<String, bool>? isOnline,
    Map<String, bool>? muted,
  })  : participantData = participantData ?? const {},
        statePerUser = statePerUser ?? const {},
        isTyping = isTyping ?? const {},
        isOnline = isOnline ?? const {},
        muted = muted ?? const {};

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>? ?? {});

    DateTime? _toDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      return null;
    }

    // Normalize participantData
    final Map<String, dynamic> pData =
    (data['participantData'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k.toString(), v));

    // Normalize statePerUser
    final Map<String, String> sMap =
    (data['statePerUser'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k.toString(), (v ?? 'active').toString()));

    // New + Legacy summary merging (ताकि UI कहीं भी null ना दिखाए)
    final String? _newText = data['lastMessageText'] as String?;
    final String? _oldText = data['lastMessage'] as String?;
    final String? _useText = _newText ?? _oldText;

    final DateTime? _newTime = _toDate(data['lastMessageAt']);
    final DateTime? _oldTime = _toDate(data['lastMessageTime']);
    final DateTime? _useTime = _newTime ?? _oldTime;

    final String? _newSender = data['lastMessageSender'] as String?;
    final String? _oldSender = data['lastMessageSenderId'] as String?;
    final String? _useSender = _newSender ?? _oldSender;

    // Top-level muted map (legacy/alt)
    final Map<String, bool> mutedMap =
    ((data['muted'] as Map?) ?? const {})
        .map((k, v) => MapEntry(k.toString(), v == true));

    return Conversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? const []),

      // Keep both new + legacy populated sensibly
      lastMessageText: _useText,
      lastMessageAt: _useTime,
      lastMessageSender: _useSender,

      lastMessage: _oldText ?? _newText,
      lastMessageTime: _oldTime ?? _newTime,
      lastMessageSenderId: _oldSender ?? _newSender,

      participantData: pData,
      statePerUser: sMap,

      isGroup: data['isGroup'] == true,
      groupName: data['groupName'] as String?,
      groupPhoto: data['groupPhoto'] as String?,

      createdAt: _toDate(data['createdAt']) ?? DateTime.now(),
      isTyping: Map<String, bool>.from(
          (data['isTyping'] as Map?)?.map((k, v) => MapEntry(k.toString(), v == true)) ?? const {}),
      isOnline: Map<String, bool>.from(
          (data['isOnline'] as Map?)?.map((k, v) => MapEntry(k.toString(), v == true)) ?? const {}),

      muted: mutedMap,
    );
  }

  Map<String, dynamic> toFirestore() {
    Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

    return {
      'participants': participants,

      // New summary
      'lastMessageText': lastMessageText,
      'lastMessageAt': _ts(lastMessageAt),
      'lastMessageSender': lastMessageSender,

      // Legacy summary (safe to keep for older screens)
      'lastMessage': lastMessage,
      'lastMessageTime': _ts(lastMessageTime),
      'lastMessageSenderId': lastMessageSenderId,

      'participantData': participantData,
      'statePerUser': statePerUser,

      'isGroup': isGroup,
      'groupName': groupName,
      'groupPhoto': groupPhoto,

      'createdAt': _ts(createdAt),
      'isTyping': isTyping,
      'isOnline': isOnline,

      // Top-level muted (legacy/alt)
      'muted': muted,
    };
  }

  // Helpers

  /// 1–1 के लिए दूसरे यूज़र का uid लौटाता है
  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId, orElse: () => '');
  }

  /// Unread count for a user (participantData से)
  int unreadFor(String uid) {
    final me = participantData[uid];
    if (me is Map && me['unreadCount'] is int) return me['unreadCount'] as int;
    // कोई legacy global map हुआ तो यहाँ जोड़ा जा सकता है (not needed for your current schema)
    return 0;
  }

  /// Mute state resolution:
  /// 1) participantData.{uid}.muted (new/canonical per-user)
  /// 2) top-level muted.{uid} (legacy/alt)
  bool isMuted(String uid) {
    final me = participantData[uid];
    if (me is Map && me['muted'] is bool) return me['muted'] as bool;
    final v = muted[uid];
    if (v is bool) return v;
    return false;
  }

  /// Convenience getter: जो भी latest time उपलब्ध हो
  DateTime? get lastMessageTimeOrNew => lastMessageAt ?? lastMessageTime;
}
