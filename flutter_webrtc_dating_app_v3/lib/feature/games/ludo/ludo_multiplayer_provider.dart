// lib/feature/games/ludo/ludo_multiplayer_provider.dart
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'constants.dart';
import 'ludo_player.dart';
import 'ludo_rules.dart';
import 'audio.dart';
import 'services/ludo_game_service.dart';
import '../game_identity.dart';

/// An opponent who backgrounded the app or lost connection.
class LudoAwayPlayer {
  final String uid;
  final String name;
  final String color;
  final int secondsLeft;
  final bool skipped;
  const LudoAwayPlayer({
    required this.uid,
    required this.name,
    required this.color,
    required this.secondsLeft,
    required this.skipped,
  });
}

class _AwayObservation {
  final Timestamp? awaySince;
  final DateTime observedAt;
  _AwayObservation(this.awaySince, this.observedAt);
}

class LudoMultiplayerProvider extends ChangeNotifier {
  final String matchId;
  final int turnDurationSeconds;

  /// Extra time other players wait before skipping a stalled turn.
  static const int turnGraceSeconds = 5;

  /// How long an opponent may be offline (killed app, lost network) while
  /// still 'active' before a peer marks them away.
  static const Duration offlineGrace = Duration(seconds: 20);

  final LudoGameService _service;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _matchSub;
  Timer? _ticker;
  bool _disposed = false;
  bool _actionsStopped = false;

  // Local User
  final String? _localUid = FirebaseAuth.instance.currentUser?.uid;
  String? _localColor;

  // Game State
  final List<LudoPlayer> players = [];
  final List<LudoPlayerType> winners = [];
  final List<String> _activeColors = [];
  final List<String> _boardColors = [];

  int _activePlayers = 2;
  int _maxPlayers = 2;
  String? _finishReason;
  String _matchState = '';

  int get activePlayers => _activePlayers;
  int get maxPlayers => _maxPlayers;
  String? get finishReason => _finishReason;

  LudoGameState _gameState = LudoGameState.throwDice;
  LudoGameState get gameState => _gameState;

  String _currentTurnColor = 'green';
  int _turnSeq = -1;
  bool _rolled = false;
  DateTime _turnObservedAt = DateTime.now();
  bool _advancing = false;
  LudoPlayerType get currentTurnType => _stringToType(_currentTurnColor);

  int _diceResult = 1;
  int get diceResult => _diceResult.clamp(1, 6);

  bool _diceStarted = false;
  bool get diceStarted => _diceStarted;

  bool _isMoving = false;

  /// Latest snapshot received while a local roll/move animation was running.
  Map<String, dynamic>? _pendingData;

  /// Latest snapshot received, used to resync after a rejected write.
  Map<String, dynamic>? _latestData;

  /// Seconds left in the current turn; listen to this instead of the
  /// provider so the board does not rebuild every second.
  final ValueNotifier<int> turnTimeLeft;

  /// Ticks once per second (for away countdowns).
  final ValueNotifier<int> secondTick = ValueNotifier<int>(0);

  bool ready = false;
  bool _matchLoaded = false;
  bool _matchMissing = false;
  bool _finishSoundPlayed = false;

  final Map<String, _AwayObservation> _awayObserved = {};
  final Set<String> _expiryRequested = {};

  final Map<String, StreamSubscription<DatabaseEvent>> _presenceSubs = {};
  final Map<String, DateTime> _offlineSince = {};
  final Set<String> _markAwayRequested = {};
  bool _reconnecting = false;

  Map<String, Map<String, dynamic>> playersInfo = {};

  LudoMultiplayerProvider({
    required this.matchId,
    this.turnDurationSeconds = 30,
    LudoGameService? service,
  })  : _service = service ?? LudoGameService(),
        turnTimeLeft = ValueNotifier<int>(turnDurationSeconds);

  // ============ GETTERS ============

  bool get matchMissing => _matchMissing;

  /// Opponents currently away, with the remaining grace time.
  List<LudoAwayPlayer> get awayOpponents {
    final now = DateTime.now();
    final graceSeconds = LudoGameService.awayGrace.inSeconds;
    final result = <LudoAwayPlayer>[];
    playersInfo.forEach((uid, info) {
      if (uid == _localUid || info['status'] != 'away') return;
      final observed = _awayObserved[uid];
      final elapsed =
          observed == null ? 0 : now.difference(observed.observedAt).inSeconds;
      result.add(LudoAwayPlayer(
        uid: uid,
        name: GameIdentity.shown(info['displayName'], 'Player'),
        color: info['color']?.toString() ?? '',
        secondsLeft: (graceSeconds - elapsed).clamp(0, graceSeconds),
        skipped: info['skipped'] == true,
      ));
    });
    return result;
  }

