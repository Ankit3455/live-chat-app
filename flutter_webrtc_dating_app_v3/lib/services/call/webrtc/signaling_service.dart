import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'call_constants.dart';
import '../call_service.dart';
import '../../../models/call_model.dart';

/// RTDB-only signaling + inbox listener for incoming calls.
/// Structure:
///   rooms/{callId}/{
///     callerId, calleeId, state, endReason,
///     offer, answer,
///     caller_candidates/{autoId}, callee_candidates/{autoId},
///     filters/{uid}
///   }
///   incoming_calls/{uid}/{callId} = { status, roomId, callType, callerId, ... }
class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _serverTimeOffsetMs = 0;
  StreamSubscription? _offsetSub;
  final Completer<void> _offsetKnown = Completer<void>();

  DatabaseReference _roomRef(String callId) =>
      _db.ref('${CallConstants.pathRooms}/$callId');

  DatabaseReference _inboxRef(String uid) =>
      _db.ref('${CallConstants.pathIncomingCalls}/$uid');

  // ─────────────────────────────────────────────────────────
  // Server clock (stale-entry checks must not depend on device clock)
  // ─────────────────────────────────────────────────────────

  void _ensureServerOffset() {
    _offsetSub ??= _db.ref('.info/serverTimeOffset').onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is num) _serverTimeOffsetMs = v.toInt();
      if (!_offsetKnown.isCompleted) _offsetKnown.complete();
    }, onError: (_) {});
  }

  Future<void> _waitForServerOffset() async {
    _ensureServerOffset();
    try {
      await _offsetKnown.future.timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  DateTime serverNow() {
    _ensureServerOffset();
    return DateTime.now().add(Duration(milliseconds: _serverTimeOffsetMs));
  }

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
      'state': CallConstants.roomStateRinging,
      'callerId': callerId,
      'calleeId': calleeId,
      'createdAt': ServerValue.timestamp,
    });
  }

  Future<void> setRoomState(String callId, String state) async {
    await _roomRef(callId).child(CallConstants.pathState).set(state);
  }

  /// Terminal write: state 'ended' plus the reason, in one update. Returns
  /// false (and writes nothing) if the room is gone or already ended, so a
  /// late write never resurrects a deleted room or overwrites the reason.
  Future<bool> endRoom(String callId, String reason) async {
    final state = await getRoomState(callId);
    if (state == null || state == CallConstants.roomStateEnded) return false;
    await _roomRef(callId).update({
      CallConstants.pathState: CallConstants.roomStateEnded,
      CallConstants.pathEndReason: reason,
      'endedBy': _auth.currentUser?.uid,
      'endedAt': ServerValue.timestamp,
    });
    return true;
  }

  /// If this client drops (app killed, network gone) the room ends for the peer.
  Future<void> armRoomOnDisconnect(String callId) async {
    await _roomRef(callId).onDisconnect().update({
      CallConstants.pathState: CallConstants.roomStateEnded,
      CallConstants.pathEndReason: CallConstants.endReasonConnectionLost,
    });
  }

  Future<void> cancelRoomOnDisconnect(String callId) async {
    await _roomRef(callId).onDisconnect().cancel();
  }

  Future<void> deleteRoom(String callId) async {
    await _roomRef(callId).remove();
  }

  Future<String?> getRoomState(String callId) async {
    final snap = await _roomRef(callId).child(CallConstants.pathState).get();
    if (snap.exists && snap.value is String) return snap.value as String;
    return null;
  }

  Future<String?> getEndReason(String callId) async {
    final snap = await _roomRef(
      callId,
    ).child(CallConstants.pathEndReason).get();
    return snap.value is String ? snap.value as String : null;
  }

  /// Emits rooms/{callId}/state (null once the room is deleted).
  Stream<String?> roomState(String callId) {
    return _roomRef(callId)
        .child(CallConstants.pathState)
        .onValue
        .map(
          (e) => e.snapshot.value is String ? e.snapshot.value as String : null,
        );
  }

  // ─────────────────────────────────────────────────────────
  // Video filter (each side writes only its own entry)
  // ─────────────────────────────────────────────────────────

  Future<void> setVideoFilter(String callId, String filterId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _roomRef(
      callId,
    ).child(CallConstants.pathFilters).child(uid).set(filterId);
  }

  /// Filter id [uid] picked for its video (null if none or room deleted).
  Stream<String?> videoFilter(String callId, String uid) {
    return _roomRef(callId)
        .child(CallConstants.pathFilters)
        .child(uid)
        .onValue
        .map(
          (e) => e.snapshot.value is String ? e.snapshot.value as String : null,
        );
  }

  // ─────────────────────────────────────────────────────────
  // Offer / Answer
  // ─────────────────────────────────────────────────────────

  /// Caller-only (rules enforce it).
  Future<void> writeOffer({required String callId, required String sdp}) async {
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

  /// Offer updates (initial offer and ICE-restart re-offers).
  Stream<Map<String, dynamic>?> onOffer(String callId) {
    return _roomRef(callId).child(CallConstants.pathOffer).onValue.map((e) {
      if (e.snapshot.exists && e.snapshot.value is Map) {
        return Map<String, dynamic>.from(e.snapshot.value as Map);
      }
      return null;
    });
  }

  /// Waits until the caller has written the offer (answering right after the
  /// ring must not fail with "Offer not found").
  Future<Map<String, dynamic>> waitForOffer(
    String callId, {
    Duration timeout = CallConstants.offerWaitTimeout,
  }) {
    final completer = Completer<Map<String, dynamic>>();
    late final StreamSubscription sub;
    final timer = Timer(timeout, () {
      sub.cancel();
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Offer not received'));
      }
    });
    sub = onOffer(callId).listen(
      (o) {
        if (o == null || o['sdp'] is! String || completer.isCompleted) return;
        timer.cancel();
        sub.cancel();
        completer.complete(o);
      },
      onError: (Object e) {
        timer.cancel();
        sub.cancel();
        if (!completer.isCompleted) completer.completeError(e);
      },
    );
    return completer.future;
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
        .where((e) => e.snapshot.value is Map)
        .map(
          (e) => Map<String, dynamic>.from(
            (e.snapshot.value as Map).cast<String, dynamic>(),
          ),
        );
  }

  // ─────────────────────────────────────────────────────────
  // INCOMING CALLS INBOX
  // ─────────────────────────────────────────────────────────

  /// Caller writes the ringing entry. Must happen AFTER the offer exists, and
  /// before sendCallPush (the function verifies this entry).
  Future<void> writeIncoming({
    required String calleeId,
    required String callId,
    required String callerId,
    required String callerName,
    String? callerAvatar,
    required CallType type,
  }) async {
    await _inboxRef(calleeId).child(callId).set({
      'status': CallConstants.inboxRinging,
      'roomId': callId,
      'callType': type == CallType.video ? 'video' : 'audio',
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Caller marks the callee's entry as no longer ringing (callerId is kept so
  /// the inbox rule still authorises the write), then tries to remove it.
  Future<void> closeIncomingForCallee({
    required String calleeId,
    required String callId,
    required String status,
  }) async {
    final ref = _inboxRef(calleeId).child(callId);
    try {
      await ref.update({'status': status});
    } catch (e) {
      debugPrint('Signaling: inbox status update failed: $e');
    }
    try {
      await ref.remove();
    } catch (_) {
      // Rules may only let the callee delete; the status update suffices.
    }
  }

  /// Emits a CallModel for each new, still-ringing, recent entry in
  ///   incoming_calls/{currentUser.uid}/{callId}
  /// after CallService has applied consent, block and busy checks.
  Stream<CallModel?> listenForIncomingCalls() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const Stream<CallModel?>.empty();
    }
    _ensureServerOffset();

    return _inboxRef(uid).onChildAdded
        .asyncMap((event) async {
          await _waitForServerOffset();
          final call = _parseIncoming(uid, event.snapshot);
          if (call == null) return null;
          try {
            return await CallService().admitIncoming(call);
          } catch (e) {
            debugPrint('Signaling: incoming call check failed: $e');
            return null;
          }
        })
        .where((call) => call != null);
  }

  CallModel? _parseIncoming(String uid, DataSnapshot snapshot) {
    final callId = snapshot.key;
    if (callId == null || snapshot.value is! Map) return null;

    final m = Map<String, dynamic>.from(
      (snapshot.value as Map).cast<String, dynamic>(),
    );

    final ts = m['timestamp'];
    final sentAt = ts is num
        ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
        : null;
    final status = m['status'] as String?;
    final isStale =
        sentAt == null ||
        serverNow().difference(sentAt) > CallConstants.incomingStaleAfter;

    if (status != CallConstants.inboxRinging || isStale) {
      // Ghost entry (caller hung up, failed, or app was offline): drop it.
      debugPrint('Signaling: dropped inbox call $callId '
          '(status=$status, stale=$isStale)');
      _inboxRef(uid).child(callId).remove().catchError((_) {});
      return null;
    }

    final callerId = m['callerId'] as String? ?? '';
    if (callerId.isEmpty || callerId == uid) return null;
    final typeStr = (m['callType'] as String? ?? 'video').toLowerCase();

    // Names/avatars from the inbox are untrusted; CallService replaces them
    // with the caller's profile.
    return CallModel(
      id: callId,
      callerId: callerId,
      callerName: m['callerName'] as String? ?? '',
      callerAvatar: m['callerAvatar'] as String?,
      receiverId: uid,
      receiverName: '',
      type: (typeStr == 'audio') ? CallType.audio : CallType.video,
      status: CallStatus.ringing,
      timestamp: sentAt,
      roomId: callId,
    );
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
