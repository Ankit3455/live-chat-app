// lib/services/notification/onesignal_service.dart
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  // 🔴 Yahan apna OneSignal App ID daalo
  static const String _appId = 'f4489084-4880-4e7f-aa6d-a3b0cfb8beb4';

  static Future<void> init() async {
    try {
      OneSignal.initialize('f4489084-4880-4e7f-aa6d-a3b0cfb8beb4');

      // Push permission (Android pe bhi sound/badge ke liye useful)
      OneSignal.Notifications.requestPermission(true);

      debugPrint("✅ OneSignal initialized");
    } catch (e, st) {
      debugPrint("❌ OneSignal init failed: $e");
      debugPrint("$st");
    }
  }
}