  bool get opponentLeft => awayOpponents.isNotEmpty;

  /// I was marked away (missed turns, or a peer saw me offline) while the
  /// game is still open on this device.
  bool get localAway =>
      _matchState == 'playing' && playersInfo[_localUid]?['status'] == 'away';

  /// Opponents who left or were dropped for being away, for the result text.
  List<String> get departedNames => [
        for (final e in playersInfo.entries)
          if (e.key != _localUid &&
              (e.value['status'] == 'left' ||
                  e.value['status'] == 'away'))
            GameIdentity.shown(e.value['displayName'], 'Player'),
      ];

  bool get _localIsParticipant {
    final status = playersInfo[_localUid]?['status'];
    return status != null && status != 'left';
  }

  bool get isLocalPlayerTurn {
    if (_localColor == null) return false;
    if (_matchState != 'playing') return false;
    if (_activeColors.length < 2) return false;
    return _localColor == _currentTurnColor && _localIsParticipant;
  }

  bool get isGameReady => _matchLoaded && playersInfo.length >= 2;

  /// Private match (from a chat invite) the other player hasn't opened yet.
  bool get waitingForJoin => _matchState == 'waiting';

  /// Private match the other player didn't open in time.
  bool get abandoned => _matchState == 'abandoned';

  bool _joinWritten = false;
  bool _starting = false;

  String? get localColor => _localColor;

  /// Colours whose pawns are drawn (everyone who has not left).
  List<String> get boardColors => List.unmodifiable(_boardColors);

  LudoPlayer get currentPlayer =>
      players.firstWhere((p) => p.type == currentTurnType,
          orElse: () => players.first);

  LudoPlayer player(LudoPlayerType type) =>
      players.firstWhere((p) => p.type == type);

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // ============ INITIALIZATION ============

  Future<void> start() async {
    _initializePlayers();

    _matchSub = _service.watchMatchDoc(matchId).listen(
      _onMatchSnapshot,
      onError: (e) => debugPrint('❌ Match listener error: $e'),
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    debugPrint('🎮 Started listening to match: $matchId');
  }

  void _initializePlayers() {
    players.clear();
    players.addAll([
      LudoPlayer(LudoPlayerType.green),
      LudoPlayer(LudoPlayerType.yellow),
      LudoPlayer(LudoPlayerType.blue),
      LudoPlayer(LudoPlayerType.red),
    ]);
  }

  /// Stops any further roll/move writes (called before an explicit Leave).
  void stopActions() {
    _actionsStopped = true;
  }

  bool get _halted => _disposed || _actionsStopped;

  // ============ FIRESTORE LISTENER ============

  void _onMatchSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (_disposed) return;
    if (!snap.exists) {
      debugPrint('❌ Match document does not exist');
      _matchMissing = true;
      ready = true;
      notifyListeners();
      return;
    }
    _matchMissing = false;
    final data = snap.data() ?? {};
    _latestData = data;

    if (_isMoving || _diceStarted) {
      _pendingData = data;
      return;
    }
    _applyData(data);
  }

  /// Applies the snapshot deferred during a local action. After a successful
  /// write, a deferred snapshot that predates it is dropped; the listener
  /// delivers the post-write state next.
  void _applyPending([bool Function(Map<String, dynamic> data)? isFresh]) {
    final data = _pendingData;
    _pendingData = null;
    if (data == null || _disposed) return;
    if (isFresh != null && !isFresh(data)) return;
    _applyData(data);
  }

  /// Drops local optimistic state and re-applies the server's latest view.
  void _resync() {
    _pendingData = null;
    final data = _latestData;
    if (data != null && !_disposed) _applyData(data);
  }

