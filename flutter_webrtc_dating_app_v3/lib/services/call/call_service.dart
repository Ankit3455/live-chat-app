// 📁 lib/services/call/call_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'call_consent.dart';
import 'webrtc/webrtc_service.dart';
import 'webrtc/signaling_service.dart';
import 'webrtc/ice_servers.dart';
import '../../models/call_model.dart';
import 'webrtc/call_constants.dart';
import '../notification/onesignal_sender.dart';

class CallPermissionDeniedException implements Exception {
  final CallType type;
  const CallPermissionDeniedException(this.type);

  String get message => type == CallType.video
      ? 'Camera and microphone permission are required for video calls'
      : 'Microphone permission is required for calls';

  @override
  String toString() => 'CallPermissionDeniedException($type)';
}

/// Owns the single call this device can be in.
///
/// Phases: idle -> outgoingRinging | incomingRinging -> connecting -> active
/// (<-> reconnecting) -> ended. Every operation is scoped by callId, so a
/// second incoming call can never end or replace the active one.
class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final WebRTCService _webrtc = WebRTCService();
  final SignalingService _signal = SignalingService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  // ── Expose to UI (your screens use these) ────────────────────────────────
  WebRTCService get webrtc => _webrtc;

  Stream<MediaStream?> get localStream => _webrtc.localStream$;
  Stream<MediaStream?> get remoteStream => _webrtc.remoteStream$;

  // ── State machine ────────────────────────────────────────────────────────
  final ValueNotifier<CallPhase> _phase = ValueNotifier(CallPhase.idle);
  ValueListenable<CallPhase> get phaseListenable => _phase;
  CallPhase get phase => _phase.value;

  /// True while an outgoing or accepted call is in progress.
  bool get isInCall => const {
    CallPhase.outgoingRinging,
    CallPhase.connecting,
    CallPhase.active,
    CallPhase.reconnecting,
  }.contains(_phase.value);

  /// In a call or an incoming call is ringing on screen.
  bool get isBusy => isInCall || _ringingCall != null;

  bool get isReconnecting => _phase.value == CallPhase.reconnecting;

  CallEndReason? _lastEndReason;
  CallEndReason? get lastEndReason => _lastEndReason;

  CallModel? _currentCall;
  CallModel? get currentCall => _currentCall;

  CallModel? _ringingCall;
  CallModel? get ringingCall => _ringingCall;

  Timer? _durationTimer;
  int _callDuration = 0; // seconds since the media connected
  int get callDuration => _callDuration;

  // UI toggles state
  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  bool _isVideoEnabled = true;
  bool get isVideoEnabled => _isVideoEnabled;

  Timer? _noAnswerTimer;
  Timer? _connectTimer;
  Timer? _reconnectTimer;
  Timer? _ringLimitTimer;
  StreamSubscription<String?>? _roomSub;
  StreamSubscription<String?>? _ringRoomSub;
  StreamSubscription<PeerLinkState>? _linkSub;

  String? _conversationId;
  bool _inboxWritten = false;
  Future<void>? _teardown;
  bool _everConnected = false;
  final Map<String, bool> _mutualByCall = {};

  /// Short user-facing text for [reason] ("Declined", "No answer", ...).
  static String endReasonMessage(CallEndReason reason) {
    switch (reason) {
      case CallEndReason.declined:
        return 'Declined';
      case CallEndReason.noAnswer:
        return 'No answer';
      case CallEndReason.busy:
        return 'User is busy';
      case CallEndReason.failed:
        return 'Call failed';
      case CallEndReason.connectionLost:
        return 'Connection lost';
      case CallEndReason.cancelled:
        return 'Call cancelled';
      case CallEndReason.hangup:
      case CallEndReason.remoteHangup:
        return 'Call ended';
    }
  }

  void _setPhase(CallPhase p) {
    if (_phase.value != p) _phase.value = p;
  }

  String? get _myUid => _auth.currentUser?.uid;

  // ── Consent ──────────────────────────────────────────────────────────────
  /// Whether both users enabled [type] calls and neither blocked the other.
  Future<CallConsentResult> checkCallAllowed({
    required String otherUserId,
    required CallType type,
    String? conversationId,
  }) {
    return CallConsent.check(
      myUid: _myUid ?? '',
      otherUid: otherUserId,
      type: type,
      conversationId: conversationId,
    );
  }

  // ── Outgoing call (from ChatScreen) ──────────────────────────────────────
  /// Order: consent -> permissions -> media + room + offer -> inbox entry ->
  /// push. Returns the callId (UI navigates afterwards).
  ///
  /// Throws [CallNotAllowedException], [CallPermissionDeniedException] or
  /// [StateError] (already in a call / not signed in).
  Future<String> startCall({
    required String receiverId,
    required CallType type,
    String? receiverName,
    String? receiverAvatar,
    String? conversationId,
  }) async {
    final caller = _auth.currentUser;
    if (caller == null) throw StateError('Not authenticated');
    if (isBusy) throw StateError('A call is already in progress');

    final consent = await checkCallAllowed(
      otherUserId: receiverId,
      type: type,
      conversationId: conversationId,
    );
    if (!consent.allowed) throw CallNotAllowedException(consent.reason!);

    await _ensurePermissions(type);
    if (isBusy) throw StateError('A call is already in progress');

    final callId = '${caller.uid}_${_uuid.v4()}';
    final cards = await Future.wait([
      _profileCard(caller.uid, fallbackName: caller.displayName),
      _profileCard(receiverId),
    ]);
    final me = cards[0];
    final other = cards[1];

    _resetForNewCall();
    _conversationId = consent.conversationId;
    _currentCall = CallModel(
      id: callId,
      callerId: caller.uid,
      callerName: me.name,
      callerAvatar: me.avatar,
      receiverId: receiverId,
      receiverName: _nonEmpty(receiverName) ?? other.name,
      receiverAvatar: _nonEmpty(receiverAvatar) ?? other.avatar,
      type: type,
      status: CallStatus.ringing,
      timestamp: DateTime.now(),
      roomId: callId,
    );
    _setPhase(CallPhase.outgoingRinging);

    var wroteInbox = false;
    try {
      final config = await IceServers.resolve(
        relayOnly: IceServers.relayOnlyWhenNotMutual && !consent.mutual,
      );
      _listenLink(callId);
      await _webrtc.startAsCaller(
        callId: callId,
        isVideo: type == CallType.video,
        calleeUserId: receiverId,
        configuration: config,
      );
      _ensureCurrent(callId);

      await _signal.armRoomOnDisconnect(callId);
      _watchRoom(callId);

      // Offer exists now, so the callee can answer immediately.
      await _signal.writeIncoming(
        calleeId: receiverId,
        callId: callId,
        callerId: caller.uid,
        callerName: me.name,
        callerAvatar: me.avatar,
        type: type,
      );
      wroteInbox = true;
      _inboxWritten = true;
      _ensureCurrent(callId);

      // sendCallPush verifies the ringing inbox entry, so it must come after.
      unawaited(
        OneSignalSender.sendCallNotification(
          receiverId: receiverId,
          callId: callId,
        ),
      );

      _noAnswerTimer = Timer(CallConstants.noAnswerTimeout, () {
        if (_currentCall?.id == callId &&
            _phase.value == CallPhase.outgoingRinging) {
          _finish(CallEndReason.noAnswer, writeRoom: true);
        }
      });
    } catch (e) {
      debugPrint('CallService: startCall failed: $e');
      if (_currentCall?.id == callId && isInCall) {
        await _finish(CallEndReason.failed, writeRoom: true);
      } else {
        // Hung up while still setting up: clean what was created afterwards.
        await _safe(
          () => _signal.endRoom(callId, CallConstants.endReasonCancelled),
        );
        await _safe(() => _signal.cancelRoomOnDisconnect(callId));
        if (wroteInbox) {
          await _safe(
            () => _signal.closeIncomingForCallee(
              calleeId: receiverId,
              callId: callId,
              status: CallConstants.inboxEnded,
            ),
          );
        }
        Timer(
          CallConstants.roomDeleteDelay,
          () => _safe(() => _signal.deleteRoom(callId)),
        );
      }
      rethrow;
    }

    await _setSpeakerphoneOn(type == CallType.video);
    _isVideoEnabled = (type == CallType.video);
    _isMuted = false;

    return callId;
  }

  // ── Incoming call gate (used by SignalingService.listenForIncomingCalls) ─
  /// Returns the call to show (caller name/avatar taken from the caller's
  /// profile, not the untrusted inbox payload), or null if it must not ring:
  /// already shown, no consent, blocked, or busy (auto-rejected as 'busy').
  Future<CallModel?> admitIncoming(CallModel call) async {
    final me = _myUid;
    if (me == null || call.receiverId != me) return null;
    if (_ringingCall?.id == call.id || _currentCall?.id == call.id) return null;

    try {
      final consent = await checkCallAllowed(
        otherUserId: call.callerId,
        type: call.type,
      );
      if (!consent.allowed) {
        await rejectCall(call.id);
        return null;
      }
      _mutualByCall[call.id] = consent.mutual;
    } catch (e) {
      // Lookup failure (offline): let it ring; rules/server still apply.
      debugPrint('CallService: consent check failed: $e');
    }

    if (isBusy) {
      await rejectCall(call.id, busy: true);
      return null;
    }

    final roomState = await _signal.getRoomState(call.id);
    if (roomState == null || roomState == CallConstants.roomStateEnded) {
      await _safe(() => _signal.clearIncoming(call.id));
      return null;
    }

    final cards = await Future.wait([
      _profileCard(call.callerId),
      _profileCard(me, fallbackName: _auth.currentUser?.displayName),
    ]);
    final caller = cards[0];
    final mine = cards[1];
    final admitted = CallModel(
      id: call.id,
      callerId: call.callerId,
      callerName: caller.name,
      callerAvatar: caller.avatar,
      receiverId: me,
      receiverName: mine.name,
      receiverAvatar: mine.avatar,
      type: call.type,
      status: CallStatus.ringing,
      timestamp: call.timestamp,
      roomId: call.id,
    );
    _setRinging(admitted);
    return admitted;
  }

  void _setRinging(CallModel call) {
    _clearRinging();
    _ringingCall = call;
    if (!isInCall) _setPhase(CallPhase.incomingRinging);

    // Caller cancelled / timed out: stop treating this device as busy.
    _ringRoomSub = _signal.roomState(call.id).listen((state) {
      if (state == null || state == CallConstants.roomStateEnded) {
        if (_ringingCall?.id == call.id) {
          _clearRinging();
          _safe(() => _signal.clearIncoming(call.id));
        }
      }
    }, onError: (_) {});
    _ringLimitTimer = Timer(CallConstants.incomingRingLimit, () {
      if (_ringingCall?.id == call.id) _clearRinging();
    });
  }

  void _clearRinging() {
    _ringRoomSub?.cancel();
    _ringRoomSub = null;
    _ringLimitTimer?.cancel();
    _ringLimitTimer = null;
    _ringingCall = null;
    if (_phase.value == CallPhase.incomingRinging) _setPhase(CallPhase.idle);
  }

  // ── Incoming call accept (from IncomingCallScreen) ───────────────────────
  /// Accept an incoming call and start as callee. On any failure the room is
  /// marked failed, the inbox entry removed and the error rethrown.
  Future<void> answerCall(CallModel call) async {
    if (_currentCall?.id == call.id && isInCall) return; // double tap
    if (isInCall) throw StateError('Already in another call');

    try {
      await _ensurePermissions(call.type);
    } catch (e) {
      if (_ringingCall?.id == call.id) _clearRinging();
      _mutualByCall.remove(call.id);
      await _safe(
        () => _signal.endRoom(call.id, CallConstants.endReasonFailed),
      );
      await _safe(() => _signal.clearIncoming(call.id));
      rethrow;
    }

    if (_ringingCall?.id == call.id) _clearRinging();
    _resetForNewCall();
    _currentCall = call.copyWith(status: CallStatus.accepted);
    _setPhase(CallPhase.connecting);

    try {
      final state = await _signal.getRoomState(call.id);
      if (state == null || state == CallConstants.roomStateEnded) {
        throw StateError('Call is no longer available');
      }
      await _signal.setRoomState(call.id, CallConstants.roomStateAccepted);
      await _signal.armRoomOnDisconnect(call.id);
      _watchRoom(call.id);

      final mutual = _mutualByCall.remove(call.id) ?? false;
      final config = await IceServers.resolve(
        relayOnly: IceServers.relayOnlyWhenNotMutual && !mutual,
      );
      _listenLink(call.id);
      await _webrtc.startAsCallee(
        callId: call.id,
        isVideo: call.type == CallType.video,
        configuration: config,
      );
      _ensureCurrent(call.id);

      await _safe(() => _signal.clearIncoming(call.id));
      _startConnectTimer(call.id);
    } catch (e) {
      debugPrint('CallService: answerCall failed: $e');
      if (_currentCall?.id == call.id && isInCall) {
        await _finish(CallEndReason.failed, writeRoom: true);
      }
      rethrow;
    }

    await _setSpeakerphoneOn(call.type == CallType.video);
    _isVideoEnabled = (call.type == CallType.video);
    _isMuted = false;
  }

  // ── Reject incoming call (Decline / busy) ────────────────────────────────
  /// Only touches [callId]; never the active call.
  Future<void> rejectCall(String callId, {bool busy = false}) async {
    if (_ringingCall?.id == callId) _clearRinging();
    _mutualByCall.remove(callId);
    await _safe(
      () => _signal.endRoom(
        callId,
        busy ? CallConstants.endReasonBusy : CallConstants.endReasonDeclined,
      ),
    );
    await _safe(() => _signal.clearIncoming(callId));
  }

  // ── Hangup/end call (used in both audio/video screens) ───────────────────
  /// Safe to call more than once and after the remote side ended the call.
  Future<void> endCall() async {
    final pending = _teardown;
    if (pending != null) return pending;
    final call = _currentCall;
    if (call == null || !isInCall) return;
    final isCaller = call.callerId == _myUid;
    final reason = isCaller && _phase.value == CallPhase.outgoingRinging
        ? CallEndReason.cancelled
        : CallEndReason.hangup;
    await _finish(reason, writeRoom: true);
  }

  // ── Controls used by your screens ────────────────────────────────────────
  void toggleMute() {
    _webrtc.toggleMute();
    _isMuted = !_isMuted;
  }

  Future<void> switchCamera() async {
    await _webrtc.switchCamera();
  }

  /// Enable/disable local video tracks (for VideoCallScreen camera icon)
  void toggleVideo() {
    final newState = _webrtc.toggleLocalVideo();
    _isVideoEnabled = newState;
  }

  /// Loudspeaker route control for mobile
  Future<void> toggleSpeaker() async {
    await _setSpeakerphoneOn(!_isSpeakerOn);
  }

  // ── Room + connection watching ───────────────────────────────────────────
  void _watchRoom(String callId) {
    _roomSub?.cancel();
    var seen = false;
    _roomSub = _signal.roomState(callId).listen((state) {
      if (_currentCall?.id != callId || _teardown != null || !isInCall) {
        return;
      }

      if (state == CallConstants.roomStateAccepted) {
        _noAnswerTimer?.cancel();
        if (_phase.value == CallPhase.outgoingRinging) {
          _setPhase(CallPhase.connecting);
          _startConnectTimer(callId);
        }
      } else if (state == CallConstants.roomStateEnded ||
          (state == null && seen)) {
        // Claim the teardown synchronously so a screen calling endCall() in
        // parallel cannot record the wrong reason.
        _runTeardown(() async {
          final reason = state == null
              ? null
              : await _safe(() => _signal.getEndReason(callId));
          await _doFinish(_remoteReason(reason), writeRoom: false);
        });
        return;
      }
      if (state != null) seen = true;
    }, onError: (e) => debugPrint('CallService: room listener error: $e'));
  }

  CallEndReason _remoteReason(String? reason) {
    switch (reason) {
      case CallConstants.endReasonDeclined:
        return CallEndReason.declined;
      case CallConstants.endReasonBusy:
        return CallEndReason.busy;
      case CallConstants.endReasonMissed:
        return CallEndReason.noAnswer;
      case CallConstants.endReasonFailed:
        return CallEndReason.failed;
      case CallConstants.endReasonConnectionLost:
        return CallEndReason.connectionLost;
      case CallConstants.endReasonCancelled:
        return CallEndReason.cancelled;
      default:
        return CallEndReason.remoteHangup;
    }
  }

  void _listenLink(String callId) {
    _linkSub?.cancel();
    _linkSub = _webrtc.linkState$.listen((s) {
      if (_currentCall?.id != callId || _teardown != null || !isInCall) {
        return;
      }
      switch (s) {
        case PeerLinkState.connected:
          _connectTimer?.cancel();
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          _noAnswerTimer?.cancel();
          if (!_everConnected) {
            _everConnected = true;
            _startDurationTicker();
          }
          _setPhase(CallPhase.active);
          break;
        case PeerLinkState.disconnected:
        case PeerLinkState.failed:
          if (!_everConnected) break; // covered by the connect timeout
          _setPhase(CallPhase.reconnecting);
          unawaited(_webrtc.restartIce());
          _reconnectTimer ??= Timer(CallConstants.reconnectGrace, () {
            if (_currentCall?.id == callId &&
                _phase.value == CallPhase.reconnecting) {
              _finish(CallEndReason.connectionLost, writeRoom: true);
            }
          });
          break;
        case PeerLinkState.connecting:
        case PeerLinkState.closed:
          break;
      }
    });
  }

  void _startConnectTimer(String callId) {
    _connectTimer?.cancel();
    _connectTimer = Timer(CallConstants.connectTimeout, () {
      if (_currentCall?.id == callId && !_everConnected) {
        _finish(CallEndReason.failed, writeRoom: true);
      }
    });
  }

  // ── Teardown ─────────────────────────────────────────────────────────────
  Future<void> _finish(CallEndReason reason, {required bool writeRoom}) =>
      _runTeardown(() => _doFinish(reason, writeRoom: writeRoom));

  /// Runs at most one teardown at a time; later callers await the same one.
  Future<void> _runTeardown(Future<void> Function() body) {
    return _teardown ??= body().whenComplete(() => _teardown = null);
  }

  Future<void> _doFinish(
    CallEndReason reason, {
    required bool writeRoom,
  }) async {
    final call = _currentCall;
    if (call == null || !isInCall) return;

    final isCaller = call.callerId == _myUid;
    _cancelCallTimers();
    await _roomSub?.cancel();
    _roomSub = null;
    await _linkSub?.cancel();
    _linkSub = null;

    if (writeRoom) {
      await _safe(() => _signal.endRoom(call.id, _roomReason(reason)));
    }
    await _safe(() => _signal.cancelRoomOnDisconnect(call.id));

    if (isCaller) {
      if (_inboxWritten) {
        await _safe(
          () => _signal.closeIncomingForCallee(
            calleeId: call.receiverId,
            callId: call.id,
            status: reason == CallEndReason.noAnswer
                ? CallConstants.inboxMissed
                : reason == CallEndReason.failed
                ? CallConstants.inboxFailed
                : CallConstants.inboxEnded,
          ),
        );
      }
      if (reason == CallEndReason.declined ||
          reason == CallEndReason.busy ||
          reason == CallEndReason.noAnswer) {
        unawaited(_writeCallEvent(call, reason));
      }
    } else {
      await _safe(() => _signal.clearIncoming(call.id));
    }

    await _webrtc.dispose();
    _stopDurationTicker();

    _currentCall = call.copyWith(
      status: _statusFor(reason),
      duration: _callDuration,
    );
    _lastEndReason = reason;
    _isMuted = false;
    _isSpeakerOn = false;
    _isVideoEnabled = true;
    _inboxWritten = false;

    // Give the peer a moment to read the reason, then drop SDP/ICE data.
    final roomId = call.id;
    Timer(CallConstants.roomDeleteDelay, () {
      _safe(() => _signal.deleteRoom(roomId));
    });

    _setPhase(CallPhase.ended);
    if (!kIsWeb) {
      await _safe(() => Helper.setSpeakerphoneOn(false));
    }
  }

  String _roomReason(CallEndReason reason) {
    switch (reason) {
      case CallEndReason.cancelled:
        return CallConstants.endReasonCancelled;
      case CallEndReason.declined:
        return CallConstants.endReasonDeclined;
      case CallEndReason.busy:
        return CallConstants.endReasonBusy;
      case CallEndReason.noAnswer:
        return CallConstants.endReasonMissed;
      case CallEndReason.failed:
        return CallConstants.endReasonFailed;
      case CallEndReason.connectionLost:
        return CallConstants.endReasonConnectionLost;
      case CallEndReason.hangup:
      case CallEndReason.remoteHangup:
        return CallConstants.endReasonHangup;
    }
  }

  CallStatus _statusFor(CallEndReason reason) {
    switch (reason) {
      case CallEndReason.declined:
        return CallStatus.rejected;
      case CallEndReason.busy:
        return CallStatus.busy;
      case CallEndReason.noAnswer:
        return CallStatus.missed;
      case CallEndReason.failed:
        return CallStatus.failed;
      default:
        return CallStatus.ended;
    }
  }

  /// Writes a `type: 'call'` message so both chats show the missed/declined
  /// call. Missed and busy calls also notify the callee.
  Future<void> _writeCallEvent(CallModel call, CallEndReason reason) async {
    try {
      final convId =
          _conversationId ??
          await CallConsent.findConversationId(call.callerId, call.receiverId);
      if (convId == null) return;

      final kind = call.type == CallType.video ? 'video' : 'audio';
      final status = reason == CallEndReason.declined
          ? 'declined'
          : reason == CallEndReason.busy
          ? 'busy'
          : 'missed';
      final text = reason == CallEndReason.declined
          ? 'Declined $kind call'
          : 'Missed $kind call';

      final convRef = _firestore.collection('conversations').doc(convId);
      final msgRef = convRef.collection('messages').doc();
      final batch = _firestore.batch();
      batch.set(msgRef, {
        'id': msgRef.id,
        'senderId': call.callerId,
        'receiverId': call.receiverId,
        'conversationId': convId,
        'message': text,
        'type': 'call',
        'status': 'sent',
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'callId': call.id,
          'callType': kind,
          'callStatus': status,
          'duration': 0,
        },
        'replyToMessageId': null,
        'isDeleted': false,
        'editedAt': null,
        'readAt': null,
        'deliveredAt': null,
      });
      batch.update(convRef, {
        'lastMessageText': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSender': call.callerId,
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': call.callerId,
        'participantData.${call.receiverId}.unreadCount': FieldValue.increment(
          1,
        ),
      });
      await batch.commit();

      if (reason != CallEndReason.declined) {
        await OneSignalSender.sendChatNotification(
          conversationId: convId,
          messageId: msgRef.id,
        );
      }
    } catch (e) {
      debugPrint('CallService: call event write failed: $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  void _resetForNewCall() {
    _cancelCallTimers();
    _roomSub?.cancel();
    _roomSub = null;
    _linkSub?.cancel();
    _linkSub = null;
    _stopDurationTicker();
    _callDuration = 0;
    _everConnected = false;
    _inboxWritten = false;
    _lastEndReason = null;
    _conversationId = null;
  }

  void _cancelCallTimers() {
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    _connectTimer?.cancel();
    _connectTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Throws if the call was ended (e.g. hung up) while an await was pending.
  void _ensureCurrent(String callId) {
    if (_currentCall?.id != callId || !isInCall) {
      throw StateError('Call $callId is no longer active');
    }
  }

  Future<void> _ensurePermissions(CallType type) async {
    if (kIsWeb) return;
    final permissions = type == CallType.video
        ? [Permission.microphone, Permission.camera]
        : [Permission.microphone];
    for (final p in permissions) {
      final status = await p.request();
      if (!status.isGranted) throw CallPermissionDeniedException(type);
    }
  }

  static String? _nonEmpty(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v;

  /// Display name + avatar from the user's profile.
  Future<({String name, String? avatar})> _profileCard(
    String uid, {
    String? fallbackName,
  }) async {
    Map<String, dynamic>? data;
    for (final collection in const ['public_profiles', 'users']) {
      try {
        final snap = await _firestore.collection(collection).doc(uid).get();
        if (snap.exists) {
          data = snap.data();
          break;
        }
      } catch (_) {}
    }

    String? str(dynamic v) => v is String ? _nonEmpty(v) : null;
    final name =
        str(data?['username']) ??
        str(data?['name']) ??
        _nonEmpty(fallbackName) ??
        'User';
    final profileImage = data?['profileImage'];
    final avatar = data?['avatar'];
    String? avatarUrl;
    if (profileImage is String && profileImage.trim().isNotEmpty) {
      avatarUrl = profileImage;
    } else if (avatar is String && avatar.startsWith('http')) {
      avatarUrl = avatar;
    }
    return (name: name, avatar: avatarUrl);
  }

  Future<T?> _safe<T>(Future<T> Function() op) async {
    try {
      return await op();
    } catch (e) {
      debugPrint('CallService: $e');
      return null;
    }
  }

  void _startDurationTicker() {
    _stopDurationTicker();
    _callDuration = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration += 1;
    });
  }

  void _stopDurationTicker() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  Future<void> _setSpeakerphoneOn(bool on) async {
    _isSpeakerOn = on;
    if (!kIsWeb) {
      try {
        await Helper.setSpeakerphoneOn(on);
      } catch (_) {}
    }
  }
}
