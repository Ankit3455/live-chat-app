// lib/services/notification/onesignal_helper.dart
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalHelper {
  /// App me user login hua → OneSignal ko userId batao
  static Future<void> setUser(String userId) async {
    try {
      await OneSignal.login(userId);
      debugPrint("✅ OneSignal user set: $userId");
    } catch (e, st) {
      debugPrint("❌ OneSignal login failed: $e");
      debugPrint("$st");
    }
  }

  /// App se logout → OneSignal se bhi nikal do
  static Future<void> logout() async {
    try {
      await OneSignal.logout();
      debugPrint("✅ OneSignal user logged out");
    } catch (e, st) {
      debugPrint("❌ OneSignal logout failed: $e");
      debugPrint("$st");
    }
  }
}
