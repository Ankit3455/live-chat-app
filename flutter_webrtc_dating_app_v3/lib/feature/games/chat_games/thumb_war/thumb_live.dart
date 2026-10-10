// lib/feature/games/chat_games/thumb_war/thumb_live.dart
//
// The live part of a Thumb War, in the Realtime Database under
// thumb_live/{gameId}: players[0] (the host) runs the fight 60 times a second
// and shares it about 15 times a second; the other phone sends only its
// button (in/{uid}) and shows the shared fight. Both write a heartbeat so a
// phone that vanished can be claimed as left. The rounds' results go to the
// Firestore duel doc (thumb_rules.dart).

import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'thumb_war.dart';

/// thumb_live/{gameId} reads and writes. database.rules.json checks them.
class ThumbLiveRef {
  ThumbLiveRef(this.gameId, this.players);

  final String gameId;
  final List<String> players;

  DatabaseReference get _root =>
      FirebaseDatabase.instance.ref('thumb_live/$gameId');

  /// Host only: creates the node naming both players.
  Future<void> create() => _root.update({'p0': players[0], 'p1': players[1]});

  Future<void> writeState(Map<String, Object> state) =>
      _root.child('s').set(state);

  Future<void> setInput(String uid, bool pressed) =>
      _root.child('in/$uid').set(pressed);

  Future<void> beat(String uid) =>
      _root.child('hb/$uid').set(ServerValue.timestamp);

  Stream<ThumbFight?> state() =>
      _root.child('s').onValue.map((e) => ThumbFight.fromMap(e.snapshot.value));

  Stream<bool> input(String uid) =>
      _root.child('in/$uid').onValue.map((e) => e.snapshot.value == true);

  /// Server time of [uid]'s last heartbeat, or null.
  Stream<int?> heartbeat(String uid) => _root
      .child('hb/$uid')
      .onValue
      .map((e) => (e.snapshot.value as num?)?.toInt());

  Future<void> remove() => _root.remove();
}

/// One live fight as the screen sees it. [practice]: against a bot on this
/// phone, nothing is shared.
class ThumbLiveMatch extends ChangeNotifier {
  ThumbLiveMatch.online({
    required String gameId,
    required List<String> players,
    required String me,
  })  : _ref = ThumbLiveRef(gameId, players),
        me = players.indexOf(me),
        isHost = players.first == me,
        _bot = null;

  ThumbLiveMatch.practice()
      : _ref = null,
        me = 0,
        isHost = true,
        _bot = ThumbBot();

  final ThumbLiveRef? _ref;
  final ThumbBot? _bot;

  /// My player index.
  final int me;

  /// This phone runs the fight.
  final bool isHost;

  ThumbFight _fight = ThumbFight();
  ThumbFight get fight => _fight;

  /// Fired as things happen, on both phones.
  VoidCallback? onDown;
  void Function(bool iPinned)? onPin;
  VoidCallback? onFightCall;
  void Function(int winner)? onRoundOver;

  /// The other phone's last heartbeat is older than [goneAfter].
  bool otherGone = false;
  static const Duration goneAfter = Duration(seconds: 20);

  bool _pressed = false;
  bool _remotePressed = false;
  Timer? _loop;
  Timer? _beat;
  final Stopwatch _clock = Stopwatch();
  int _ticksDone = 0;
  int _lastShared = -100;
  final List<StreamSubscription<Object?>> _subs = [];
  DateTime _lastOtherBeat = DateTime.now();
  bool _disposed = false;

  // What was last seen, to fire the events once.
  FightState _seenState = FightState.idle;
  int _seenPins = 0;
  int _seenRounds = 0;
  bool _calledFight = false;

  bool get pressed => _pressed;

