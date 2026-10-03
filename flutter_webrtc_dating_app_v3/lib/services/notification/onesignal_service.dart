// lib/services/notification/onesignal_service.dart

/// OneSignal is initialised in main() and permission is asked by
/// NotificationChannels.requestPermissionOnce, so only the app id lives here.
class OneSignalService {
  OneSignalService._();

  static const String appId = 'f4489084-4880-4e7f-aa6d-a3b0cfb8beb4';
}
