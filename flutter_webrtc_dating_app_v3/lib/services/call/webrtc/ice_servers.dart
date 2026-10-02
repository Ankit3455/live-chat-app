import 'package:flutter_webrtc/flutter_webrtc.dart';

class IceServers {
  static Map<String, dynamic> get configuration => {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
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

  /// For createOffer / createAnswer on older flutter_webrtc versions use Map.
  static Map<String, dynamic> defaultOfferOptions({bool iceRestart = false}) => {
    'offerToReceiveAudio': true,
    'offerToReceiveVideo': true,
    'iceRestart': iceRestart,
  };
}