  void _applyData(Map<String, dynamic> data) {
    final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
    playersInfo.clear();
    _boardColors.clear();

    playersMap.forEach((uid, info) {
      if (info is! Map) return;
      final color = info['color']?.toString() ?? '';
      if (color.isEmpty) return;
      playersInfo[uid] = Map<String, dynamic>.from(info);
      if (info['status'] != 'left') _boardColors.add(color);
      if (uid == _localUid) _localColor = color;
    });

    _activeColors
      ..clear()
      ..addAll(LudoGameService.activeColorsOf(data));

    if (playersInfo.length >= 2) {
      _matchLoaded = true;
    }
    ready = true;

    final wasWaiting = _matchState == 'waiting';
    _matchState = data['state']?.toString() ?? '';
    if (_matchState == 'waiting') _handleWaiting(data);
    _activePlayers = (data['activePlayers'] as num?)?.toInt() ?? _activeColors.length;
    _maxPlayers = (data['maxPlayers'] as num?)?.toInt() ?? 2;
    _finishReason = data['finishReason']?.toString();
    _rolled = data['rolled'] == true;

    final dice = data['dice'];
    if (dice is num) _diceResult = dice.toInt();

    // A new turn (including bonus turns) restarts the local countdown,
    // measured from snapshot arrival so device clock skew does not matter.
    final newTurnColor = (data['turnColor'] ?? 'green').toString();
    final newSeq = LudoGameService.turnSeqOf(data);
    if (newTurnColor != _currentTurnColor ||
        newSeq != _turnSeq ||
        (wasWaiting && _matchState == 'playing')) {
      _currentTurnColor = newTurnColor;
      _turnSeq = newSeq;
      _turnObservedAt = DateTime.now();
      _advancing = false;
      turnTimeLeft.value = turnDurationSeconds;
    }

    _applyPawnSteps(Map<String, dynamic>.from(data['pawnSteps'] ?? {}));
    _applyWinners(List<String>.from(data['winners'] ?? const []));
    _trackAway();
    _syncPresenceWatches();

    if (_matchState == 'finished') {
      _gameState = LudoGameState.finish;
      _clearHighlights();
      _playFinishSound();
    } else if (isLocalPlayerTurn && _rolled) {
      _gameState = LudoGameState.pickPawn;
      _highlightLegalPawns();
    } else {
      _gameState = LudoGameState.throwDice;
      _clearHighlights();
    }

    notifyListeners();
  }

  void _applyPawnSteps(Map<String, dynamic> pawnSteps) {
    pawnSteps.forEach((colorStr, steps) {
      if (!LudoRules.colorOrder.contains(colorStr)) return;
      final parsed = LudoRules.parseSteps(steps);
      final targetPlayer = player(_stringToType(colorStr));
      for (int i = 0; i < parsed.length; i++) {
        if (targetPlayer.pawns[i].step != parsed[i]) {
          targetPlayer.movePawn(i, parsed[i]);
        }
      }
    });
  }

  void _applyWinners(List<String> winnersList) {
    winners
      ..clear()
      ..addAll(winnersList
          .where(LudoRules.colorOrder.contains)
          .map(_stringToType));
  }

  void _trackAway() {
    final now = DateTime.now();
    final awayNow = <String>{};
    playersInfo.forEach((uid, info) {
      if (info['status'] != 'away') return;
      awayNow.add(uid);
      final since = info['awaySince'] is Timestamp
          ? info['awaySince'] as Timestamp
          : null;
      final previous = _awayObserved[uid];
      if (previous == null || previous.awaySince != since) {
        _awayObserved[uid] = _AwayObservation(since, now);
      }
    });
    _awayObserved.removeWhere((uid, _) => !awayNow.contains(uid));
  }

  /// Watches RTDB presence of every opponent still in a running match.
  void _syncPresenceWatches() {
    final wanted = <String>{};
    if (_matchState == 'playing') {
      playersInfo.forEach((uid, info) {
        if (uid != _localUid && info['status'] != 'left') wanted.add(uid);
      });
    }
    for (final uid in _presenceSubs.keys.toList()) {
      if (wanted.contains(uid)) continue;
      _presenceSubs.remove(uid)?.cancel();
      _offlineSince.remove(uid);
    }
    for (final uid in wanted) {
      // Read directly instead of PresenceWatch.watchOne: only an explicit
      // 'offline' counts, a missing node is unknown, not offline.
      _presenceSubs[uid] ??= FirebaseDatabase.instance
          .ref('presence/$uid/state')
          .onValue
          .listen(
        (event) {
          if (event.snapshot.value == 'offline') {
            _offlineSince[uid] ??= DateTime.now();
          } else {
            _offlineSince.remove(uid);
          }
        },
        onError: (Object e) => debugPrint('❌ Presence($uid) error: $e'),
      );
    }
  }

