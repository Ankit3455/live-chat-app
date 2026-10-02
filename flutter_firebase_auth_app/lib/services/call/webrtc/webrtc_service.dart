import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'ice_servers.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final _localStreamController = StreamController<MediaStream?>.broadcast();
  final _remoteStreamController = StreamController<MediaStream?>.broadcast();

  Stream<MediaStream?> get localStream => _localStreamController.stream;
  Stream<MediaStream?> get remoteStream => _remoteStreamController.stream;

  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerOn = true;

  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isSpeakerOn => _isSpeakerOn;

  // Initialize WebRTC
  Future<void> initialize({required bool isVideo}) async {
    await _createPeerConnection();
    await _getUserMedia(isVideo: isVideo);
  }

  // Create peer connection
  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(
      IceServers.configuration,
    );

    // Handle remote stream
    _peerConnection!.onAddStream = (MediaStream stream) {
      _remoteStream = stream;
      _remoteStreamController.add(stream);
    };

    // Handle connection state
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state: $state');
    };

    _peerConnection!.onSignalingState = (RTCSignalingState state) {
      print('Signaling state: $state');
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE connection state: $state');
    };
  }

  // Get user media
  Future<void> _getUserMedia({required bool isVideo}) async {
    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': isVideo
          ? {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      }
          : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _localStreamController.add(_localStream);

      // Add local stream to peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });
    } catch (e) {
      print('Error getting user media: $e');
      throw e;
    }
  }

  // Create offer
  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  // Create answer
  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  // Set remote description
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
  }

  // Add ICE candidate
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  // Get ICE candidates
  Stream<RTCIceCandidate> getIceCandidates() {
    final controller = StreamController<RTCIceCandidate>();

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      controller.add(candidate);
    };

    return controller.stream;
  }

  // Toggle mute
  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
  }

  // Toggle video
  void toggleVideo() {
    _isVideoEnabled = !_isVideoEnabled;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = _isVideoEnabled;
    });
  }

  // Toggle speaker
  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    _localStream?.getAudioTracks().forEach((track) {
      track.enableSpeakerphone(_isSpeakerOn);
    });
  }

  // Switch camera
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!
          .getVideoTracks()
          .firstWhere((track) => track.kind == 'video');
      await Helper.switchCamera(videoTrack);
    }
  }

  // Dispose
  Future<void> dispose() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localStream = null;

    _remoteStream?.getTracks().forEach((track) => track.stop());
    await _remoteStream?.dispose();
    _remoteStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    _localStreamController.close();
    _remoteStreamController.close();
  }
}