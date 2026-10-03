import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// ICE server configuration.
///
/// Order of precedence:
///  1. `getTurnCredentials` callable (short-lived TURN credentials, WP-15),
///     expected to return `{iceServers: [{urls, username?, credential?}], ttlSeconds?}`.
///  2. [defaultIceServers] (public STUN + shared openrelay TURN) when the
///     callable is missing, fails or times out.
class IceServers {
  static const String turnCredentialsFunction = 'getTurnCredentials';

  /// When true, calls between users who have not both replied in the chat use
  /// `iceTransportPolicy: 'relay'` so their IPs are not exposed to each other.
  /// Keep off until a reliable TURN server is provisioned (owner action O-10);
  /// the shared openrelay server has no SLA.
  static const bool relayOnlyWhenNotMutual = false;

  static const List<Map<String, dynamic>> defaultIceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {
      'urls': 'turn:openrelay.metered.ca:80',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    {
      'urls': 'turn:openrelay.metered.ca:443',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    {
      'urls': 'turns:openrelay.metered.ca:443',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
  ];

  static const Duration _fetchTimeout = Duration(seconds: 4);
  static const Duration _retryAfterFailure = Duration(minutes: 10);

  static List<Map<String, dynamic>>? _cachedServers;
  static DateTime? _cachedUntil;
  static DateTime? _lastFailureAt;

  /// Synchronous default configuration (no remote lookup).
  static Map<String, dynamic> get configuration =>
      buildConfiguration(defaultIceServers);

  static Map<String, dynamic> buildConfiguration(
    List<Map<String, dynamic>> servers, {
    bool relayOnly = false,
  }) => {
    'iceServers': servers,
    'iceTransportPolicy': relayOnly ? 'relay' : 'all',
    'sdpSemantics': 'unified-plan',
    'continualGatheringPolicy': 'gather_continually',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };

  /// Configuration for a new call; never throws.
  static Future<Map<String, dynamic>> resolve({bool relayOnly = false}) async {
    final servers = await _remoteServers() ?? defaultIceServers;
    return buildConfiguration(servers, relayOnly: relayOnly);
  }

  static Future<List<Map<String, dynamic>>?> _remoteServers() async {
    final now = DateTime.now();
    if (_cachedServers != null &&
        _cachedUntil != null &&
        now.isBefore(_cachedUntil!)) {
      return _cachedServers;
    }
    if (_lastFailureAt != null &&
        now.difference(_lastFailureAt!) < _retryAfterFailure) {
      return null;
    }

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable(turnCredentialsFunction)
          .call()
          .timeout(_fetchTimeout);
      final data = result.data;
      if (data is! Map || data['iceServers'] is! List) {
        throw const FormatException('iceServers missing');
      }

      final servers = <Map<String, dynamic>>[];
      for (final s in data['iceServers'] as List) {
        if (s is Map && s['urls'] != null) {
          servers.add(Map<String, dynamic>.from(s));
        }
      }
      if (servers.isEmpty) throw const FormatException('iceServers empty');

      final ttl = (data['ttlSeconds'] as num?)?.toInt() ?? 3600;
      // Refresh well before the credentials expire.
      _cachedServers = servers;
      _cachedUntil = now.add(Duration(seconds: (ttl * 0.8).floor()));
      _lastFailureAt = null;
      return servers;
    } catch (e) {
      debugPrint('IceServers: using default servers ($e)');
      _lastFailureAt = now;
      return null;
    }
  }

  /// For createOffer / createAnswer on older flutter_webrtc versions use Map.
  static Map<String, dynamic> defaultOfferOptions({bool iceRestart = false}) =>
      {
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
        'iceRestart': iceRestart,
      };
}
