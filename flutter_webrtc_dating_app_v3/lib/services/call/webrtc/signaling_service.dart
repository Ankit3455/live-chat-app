import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'call_constants.dart';
import '../../../models/call_model.dart';

/// RTDB-only signaling + inbox listener for incoming calls.
/// Structure:
///   rooms/{callId}/{
///     callerId, calleeId, state,
///     offer, answer,
///     caller_candidates/{autoId}, callee_candidates/{autoId}
///   }
///   incoming_calls/{uid}/{callId} = { status, roomId, callType, callerId, ... }
class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DatabaseReference _roomRef(String callId) =>
      _db.ref('${CallConstants.pathRooms}/$callId');

  DatabaseReference _inboxRef(String uid) =>
      _db.ref('incoming_calls/$uid');

  // ─────────────────────────────────────────────────────────
  // Room lifecycle
  // ─────────────────────────────────────────────────────────

  /// MUST be called by the caller before writing offer.
  /// Write caller/callee IDs so rules can authorize subsequent writes.
  Future<void> createRoomSkeleton({
    required String callId,
    required String callerId,
    required String calleeId,
  }) async {
    await _roomRef(callId).set({
      'state': CallConstants.roomStateActive,
      'callerId': callerId,
      'calleeId': calleeId,
      'createdAt': ServerValue.timestamp,
    });
  }

  Future<void> setRoomState(String callId, String state) async {
    await _roomRef(callId).child('state').set(state);
  }

  Future<void> deleteRoom(String callId) async {
    await _roomRef(callId).remove();
  }

  Future<String?> getRoomState(String callId) async {
    final snap = await _roomRef(callId).child('state').get();
    if (snap.exists && snap.value is String) return snap.value as String;
    return null;
  }

  // ─────────────────────────────────────────────────────────
  // Offer / Answer
  // ─────────────────────────────────────────────────────────

  /// Caller-only (rules enforce it).
  Future<void> writeOffer({
    required String callId,
    required String sdp,
  }) async {
    await _roomRef(callId).child(CallConstants.pathOffer).set({
      'type': 'offer',
      'sdp': sdp,
      'ts': ServerValue.timestamp,
      'by': _auth.currentUser?.uid,
    });
  }

  /// Callee reads the offer once when accepting the call.
  Future<Map<String, dynamic>?> getOfferOnce(String callId) async {
    final snap = await _roomRef(callId).child(CallConstants.pathOffer).get();
    if (snap.exists && snap.value is Map) {
      return Map<String, dynamic>.from(snap.value as Map);
    }
    return null;
  }

  /// Callee-only (rules enforce it).
  Future<void> writeAnswer({
    required String callId,
    required String sdp,
  }) async {
    await _roomRef(callId).child(CallConstants.pathAnswer).set({
      'type': 'answer',
      'sdp': sdp,
      'ts': ServerValue.timestamp,
      'by': _auth.currentUser?.uid,
    });
  }

  /// Caller waits on this to receive callee's answer.
  Stream<Map<String, dynamic>?> onAnswer(String callId) {
    final ref = _roomRef(callId).child(CallConstants.pathAnswer);
    return ref.onValue.map((e) {
      if (e.snapshot.exists && e.snapshot.value is Map) {
        return Map<String, dynamic>.from(e.snapshot.value as Map);
      }
      return null;
    });
  }

  // ─────────────────────────────────────────────────────────
  // ICE candidates
  // ─────────────────────────────────────────────────────────

  /// Local side pushes candidates to its own bucket.
  /// Caller -> caller_candidates ; Callee -> callee_candidates
  Future<void> addLocalCandidate({
    required String callId,
    required bool isCaller,
    required Map<String, dynamic> candidate,
  }) async {
    final path = isCaller
        ? CallConstants.pathCallerCandidates
        : CallConstants.pathCalleeCandidates;

    await _roomRef(callId).child(path).push().set({
      ...candidate,
      'by': _auth.currentUser?.uid,
      'ts': ServerValue.timestamp,
    });
  }

  /// Remote candidates stream:
  /// Caller listens to callee_candidates; Callee listens to caller_candidates.
  Stream<Map<String, dynamic>> remoteCandidatesStream({
    required String callId,
    required bool isCaller,
  }) {
    final path = isCaller
        ? CallConstants.pathCalleeCandidates
        : CallConstants.pathCallerCandidates;

    final ref = _roomRef(callId).child(path);

    return ref.onChildAdded
        .where((e) => e.snapshot.value != null)
        .map((e) => Map<String, dynamic>.from(
      (e.snapshot.value as Map).cast<String, dynamic>(),
    ));
  }

  // ─────────────────────────────────────────────────────────
  // INCOMING CALLS INBOX (UI)
  // ─────────────────────────────────────────────────────────

  /// Emits a CallModel each time a new child is added to:
  ///   incoming_calls/{currentUser.uid}/{callId}
  Stream<CallModel?> listenForIncomingCalls() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const Stream<CallModel?>.empty();
    }

    return _inboxRef(uid).onChildAdded.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;

      final m = Map<String, dynamic>.from(
        (event.snapshot.value as Map).cast<String, dynamic>(),
      );

      // Common payload keys (adjust if your backend differs):
      // { status, roomId, callType, callerId, callerName, callerAvatar, ... }
      final callId = event.snapshot.key ?? (m['roomId'] as String? ?? '');
      final callerId = m['callerId'] as String? ?? '';
      final callerName = m['callerName'] as String? ?? 'User';
      final typeStr = (m['callType'] as String? ?? 'video').toLowerCase();

      // ⚠️ If your CallModel constructor/enums differ, tweak this mapping.
      return CallModel(
        id: callId,
        callerId: callerId,
        callerName: callerName,
        callerAvatar: m['callerAvatar'] as String?,      // optional
        receiverId: uid,
        receiverName: (m['receiverName'] as String?)     // REQUIRED by model
            ?? (FirebaseAuth.instance.currentUser?.displayName ?? ''),
        receiverAvatar: m['receiverAvatar'] as String?,  // optional
        type: (typeStr == 'audio') ? CallType.audio : CallType.video,
        status: CallStatus.ringing,
        // timestamp: RTDB me usually int (ServerValue.timestamp) hota hai
        timestamp: (() {
          final v = m['timestamp'];
          if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
          if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
          return DateTime.now();
        })(),
        roomId: (m['roomId'] as String?),                // optional
        // offer/answer signaling payloads RTDB inbox me aam tor pe nahi hote; agar bhej rahe ho to map kar lo:
        offer: (m['offer'] is Map) ? Map<String, dynamic>.from(m['offer']) : null,
        answer: (m['answer'] is Map) ? Map<String, dynamic>.from(m['answer']) : null,
      );

    });
  }

  /// Optional helpers to keep inbox tidy (call from UI if needed)
  Future<void> markIncomingDelivered(String callId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _inboxRef(uid).child(callId).update({'status': 'delivered'});
  }

  Future<void> clearIncoming(String callId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _inboxRef(uid).child(callId).remove();
  }
}
