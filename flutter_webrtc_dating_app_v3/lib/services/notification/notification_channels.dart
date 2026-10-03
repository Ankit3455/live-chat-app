// import 'dart:io';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
//
// class NotificationChannels {
//   static final FlutterLocalNotificationsPlugin _notifications =
//   FlutterLocalNotificationsPlugin();
//
//   // Channel IDs
//   static const String channelVideo = 'video_calls';
//   static const String channelAudio = 'audio_calls';
//
//   // Old (keep for backward)
//   static const String channelChatLegacy = 'chat_messages';
//
//   // NEW
//   static const String channelChatActive = 'chat_active';
//   static const String channelChatNew = 'chat_new';
//   static const String groupNewKey = 'new_messages_group';
//
//   static Future<void> initialize() async {
//     const AndroidInitializationSettings androidSettings =
//     AndroidInitializationSettings('@mipmap/ic_launcher');
//
//     const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );
//
//     const InitializationSettings initSettings =
//     InitializationSettings(android: androidSettings, iOS: iosSettings);
//
//     await _notifications.initialize(initSettings);
//     await _createChannels();
//     await _requestPermissions();
//   }
//
//   static Future<void> _requestPermissions() async {
//     // FCM (iOS + Android 13+ visible toggles in system)
//     await FirebaseMessaging.instance.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//
//     // Android 13+ (POST_NOTIFICATIONS) – flutter_local_notifications की explicit permission
//     final androidImpl = _notifications
//         .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin>();
//     if (androidImpl != null && Platform.isAndroid) {
//       // यह silently no-op होगा अगर API < 33
//       await androidImpl.requestNotificationsPermission();
//     }
//   }
//
//   static Future<void> _createChannels() async {
//     final android = _notifications
//         .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin>();
//
//     // ---- Calls (existing) ----
//     const AndroidNotificationChannel videoCallChannel = AndroidNotificationChannel(
//       channelVideo,
//       'Video Calls',
//       description: 'Incoming video call notifications',
//       importance: Importance.max,
//       enableVibration: true,
//       enableLights: true,
//       playSound: true,
//       showBadge: true,
//     );
//
//     const AndroidNotificationChannel audioCallChannel = AndroidNotificationChannel(
//       channelAudio,
//       'Voice Calls',
//       description: 'Incoming voice call notifications',
//       importance: Importance.max,
//       enableVibration: true,
//       enableLights: true,
//       playSound: true,
//       showBadge: true,
//     );
//
//     // in NotificationChannels._createChannels()
//
//     const AndroidNotificationChannel newMessageChannel = AndroidNotificationChannel(
//       'chat_new_messages',
//       'New Chat Messages (Silent)',
//       description: 'First-time messages / requests (silent)',
//       importance: Importance.low,        // no sound
//       playSound: false,
//       enableVibration: false,
//       showBadge: true,
//     );
//
// // create it like others:
//     await _notifications
//         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(newMessageChannel);
//
//
//     // ---- Legacy chat (keep) ----
//     const AndroidNotificationChannel legacyChat = AndroidNotificationChannel(
//       channelChatLegacy,
//       'Chat Messages',
//       description: 'New chat messages',
//       importance: Importance.high,
//     );
//
//     // ---- NEW: Active chats (loud) ----
//     const AndroidNotificationChannel activeChat = AndroidNotificationChannel(
//       channelChatActive,
//       'Active Chats',
//       description: 'Notifications for active conversations',
//       importance: Importance.high, // sound + heads-up
//       playSound: true,
//       showBadge: true,
//     );
//
//     // ---- NEW: New messages (silent + grouped) ----
//     const AndroidNotificationChannel newChat = AndroidNotificationChannel(
//       channelChatNew,
//       'New Messages',
//       description: 'Silent, grouped notifications for new senders',
//       importance: Importance.low, // silent
//       playSound: false,
//       showBadge: true,
//     );
//
//     await android?.createNotificationChannel(videoCallChannel);
//     await android?.createNotificationChannel(audioCallChannel);
//     await android?.createNotificationChannel(legacyChat);
//     await android?.createNotificationChannel(activeChat);
//     await android?.createNotificationChannel(newChat);
//   }
//
//   // ========= BASIC (kept for backward) =========
//   static Future<void> showNotification({
//     required String title,
//     required String body,
//     String? payload,
//   }) async {
//     const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//       channelChatLegacy,
//       'Chat Messages',
//       importance: Importance.high,
//       priority: Priority.high,
//       playSound: true,
//     );
//
//     const NotificationDetails details = NotificationDetails(
//       android: androidDetails,
//       iOS: DarwinNotificationDetails(),
//     );
//
//     await _notifications.show(
//       DateTime.now().millisecondsSinceEpoch ~/ 1000,
//       title,
//       body,
//       details,
//       payload: payload,
//     );
//   }
//
//   // ========= NEW: Active chat (loud) =========
//   static Future<void> showActiveChat({
//     required String title,
//     required String body,
//     String? payload,
//   }) async {
//     const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//       channelChatActive,
//       'Active Chats',
//       importance: Importance.high,
//       priority: Priority.high,
//       playSound: true,
//       channelShowBadge: true,
//     );
//
//     const NotificationDetails details = NotificationDetails(
//       android: androidDetails,
//       iOS: DarwinNotificationDetails(presentSound: true),
//     );
//
//     await _notifications.show(
//       DateTime.now().millisecondsSinceEpoch ~/ 1000,
//       title,
//       body,
//       details,
//       payload: payload,
//     );
//   }
//
//   // ========= NEW: New messages (silent + grouped) =========
//   // single sticky notification id so it updates count
//   static const int _newMsgStickyId = 777001;
//
//   static Future<void> showNewMessageGrouped({
//     required int totalNewSenders,
//   }) async {
//     final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//       channelChatNew,
//       'New Messages',
//       importance: Importance.low,
//       priority: Priority.low,
//       playSound: false,
//       channelShowBadge: true,
//       groupKey: groupNewKey,
//       onlyAlertOnce: true, // update in place
//     );
//
//     final NotificationDetails details = NotificationDetails(
//       android: androidDetails,
//       iOS: const DarwinNotificationDetails(presentSound: false),
//     );
//
//     final title = 'New messages';
//     final body = totalNewSenders <= 1
//         ? '1 new person messaged you'
//         : '$totalNewSenders new people messaged you';
//
//     await _notifications.show(
//       _newMsgStickyId,
//       title,
//       body,
//       details,
//       payload: 'open:new_messages',
//     );
//   }
//
//   // ========= Calls =========
//   static Future<void> showIncomingCallNotification({
//     required String callId,
//     required String callerName,
//     String? callerAvatar,
//     required bool isVideo,
//   }) async {
//     final channelId = isVideo ? channelVideo : channelAudio;
//
//     final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//       channelId,
//       isVideo ? 'Video Calls' : 'Voice Calls',
//       importance: Importance.max,
//       priority: Priority.max,
//       fullScreenIntent: true,
//       category: AndroidNotificationCategory.call,
//       ongoing: true,
//       autoCancel: false,
//       colorized: true,
//     );
//
//     const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//     );
//
//     final NotificationDetails details = NotificationDetails(
//       android: androidDetails,
//       iOS: iosDetails,
//     );
//
//     await _notifications.show(
//       callId.hashCode,
//       isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
//       callerName,
//       details,
//       payload: 'call:$callId',
//     );
//   }
//
//   static Future<void> cancelNotification(String idOrCallId) async {
//     await _notifications.cancel(idOrCallId.hashCode);
//   }
//
//   static Future<void> cancelAllNotifications() async {
//     await _notifications.cancelAll();
//   }
// }


