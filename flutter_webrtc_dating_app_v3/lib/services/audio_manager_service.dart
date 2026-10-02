import 'package:flutter/services.dart';
import 'dart:io' show Platform;

class AudioManagerService {
  static const MethodChannel _channel = MethodChannel('audio_manager_channel');

  /// Set audio mode for calls
  /// [inCall] - true for MODE_IN_COMMUNICATION, false for MODE_NORMAL
  static Future<void> setCallAudioMode(bool inCall) async {
    if (!Platform.isAndroid) return; // iOS handles this automatically

    try {
      await _channel.invokeMethod('setCallAudioMode', {'inCall': inCall});
      print('✅ Audio mode set: inCall=$inCall');
    } catch (e) {
      print('❌ Failed to set audio mode: $e');
    }
  }

  /// Enable/disable speakerphone
  static Future<void> setSpeakerphone(bool enabled) async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('setSpeakerphone', {'enabled': enabled});
      print('🔊 Speakerphone: ${enabled ? "ON" : "OFF"}');
    } catch (e) {
      print('❌ Failed to set speakerphone: $e');
    }
  }
}