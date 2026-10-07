import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../services/presence_watch.dart';
import '../game_identity.dart';
import 'carrom_board_view.dart';
import 'carrom_physics.dart';
import 'carrom_result_screen.dart';
import 'carrom_rules.dart';
import 'services/carrom_audio_service.dart';

/// ==================== MAIN GAME SCREEN ====================
class CarromGameScreen extends StatefulWidget {
  final String matchId;

  const CarromGameScreen({Key? key, required this.matchId}) : super(key: key);

  @override
  State<CarromGameScreen> createState() => _CarromGameScreenState();
}

class _CarromGameScreenState extends State<CarromGameScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CarromAudioService _audioService = CarromAudioService();

  static const int _turnDuration = 30;
  // Extra seconds before the waiting player may pass a silent opponent's turn.
  static const int _turnGrace = 10;
  static const int _maxMissedTurns = 3;
  // An opponent offline this long during a started match loses by forfeit.
  static const int _offlineForfeitSeconds = 20;

  DateTime? _gameStartTime;

  // Turn timer, restarted on every turn/turnSeq change.
  Timer? _turnTicker;
  DateTime? _turnStartedLocal;
  String _turnKey = '';
  String? _timedOutKey;
  int _turnTimeLeft = _turnDuration;
  bool _timeoutInFlight = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _matchSub;

  // Opponent presence (RTDB).
  StreamSubscription<bool>? _presenceSub;
  String? _presenceUid;
  bool _opponentOnline = true;
  DateTime? _offlineSince;
  Timer? _offlineTicker;
  int _offlineLeft = _offlineForfeitSeconds;
  bool _offlineClaimInFlight = false;

  Map<String, dynamic>? _matchData;
  late final CarromBoardController _board;
  String? _myUid;
  String? _opponentUid;
  String _hostUid = '';
  CarromPlayers? _players;
  String _status = 'waiting';
  String _turnUid = '';
  bool _loading = true;

  // Last applied `moveSeq` and the board at that seq; snapshots at or below
  // it are ignored, the next one is replayed from this board.
  int _appliedSeq = -1;
  CarromState _authState = CarromState.initial();
  // Newest snapshot that arrived while a shot was playing or being saved.
  Map<String, dynamic>? _queuedSnapshot;

  bool _writingShot = false;
  bool _resultShown = false;
  bool _leaving = false;
  DateTime _lastCollisionSound = DateTime.fromMillisecondsSinceEpoch(0);

  DocumentReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('carrom_matches').doc(widget.matchId);

  bool get _isMyTurn =>
      _status == 'started' && _myUid != null && _turnUid == _myUid;

  bool get _boardBusy => _writingShot || _board.busy;

  @override
  void initState() {
    super.initState();
    _myUid = _auth.currentUser?.uid;
    _board = CarromBoardController(
      canShoot: () => _isMyTurn && !_writingShot && !_resultShown,
      onShoot: _shoot,
      onEvent: _onShotEvent,
    );
    _audioService.initialize();
    _listenMatch();
  }

  @override
  void dispose() {
    _turnTicker?.cancel();
    _offlineTicker?.cancel();
    _matchSub?.cancel();
    _presenceSub?.cancel();
    // Leaving a live match any other way than the dialog still forfeits.
    if (_status == 'started' && !_resultShown && !_leaving) {
      _leaving = true;
      unawaited(_forfeit());
    }
    _board.dispose();
    super.dispose();
  }

  // ==================== FIREBASE LISTENER ====================
  void _listenMatch() {
    _matchSub = _ref.snapshots().listen(
          _onMatchSnapshot,
          onError: (Object e) => debugPrint('Carrom match listener error: $e'),
        );
  }

  void _onMatchSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    if (!snap.exists) {
      _exitToList(
        message: 'This match has ended. Find a new one from the lobby.',
      );
      return;
    }

    final data = snap.data()!;
    _matchData = data;

    final players = Map<String, dynamic>.from(data['players'] ?? {});
    _hostUid = data['host'] as String? ?? '';
    if (_myUid != null && players.isNotEmpty) {
      _opponentUid = players.keys.firstWhere(
        (k) => k != _myUid,
        orElse: () => '',
      );
      final guest = players.keys.firstWhere(
        (k) => k != _hostUid,
        orElse: () => '',
      );
      if (_hostUid.isNotEmpty && guest.isNotEmpty) {
        _players = CarromPlayers(whiteUid: _hostUid, blackUid: guest);
      }
      _board.setPerspective(isHost: _hostUid == _myUid);
      _watchOpponent();
    }

    final status = data['status'] as String? ?? 'waiting';
    final turn = data['turn'] as String? ?? '';

    setState(() {
      _status = status;
      _turnUid = turn;
      _loading = false;
    });

    if (status == 'started') _gameStartTime ??= DateTime.now();

    _syncBoard(data);

    if (status == 'started') {
      final key = '$turn:${(data['turnSeq'] as num?)?.toInt() ?? 0}';
      if (key != _turnKey) {
        _turnKey = key;
        _restartTurnTimer();
      }
      _board.setStrikerSide(hostSide: turn == _hostUid);
    } else {
      _turnTicker?.cancel();
    }
    _updateOfflineCountdown();

    if (status == 'finished') {
      // Let the final shot finish playing first.
      if (!_boardBusy) _showResult(data);
    } else if (status == 'cancelled') {
      _exitToList(
        message: 'The match was cancelled. Find a new one from the lobby.',
      );
    }
  }

  /// Snapshot-only sync: apply each new `moveSeq` once. The opponent's next
  /// shot is replayed through the same physics from the previous board; any
  /// other jump slides or snaps to the synced board.
  void _syncBoard(Map<String, dynamic> data) {
    if (_boardBusy) {
      _queuedSnapshot = data;
      return;
    }
    final seq = (data['moveSeq'] as num?)?.toInt() ?? 0;
    if (seq <= _appliedSeq) return;

    final raw = data['boardState'];
    final state = CarromState.fromMap(
      raw is Map ? Map<String, dynamic>.from(raw) : null,
    );
    final lastMove = data['lastMove'];
    final fromOpponent = lastMove is Map && lastMove['fromUid'] != _myUid;
    final next = _appliedSeq >= 0 && seq == _appliedSeq + 1 && fromOpponent;
    final previous = _authState;

    _appliedSeq = seq;
    _authState = state;

    if (!next) {
      _board.showState(state);
      return;
    }
    final move = Map<String, dynamic>.from(lastMove);
    final replay = _replayable(move, previous);
    if (replay != null) {
      _audioService.playStrike();
      _board.play(replay, onDone: () => _afterAnimation(state));
    } else {
      _board.animateTo(state, onDone: _drainQueuedSnapshot);
      _playMoveSounds(move);
    }
  }

  /// Simulates the opponent's shot locally if it was recorded with the same
  /// physics, else null.
  ShotResult? _replayable(Map<String, dynamic> move, CarromState previous) {
    if (move['type'] != 'shot') return null;
    if ((move['physicsVersion'] as num?)?.toInt() != kCarromPhysicsVersion) {
      return null;
    }
    final shot = move['shot'];
    if (shot is! Map) return null;
    double? n(String k) => (shot[k] as num?)?.toDouble();
    final sx = n('sx'), sy = n('sy'), vx = n('vx'), vy = n('vy');
    if (sx == null || sy == null || vx == null || vy == null) return null;
    final result = simulateShot(
      previous.coins,
      CarromPos(sx, sy),
      CarromPos(vx, vy),
    );
    if (result.hash != move['hash']) {
      debugPrint('Carrom replay hash mismatch: ${result.hash} vs '
          '${move['hash']} (snapping to the synced board)');
    }
    return result;
  }

  void _afterAnimation(CarromState state) {
    if (!mounted) return;
    _board.showState(state, effects: true);
    _drainQueuedSnapshot();
  }

  void _drainQueuedSnapshot() {
    final q = _queuedSnapshot;
    _queuedSnapshot = null;
    if (!mounted) return;
    _board.setStrikerSide(hostSide: _turnUid == _hostUid);
    if (q != null) _syncBoard(q);
    final data = _matchData;
    if (!_boardBusy && _status == 'finished' && data != null) {
      _showResult(data);
    }
  }

  void _playMoveSounds(Map<String, dynamic> lastMove) {
    if (lastMove['type'] == 'timeout') return;
    _audioService.playStrike();
    final pocketed = List<String>.from(lastMove['pocketed'] ?? const []);
    for (int i = 0; i < pocketed.length; i++) {
      Future.delayed(Duration(milliseconds: 200 + i * 150), () {
        _audioService.playPocket();
      });
    }
    if ((lastMove['fouls'] as List?)?.isNotEmpty ?? false) {
      _audioService.playFoul();
    }
  }

  void _onShotEvent(ShotEvent e) {
    switch (e.type) {
      case ShotEventType.pocket:
        _audioService.playPocket();
      case ShotEventType.collision:
      case ShotEventType.rail:
        if (e.speed < 40) return;
        final now = DateTime.now();
        if (now.difference(_lastCollisionSound).inMilliseconds < 70) return;
        _lastCollisionSound = now;
        _audioService.playCollision();
    }
  }

  // ==================== PRESENCE ====================
  void _watchOpponent() {
    final uid = _opponentUid;
    if (uid == null || uid.isEmpty || uid == _presenceUid) return;
    _presenceUid = uid;
    _presenceSub?.cancel();
    // Only an explicit 'offline' counts: a never-written presence node must
    // not make a live opponent forfeit.
    _presenceSub = PresenceWatch.instance.watchGone(uid).listen(
      (gone) {
        if (!mounted) return;
        _opponentOnline = !gone;
        _updateOfflineCountdown();
      },
      onError: (Object e) => debugPrint('Carrom presence error: $e'),
    );
  }

  void _updateOfflineCountdown() {
    final counting = !_opponentOnline && _status == 'started' && !_resultShown;
    if (!counting) {
      if (_offlineSince != null) {
        _offlineTicker?.cancel();
        _offlineTicker = null;
        setState(() {
          _offlineSince = null;
          _offlineLeft = _offlineForfeitSeconds;
        });
      }
      return;
    }
    if (_offlineSince != null) return;
    _offlineSince = DateTime.now();
    _offlineTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _onOfflineTick(),
    );
    setState(() => _offlineLeft = _offlineForfeitSeconds);
  }

  void _onOfflineTick() {
    final since = _offlineSince;
    if (!mounted || since == null) return;
    final left = max(
      0,
      _offlineForfeitSeconds - DateTime.now().difference(since).inSeconds,
    );
    setState(() => _offlineLeft = left);
    if (left == 0) _claimOpponentLeft();
  }

  /// The opponent stayed offline: they forfeit and this player wins.
  Future<void> _claimOpponentLeft() async {
    final me = _myUid;
    final other = _opponentUid;
    if (_offlineClaimInFlight || me == null || other == null || other.isEmpty) {
      return;
    }
    _offlineClaimInFlight = true;
    try {
      await _firestore.runTransaction((tx) async {
        final d = (await tx.get(_ref)).data();
        if (d == null || d['status'] != 'started') return;
        tx.update(_ref, {
          'status': 'finished',
          'winnerUid': me,
          'finishReason': 'forfeit',
          'forfeitedBy': other,
          'finishedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('Carrom offline forfeit failed: $e');
    } finally {
      _offlineClaimInFlight = false;
    }
  }

  // ==================== TURN TIMER ====================
  void _restartTurnTimer() {
    _turnTicker?.cancel();
    _turnStartedLocal = DateTime.now();
    _turnTimeLeft = _turnDuration;
    _turnTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _onTurnTick(),
    );
  }

  void _onTurnTick() {
    if (!mounted || _status != 'started' || _turnStartedLocal == null) return;
    final elapsed = DateTime.now().difference(_turnStartedLocal!).inSeconds;
    setState(() => _turnTimeLeft = max(0, _turnDuration - elapsed));

    if (_boardBusy) return;
    final limit =
        _turnUid == _myUid ? _turnDuration : _turnDuration + _turnGrace;
    if (elapsed >= limit) _passTurnOnTimeout();
  }

  /// Either player may pass an expired turn; the transaction only succeeds if
  /// the turn has not moved on in the meantime.
  Future<void> _passTurnOnTimeout() async {
    final players = _players;
    if (_timeoutInFlight || players == null || _timedOutKey == _turnKey) {
      return;
    }
    _timeoutInFlight = true;
    final expectedKey = _turnKey;
    _timedOutKey = expectedKey;
    var passed = false;

    try {
      await _firestore.runTransaction((tx) async {
        final d = (await tx.get(_ref)).data();
        if (d == null || d['status'] != 'started') return;
        final holder = d['turn'] as String? ?? '';
        final turnSeq = (d['turnSeq'] as num?)?.toInt() ?? 0;
        if ('$holder:$turnSeq' != expectedKey) return;

        final moveSeq = (d['moveSeq'] as num?)?.toInt() ?? 0;
        final raw = d['boardState'];
        final state = resolveTimeout(
          CarromState.fromMap(
            raw is Map ? Map<String, dynamic>.from(raw) : null,
          ),
          holder,
        );
        final timeouts = Map<String, dynamic>.from(d['timeouts'] ?? {});
        final missed = ((timeouts[holder] as num?)?.toInt() ?? 0) + 1;
        final other = players.other(holder);

        final update = <String, dynamic>{
          'boardState': state.toMap(),
          'scores': players.scores(state),
          'moveSeq': moveSeq + 1,
          'lastMove': {
            'fromUid': holder,
            'type': 'timeout',
            'seq': moveSeq + 1,
            'pocketed': <String>[],
            'fouls': <String>[],
            'ts': FieldValue.serverTimestamp(),
          },
          'turn': other,
          'turnSeq': turnSeq + 1,
          'turnStartedAt': FieldValue.serverTimestamp(),
          'timeouts.$holder': missed,
        };
        if (missed >= _maxMissedTurns) {
          update.addAll({
            'status': 'finished',
            'winnerUid': other,
            'finishReason': 'timeout',
            'finishedAt': FieldValue.serverTimestamp(),
          });
        }
        tx.update(_ref, update);
        passed = true;
      });
    } catch (e) {
      debugPrint('Carrom turn timeout failed: $e');
    } finally {
      _timeoutInFlight = false;
    }

    if (passed && mounted && expectedKey.startsWith('$_myUid:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Time's up, so your turn passed."),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ==================== SHOTS ====================
  /// Simulates the shot at once, plays it back and saves it in parallel; the
  /// board settles on the saved outcome when both are done.
  void _shoot(CarromPos strikerPos, CarromPos velocity) {
    final myUid = _myUid;
    final players = _players;
    if (myUid == null || players == null || !_isMyTurn || _boardBusy) return;

    final vel = clampStrikerVelocity(velocity);
    final result = simulateShot(_authState.coins, strikerPos, vel);
    final baseSeq = _appliedSeq;
    _writingShot = true;

    var played = false;
    var saved = false;
    ShotOutcome? outcome;
    var newSeq = baseSeq;

    void finish() {
      if (!played || !saved || !mounted) return;
      _settleOwnShot(outcome, newSeq);
    }

    _audioService.playStrike();
    Haptics.medium();
    _board.play(result, onDone: () {
      played = true;
      finish();
    });

    _saveShot(myUid, players, baseSeq, strikerPos, vel, result).then((r) {
      outcome = r?.$1;
      newSeq = r?.$2 ?? baseSeq;
      saved = true;
      _writingShot = false;
      finish();
    });
  }

  Future<(ShotOutcome, int)?> _saveShot(
    String myUid,
    CarromPlayers players,
    int baseSeq,
    CarromPos strikerPos,
    CarromPos vel,
    ShotResult result,
  ) async {
    (ShotOutcome, int)? saved;
    try {
      await _firestore.runTransaction((tx) async {
        final d = (await tx.get(_ref)).data();
        if (d == null) throw StateError('match missing');
        final seq = (d['moveSeq'] as num?)?.toInt() ?? 0;
        if (d['status'] != 'started' || d['turn'] != myUid || seq != baseSeq) {
          throw StateError('stale shot');
        }

        final raw = d['boardState'];
        final before = CarromState.fromMap(
          raw is Map ? Map<String, dynamic>.from(raw) : null,
        );
        final o = resolveShot(
          before: before,
          coinsAfter: result.coins,
          pocketed: result.pocketed,
          strikerPocketed: result.strikerPocketed,
          shooterUid: myUid,
          players: players,
        );
        final turnSeq = (d['turnSeq'] as num?)?.toInt() ?? 0;

        final update = <String, dynamic>{
          'boardState': o.state.toMap(),
          'scores': o.scores,
          'moveSeq': seq + 1,
          'lastMove': {
            'fromUid': myUid,
            'type': 'shot',
            'seq': seq + 1,
            'shot': {
              'sx': strikerPos.x,
              'sy': strikerPos.y,
              'vx': vel.x,
              'vy': vel.y,
            },
            'physicsVersion': kCarromPhysicsVersion,
            'hash': result.hash,
            'pocketed': result.pocketed,
            'fouls': o.fouls,
            'returned': o.returnedToCentre,
            'ts': FieldValue.serverTimestamp(),
          },
          'turn': o.keepsTurn ? myUid : players.other(myUid),
          'turnSeq': turnSeq + 1,
          'turnStartedAt': FieldValue.serverTimestamp(),
          'timeouts.$myUid': 0,
        };
        if (o.winnerUid != null) {
          update.addAll({
            'status': 'finished',
            'winnerUid': o.winnerUid,
            'finishReason': 'cleared',
            'finishedAt': FieldValue.serverTimestamp(),
          });
        }
        tx.update(_ref, update);
        saved = (o, seq + 1);
      });
    } catch (e) {
      debugPrint('Carrom shot not saved: $e');
      saved = null;
    }
    return saved;
  }

  void _settleOwnShot(ShotOutcome? o, int newSeq) {
    if (o != null) {
      _appliedSeq = newSeq;
      _authState = o.state;
      _board.showState(o.state, effects: true);
      if (o.foul) {
        _audioService.playFoul();
        Haptics.warning();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_foulMessage(o.fouls)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _drainQueuedSnapshot();
    } else {
      // Rejected (turn moved on or offline): fall back to the shared board.
      _appliedSeq = -1;
      _queuedSnapshot = null;
      final data = _matchData;
      if (data != null) _syncBoard(data);
      _board.setStrikerSide(hostSide: _turnUid == _hostUid);
    }
  }

  String _foulMessage(List<String> fouls) {
    if (fouls.contains(kFoulStriker)) {
      return 'Foul: you pocketed the striker. Your coins from this shot '
          'and a penalty coin go back.';
    }
    if (fouls.contains(kFoulOpponentLast)) {
      return "Foul: you can't pocket your opponent's last coin. "
          'It goes back with a penalty coin.';
    }
    return 'Foul: cover the Queen before your last coin. '
        'It goes back with a penalty coin.';
  }

  // ==================== RESULT / LEAVE ====================
  void _showResult(Map<String, dynamic> data) {
    if (_resultShown || !mounted) return;
    _resultShown = true;
    _turnTicker?.cancel();
    _offlineTicker?.cancel();

    final scores = Map<String, dynamic>.from(data['scores'] ?? {});
    int scoreOf(String? uid) => (scores[uid] as num?)?.toInt() ?? 0;

    int? gameDuration;
    if (_gameStartTime != null) {
      gameDuration = DateTime.now().difference(_gameStartTime!).inSeconds;
    }

    String opponentName = 'Opponent';
    final players = Map<String, dynamic>.from(data['players'] ?? {});
    final userData = players[_opponentUid];
    if (userData is Map) {
      opponentName = GameIdentity.shown(userData['displayName'], opponentName);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CarromResultScreen(
          matchId: widget.matchId,
          myScore: scoreOf(_myUid),
          opponentScore: scoreOf(_opponentUid),
          opponentUid: _opponentUid ?? '',
          opponentName: opponentName,
          gameDurationSeconds: gameDuration,
          winnerUid: data['winnerUid'] as String?,
          finishReason: data['finishReason'] as String?,
        ),
      ),
    );
  }

  void _exitToList({String? message}) {
    if (_leaving || _resultShown || !mounted) return;
    _leaving = true;
    _turnTicker?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmLeave() async {
    if (_status != 'started' || _resultShown) {
      _exitToList();
      return;
    }
    Haptics.warning();
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave game?'),
        content: const Text(
          'If you leave, you forfeit and your opponent wins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) await _forfeit();
  }

  Future<void> _forfeit() async {
    final me = _myUid;
    if (me == null) return;
    try {
      await _firestore.runTransaction((tx) async {
        final d = (await tx.get(_ref)).data();
        if (d == null || d['status'] != 'started') return;
        tx.update(_ref, {
          'status': 'finished',
          'winnerUid': _players?.other(me) ?? _opponentUid,
          'finishReason': 'forfeit',
          'forfeitedBy': me,
          'finishedAt': FieldValue.serverTimestamp(),
        });
      });
      // The listener sees 'finished' and opens the result screen.
    } catch (e) {
      debugPrint('Carrom forfeit failed: $e');
      _exitToList(
        message: "Couldn't reach the server, so you've left the match.",
      );
    }
  }

  // ==================== UI BUILDER ====================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.brandPurpleLight))
            : SafeArea(
                child: Column(
                  children: [
                    // 1. Custom Game AppBar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceRaised,
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Leave game',
                            icon: const Icon(Icons.arrow_back,
                                color: AppColors.white),
                            onPressed: _confirmLeave,
                          ),
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: const Text(
                                'Carrom',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: _audioService.isMuted ? 'Unmute' : 'Mute',
                            icon: Icon(
                              _audioService.isMuted
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              color: AppColors.brandPurpleLight,
                            ),
                            onPressed: () =>
                                setState(() => _audioService.toggleMute()),
                          ),
                        ],
                      ),
                    ),

                    // 2. HUD (Score Board)
                    _buildHUD(),
                    if (_offlineSince != null) _buildOfflineBanner(),

                    // 3. THE BOARD: square sized by the shorter side.
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final side = min(
                            432.0,
                            min(constraints.maxWidth, constraints.maxHeight),
                          );
                          return Center(
                            child: SizedBox(
                              width: side,
                              height: side,
                              child: Container(
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.black.withOpacity(0.6),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: CarromBoardView(controller: _board),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // 4. Bottom Status Bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.touch_app,
                              color: AppColors.lavender, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: ValueListenableBuilder<double?>(
                              valueListenable: _board.aimPower,
                              builder: (context, power, _) => Semantics(
                                liveRegion: power == null,
                                child: Text(
                                  _statusText(power),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String _statusText(double? power) {
    if (_status != 'started') return 'Waiting for the game to start…';
    if (power != null) {
      return 'Power ${(power * 100).round()}%: release to shoot, '
          'or drag back to the striker to cancel.';
    }
    if (!_isMyTurn) return "Waiting for your opponent's shot…";
    if (_authState.queenPendingBy == _myUid) {
      return 'Cover the Queen: pocket one of your coins.';
    }
    return 'Your turn: slide the striker along your line, then pull back '
        'from it to aim and release to shoot.';
  }

  Widget _buildOfflineBanner() {
    final secs = _offlineLeft.toString().padLeft(2, '0');
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppColors.error.withValues(alpha: 0.16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Opponent went offline… you win in 0:$secs',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD() {
    final players = Map<String, dynamic>.from(_matchData?['players'] ?? {});
    final scores = Map<String, dynamic>.from(_matchData?['scores'] ?? {});

    String getSafeName(String? uid, String defaultName) {
      if (uid == null) return defaultName;
      final userData = players[uid];
      if (userData != null && userData is Map) {
        return GameIdentity.shown(userData['displayName'], defaultName);
      }
      return defaultName;
    }

    final myName = getSafeName(_myUid, 'You');
    final opName = getSafeName(
      _opponentUid,
      _status == 'waiting' ? 'Waiting…' : 'Opponent',
    );

    final myScore = (scores[_myUid] as num?)?.toInt() ?? 0;
    final opScore = (scores[_opponentUid] as num?)?.toInt() ?? 0;
    final isMyTurn = _isMyTurn;
    final iAmWhite = _hostUid == _myUid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: _buildPlayerInfo(myName, myScore, isMyTurn, true, iAmWhite),
          ),
          const SizedBox(width: 8),

          // Timer / Turn Indicator
          AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isMyTurn
                  ? AppColors.success.withOpacity(0.16)
                  : AppColors.surface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isMyTurn ? AppColors.success : AppColors.borderStrong),
            ),
            child: Semantics(
              label: isMyTurn ? 'Your turn' : "Opponent's turn",
              value:
                  _status == 'started' ? '$_turnTimeLeft seconds left' : null,
              excludeSemantics: true,
              child: Column(
                children: [
                  Text(
                    isMyTurn ? 'Your turn' : 'Opponent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isMyTurn ? AppColors.success : AppColors.lavender,
                    ),
                  ),
                  if (_status == 'started')
                    Text(
                      '$_turnTimeLeft s',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _turnTimeLeft < 10
                            ? AppColors.error
                            : AppColors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),
          Flexible(
            child:
                _buildPlayerInfo(opName, opScore, !isMyTurn, false, !iAmWhite),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerInfo(
    String name,
    int score,
    bool isActive,
    bool isMe,
    bool isWhite,
  ) {
    final colourDot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Coin colour of this player (game semantics).
        color: isWhite ? Colors.white : const Color(0xFF212121),
        border: Border.all(color: AppColors.borderStrong, width: 1),
      ),
    );
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMe) ...[colourDot, const SizedBox(width: 6)],
            Flexible(
              child: Text(
                name.length > 10 ? '${name.substring(0, 8)}..' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? AppColors.pinkLight : AppColors.lavender,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            if (!isMe) ...[const SizedBox(width: 6), colourDot],
          ],
        ),
        const SizedBox(height: 4),
        _ScorePop(score: score),
      ],
    );
  }
}

/// HUD score that briefly pops when it changes.
class _ScorePop extends StatefulWidget {
  const _ScorePop({required this.score});

  final int score;

  @override
  State<_ScorePop> createState() => _ScorePopState();
}

class _ScorePopState extends State<_ScorePop> {
  bool _up = false;

  @override
  void didUpdateWidget(_ScorePop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) _up = true;
  }

  @override
  Widget build(BuildContext context) {
    final up = _up && !MediaQuery.disableAnimationsOf(context);
    return AnimatedScale(
      scale: up ? 1.25 : 1.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      onEnd: () {
        if (_up && mounted) setState(() => _up = false);
      },
      child: Text(
        '${widget.score} pts',
        style: TextStyle(
          color: up ? AppColors.pinkLight : AppColors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
