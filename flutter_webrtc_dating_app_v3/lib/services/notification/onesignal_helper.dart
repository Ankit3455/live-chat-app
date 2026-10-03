// lib/services/notification/onesignal_helper.dart
import '../session_service.dart';

/// Push identity is bound/unbound by SessionService on auth changes.
/// Kept as a forwarder for older call sites.
class OneSignalHelper {
  @Deprecated('SessionService binds the push identity on sign-in')
  static Future<void> setUser(String userId) =>
      SessionService.instance.bindPushIdentity(userId);

  @Deprecated('Use AuthService.signOut / SessionService.signOut')
  static Future<void> logout() => SessionService.instance.unbindPushIdentity();
}
