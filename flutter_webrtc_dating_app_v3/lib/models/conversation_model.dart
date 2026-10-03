// lib/models/conversation_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical conversation schema (`conversations/{id}`):
/// ```
/// participants: [uidA, uidB] (sorted), isGroup: false, createdAt: Timestamp
/// lastMessage: { text, type, senderId, messageId, at: Timestamp, isDeleted? }
/// lastMessageAt: Timestamp            // top-level, used for ordering
/// participantData: { <uid>: { unreadCount, lastReadAt: Timestamp,
///                              hasReplied, muted, clearedBefore: Timestamp } }
/// statePerUser: { <uid>: 'active' | 'new' | 'deleted' }
/// typingAt: { <uid>: Timestamp }
/// ```
/// Legacy fields (lastMessageText, lastMessageSender, lastMessageTime,
/// lastMessageSenderId, string lastMessage, isTyping, top-level muted, int
/// lastReadAt) are read as fallbacks only and never written.
class Conversation {
  final String id;
  final List<String> participants;

  // Summary (read from the lastMessage map, falling back to legacy fields)
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final String? lastMessageSender;
  final String? lastMessageType;
  final String? lastMessageId;

  // Legacy aliases kept for older screens; same values as above.
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;

  /// participantData: { "<uid>": { unreadCount, lastReadAt, hasReplied,
  /// muted, clearedBefore } }
  final Map<String, dynamic> participantData;

  /// statePerUser: { "<uid>": "active" | "new" | "deleted" }
  final Map<String, String> statePerUser;

  // Optional group meta
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;

  final DateTime createdAt;

  /// Last typing heartbeat per user. Consider it stale after a few seconds.
  final Map<String, DateTime> typingAt;

