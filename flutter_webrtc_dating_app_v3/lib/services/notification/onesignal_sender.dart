// lib/services/notification/onesignal_sender.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Push notifications are sent by Cloud Functions (functions/index.js).
/// The OneSignal REST API key lives only on the server; the client passes
/// ids and the server verifies the sender before notifying the receiver.
class OneSignalSender {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ================================================
  // 📨 CHAT NOTIFICATION
  // ================================================
  static Future<void> sendChatNotification({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      await _functions.httpsCallable('sendChatPush').call({
        'conversationId': conversationId,
        'messageId': messageId,
      });
    } catch (e) {
      debugPrint('❌ Chat notification error: $e');
    }
  }

  // ================================================
  // 📞 CALL NOTIFICATION
  // ================================================
  static Future<void> sendCallNotification({
    required String receiverId,
    required String callId,
  }) async {
    try {
      await _functions.httpsCallable('sendCallPush').call({
        'receiverId': receiverId,
        'callId': callId,
      });
      debugPrint('✅ Call notification sent');
    } catch (e) {
      debugPrint('❌ Call notification error: $e');
    }
  }
}