  /// An opponent who vanished without writing 'away' is marked away by us;
  /// the away grace (expireAway) then forfeits or skips them.
  void _markOfflinePlayersAway() {
    if (_actionsStopped || !_localIsParticipant) return;
    final now = DateTime.now();
    _offlineSince.forEach((uid, since) {
      if (now.difference(since) < offlineGrace) return;
      if (playersInfo[uid]?['status'] != 'active') return;
      if (!_markAwayRequested.add(uid)) return;
      debugPrint('📴 $uid offline for ${offlineGrace.inSeconds}s: marking away');
      _service.markAway(matchId: matchId, odId: uid).whenComplete(() {
        Future.delayed(
          const Duration(seconds: 5),
          () => _markAwayRequested.remove(uid),
        );
      });
    });
  }

  void _playFinishSound() {
    if (_finishSoundPlayed || winners.isEmpty) return;
    _finishSoundPlayed = true;
    if (winners.first.name == _localColor) {
      Audio.playWin();
    } else {
      Audio.playLose();
    }
  }

  List<int> _legalPawnsFor(LudoPlayer p, int dice) => LudoRules.legalPawns(
        p.pawns.map((pw) => pw.step).toList(),
        dice,
        p.path.length - 1,
      );

  void _highlightLegalPawns() {
    final local = _localColor;
    if (local == null) return;
    final p = player(_stringToType(local));
    p.highlightPawns(_legalPawnsFor(p, _diceResult));
  }

  void _clearHighlights() {
    for (final p in players) {
      if (p.pawns.any((pw) => pw.highlight)) p.highlightAllPawns(false);
    }
  }

  // ============ GAME ACTIONS ============

