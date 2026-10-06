import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:availchat/feature/games/ludo/services/ludo_game_service.dart';

void main() {
  tearDown(() => LudoGameService.serverOffset = Duration.zero);

  // Server timestamps as the server wrote them, [serverClock] = real time.
  Map<String, dynamic> entry(DateTime serverClock,
          {Duration age = Duration.zero}) =>
      {
        'heartbeatAt': Timestamp.fromDate(serverClock.subtract(age)),
        'expiresAt': Timestamp.fromDate(
          serverClock.subtract(age).add(LudoGameService.queueTtl),
        ),
      };

  test('a just-heartbeated entry is fresh on an accurate clock', () {
    expect(LudoGameService.isFreshQueueEntry(entry(DateTime.now())), isTrue);
  });

  test('an entry older than the heartbeat max age is stale', () {
    final data = entry(DateTime.now(), age: const Duration(seconds: 60));
    expect(LudoGameService.isFreshQueueEntry(data), isFalse);
  });

  test(
      'a device clock running ahead still sees fresh entries once the offset is known',
      () {
    const skew = Duration(minutes: 10);
    // The device clock reads 10 minutes ahead of the server.
    final serverClock = DateTime.now().subtract(skew);
    final data = entry(serverClock, age: const Duration(seconds: 5));

    expect(LudoGameService.isFreshQueueEntry(data), isFalse);

    LudoGameService.serverOffset = -skew;
    expect(LudoGameService.isFreshQueueEntry(data), isTrue);
  });

  test('a device clock running behind does not keep expired entries alive', () {
    const skew = Duration(minutes: 10);
    // The device clock reads 10 minutes behind the server.
    final serverClock = DateTime.now().add(skew);
    final data = entry(serverClock, age: const Duration(minutes: 3));

    expect(LudoGameService.isFreshQueueEntry(data), isTrue);

    LudoGameService.serverOffset = skew;
    expect(LudoGameService.isFreshQueueEntry(data), isFalse);
  });
}
