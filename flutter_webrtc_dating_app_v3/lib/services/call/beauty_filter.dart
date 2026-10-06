import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Skin smoothing done natively on the outgoing camera frames
/// (BeautyFrameProcessor.kt / AppDelegate.swift), so the other side sees it
/// without any signaling. No-op on web and desktop.
class BeautyFilter {
  BeautyFilter._();

  static const MethodChannel _channel = MethodChannel('video_beauty');

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static const double off = 0;
  static const double soft = 0.45;
  static const double strong = 0.85;

  /// Picker steps, weakest first.
  static const levels = <(String, double)>[
    ('Off', off),
    ('Soft', soft),
    ('Strong', strong),
  ];

  /// Smooths the local video track [trackId] at [level] (0 = off, 1 = max).
  /// Returns false when the native side could not find the track.
  static Future<bool> setBeauty(String trackId, double level) async {
    if (!isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('setBeauty', {
        'trackId': trackId,
        'level': level.clamp(0.0, 1.0).toDouble(),
      });
      return ok ?? false;
    } catch (e) {
      debugPrint('BeautyFilter.setBeauty failed: $e');
      return false;
    }
  }

  static Future<void> clear(String trackId) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('clear', {'trackId': trackId});
    } catch (e) {
      debugPrint('BeautyFilter.clear failed: $e');
    }
  }

  static const _prefKey = 'call_beauty_level';

  static Future<double> loadLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getDouble(_prefKey) ?? off).clamp(0.0, 1.0).toDouble();
    } catch (_) {
      return off;
    }
  }

  static Future<void> saveLevel(double level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefKey, level);
    } catch (_) {}
  }
}
