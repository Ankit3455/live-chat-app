// lib/services/notification/onesignal_service.dart
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  static const String appId = 'f4489084-4880-4e7f-aa6d-a3b0cfb8beb4';

  static Future<void> init() async {
    try {
      OneSignal.initialize(appId);

      // Push permission (Android pe bhi sound/badge ke liye useful)
      OneSignal.Notifications.requestPermission(true);

      if (kDebugMode) debugPrint('OneSignal initialized');
    } catch (e) {
      if (kDebugMode) debugPrint('OneSignal init failed: $e');
    }
  }
}
