import 'package:flutter_webrtc/flutter_webrtc.dart';

class IceServers {
  static Map<String, dynamic> get configuration => {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},

      // TURN servers (same as Kotlin)
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
      {
        'urls': 'turns:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
    ],
    'sdpSemantics': 'unified-plan',
    'continualGatheringPolicy': 'gather_continually',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };
}