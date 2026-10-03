import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/call_model.dart';

enum CallDenyReason { notAuthenticated, noConversation, notEnabled, blocked }

class CallConsentResult {
  final bool allowed;
  final CallDenyReason? reason;
  final String? conversationId;

  /// Both users have replied in the chat (used for the relay-only ICE policy).
  final bool mutual;

  const CallConsentResult._(
    this.allowed,
    this.reason,
    this.conversationId,
    this.mutual,
  );

  const CallConsentResult.allowed(String conversationId, {bool mutual = false})
    : this._(true, null, conversationId, mutual);

  const CallConsentResult.denied(
    CallDenyReason reason, {
    String? conversationId,
  }) : this._(false, reason, conversationId, false);
}

class CallNotAllowedException implements Exception {
  final CallDenyReason reason;
  const CallNotAllowedException(this.reason);

  String get message => reason == CallDenyReason.blocked
      ? 'You cannot call this user.'
      : CallConsent.consentTooltip;

  @override
  String toString() => 'CallNotAllowedException($reason)';
}

/// Call consent (DEST-012): a call type is allowed only when BOTH users enabled
/// it in their chat, and neither has blocked the other.
///
/// Stored on the conversation doc:
///   participantData.{uid}.callEnabled = { audio: bool, video: bool }
/// Blocks (written by the safety service):
///   users/{uid}/blocked/{otherUid}, users/{uid}/blockedBy/{otherUid}
class CallConsent {
  static const String fieldCallEnabled = 'callEnabled';
  static const String keyAudio = 'audio';
  static const String keyVideo = 'video';

  static const String blockedCollection = 'blocked';
  static const String blockedByCollection = 'blockedBy';

  static const String consentTooltip =
      'Calls are possible only when both users enable call permission.';

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Map<String, String> _conversationIds = {};

  static String typeKey(CallType type) =>
      type == CallType.video ? keyVideo : keyAudio;

  static Map<String, dynamic>? _participant(
    Map<String, dynamic> conversation,
    String uid,
  ) {
    final pd = conversation['participantData'];
    if (pd is! Map) return null;
    final me = pd[uid];
    return me is Map ? Map<String, dynamic>.from(me) : null;
  }

  /// Whether [uid] enabled [type] calls in this conversation.
  static bool isEnabledFor(
    Map<String, dynamic> conversation,
    String uid,
    CallType type,
  ) {
    final flags = _participant(conversation, uid)?[fieldCallEnabled];
    return flags is Map && flags[typeKey(type)] == true;
  }

  /// Pure check on a conversation doc (use in StreamBuilders).
  static bool isAllowed(
    Map<String, dynamic> conversation,
    String uidA,
    String uidB,
    CallType type,
  ) =>
      isEnabledFor(conversation, uidA, type) &&
      isEnabledFor(conversation, uidB, type);

  static bool isMutual(
    Map<String, dynamic> conversation,
    String uidA,
    String uidB,
  ) {
    return _participant(conversation, uidA)?['hasReplied'] == true &&
        _participant(conversation, uidB)?['hasReplied'] == true;
  }

  /// Current user's toggle. Writes only their own entry.
  static Future<void> setCallEnabled({
    required String conversationId,
    required String uid,
    required CallType type,
    required bool enabled,
  }) {
    return _db.collection('conversations').doc(conversationId).update({
      'participantData.$uid.$fieldCallEnabled.${typeKey(type)}': enabled,
    });
  }

  static String _pairKey(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('|');
  }

  /// The 1:1 conversation between two users, or null if none exists.
  static Future<String?> findConversationId(String uidA, String uidB) async {
    final key = _pairKey(uidA, uidB);
    final cached = _conversationIds[key];
    if (cached != null) return cached;

    final participants = [uidA, uidB]..sort();
    final q = await _db
        .collection('conversations')
        .where('participants', isEqualTo: participants)
        .where('isGroup', isEqualTo: false)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return _conversationIds[key] = q.docs.first.id;
  }

  static Future<bool> _exists(DocumentReference ref) async {
    try {
      return (await ref.get()).exists;
    } catch (e) {
      // Missing rules or offline: the server-side check still applies.
      debugPrint('CallConsent: block lookup failed: $e');
      return false;
    }
  }

  static Future<bool> isBlockedBetween(String myUid, String otherUid) async {
    final me = _db.collection('users').doc(myUid);
    final results = await Future.wait([
      _exists(me.collection(blockedCollection).doc(otherUid)),
      _exists(me.collection(blockedByCollection).doc(otherUid)),
    ]);
    return results.any((b) => b);
  }

  /// Full check used before starting or showing a call.
  static Future<CallConsentResult> check({
    required String myUid,
    required String otherUid,
    required CallType type,
    String? conversationId,
  }) async {
    if (myUid.isEmpty || otherUid.isEmpty) {
      return const CallConsentResult.denied(CallDenyReason.notAuthenticated);
    }

    final convId = conversationId ?? await findConversationId(myUid, otherUid);
    if (convId == null) {
      return const CallConsentResult.denied(CallDenyReason.noConversation);
    }

    final results = await Future.wait<Object?>([
      _db.collection('conversations').doc(convId).get(),
      isBlockedBetween(myUid, otherUid),
    ]);
    final snap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final blocked = results[1] as bool;

    if (blocked) {
      return CallConsentResult.denied(
        CallDenyReason.blocked,
        conversationId: convId,
      );
    }
    final data = snap.data();
    if (data == null) {
      return const CallConsentResult.denied(CallDenyReason.noConversation);
    }
    if (!isAllowed(data, myUid, otherUid, type)) {
      return CallConsentResult.denied(
        CallDenyReason.notEnabled,
        conversationId: convId,
      );
    }
    return CallConsentResult.allowed(
      convId,
      mutual: isMutual(data, myUid, otherUid),
    );
  }
}
