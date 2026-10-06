class CallConstants {
  // RTDB paths
  static const String pathRooms = 'rooms';
  static const String pathIncomingCalls = 'incoming_calls';
  static const String pathOffer = 'offer';
  static const String pathAnswer = 'answer';
  static const String pathCallerCandidates = 'caller_candidates';
  static const String pathCalleeCandidates = 'callee_candidates';
  static const String pathState = 'state';
  static const String pathEndReason = 'endReason';

  /// rooms/{id}/filters/{uid} = VideoFilter id that uid picked for its video.
  static const String pathFilters = 'filters';

  // Room state: ringing -> accepted -> ended. The reason for 'ended' is in
  // rooms/{id}/endReason (one of the endReason* values below).
  static const String roomStateRinging = 'ringing';
  static const String roomStateAccepted = 'accepted';
  static const String roomStateEnded = 'ended';

  /// Legacy initial state written by older builds.
  static const String roomStateActive = 'active';

  static const String endReasonHangup = 'hangup';
  static const String endReasonCancelled = 'cancelled';
  static const String endReasonDeclined = 'declined';
  static const String endReasonBusy = 'busy';
  static const String endReasonMissed = 'missed';
  static const String endReasonFailed = 'failed';
  static const String endReasonConnectionLost = 'connection_lost';

  // incoming_calls/{uid}/{callId}/status
  static const String inboxRinging = 'ringing';
  static const String inboxEnded = 'ended';
  static const String inboxMissed = 'missed';
  static const String inboxFailed = 'failed';

  // Timing
  static const Duration noAnswerTimeout = Duration(seconds: 45);
  static const Duration offerWaitTimeout = Duration(seconds: 15);
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration reconnectGrace = Duration(seconds: 15);
  static const Duration roomDeleteDelay = Duration(seconds: 5);

  /// Inbox entries older than this are ignored (ghost calls).
  static const Duration incomingStaleAfter = Duration(seconds: 60);

  /// Safety net so a ringing screen that never resolves cannot keep the
  /// callee "busy" forever.
  static const Duration incomingRingLimit = Duration(seconds: 70);
}
