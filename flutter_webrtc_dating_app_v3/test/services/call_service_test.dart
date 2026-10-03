import 'package:availchat/models/call_model.dart';
import 'package:availchat/services/call/call_service.dart';
import 'package:availchat/services/call/webrtc/call_constants.dart';
import 'package:flutter_test/flutter_test.dart';

// DEST-019/022/023: end reasons and timeouts the call screens rely on.
void main() {
  test('every end reason has user-facing text', () {
    for (final r in CallEndReason.values) {
      expect(CallService.endReasonMessage(r), isNotEmpty, reason: r.name);
    }
    expect(CallService.endReasonMessage(CallEndReason.declined), 'Declined');
    expect(CallService.endReasonMessage(CallEndReason.noAnswer), 'No answer');
    expect(CallService.endReasonMessage(CallEndReason.busy), 'User is busy');
  });

  test('timeouts keep ghost calls from ringing forever', () {
    expect(
      CallConstants.incomingRingLimit,
      greaterThan(CallConstants.noAnswerTimeout),
    );
    expect(
      CallConstants.incomingStaleAfter,
      greaterThan(CallConstants.noAnswerTimeout),
    );
  });

  test('permission errors name the missing permission', () {
    expect(
      const CallPermissionDeniedException(CallType.video).message,
      contains('Camera'),
    );
    expect(
      const CallPermissionDeniedException(CallType.audio).message,
      isNot(contains('Camera')),
    );
  });
}
