import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationChannels {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    await _createChannels();
    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    // Firebase messaging permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _createChannels() async {
    // Video calls channel
    const AndroidNotificationChannel videoCallChannel = AndroidNotificationChannel(
      'video_calls',
      'Video Calls',
      description: 'Incoming video call notifications',
      importance: Importance.max,
      enableVibration: true,
      enableLights: true,
      playSound: true,
      showBadge: true,
    );

    // Audio calls channel
    const AndroidNotificationChannel audioCallChannel = AndroidNotificationChannel(
      'audio_calls',
      'Voice Calls',
      description: 'Incoming voice call notifications',
      importance: Importance.max,
      enableVibration: true,
      enableLights: true,
      playSound: true,
      showBadge: true,
    );

    // Message channel
    const AndroidNotificationChannel messageChannel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'New chat messages',
      importance: Importance.high,
    );

    // Create channels
    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(videoCallChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(audioCallChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(messageChannel);
  }

  // Basic notification
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      importance: Importance.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Incoming call notification (simple version)
  static Future<void> showIncomingCallNotification({
    required String callId,
    required String callerName,
    String? callerAvatar,
    required bool isVideo,
  }) async {
    final channelId = isVideo ? 'video_calls' : 'audio_calls';
    final callType = isVideo ? 'Video' : 'Voice';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'video_calls',
      'Video Calls',
      importance: Importance.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      ongoing: true,
      autoCancel: false,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      callId.hashCode,
      'Incoming $callType Call',
      callerName,
      details,
      payload: 'call:$callId',
    );
  }

  // Cancel notification
  static Future<void> cancelNotification(String callId) async {
    await _notifications.cancel(callId.hashCode);
  }

  // Cancel all
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}