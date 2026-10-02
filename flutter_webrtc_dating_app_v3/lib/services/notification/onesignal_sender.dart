// // lib/services/notification/onesignal_sender.dart
// import 'dart:convert';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
//
// class OneSignalSender {
//   static const String _oneSignalAppId = 'f4489084-4880-4e7f-aa6d-a3b0cfb8beb4';
//   static const String _oneSignalRestApiKey =
//       'os_v2_app_6rejbbciqbhh7ktnuoym7of6wtw3b7ftmbmulnvm6zp3tkcuw7ztuaulfo3q3g656v75od2nlvddkkzquqky2l6klikumsb66gqtbli';
//
//   static final FirebaseFirestore _db = FirebaseFirestore.instance;
//
//   static Future<void> sendChatNotification({
//     required String senderId,
//     required String receiverId,
//     required String message,
//     required String conversationId,
//   }) async {
//     try {
//       final senderSnap = await _db.collection('users').doc(senderId).get();
//       final senderData = senderSnap.data() ?? {};
//       final senderName =
//       (senderData['username'] ?? senderData['name'] ?? 'Someone').toString();
//
//       final trimmedMessage =
//       message.length > 120 ? '${message.substring(0, 117)}...' : message;
//
//       final payload = {
//         'app_id': _oneSignalAppId,
//         'target_channel': 'push',
//
//         'include_aliases': {
//           'external_id': [receiverId],
//         },
//
//         'headings': {'en': senderName},
//         'contents': {'en': trimmedMessage},
//
//         // ✅ Native channel use karo (jo MainActivity me banaya)
//         'existing_android_channel_id': 'onesignal_chat_channel',
//
//         'priority': 10,
//
//         'data': {
//           'type': 'new_message',
//           'conversationId': conversationId,
//           'senderId': senderId,
//           'receiverId': receiverId,
//         },
//       };
//
//       final response = await http.post(
//         Uri.parse('https://onesignal.com/api/v1/notifications'),
//         headers: {
//           'Content-Type': 'application/json; charset=utf-8',
//           'Authorization': 'Basic $_oneSignalRestApiKey',
//         },
//         body: jsonEncode(payload),
//       );
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         debugPrint('✅ OneSignal push sent');
//       } else {
//         debugPrint('❌ OneSignal error ${response.statusCode}: ${response.body}');
//       }
//     } catch (e) {
//       debugPrint('❌ OneSignal exception: $e');
//     }
//   }
// }



// lib/services/notification/onesignal_sender.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OneSignalSender {
  static const String _oneSignalAppId = 'f4489084-4880-4e7f-aa6d-a3b0cfb8beb4';
  static const String _oneSignalRestApiKey =
      'os_v2_app_6rejbbciqbhh7ktnuoym7of6wtw3b7ftmbmulnvm6zp3tkcuw7ztuaulfo3q3g656v75od2nlvddkkzquqky2l6klikumsb66gqtbli';

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================================================
  // 📨 CHAT NOTIFICATION (EXISTING - NO CHANGE)
  // ================================================
  static Future<void> sendChatNotification({
    required String senderId,
    required String receiverId,
    required String message,
    required String conversationId,
  }) async {
    try {
      final senderSnap = await _db.collection('users').doc(senderId).get();
      final senderData = senderSnap.data() ?? {};
      final senderName =
      (senderData['username'] ?? senderData['name'] ?? 'Someone').toString();

      final trimmedMessage =
      message.length > 120 ? '${message.substring(0, 117)}...' : message;

      final payload = {
        'app_id': _oneSignalAppId,
        'target_channel': 'push',

        'include_aliases': {
          'external_id': [receiverId],
        },

        'headings': {'en': senderName},
        'contents': {'en': trimmedMessage},

        // ✅ Chat channel (custom sound)
        'existing_android_channel_id': 'onesignal_chat_channel',

        'priority': 10,

        'data': {
          'type': 'new_message',
          'conversationId': conversationId,
          'senderId': senderId,
          'receiverId': receiverId,
        },
      };

      await _sendToOneSignal(payload);
    } catch (e) {
      debugPrint('❌ Chat notification error: $e');
    }
  }

  // ================================================
  // 📞 CALL NOTIFICATION (NEW - ADDED)
  // ================================================
  static Future<void> sendCallNotification({
    required String callerId,
    required String callerName,
    String? callerAvatar,
    required String receiverId,
    required String callId,
    required bool isVideo,
  }) async {
    try {
      final callType = isVideo ? 'Video' : 'Voice';

      // ✅ Video ya Audio channel select karo
      final channelId = isVideo
          ? 'onesignal_video_call_channel'
          : 'onesignal_audio_call_channel';

      final payload = {
        'app_id': _oneSignalAppId,
        'target_channel': 'push',

        'include_aliases': {
          'external_id': [receiverId],
        },

        'headings': {'en': 'Incoming $callType Call'},
        'contents': {'en': '$callerName is calling...'},

        // ✅ Call channel use karo (incoming_call.mp3 bajegi)
        'existing_android_channel_id': channelId,

        // ✅ High priority for calls
        'priority': 10,

        // ✅ Time to live (60 seconds - call expire)
        'ttl': 60,

        'data': {
          'type': 'call',
          'callId': callId,
          'callerId': callerId,
          'callerName': callerName,
          'callerAvatar': callerAvatar,
          'callType': isVideo ? 'video' : 'audio',
          'receiverId': receiverId,
        },

        // ✅ iOS specific
        'ios_sound': 'incoming_call.wav',
      };

      await _sendToOneSignal(payload);
      debugPrint('✅ Call notification sent to $receiverId');
    } catch (e) {
      debugPrint('❌ Call notification error: $e');
    }
  }

  // ================================================
  // 🚫 MISSED CALL NOTIFICATION (NEW - BONUS)
  // ================================================
  static Future<void> sendMissedCallNotification({
    required String callerId,
    required String callerName,
    required String receiverId,
    required bool wasVideo,
  }) async {
    try {
      final callType = wasVideo ? 'video' : 'voice';

      final payload = {
        'app_id': _oneSignalAppId,
        'target_channel': 'push',

        'include_aliases': {
          'external_id': [receiverId],
        },

        'headings': {'en': 'Missed Call'},
        'contents': {'en': 'You missed a $callType call from $callerName'},

        // ✅ Normal chat channel for missed call (softer sound)
        'existing_android_channel_id': 'onesignal_chat_channel',

        'priority': 10,

        'data': {
          'type': 'missed_call',
          'callerId': callerId,
          'callerName': callerName,
          'callType': callType,
        },
      };

      await _sendToOneSignal(payload);
      debugPrint('✅ Missed call notification sent');
    } catch (e) {
      debugPrint('❌ Missed call notification error: $e');
    }
  }

  // ================================================
  // 🔧 HELPER: Send to OneSignal API (NEW - ADDED)
  // ================================================
  static Future<void> _sendToOneSignal(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('https://onesignal.com/api/v1/notifications'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Basic $_oneSignalRestApiKey',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint('✅ OneSignal push sent');
    } else {
      debugPrint('❌ OneSignal error ${response.statusCode}: ${response.body}');
    }
  }
}