  /// Legacy boolean typing flags (never expire; do not rely on them).
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
    this.lastMessageType,
    this.lastMessageId,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    Map<String, dynamic>? participantData,
    Map<String, String>? statePerUser,
    this.isGroup = false,
    this.groupName,
    this.groupPhoto,
    required this.createdAt,
    Map<String, DateTime>? typingAt,
    Map<String, bool>? isTyping,
    Map<String, bool>? isOnline,
    Map<String, bool>? muted,
  })  : participantData = participantData ?? const {},
        statePerUser = statePerUser ?? const {},
        typingAt = typingAt ?? const {},
        isTyping = isTyping ?? const {},
        isOnline = isOnline ?? const {},
        muted = muted ?? const {};

  static DateTime? toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return null;
  }

  /// Deterministic 1-1 conversation id: `sorted[0]_sorted[1]`.
  static String idFor(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>? ?? {});

    final Map<String, dynamic> pData =
        ((data['participantData'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v));

    final Map<String, String> sMap =
        ((data['statePerUser'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v ?? 'active').toString()));

    // Canonical summary map, with legacy string/flat fields as fallback.
    final rawLast = data['lastMessage'];
    final Map lastMap = rawLast is Map ? rawLast : const {};
    final String? legacyLastString = rawLast is String ? rawLast : null;

    final String? text = (lastMap['text'] as String?) ??
        (data['lastMessageText'] as String?) ??
        legacyLastString;
    final DateTime? time = toDate(data['lastMessageAt']) ??
        toDate(lastMap['at']) ??
        toDate(data['lastMessageTime']);
    final String? sender = (lastMap['senderId'] as String?) ??
        (data['lastMessageSender'] as String?) ??
        (data['lastMessageSenderId'] as String?);

    final Map<String, bool> mutedMap = ((data['muted'] as Map?) ?? const {})
        .map((k, v) => MapEntry(k.toString(), v == true));

    final Map<String, DateTime> typing = {};
    final rawTyping = data['typingAt'];
    if (rawTyping is Map) {
      rawTyping.forEach((k, v) {
        final d = toDate(v);
        if (d != null) typing[k.toString()] = d;
      });
    }

    return Conversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? const []),
      lastMessageText: text,
      lastMessageAt: time,
      lastMessageSender: sender,
      lastMessageType: lastMap['type'] as String?,
      lastMessageId: lastMap['messageId'] as String?,
      lastMessage: text,
      lastMessageTime: time,
      lastMessageSenderId: sender,
      participantData: pData,
      statePerUser: sMap,
      isGroup: data['isGroup'] == true,
      groupName: data['groupName'] as String?,
      groupPhoto: data['groupPhoto'] as String?,
      createdAt: toDate(data['createdAt']) ?? DateTime.now(),
      typingAt: typing,
      isTyping: ((data['isTyping'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), v == true)),
      isOnline: ((data['isOnline'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), v == true)),
      muted: mutedMap,
    );
  }

  /// Canonical shape only (see class doc).
  Map<String, dynamic> toFirestore() {
    Timestamp? ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

    return {
      'participants': participants,
      'lastMessage': {
        'text': lastMessageText,
        'type': lastMessageType,
        'senderId': lastMessageSender,
        'messageId': lastMessageId,
        'at': ts(lastMessageAt),
      },
      'lastMessageAt': ts(lastMessageAt),
      'participantData': participantData,
      'statePerUser': statePerUser,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupPhoto': groupPhoto,
      'createdAt': ts(createdAt),
      'typingAt': typingAt.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
    };
  }

  // Helpers

  /// Returns the other participant's uid in a 1-1 conversation.
  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId,
        orElse: () => '');
  }

  Map _dataFor(String uid) {
    final me = participantData[uid];
    return me is Map ? me : const {};
  }

  /// Raw unread counter for [uid] from participantData.
  int unreadFor(String uid) => (_dataFor(uid)['unreadCount'] as num?)?.toInt() ?? 0;

  bool hasRepliedFor(String uid) => _dataFor(uid)['hasReplied'] == true;

  DateTime? lastReadAtFor(String uid) => toDate(_dataFor(uid)['lastReadAt']);

  /// Per-user "clear chat" / "delete chat" cutoff. Messages at or before this
  /// time are hidden for [uid].
  DateTime? clearedBeforeFor(String uid) =>
      toDate(_dataFor(uid)['clearedBefore']);

  /// 'active' | 'new' | 'deleted', derived from statePerUser with the legacy
  /// participantData status/hasReplied as fallback.
  String stateFor(String uid) {
    final s = statePerUser[uid];
    if (s != null && s.isNotEmpty) return s;
    final me = _dataFor(uid);
    if (me['status'] == 'active' || me['hasReplied'] == true) return 'active';
    return 'new';
  }

  /// False for conversations that were created without any message (legacy
  /// eager creation).
  bool get hasMessages => (lastMessageSender ?? '').isNotEmpty;

  /// Whether the conversation should appear in [uid]'s chat list and badges.
  bool isVisibleTo(String uid) =>
      participants.contains(uid) &&
      hasMessages &&
      statePerUser[uid] != 'deleted';

  /// Whether the latest message is hidden for [uid] by clear/delete.
  bool isClearedFor(String uid) {
    final cb = clearedBeforeFor(uid);
    final t = lastMessageAt;
    return cb != null && t != null && !t.isAfter(cb);
  }

  /// Unread count to show in badges: 0 for hidden or cleared conversations.
  int visibleUnreadFor(String uid) {
    if (!isVisibleTo(uid) || isClearedFor(uid)) return 0;
    return unreadFor(uid);
  }

  /// Mute state resolution:
  /// 1) participantData.{uid}.muted (canonical)
  /// 2) top-level muted.{uid} (legacy)
  bool isMuted(String uid) {
    final v = _dataFor(uid)['muted'];
    if (v is bool) return v;
    return muted[uid] ?? false;
  }

  /// Whether [uid] has a typing heartbeat newer than [staleAfter].
  bool isTypingFresh(String uid,
      {Duration staleAfter = const Duration(seconds: 5)}) {
    final at = typingAt[uid];
    return at != null && DateTime.now().difference(at) < staleAfter;
  }

  DateTime? get lastMessageTimeOrNew => lastMessageAt ?? lastMessageTime;
}