  Future<void> throwDice() async {
    if (_halted) return;
    if (!isGameReady || !isLocalPlayerTurn) return;
    if (_gameState != LudoGameState.throwDice || _rolled) return;
    if (_diceStarted || _isMoving) return;

    final color = _localColor!;
    final seq = _turnSeq;

    _diceStarted = true;
    notifyListeners();
    Audio.rollDice();

    // Marked away while the game was open: playing again means I'm back.
    if (localAway) await reconnectLocal();

    await Future.delayed(const Duration(seconds: 1));
    if (_halted) return;

    final dice = Random().nextInt(6) + 1;
    final result = await _service.rollDice(
      matchId: matchId,
      color: color,
      expectedSeq: seq,
      dice: dice,
    );
    if (_disposed) return;

    _diceStarted = false;
    if (result == null || _actionsStopped) {
      _resync();
      notifyListeners();
      return;
    }

    _diceResult = result.dice;
    _rolled = !result.turnPassed;
    _gameState =
        result.turnPassed ? LudoGameState.throwDice : LudoGameState.pickPawn;
    if (!result.turnPassed) {
      player(_stringToType(color)).highlightPawns(result.legalPawns);
    }
    _applyPending((d) =>
        LudoGameService.turnSeqOf(d) > seq || d['rolled'] == true);
    notifyListeners();

    if (!result.turnPassed && result.legalPawns.length == 1) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (_halted) return;
      final p = player(_stringToType(color));
      final index = result.legalPawns.first;
      final to = LudoRules.targetStep(
          p.pawns[index].step, result.dice, p.path.length - 1);
      if (to != null) await move(p.type, index, to);
    }
  }

  Future<void> move(LudoPlayerType type, int pawnIndex, int toStep) async {
    if (_halted) return;
    if (!isLocalPlayerTurn || type.name != _localColor) return;
    if (_gameState != LudoGameState.pickPawn || _isMoving) return;

    final selectedPlayer = player(type);
    final fromStep = selectedPlayer.pawns[pawnIndex].step;
    final target = LudoRules.targetStep(
        fromStep, _diceResult, selectedPlayer.path.length - 1);
    if (target == null || target != toStep) {
      debugPrint('⚠️ Illegal move rejected: $fromStep -> $toStep');
      return;
    }

    final seq = _turnSeq;
    _isMoving = true;
    _gameState = LudoGameState.moving;
    selectedPlayer.highlightAllPawns(false);
    notifyListeners();

    var committed = false;
    try {
      for (int i = max(fromStep + 1, 0); i <= target; i++) {
        if (_halted) return;
        selectedPlayer.movePawn(pawnIndex, i);
        Audio.playMove();
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 150));
      }
      if (_halted) return;

      final result = await _service.commitMove(
        matchId: matchId,
        uid: _localUid ?? '',
        color: type.name,
        expectedSeq: seq,
        pawnIndex: pawnIndex,
      );
      committed = result != null;
      if (result != null && result.captured && !_disposed) {
        Audio.playKill();
      }
    } catch (e) {
      debugPrint('❌ Move error: $e');
    } finally {
      _isMoving = false;
      if (!_disposed) {
        if (committed) {
          _applyPending((d) => LudoGameService.turnSeqOf(d) > seq);
        } else {
          // Rejected (turn moved on): restore the server's pawn positions.
          _resync();
        }
        notifyListeners();
      }
    }
  }

  /// Clears my 'away' status (e.g. "I'm back" on the away banner).
  Future<void> reconnectLocal() async {
    final uid = _localUid;
    if (uid == null || _reconnecting || _halted) return;
    _reconnecting = true;
    try {
      await _service.playerReconnect(matchId: matchId, odId: uid);
    } finally {
      _reconnecting = false;
    }
  }

  /// Marks me as joined; the host starts the match once both are in.
  void _handleWaiting(Map<String, dynamic> data) {
    final uid = _localUid;
    if (uid == null) return;
    final joined = Map<String, dynamic>.from(data['joined'] ?? const {});
    if (joined[uid] != true && !_joinWritten) {
      _joinWritten = true;
      _service.markJoined(matchId, uid).catchError((Object e) {
        _joinWritten = false;
        debugPrint('❌ markJoined failed: $e');
      });
    }
    final uids = List<String>.from(data['playerUids'] ?? const []);
    if (data['host'] == uid &&
        !_starting &&
        uids.isNotEmpty &&
        uids.every((u) => joined[u] == true)) {
      _starting = true;
      _service
          .startPrivateMatch(matchId)
          .catchError((Object e) => debugPrint('❌ start failed: $e'))
          .whenComplete(() => _starting = false);
    }
  }

  // ============ TURN CLOCK / DEADLINES ============

  void _tick() {
    if (_disposed) return;
    secondTick.value++;
    if (_matchState != 'playing' || !isGameReady) return;

    final elapsed = DateTime.now().difference(_turnObservedAt).inSeconds;
    final left = turnDurationSeconds - elapsed;
    turnTimeLeft.value = left.clamp(0, turnDurationSeconds);

    if (!_actionsStopped && _localIsParticipant && !_advancing) {
      final ownTurn = isLocalPlayerTurn;
      final timedOut = ownTurn
          ? left <= 0 && !_isMoving && !_diceStarted
          : left <= -turnGraceSeconds;
      if (timedOut) _advanceStalledTurn();
    }

    _expireAwayPlayers();
    _markOfflinePlayersAway();
  }

  Future<void> _advanceStalledTurn() async {
    _advancing = true;
    debugPrint('⏰ Turn timeout: skipping $_currentTurnColor');
    final ok = await _service.advanceTurn(
      matchId: matchId,
      expectedColor: _currentTurnColor,
      expectedSeq: _turnSeq,
    );
    // On failure the turn already moved on, or retry on the next tick.
    if (!ok && !_disposed) {
      Future.delayed(const Duration(seconds: 3), () => _advancing = false);
    }
  }

  void _expireAwayPlayers() {
    if (_actionsStopped || !_localIsParticipant) return;
    final now = DateTime.now();
    _awayObserved.forEach((uid, obs) {
      if (uid == _localUid) return;
      if (playersInfo[uid]?['skipped'] == true) return;
      if (now.difference(obs.observedAt) < LudoGameService.awayGrace) return;
      final key = '$uid:${obs.awaySince?.millisecondsSinceEpoch}';
      if (!_expiryRequested.add(key)) return;
      _service.expireAway(matchId: matchId, odId: uid, awaySince: obs.awaySince);
    });
  }

  // ============ HELPERS ============

  LudoPlayerType _stringToType(String s) {
    switch (s.toLowerCase()) {
      case 'green':
        return LudoPlayerType.green;
      case 'yellow':
        return LudoPlayerType.yellow;
      case 'blue':
        return LudoPlayerType.blue;
      case 'red':
        return LudoPlayerType.red;
      default:
        return LudoPlayerType.green;
    }
  }

  // ============ CLEANUP ============

  void disposeProvider() {
    _matchSub?.cancel();
    _matchSub = null;
    _ticker?.cancel();
    _ticker = null;
    for (final sub in _presenceSubs.values) {
      sub.cancel();
    }
    _presenceSubs.clear();
    _offlineSince.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    disposeProvider();
    turnTimeLeft.dispose();
    secondTick.dispose();
    super.dispose();
  }
}
