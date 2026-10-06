import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android side of incoming calls (MainActivity.kt / CallNotifier.kt): the
/// native ringing notification shown while the app is closed or in the
/// background, and the Accept / Show taps that open the app. No-ops on other
/// platforms.
class CallIntentChannel {
  CallIntentChannel._();

  static const MethodChannel _channel = MethodChannel('call_intent');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Call id the user accepted from the notification; IncomingCallScreen
  /// answers it as soon as it is shown for that call.
  static final ValueNotifier<String?> autoAnswerCallId = ValueNotifier(null);

  /// True (once) when [callId] was accepted from the notification.
  static bool takeAutoAnswer(String callId) {
    if (autoAnswerCallId.value != callId) return false;
    autoAnswerCallId.value = null;
    return true;
  }

  /// [onAction] gets `{action: show|accept|decline, callId, callerId, ...}`
  /// for taps while the app is running; return true once handled.
  static void setActionHandler(
    Future<bool> Function(Map<String, dynamic> action) onAction,
  ) {
    if (!_supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onCallAction') return false;
      final args = call.arguments;
      if (args is! Map) return false;
      return onAction(Map<String, dynamic>.from(args));
    });
  }

  /// The notification tap that launched the app, returned once.
  static Future<Map<String, dynamic>?> initialAction() async {
    if (!_supported) return null;
    try {
      final args = await _channel.invokeMethod<Object?>('getInitialCallAction');
      return args is Map ? Map<String, dynamic>.from(args) : null;
    } catch (e) {
      if (kDebugMode) debugPrint('CallIntentChannel: initial action: $e');
      return null;
    }
  }

  /// Stops the native ringing for [callId] and keeps a late push silent.
  static Future<void> cancelNotification(String callId) =>
      _invoke('cancelCallNotification', {'callId': callId});

  /// Lets the lock screen come back once no call UI is showing.
  static Future<void> releaseLockScreen() => _invoke('releaseLockScreen');

  /// Calls declined from the notification that still have to be rejected.
  static Future<List<String>> consumePendingDeclines() async {
    if (!_supported) return const [];
    try {
      final ids = await _channel.invokeListMethod<String>(
        'consumePendingDeclines',
      );
      return ids ?? const [];
    } catch (e) {
      if (kDebugMode) debugPrint('CallIntentChannel: pending declines: $e');
      return const [];
    }
  }

  /// False on Android 14+ until the user allows full-screen notifications.
  static Future<bool> canUseFullScreenIntent() async {
    if (!_supported) return true;
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ??
          true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> openFullScreenIntentSettings() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'openFullScreenIntentSettings',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _invoke(String method, [Object? args]) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (e) {
      if (kDebugMode) debugPrint('CallIntentChannel: $method: $e');
    }
  }
}
