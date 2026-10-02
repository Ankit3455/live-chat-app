//📁 lib/services/call/webrtc/webrtc_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../audio_manager_service.dart' show AudioManagerService; // adjust if needed
import 'ice_servers.dart';
import 'signaling_service.dart';
import 'call_constants.dart';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  final _auth = FirebaseAuth.instance;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  final SignalingService _signal = SignalingService();

  final _remoteStreamCtrl = StreamController<MediaStream?>.broadcast();
  Stream<MediaStream?> get remoteStream$ => _remoteStreamCtrl.stream;

  final _localStreamCtrl = StreamController<MediaStream?>.broadcast();
  Stream<MediaStream?> get localStream$ => _localStreamCtrl.stream;

  StreamSubscription? _answerSub;
  StreamSubscription? _remoteIceSub;

  final List<RTCIceCandidate> _pendingRemote = [];
  bool _remoteSdpSet = false;

  String? _callId;
  bool _isCaller = true;
  bool _isVideo = true;

  // --------- NEW: safe helpers ----------
  void _safeAttachToRenderer(RTCVideoRenderer? renderer, MediaStream? stream, {String tag = ''}) {
    if (renderer == null || stream == null) return;
    try {
      // On some versions, accessing srcObject on a disposed renderer throws.
      renderer.srcObject = stream;
    } catch (e) {
      // swallow & log; renderer might not be initialized or already disposed
      debugPrint('⚠️ $_runtimeTag $tag: failed to set srcObject: $e');
    }
  }

  String get _runtimeTag => 'WebRTCService';

  // expose to CallService/UI (used in your VideoCallScreen)
  Future<void> attachRenderers({
    required RTCVideoRenderer local,
    required RTCVideoRenderer remote,
  }) async {
    _localRenderer = local;
    _remoteRenderer = remote;

    // If streams already exist (because call started before UI opened),
    // attach them now, safely.
    _safeAttachToRenderer(_localRenderer, _localStream, tag: 'attachRenderers/local');
    _safeAttachToRenderer(_remoteRenderer, _remoteStream, tag: 'attachRenderers/remote');
  }

  // alias to match your UI's existing call
  Future<void> setRenderers(RTCVideoRenderer local, RTCVideoRenderer remote) async {
    await attachRenderers(local: local, remote: remote);
  }

  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection(IceServers.configuration);

    _pc!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        _remoteStreamCtrl.add(_remoteStream);
        // SAFE attach (will no-op if renderer not set yet, or disposed)
        _safeAttachToRenderer(_remoteRenderer, _remoteStream, tag: 'onTrack/remote');
      }
    };

    _pc!.onIceCandidate = (RTCIceCandidate c) async {
      if (_callId == null) return;
      final map = {
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      };
      await _signal.addLocalCandidate(
        callId: _callId!,
        isCaller: _isCaller,
        candidate: map,
      );
    };
  }

  Future<void> _getUserMedia() async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': _isVideo
          ? {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
        'frameRate': {'ideal': 30},
      }
          : false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);

    for (var track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }

    _localStreamCtrl.add(_localStream);
    // SAFE attach (renderer may not exist yet; also avoid crash if disposed)
    _safeAttachToRenderer(_localRenderer, _localStream, tag: 'getUserMedia/local');
  }

  // ─────────────────────────────────────────────────────────
  // Caller
  // ─────────────────────────────────────────────────────────
  Future<void> startAsCaller({
    required String callId,
    required bool isVideo,
    required String calleeUserId,
  }) async {
    _callId = callId;
    _isCaller = true;
    _isVideo = isVideo;
    _remoteSdpSet = false;

    final callerId = _auth.currentUser?.uid;
    if (callerId == null) throw StateError('No auth user for caller');

    await _createPeerConnection();
    await _getUserMedia();

    await _signal.createRoomSkeleton(
      callId: callId,
      callerId: callerId,
      calleeId: calleeUserId,
    );

    final offer = await _pc!.createOffer(
      IceServers.defaultOfferOptions(iceRestart: false),
    );
    await _pc!.setLocalDescription(offer);
    await _signal.writeOffer(callId: callId, sdp: offer.sdp ?? '');

    _answerSub = _signal.onAnswer(callId).listen((ans) async {
      if (ans == null) return;
      final sdp = ans['sdp'] as String?;
      if (sdp == null) return;
      await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
      _remoteSdpSet = true;
      await _listenRemoteCandidates();
      await _drainPending();
      await _answerSub?.cancel();
      _answerSub = null;
    });
  }

  // ─────────────────────────────────────────────────────────
  // Callee
  // ─────────────────────────────────────────────────────────
  Future<void> startAsCallee({
    required String callId,
    required bool isVideo,
  }) async {
    _callId = callId;
    _isCaller = false;
    _isVideo = isVideo;
    _remoteSdpSet = false;

    await _createPeerConnection();
    await _getUserMedia();

    final offerMap = await _signal.getOfferOnce(callId);
    if (offerMap == null) throw StateError('Offer not found for $callId');
    final offerSdp = offerMap['sdp'] as String?;
    if (offerSdp == null) throw StateError('Offer missing SDP');

    await _pc!.setRemoteDescription(RTCSessionDescription(offerSdp, 'offer'));
    _remoteSdpSet = true;

    final answer = await _pc!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': isVideo,
    });
    await _pc!.setLocalDescription(answer);
    await _signal.writeAnswer(callId: callId, sdp: answer.sdp ?? '');

    await _listenRemoteCandidates();
    await _drainPending();
  }

  Future<void> _listenRemoteCandidates() async {
    if (_callId == null) return;
    await _remoteIceSub?.cancel();
    _remoteIceSub = _signal
        .remoteCandidatesStream(callId: _callId!, isCaller: _isCaller)
        .listen((map) async {
      final c = RTCIceCandidate(
        map['candidate'] as String?,
        map['sdpMid'] as String?,
        map['sdpMLineIndex'] as int?,
      );
      if (!_remoteSdpSet) {
        _pendingRemote.add(c);
      } else {
        try {
          await _pc!.addCandidate(c);
        } catch (_) {}
      }
    });
  }

  Future<void> _drainPending() async {
    if (!_remoteSdpSet) return;
    for (final c in _pendingRemote) {
      try {
        await _pc!.addCandidate(c);
      } catch (_) {}
    }
    _pendingRemote.clear();
  }

  // Public controls used by CallService
  void toggleMute() {
    final tracks = _localStream?.getAudioTracks() ?? [];
    if (tracks.isEmpty) return;
    tracks.first.enabled = !tracks.first.enabled;
  }

  Future<void> switchCamera() async {
    if (_localStream == null || kIsWeb) return;
    final tracks = _localStream!.getVideoTracks();
    if (tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
  }

  // expose to CallService
  bool toggleLocalVideo() {
    final s = _localStream;
    if (s == null) return false;
    final vids = s.getVideoTracks();
    if (vids.isEmpty) return false;
    final newEnabled = !vids.first.enabled;
    for (final t in vids) {
      t.enabled = newEnabled;
    }
    // refresh attachment (optional)
    _safeAttachToRenderer(_localRenderer, _localStream, tag: 'toggleLocalVideo/local');
    return newEnabled;
  }

  // Cleanup
  Future<void> endCallAndCleanup() async {
    try {
      // ✅ Just dispose — DO NOT delete room here
      await dispose();
    } catch (e) {
      print("⚠️ WebRTC cleanup error: $e");
    }
  }


  Future<void> dispose() async {
    try {
      await _remoteIceSub?.cancel();
      await _answerSub?.cancel();
    } catch (_) {}

    try { await _pc?.close(); } catch (_) {}
    _pc = null;

    try { await _localStream?.dispose(); } catch (_) {}
    _localStream = null;

    try { await _remoteStream?.dispose(); } catch (_) {}
    _remoteStream = null;

    // Do NOT touch renderers here, they are owned by UI screens and will be disposed there.
    // Just stop sending streams to them.
    _remoteSdpSet = false;
    _pendingRemote.clear();

    _remoteStreamCtrl.add(null);
    _localStreamCtrl.add(null);
  }
}