  Future<void> start() async {
    final ref = _ref;
    if (ref != null) {
      final other = ref.players[1 - me];
      if (isHost) {
        try {
          await ref.create();
        } catch (e) {
          _log('create', e);
        }
        _subs.add(
          ref.input(other).listen((v) => _remotePressed = v, onError: _ignore),
        );
      } else {
        _subs.add(ref.state().listen(_onShared, onError: _ignore));
      }
      _subs.add(
        ref.heartbeat(other).listen((_) {
          _lastOtherBeat = DateTime.now();
        }, onError: _ignore),
      );
      _beat = Timer.periodic(const Duration(seconds: 3), (_) => _sendBeat());
      _sendBeat();
    }
    if (isHost) {
      _clock.start();
      _loop = Timer.periodic(const Duration(milliseconds: 8), (_) => _run());
    }
  }

  /// My button.
  void press(bool down) {
    if (_pressed == down) return;
    _pressed = down;
    final ref = _ref;
    if (ref != null && !isHost) {
      ref.setInput(ref.players[me], down).catchError(_ignore);
    }
  }

  /// Host: catch up on the ticks that are due, share, repaint.
  void _run() {
    final due = _clock.elapsedMicroseconds * ThumbWar.ticksPerSecond ~/ 1000000;
    if (due <= _ticksDone) return;
    // After a long pause (app in background) don't fast-forward the fight.
    if (due - _ticksDone > 30) _ticksDone = due - 1;
    final before = (_fight.state, _fight.phase);
    while (_ticksDone < due) {
      _fight.input[me] = _pressed;
      final bot = _bot;
      if (bot != null) {
        bot.drive(_fight, 1 - me);
      } else {
        _fight.input[1 - me] = _remotePressed;
      }
      _fight.step();
      _ticksDone++;
    }
    final changed = before != (_fight.state, _fight.phase);
    final ref = _ref;
    if (ref != null && (changed || _ticksDone - _lastShared >= 4)) {
      _lastShared = _ticksDone;
      ref.writeState(_fight.toMap()).catchError(_ignore);
    }
    _checkGone();
    _observe();
    if (!_disposed) notifyListeners();
    if (_fight.phase == FightPhase.over) _loop?.cancel();
  }

  void _onShared(ThumbFight? f) {
    if (f == null || _disposed) return;
    _fight = f;
    _checkGone();
    _observe();
    notifyListeners();
  }

  void _checkGone() {
    if (_ref == null) return;
    otherGone = DateTime.now().difference(_lastOtherBeat) > goneAfter;
  }

  /// Fires the sound / haptic events for what changed since last time.
  void _observe() {
    final f = _fight;
    if (f.phase == FightPhase.intro && f.phaseTicks < ThumbWar.fightCallTick) {
      _calledFight = false;
    }
    if (f.phase == FightPhase.intro &&
        !_calledFight &&
        f.phaseTicks >= ThumbWar.fightCallTick) {
      _calledFight = true;
      onFightCall?.call();
    }
    if (f.pins > _seenPins) {
      final pinner = f.state.pinner;
      onPin?.call(pinner == null ? false : pinner == me);
    }
    if (f.state != _seenState && f.state.down != null && f.pins == _seenPins) {
      onDown?.call();
    }
    if (f.roundWinners.length > _seenRounds) {
      onRoundOver?.call(f.roundWinners.last);
    }
    _seenPins = f.pins;
    _seenState = f.state;
    _seenRounds = f.roundWinners.length;
  }

  void _sendBeat() {
    final ref = _ref;
    if (ref == null) return;
    ref.beat(ref.players[me]).catchError(_ignore);
  }

  /// Host, when the match is decided: the live node isn't needed any more.
  Future<void> cleanUp() async {
    final ref = _ref;
    if (ref == null || !isHost) return;
    try {
      await ref.remove();
    } catch (e) {
      _log('remove', e);
    }
  }

  static void _ignore(Object e, [StackTrace? _]) => _log('stream', e);

  static void _log(String where, Object e) {
    if (kDebugMode) debugPrint('ThumbLiveMatch.$where failed: $e');
  }

  @override
  void dispose() {
    _disposed = true;
    _loop?.cancel();
    _beat?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    final ref = _ref;
    if (ref != null && !isHost && _pressed) {
      ref.setInput(ref.players[me], false).catchError(_ignore);
    }
    super.dispose();
  }
}
