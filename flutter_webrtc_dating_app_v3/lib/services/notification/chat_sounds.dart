import 'dart:async';
import 'dart:collection';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../call/call_service.dart';

/// Short in-app sounds for the open chat, where the push is suppressed:
/// "received" for an incoming message, a quieter "sent" once a message is
/// written. One shared low-latency player; honours the user's
/// notificationSettings.soundEnabled. Android only: on iOS the default
/// audio session would ignore the silent switch.
class ChatSounds {
  ChatSounds._();

  static final ChatSounds instance = ChatSounds._();

  static const String _asset = 'sounds/notification_sound.mp3';
  static const double _receivedVolume = 0.6;
  static const double _sentVolume = 0.25;
  static const Duration _minGap = Duration(milliseconds: 600);
  static const Duration _settingsMaxAge = Duration(minutes: 5);
  static const int _recentIdsMax = 50;

  AudioPlayer? _player;
  Future<AudioPlayer>? _loading;
  DateTime _lastPlayed = DateTime.fromMillisecondsSinceEpoch(0);

  // The open chat's listener and its suppressed push both report the same
  // message; whichever comes first plays.
  final Queue<String> _recentIds = Queue<String>();

  String? _settingsUid;
  DateTime? _settingsReadAt;
  bool _soundEnabled = true;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void playReceived({String? messageId}) {
    if (messageId != null) {
      if (_recentIds.contains(messageId)) return;
      _recentIds.addLast(messageId);
      if (_recentIds.length > _recentIdsMax) _recentIds.removeFirst();
    }
    unawaited(_play(_receivedVolume));
  }

  void playSent() => unawaited(_play(_sentVolume));

  Future<void> _play(double volume) async {
    if (!_supported) return;
    final calls = CallService();
    if (calls.isInCall || calls.ringingCall != null) return;
    final now = DateTime.now();
    if (now.difference(_lastPlayed) < _minGap) return;
    _lastPlayed = now;
    try {
      if (!await _soundOn()) return;
      final player = await _ready();
      await player.stop();
      await player.setVolume(volume);
      await player.resume();
    } catch (e) {
      if (kDebugMode) debugPrint('ChatSounds: $e');
    }
  }

  Future<AudioPlayer> _ready() {
    final player = _player;
    if (player != null) return Future.value(player);
    return _loading ??= _create().whenComplete(() => _loading = null);
  }

  Future<AudioPlayer> _create() async {
    final player = AudioPlayer(playerId: 'chat_sounds');
    try {
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      // Notification usage: muted in silent/vibrate mode, doesn't pause
      // other audio.
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationEvent,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      await player.setSource(AssetSource(_asset));
    } catch (_) {
      await player.dispose();
      rethrow;
    }
    return _player = player;
  }

  Future<bool> _soundOn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final readAt = _settingsReadAt;
    if (uid == _settingsUid &&
        readAt != null &&
        DateTime.now().difference(readAt) < _settingsMaxAge) {
      return _soundEnabled;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 3));
      final settings = doc.data()?['notificationSettings'];
      _soundEnabled = settings is! Map || settings['soundEnabled'] != false;
      _settingsUid = uid;
      _settingsReadAt = DateTime.now();
    } catch (e) {
      // Keep the last known value; retry on the next sound.
      if (kDebugMode) debugPrint('ChatSounds settings: $e');
      if (uid != _settingsUid) return true;
    }
    return _soundEnabled;
  }
}