// lib/services/notification/notification_channels.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saare local notification channels yahin se manage honge.
class NotificationChannels {
  NotificationChannels._();

  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  // ===== Channel IDs =====
  // Same ids as MainActivity.kt and functions/index.js, so local and
  // OneSignal notifications share one set of user-visible channels.
  static const String channelVideo = 'onesignal_video_call_channel';
  static const String channelAudio = 'onesignal_audio_call_channel';
  static const String channelChatActive = 'onesignal_chat_channel'; // loud
  // Chats the user has not replied to yet: silent (DECISIONS.md).
  static const String channelChatNew = 'onesignal_new_chat_channel';
  static const String groupNewKey = 'new_messages_group';

  static const String _permissionAskedKey = 'notification_permission_asked';

  // Manifest me jo id dali hogi: android:default_notification_channel_id
  static const String highImportanceChannelId = 'high_importance_channel';

  /// Creates channels and routes taps to [onTap] (including the tap that
  /// launched the app). Never prompts; see [requestPermissionOnce].
  static Future<void> initialize({void Function(String? payload)? onTap}) async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) => onTap?.call(resp.payload),
    );

    await _createChannels();

    if (onTap != null) {
      try {
        final launch = await _notifications.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp ?? false) {
          onTap(launch!.notificationResponse?.payload);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Notification launch details failed: $e');
      }
    }
  }

  static Future<bool> permissionAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_permissionAskedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks for notification permission (iOS, Android 13+) at most once per
  /// install. Call after sign-in, when the user has reached the app.
  static Future<void> requestPermissionOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_permissionAskedKey) ?? false) return;
      await prefs.setBool(_permissionAskedKey, true);
      if (!OneSignal.Notifications.permission) {
        await OneSignal.Notifications.requestPermission(false);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Notification permission error: $e');
    }
  }

  /// Saare Android channels create karo (ek hi baar)
  static Future<void> _createChannels() async {
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl == null) return;

    // Default / high importance
    const AndroidNotificationChannel highImportanceChannel =
    AndroidNotificationChannel(
      highImportanceChannelId,
      'High Importance Notifications',
      description:
      'Used by FCM and system when no specific channel is provided.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      showBadge: true,
    );

    // Video calls
    const AndroidNotificationChannel videoCallChannel =
    AndroidNotificationChannel(
      channelVideo,
      'Video Calls',
      description: 'Incoming video call notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('incoming_call'),
      showBadge: true,
    );

    // Audio calls
    const AndroidNotificationChannel audioCallChannel =
    AndroidNotificationChannel(
      channelAudio,
      'Voice Calls',
      description: 'Incoming voice call notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('incoming_call'),
      showBadge: true,
    );

    // Active chats (loud)
    const AndroidNotificationChannel activeChat = AndroidNotificationChannel(
      channelChatActive,
      'Chat Messages',
      description: 'Messages in your active chats',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      showBadge: true,
    );

    // New chats (silent)
    const AndroidNotificationChannel newChat = AndroidNotificationChannel(
      channelChatNew,
      'New Chat Requests',
      description: 'Messages from people you have not replied to yet',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: true,
    );

    await androidImpl.createNotificationChannel(highImportanceChannel);
    await androidImpl.createNotificationChannel(videoCallChannel);
    await androidImpl.createNotificationChannel(audioCallChannel);
    await androidImpl.createNotificationChannel(activeChat);
    await androidImpl.createNotificationChannel(newChat);
  }

  // =============================================================
  // BASIC NOTIFICATION (chat channel)
  // =============================================================
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      channelChatActive,
      'Chat Messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    const NotificationDetails details =
    NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // =============================================================
  // LOUD FOREGROUND CHAT
  // =============================================================
  static Future<void> showActiveChat({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      channelChatActive,
      'Chat Messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      channelShowBadge: true,
    );

    const NotificationDetails details =
    NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // =============================================================
  // GROUPED SILENT NEW MESSAGES
  // =============================================================
  static const int _newMsgStickyId = 777001;

  static Future<void> showNewMessageGrouped({
    required int totalNewSenders,
  }) async {
    final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      channelChatNew,
      'New Chat Requests',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      groupKey: groupNewKey,
      onlyAlertOnce: true,
      channelShowBadge: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(presentSound: false),
    );

    final body = totalNewSenders <= 1
        ? '1 new person messaged you'
        : '$totalNewSenders new people messaged you';

    await _notifications.show(
      _newMsgStickyId,
      'New messages',
      body,
      details,
      payload: 'open:new_messages',
    );
  }

  // =============================================================
  // CALL NOTIFICATION
  // =============================================================
  static Future<void> showIncomingCallNotification({
    required String callId,
    required String callerName,
    required bool isVideo,
    String? callerId,
  }) async {
    final channelId = isVideo ? channelVideo : channelAudio;

    final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      channelId,
      isVideo ? 'Video Calls' : 'Voice Calls',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      autoCancel: false,
      ongoing: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('incoming_call'),
      category: AndroidNotificationCategory.call,
    );

    final NotificationDetails details =
    NotificationDetails(android: androidDetails);

    await _notifications.show(
      callId.hashCode,
      isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
      callerName,
      details,
      payload: 'call:$callId:${callerId ?? ''}',
    );
  }

  static Future<void> cancelNotification(String callId) async {
    await _notifications.cancel(callId.hashCode);
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
