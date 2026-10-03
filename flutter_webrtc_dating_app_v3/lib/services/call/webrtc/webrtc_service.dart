//📁 lib/services/call/webrtc/webrtc_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ice_servers.dart';
import 'signaling_service.dart';

/// Simplified peer connection state used by CallService.
enum PeerLinkState { connecting, connected, disconnected, failed, closed }

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

  final _linkStateCtrl = StreamController<PeerLinkState>.broadcast();
  Stream<PeerLinkState> get linkState$ => _linkStateCtrl.stream;
  PeerLinkState _linkState = PeerLinkState.closed;
  PeerLinkState get linkState => _linkState;

  StreamSubscription? _answerSub;
  StreamSubscription? _offerSub;
  StreamSubscription? _remoteIceSub;

  final List<RTCIceCandidate> _pendingRemote = [];
  bool _remoteSdpSet = false;

  String? _callId;
  bool _isCaller = true;
  bool _isVideo = true;
  String? _lastRemoteSdp;
  bool _restartingIce = false;

  String? get activeCallId => _callId;

  void _safeAttachToRenderer(
    RTCVideoRenderer? renderer,
    MediaStream? stream, {
    String tag = '',
  }) {
    if (renderer == null || stream == null) return;
    try {
      // On some versions, accessing srcObject on a disposed renderer throws.
      renderer.srcObject = stream;
    } catch (e) {
      debugPrint('WebRTCService $tag: failed to set srcObject: $e');
    }
  }

  // expose to CallService/UI (used in your VideoCallScreen)
  Future<void> attachRenderers({
    required RTCVideoRenderer local,
    required RTCVideoRenderer remote,
  }) async {
    _localRenderer = local;
    _remoteRenderer = remote;

    // Streams may already exist if the call started before the UI opened.
    _safeAttachToRenderer(
      _localRenderer,
      _localStream,
      tag: 'attachRenderers/local',
    );
    _safeAttachToRenderer(
      _remoteRenderer,
      _remoteStream,
      tag: 'attachRenderers/remote',
    );
  }

  // alias to match your UI's existing call
  Future<void> setRenderers(
    RTCVideoRenderer local,
    RTCVideoRenderer remote,
  ) async {
    await attachRenderers(local: local, remote: remote);
  }

  void _setLinkState(PeerLinkState s) {
    if (_linkState == s) return;
    _linkState = s;
    if (!_linkStateCtrl.isClosed) _linkStateCtrl.add(s);
  }

  Future<void> _createPeerConnection(
    Map<String, dynamic>? configuration,
  ) async {
    final pc = await createPeerConnection(
      configuration ?? IceServers.configuration,
    );
    _pc = pc;
    _setLinkState(PeerLinkState.connecting);

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        _remoteStreamCtrl.add(_remoteStream);
        _safeAttachToRenderer(
          _remoteRenderer,
          _remoteStream,
          tag: 'onTrack/remote',
        );
      }
    };

    pc.onIceCandidate = (RTCIceCandidate c) async {
      final callId = _callId;
      if (callId == null || c.candidate == null) return;
      try {
        await _signal.addLocalCandidate(
          callId: callId,
          isCaller: _isCaller,
          candidate: {
            'candidate': c.candidate,
            'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
          },
        );
      } catch (e) {
        debugPrint('WebRTCService: candidate write failed: $e');
      }
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _setLinkState(PeerLinkState.connected);
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          _setLinkState(PeerLinkState.disconnected);
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _setLinkState(PeerLinkState.failed);
          break;
        default:
          break;
      }
    };

    // Some platforms only report the ICE-level state reliably.
    pc.onIceConnectionState = (RTCIceConnectionState state) {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _setLinkState(PeerLinkState.connected);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _setLinkState(PeerLinkState.disconnected);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _setLinkState(PeerLinkState.failed);
          break;
        default:
          break;
      }
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
    _safeAttachToRenderer(
      _localRenderer,
      _localStream,
      tag: 'getUserMedia/local',
    );
  }

  Future<void> _prepare({
    required String callId,
    required bool isCaller,
    required bool isVideo,
    Map<String, dynamic>? configuration,
  }) async {
    // Never overwrite a live connection without closing it.
    if (_pc != null) await dispose();

    _callId = callId;
    _isCaller = isCaller;
    _isVideo = isVideo;
    _remoteSdpSet = false;
    _lastRemoteSdp = null;
    _restartingIce = false;

    await _createPeerConnection(configuration);
    await _getUserMedia();
  }

  // ─────────────────────────────────────────────────────────
  // Caller: media -> room skeleton -> offer. The inbox entry and push are
  // written by CallService only after this returns.
  // ─────────────────────────────────────────────────────────
  Future<void> startAsCaller({
    required String callId,
    required bool isVideo,
    required String calleeUserId,
    Map<String, dynamic>? configuration,
  }) async {
    final callerId = _auth.currentUser?.uid;
    if (callerId == null) throw StateError('No auth user for caller');

    await _prepare(
      callId: callId,
      isCaller: true,
      isVideo: isVideo,
      configuration: configuration,
    );

    await _signal.createRoomSkeleton(
      callId: callId,
      callerId: callerId,
      calleeId: calleeUserId,
    );

    // Listen for answers before publishing the offer. Later answers belong to
    // ICE restarts.
    _answerSub = _signal.onAnswer(callId).listen((ans) async {
      final sdp = ans?['sdp'] as String?;
      final pc = _pc;
      if (sdp == null || pc == null || _callId != callId) return;
      if (sdp == _lastRemoteSdp) return;
      try {
        await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
        _lastRemoteSdp = sdp;
        _restartingIce = false;
        if (!_remoteSdpSet) {
          _remoteSdpSet = true;
          await _listenRemoteCandidates();
          await _drainPending();
        }
      } catch (e) {
        debugPrint('WebRTCService: applying answer failed: $e');
      }
    });

    await _sendOffer(iceRestart: false);
  }

  Future<void> _sendOffer({required bool iceRestart}) async {
    final pc = _pc;
    final callId = _callId;
    if (pc == null || callId == null) return;
    final offer = await pc.createOffer(
      IceServers.defaultOfferOptions(iceRestart: iceRestart),
    );
    await pc.setLocalDescription(offer);
    await _signal.writeOffer(callId: callId, sdp: offer.sdp ?? '');
  }

  /// Caller-side ICE restart after a network change; the callee answers the
  /// new offer through its offer listener.
  Future<void> restartIce() async {
    if (!_isCaller || _pc == null || _restartingIce || !_remoteSdpSet) return;
    _restartingIce = true;
    try {
      await _sendOffer(iceRestart: true);
    } catch (e) {
      _restartingIce = false;
      debugPrint('WebRTCService: ICE restart failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // Callee
  // ─────────────────────────────────────────────────────────
  Future<void> startAsCallee({
    required String callId,
    required bool isVideo,
    Map<String, dynamic>? configuration,
  }) async {
    await _prepare(
      callId: callId,
      isCaller: false,
      isVideo: isVideo,
      configuration: configuration,
    );

    final offerMap = await _signal.waitForOffer(callId);
    await _applyOfferAndAnswer(offerMap['sdp'] as String);

    await _listenRemoteCandidates();
    await _drainPending();

    // Re-offers from the caller (ICE restart).
    _offerSub = _signal.onOffer(callId).listen((offer) async {
      final sdp = offer?['sdp'] as String?;
      if (sdp == null || sdp == _lastRemoteSdp || _callId != callId) return;
      try {
        await _applyOfferAndAnswer(sdp);
      } catch (e) {
        debugPrint('WebRTCService: re-offer failed: $e');
      }
    });
  }

  Future<void> _applyOfferAndAnswer(String offerSdp) async {
    final pc = _pc;
    final callId = _callId;
    if (pc == null || callId == null) throw StateError('Call was closed');

    await pc.setRemoteDescription(RTCSessionDescription(offerSdp, 'offer'));
    _lastRemoteSdp = offerSdp;
    _remoteSdpSet = true;

    final answer = await pc.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _isVideo,
    });
    await pc.setLocalDescription(answer);
    await _signal.writeAnswer(callId: callId, sdp: answer.sdp ?? '');
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
            (map['sdpMLineIndex'] as num?)?.toInt(),
          );
          final pc = _pc;
          if (!_remoteSdpSet || pc == null) {
            _pendingRemote.add(c);
          } else {
            try {
              await pc.addCandidate(c);
            } catch (_) {}
          }
        });
  }

  Future<void> _drainPending() async {
    final pc = _pc;
    if (!_remoteSdpSet || pc == null) return;
    final pending = List<RTCIceCandidate>.from(_pendingRemote);
    _pendingRemote.clear();
    for (final c in pending) {
      try {
        await pc.addCandidate(c);
      } catch (_) {}
    }
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
    _safeAttachToRenderer(
      _localRenderer,
      _localStream,
      tag: 'toggleLocalVideo/local',
    );
    return newEnabled;
  }

  // Cleanup
  Future<void> endCallAndCleanup() async {
    try {
      await dispose();
    } catch (e) {
      debugPrint('WebRTC cleanup error: $e');
    }
  }

  Future<void> dispose() async {
    _callId = null;

    try {
      await _remoteIceSub?.cancel();
      await _answerSub?.cancel();
      await _offerSub?.cancel();
    } catch (_) {}
    _remoteIceSub = null;
    _answerSub = null;
    _offerSub = null;

    final pc = _pc;
    _pc = null;
    if (pc != null) {
      pc.onTrack = null;
      pc.onIceCandidate = null;
      pc.onConnectionState = null;
      pc.onIceConnectionState = null;
      try {
        await pc.close();
      } catch (_) {}
    }

    try {
      for (final t in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;

    try {
      await _remoteStream?.dispose();
    } catch (_) {}
    _remoteStream = null;

    // Renderers are owned (and disposed) by the call screens; drop the refs so
    // a finished call never writes into a disposed renderer.
    _localRenderer = null;
    _remoteRenderer = null;

    _remoteSdpSet = false;
    _lastRemoteSdp = null;
    _restartingIce = false;
    _pendingRemote.clear();
    _setLinkState(PeerLinkState.closed);

    _remoteStreamCtrl.add(null);
    _localStreamCtrl.add(null);
  }
}
