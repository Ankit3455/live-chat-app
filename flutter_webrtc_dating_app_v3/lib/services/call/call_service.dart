// 📁 lib/services/call/call_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'webrtc/webrtc_service.dart';
import 'webrtc/signaling_service.dart';
import '../../models/call_model.dart';
import 'webrtc/call_constants.dart';

// ✅ ADD THIS IMPORT
import '../notification/onesignal_sender.dart';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final WebRTCService _webrtc = WebRTCService();
  final SignalingService _signal = SignalingService();
  final _auth = FirebaseAuth.instance;
  final _rtdb = FirebaseDatabase.instance;

  // ── Expose to UI (your screens use these) ────────────────────────────────
  WebRTCService get webrtc => _webrtc;

  // alias streams with names your screens use
  Stream<MediaStream?> get localStream => _webrtc.localStream$;
  Stream<MediaStream?> get remoteStream => _webrtc.remoteStream$;

  // current call & duration
  CallModel? _currentCall;
  CallModel? get currentCall => _currentCall;

  Timer? _durationTimer;
  int _callDuration = 0; // seconds
  int get callDuration => _callDuration;

  // UI toggles state
  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  bool _isVideoEnabled = true;
  bool get isVideoEnabled => _isVideoEnabled;

  // ── Outgoing call (from ChatScreen) ──────────────────────────────────────
  /// Creates a callId, writes inbox for callee, creates RTDB room,
  /// starts WebRTC as caller. Returns the callId (UI navigates afterwards).
  Future<String> startCall({
    required String receiverId,
    required CallType type,
  }) async {
    final caller = _auth.currentUser;
    if (caller == null) {
      throw StateError('Not authenticated');
    }

    // generate a simple callId (you can switch to uuid if you want)
    final callId =
        '${caller.uid}_${receiverId}_${DateTime.now().millisecondsSinceEpoch}';

    // set current call model (minimal; extend as you like)
    _currentCall = CallModel(
      id: callId,
      callerId: caller.uid,
      callerName: caller.displayName ?? 'User',
      callerAvatar: caller.photoURL,
      receiverId: receiverId,
      receiverName: '', // unknown here; fill later if you have it
      receiverAvatar: null,
      type: type,
      status: CallStatus.ringing,
      timestamp: DateTime.now(),
      duration: null,
      roomId: callId,
      offer: null,
      answer: null,
    );

    // write to callee's inbox so incoming screen can appear there device:
    await _rtdb.ref('incoming_calls/$receiverId/$callId').set({
      'status': 'ringing',
      'roomId': callId,
      'callType': type == CallType.video ? 'video' : 'audio',
      'callerId': caller.uid,
      'callerName': caller.displayName ?? 'User',
      'callerAvatar': caller.photoURL,
      'timestamp': ServerValue.timestamp,
    });

    // ✅ ADD THIS: Send OneSignal Push Notification for Call
    await OneSignalSender.sendCallNotification(
      receiverId: receiverId,
      callId: callId,
    );

    // start WebRTC as the caller (renderer will be attached by the call screen later)
    await _webrtc.startAsCaller(
      callId: callId,
      isVideo: type == CallType.video,
      calleeUserId: receiverId,
    );

    // start duration counter
    _startDurationTicker();

    // default audio route: speaker ON for video, OFF for audio
    await _setSpeakerphoneOn(type == CallType.video);

    _isVideoEnabled = (type == CallType.video);
    _isMuted = false;

    return callId;
  }

  // ── Incoming call accept (from IncomingCallScreen) ───────────────────────
  /// Accept an incoming call and start as callee.
  Future<void> answerCall(CallModel call) async {
    _currentCall = call.copyWith(status: CallStatus.accepted);

    await _webrtc.startAsCallee(
      callId: call.id,
      isVideo: call.type == CallType.video,
    );

    // remove inbox entry on this device (optional hygiene)
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _rtdb.ref('incoming_calls/$uid/${call.id}').remove();
      }
    } catch (_) {}

    _startDurationTicker();
    await _setSpeakerphoneOn(call.type == CallType.video);
    _isVideoEnabled = (call.type == CallType.video);
    _isMuted = false;
  }

  // ── Reject incoming call (Decline) ───────────────────────────────────────
  Future<void> rejectCall(String callId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _rtdb.ref('incoming_calls/$uid/$callId').remove();
      }
    } catch (_) {}
    // no pc started yet typically, but safe cleanup
    await endCall();
  }

  // ── Hangup/end call (used in both audio/video screens) ───────────────────
  Future<void> endCall() async {
    try {
      if (_currentCall != null && _currentCall!.roomId != null) {
        final roomId = _currentCall!.roomId!;
        // ✅ Do NOT delete the room. Just update state.
        await FirebaseDatabase.instance.ref('rooms/$roomId/state').set('ended');
      }
    } catch (e) {
      print("⚠️ Error updating call state: $e");
    }

    // ✅ Proper clean up
    await _webrtc.dispose();
    _stopDurationTicker();

    _currentCall = _currentCall?.copyWith(
      status: CallStatus.ended,
      duration: _callDuration,
    );

    _isMuted = false;
    _isSpeakerOn = false;
    _isVideoEnabled = true;
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

  // ── Helpers ──────────────────────────────────────────────────────────────
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
