class CallConstants {
  // Intent extras
  static const String extraRoomId = 'roomId';
  static const String extraIsCaller = 'isCaller';
  static const String extraCallType = 'callType';
  static const String extraCallerName = 'callerName';
  static const String extraCallId = 'callId';
  static const String extraCallerId = 'callerId';

  // Call types
  static const String callTypeVideo = 'video';
  static const String callTypeAudio = 'audio';

  // Call statuses
  static const String callStatusRinging = 'ringing';
  static const String callStatusAnswered = 'answered';
  static const String callStatusDeclined = 'declined';
  static const String callStatusMissed = 'missed';
  static const String callStatusDelivered = 'delivered';

  // Notification channel IDs
  static const String channelIdCalls = 'incoming_calls';
  static const String channelIdService = 'call_service';

  // Notification IDs
  static const int notificationIdIncomingCall = 1002;
  static const int notificationIdService = 1001;

  // Room state
  static const String roomStateEnded = 'ended';
}