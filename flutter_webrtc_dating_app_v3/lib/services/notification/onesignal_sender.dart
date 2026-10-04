// lib/services/notification/onesignal_sender.dart

import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/push_config.dart';

/// Push notifications are sent by a server that holds the OneSignal REST API
/// key: the Cloudflare Worker (cloudflare/push-worker) when
/// [PushConfig.enabled], otherwise the Cloud Functions callables. The client
/// passes ids and the server verifies the sender before notifying the
/// receiver. Errors are logged, never thrown.
class OneSignalSender {
  static const Duration _timeout = Duration(seconds: 8);

  // ================================================
  // 📨 CHAT NOTIFICATION
  // ================================================
  static Future<void> sendChatNotification({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      await _send(
        workerPath: '/chat-push',
        callable: 'sendChatPush',
        body: {'conversationId': conversationId, 'messageId': messageId},
      );
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
      await _send(
        workerPath: '/call-push',
        callable: 'sendCallPush',
        body: {'receiverId': receiverId, 'callId': callId},
      );
      debugPrint('✅ Call notification sent');
    } catch (e) {
      debugPrint('❌ Call notification error: $e');
    }
  }

  static Future<void> _send({
    required String workerPath,
    required String callable,
    required Map<String, String> body,
  }) async {
    if (!PushConfig.enabled) {
      await FirebaseFunctions.instance
          .httpsCallable(callable)
          .call(body)
          .timeout(_timeout);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('not signed in');
    final idToken = await user.getIdToken();
    if (idToken == null) throw StateError('no ID token');

    final response = await http
        .post(
          Uri.parse('${PushConfig.workerUrl}$workerPath'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw StateError('push worker ${response.statusCode}: ${response.body}');
    }
  }
}
