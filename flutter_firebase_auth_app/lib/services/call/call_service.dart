import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../models/call_model.dart';
import '../chat_service.dart';
import 'webrtc/webrtc_service.dart';
import 'webrtc/signaling_service.dart';

class CallService {
  final WebRTCService _webrtc = WebRTCService();
  final SignalingService _signal = SignalingService();
  final ChatService _chat = ChatService();

  CallModel? _currentCall;
  StreamSubscription? _callSub;
  StreamSubscription? _iceSub;
  Timer? _timer;
  int _secs = 0;

  CallModel? get currentCall => _currentCall;
  int get callDuration => _secs;

  Stream<MediaStream?> get localStream => _webrtc.localStream;
  Stream<MediaStream?> get remoteStream => _webrtc.remoteStream;

  bool get isMuted => _webrtc.isMuted;
  bool get isVideoEnabled => _webrtc.isVideoEnabled;
  bool get isSpeakerOn => _webrtc.isSpeakerOn;

  Future<String> startCall({
    required String receiverId,
    required CallType type,
  }) async {
    final receiver = await _chat.getUserDetails(receiverId);
    if (receiver == null) {
      throw Exception('User not found');
    }

    await _webrtc.initialize(isVideo: type == CallType.video);
    final offer = await _webrtc.createOffer();

    final callId = await _signal.createCall(
      receiverId: receiverId,
      receiverName: receiver.username,
      receiverAvatar: (receiver.profileImage.isNotEmpty)
          ? receiver.profileImage
          : receiver.avatarString,
      type: type,
      offer: {
        'sdp': offer.sdp,
        'type': offer.type,
      },
    );

    _listenToCall(callId, isOutgoing: true);
    _listenForIceCandidates(callId, isOutgoing: true);

    return callId;
  }

  Future<void> answerCall(CallModel call) async {
    _currentCall = call;

    await _webrtc.initialize(isVideo: call.type == CallType.video);

    final offerDesc = RTCSessionDescription(
      call.offer?['sdp'],
      call.offer?['type'],
    );
    await _webrtc.setRemoteDescription(offerDesc);

    final answer = await _webrtc.createAnswer();
    await _signal.answerCall(call.id, {
      'sdp': answer.sdp,
      'type': answer.type,
    });

    _startTimer();
    _listenToCall(call.id, isOutgoing: false);
    _listenForIceCandidates(call.id, isOutgoing: false);
  }

  Future<void> rejectCall(String callId) => _signal.rejectCall(callId);

  Future<void> endCall() async {
    if (_currentCall != null) {
      await _signal.endCall(_currentCall!.id, _secs);
    }
    await _cleanup();
  }

  void toggleMute() => _webrtc.toggleMute();
  void toggleVideo() => _webrtc.toggleVideo();
  void toggleSpeaker() => _webrtc.toggleSpeaker();
  Future<void> switchCamera() => _webrtc.switchCamera();

  void _listenToCall(String callId, {required bool isOutgoing}) {
    _callSub?.cancel();
    _callSub = _signal.getCallStream(callId).listen((call) {
      if (call == null) return;

      _currentCall = call;

      if (isOutgoing && call.answer != null) {
        final answer = RTCSessionDescription(
          call.answer?['sdp'],
          call.answer?['type'],
        );
        _webrtc.setRemoteDescription(answer);
        _startTimer();
      }

      if (call.status == CallStatus.ended ||
          call.status == CallStatus.rejected) {
        endCall();
      }
    });
  }

  void _listenForIceCandidates(String callId, {required bool isOutgoing}) {
    _webrtc.getIceCandidates().listen((candidate) {
      _signal.addIceCandidate(
        callId: callId,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
        },
        isOffer: isOutgoing,
      );
    });

    _iceSub?.cancel();
    _iceSub = _signal
        .getIceCandidates(callId: callId, isOffer: isOutgoing)
        .listen((candidates) {
    for (final c in candidates) {
    _webrtc.addIceCandidate(RTCIceCandidate(
    c['candidate'],
    c['sdpMid'],
    c['sdpMLineIndex'],
    ));
    }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), () {
      _secs++;
    } as void Function(Timer timer));
  }

  Future<void> _cleanup() async {
    _timer?.cancel();
    _secs = 0;
    _currentCall = null;

    await _callSub?.cancel();
    await _iceSub?.cancel();
    await _webrtc.dispose();
  }
}

