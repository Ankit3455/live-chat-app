import 'package:availchat/models/call_model.dart';
import 'package:availchat/services/call/call_consent.dart';
import 'package:flutter_test/flutter_test.dart';

// DEST-012: a call type is allowed only when both users enabled it.
void main() {
  Map<String, dynamic> conv(Map<String, dynamic> participantData) => {
    'participants': ['a', 'b'],
    'participantData': participantData,
  };

  test('both users must enable the same call type', () {
    final c = conv({
      'a': {
        'callEnabled': {'audio': true, 'video': true},
      },
      'b': {
        'callEnabled': {'audio': true},
      },
    });
    expect(CallConsent.isAllowed(c, 'a', 'b', CallType.audio), isTrue);
    expect(CallConsent.isAllowed(c, 'b', 'a', CallType.audio), isTrue);
    expect(CallConsent.isAllowed(c, 'a', 'b', CallType.video), isFalse);
  });

  test('the caller enabling calls alone is not enough', () {
    final c = conv({
      'a': {
        'callEnabled': {'audio': true, 'video': true},
      },
    });
    expect(CallConsent.isEnabledFor(c, 'a', CallType.video), isTrue);
    expect(CallConsent.isAllowed(c, 'a', 'b', CallType.video), isFalse);
  });

  test('missing or malformed data never allows a call', () {
    expect(CallConsent.isAllowed({}, 'a', 'b', CallType.audio), isFalse);
    expect(
      CallConsent.isAllowed({'participantData': 'x'}, 'a', 'b', CallType.audio),
      isFalse,
    );
    final truthy = conv({
      'a': {
        'callEnabled': {'audio': 'true'},
      },
      'b': {
        'callEnabled': {'audio': 1},
      },
    });
    expect(CallConsent.isAllowed(truthy, 'a', 'b', CallType.audio), isFalse);
  });

  test('mutual requires both users to have replied', () {
    expect(
      CallConsent.isMutual(
        conv({
          'a': {'hasReplied': true},
          'b': {'hasReplied': true},
        }),
        'a',
        'b',
      ),
      isTrue,
    );
    expect(
      CallConsent.isMutual(
        conv({
          'a': {'hasReplied': true},
        }),
        'a',
        'b',
      ),
      isFalse,
    );
  });

  test('typeKey matches the stored map keys', () {
    expect(CallConsent.typeKey(CallType.audio), CallConsent.keyAudio);
    expect(CallConsent.typeKey(CallType.video), CallConsent.keyVideo);
  });

  test('blocked users get a different message than missing consent', () {
    expect(
      const CallNotAllowedException(CallDenyReason.blocked).message,
      isNot(CallConsent.consentTooltip),
    );
    expect(
      const CallNotAllowedException(CallDenyReason.notEnabled).message,
      CallConsent.consentTooltip,
    );
  });
}
