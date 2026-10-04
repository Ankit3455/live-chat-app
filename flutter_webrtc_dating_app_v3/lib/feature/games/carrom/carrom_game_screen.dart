import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flame/components.dart' hide Timer;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
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

  DateTime? _gameStartTime;

  // Turn timer, restarted on every turn/turnSeq change.
  Timer? _turnTicker;
  DateTime? _turnStartedLocal;
  String _turnKey = '';
  String? _timedOutKey;
  int _turnTimeLeft = _turnDuration;
  bool _timeoutInFlight = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _matchSub;

  Map<String, dynamic>? _matchData;
  late final CarromBoardGame _game;
  String? _myUid;
  String? _opponentUid;
  String _hostUid = '';
  CarromPlayers? _players;
  String _status = 'waiting';
  String _turnUid = '';
  bool _loading = true;

  // Last applied `moveSeq`; snapshots at or below it are ignored.
  int _appliedSeq = -1;
  bool _writingShot = false;
  bool _resultShown = false;
  bool _leaving = false;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('carrom_matches').doc(widget.matchId);

  bool get _isMyTurn =>
      _status == 'started' && _myUid != null && _turnUid == _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = _auth.currentUser?.uid;
    _game = CarromBoardGame(
      audioService: _audioService,
      canShoot: () => _isMyTurn && !_writingShot && !_resultShown,
      onShotComplete: _onShotComplete,
    );
    _audioService.initialize();
    _listenMatch();
  }

  @override
  void dispose() {
    _turnTicker?.cancel();
    _matchSub?.cancel();
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
      _exitToList(message: 'Match no longer exists');
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
      _game.setPerspective(isHost: _hostUid == _myUid);
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
      _game.setStrikerSide(hostSide: turn == _hostUid);
    } else {
      _turnTicker?.cancel();
    }

    if (status == 'finished') {
      _showResult(data);
    } else if (status == 'cancelled') {
      _exitToList(message: 'Match was cancelled');
    }
  }

  /// Snapshot-only sync: apply each new `moveSeq` once, animating the
  /// opponent's move. Never runs while this device is resolving its own shot.
  void _syncBoard(Map<String, dynamic> data) {
    if (_writingShot || _game.shotInProgress) return;
    final seq = (data['moveSeq'] as num?)?.toInt() ?? 0;
    if (seq <= _appliedSeq) return;

    final raw = data['boardState'];
    final state = CarromState.fromMap(
      raw is Map ? Map<String, dynamic>.from(raw) : null,
    );
    final lastMove = data['lastMove'];
    final fromOpponent = lastMove is Map && lastMove['fromUid'] != _myUid;
    final animate = _appliedSeq >= 0 && seq == _appliedSeq + 1 && fromOpponent;

    _appliedSeq = seq;
    _game.applyState(state, animate: animate);
    if (animate) _playMoveSounds(Map<String, dynamic>.from(lastMove));
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

    if (_game.shotInProgress || _writingShot || _game.isAnimating) return;
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
          content: Text("Time's up! Turn passed."),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ==================== SHOTS ====================
  Future<void> _onShotComplete(LocalShot shot) async {
    final myUid = _myUid;
    final players = _players;
    if (myUid == null || players == null) return;

    _writingShot = true;
    final baseSeq = _appliedSeq;
    ShotOutcome? outcome;
    var newSeq = baseSeq;

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
          coinsAfter: shot.coinsAfter,
          pocketed: shot.pocketed,
          strikerPocketed: shot.strikerPocketed,
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
            'shot': shot.shotData,
            'pocketed': shot.pocketed,
            'fouls': shot.strikerPocketed ? ['striker_pocketed'] : <String>[],
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
        outcome = o;
        newSeq = seq + 1;
      });
    } catch (e) {
      debugPrint('Carrom shot not saved: $e');
      outcome = null;
    }

    _writingShot = false;
    if (!mounted) return;

    final o = outcome;
    if (o != null) {
      _appliedSeq = newSeq;
      _game.applyState(o.state, animate: false);
      if (o.foul) {
        _audioService.playFoul();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foul! Striker pocketed (-1)'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Rejected (turn moved on or offline): fall back to the shared board.
      _appliedSeq = -1;
      final data = _matchData;
      if (data != null) _syncBoard(data);
    }
    _game.setStrikerSide(hostSide: _turnUid == _hostUid);
  }

  // ==================== RESULT / LEAVE ====================
  void _showResult(Map<String, dynamic> data) {
    if (_resultShown || !mounted) return;
    _resultShown = true;
    _turnTicker?.cancel();

    final scores = Map<String, dynamic>.from(data['scores'] ?? {});
    int scoreOf(String? uid) => (scores[uid] as num?)?.toInt() ?? 0;

    int? gameDuration;
    if (_gameStartTime != null) {
      gameDuration = DateTime.now().difference(_gameStartTime!).inSeconds;
    }

    String opponentName = 'Opponent';
    final players = Map<String, dynamic>.from(data['players'] ?? {});
    final userData = players[_opponentUid];
    if (userData is Map && userData['displayName'] != null) {
      opponentName = userData['displayName'].toString();
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
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave match?'),
        content: const Text(
          'Leaving now counts as a forfeit and your opponent wins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Forfeit'),
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
      _exitToList(message: 'Could not reach the server. Left the match.');
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
                                  child: GameWidget(game: _game),
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
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                _statusText(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
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

  String _statusText() {
    if (_status != 'started') return 'Waiting for game to start...';
    if (!_isMyTurn) return 'Opponent is thinking...';
    final board = _matchData?['boardState'];
    if (board is Map && board['queenPendingBy'] == _myUid) {
      return 'Cover the Queen: pocket one of your coins!';
    }
    return 'YOUR TURN - slide the striker, flick forward to shoot';
  }

  Widget _buildHUD() {
    final players = Map<String, dynamic>.from(_matchData?['players'] ?? {});
    final scores = Map<String, dynamic>.from(_matchData?['scores'] ?? {});

    String getSafeName(String? uid, String defaultName) {
      if (uid == null) return defaultName;
      final userData = players[uid];
      if (userData != null && userData is Map) {
        return userData['displayName']?.toString() ?? defaultName;
      }
      return defaultName;
    }

    final myName = getSafeName(_myUid, 'You');
    final opName = getSafeName(
      _opponentUid,
      _status == 'waiting' ? 'Waiting...' : 'Opponent',
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
          Container(
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
              label: isMyTurn ? 'Your turn' : 'Opponent\'s turn',
              value: _status == 'started'
                  ? '$_turnTimeLeft seconds left'
                  : null,
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
            child: _buildPlayerInfo(
                opName, opScore, !isMyTurn, false, !iAmWhite),
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
        Text(
          '$score pts',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Result of one local shot once every body has stopped.
class LocalShot {
  final Map<String, CarromPos> coinsAfter;
  final List<String> pocketed;
  final bool strikerPocketed;
  final Map<String, double> shotData;

  const LocalShot({
    required this.coinsAfter,
    required this.pocketed,
    required this.strikerPocketed,
    required this.shotData,
  });
}

/// ==================== CARROM BOARD GAME LOGIC ====================
/// Physics runs in fixed logical units ([kBoardSize]) and the camera scales
/// them to the widget, so synced positions match on every screen size.
class CarromBoardGame extends Forge2DGame {
  CarromBoardGame({
    required this.canShoot,
    required this.onShotComplete,
    this.audioService,
  }) : super(gravity: Vector2.zero());

  final bool Function() canShoot;
  final Future<void> Function(LocalShot shot) onShotComplete;
  final CarromAudioService? audioService;

  static const double _restSpeed = 0.15;
  static const double _maxShotSpeed = 60.0;
  static const double _minFlickSpeed = 4.0;
  static const double _maxShotSeconds = 10.0;
  static const double _animSeconds = 0.6;

  final Map<String, Coin> coins = {};
  Striker? striker;
  _InputLayer? _input;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  // Guest sees the board rotated so their own baseline is at the bottom.
  bool _flipped = false;
  bool _strikerHostSide = true;
  CarromState? _pendingState;

  bool _placing = false;

  bool _shotInProgress = false;
  bool get shotInProgress => _shotInProgress;
  double _shotTime = 0;
  final List<String> _shotPocketed = [];
  bool _strikerPocketed = false;
  Map<String, double> _shotData = const {};

  double _animT = -1;
  final Map<String, Vector2> _animFrom = {};
  final Map<String, Vector2> _animTo = {};
  CarromState? _animTarget;
  bool get isAnimating => _animTarget != null;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2.all(kBoardSize / 2);
    _applyCamera(size);

    await world.add(CarromBoard());
    await _addWalls();

    striker = Striker(
      initialPosition:
          Vector2(kBoardSize / 2, baselineY(hostSide: _strikerHostSide)),
    );
    await world.add(striker!);

    _input = _InputLayer(this);
    await add(_input!);

    _setExact(_pendingState ?? CarromState.initial());
    _pendingState = null;
    _loaded = true;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _applyCamera(size);
  }

  void _applyCamera(Vector2 canvas) {
    if (canvas.x <= 0 || canvas.y <= 0) return;
    camera.viewfinder.zoom = min(canvas.x, canvas.y) / kBoardSize;
    camera.viewfinder.angle = _flipped ? pi : 0;
  }

  void setPerspective({required bool isHost}) {
    if (_flipped == !isHost) return;
    _flipped = !isHost;
    _applyCamera(size);
  }

  Vector2 _canvasToWorld(Vector2 p) {
    final d = (p - size / 2) / camera.viewfinder.zoom;
    return Vector2.all(kBoardSize / 2) + (_flipped ? -d : d);
  }

  Vector2 _canvasVelocityToWorld(Vector2 v) {
    final w = v / camera.viewfinder.zoom;
    return _flipped ? -w : w;
  }

  Future<void> _addWalls() async {
    const t = 1.0;
    const inner = kBoardSize - 2 * kBoardMargin;
    const mid = kBoardSize / 2;
    await world.addAll([
      Wall(
        wallSize: Vector2(inner + 2 * t, t),
        initialPosition: Vector2(mid, kBoardMargin - t / 2),
      ),
      Wall(
        wallSize: Vector2(inner + 2 * t, t),
        initialPosition: Vector2(mid, kBoardSize - kBoardMargin + t / 2),
      ),
      Wall(
        wallSize: Vector2(t, inner + 2 * t),
        initialPosition: Vector2(kBoardMargin - t / 2, mid),
      ),
      Wall(
        wallSize: Vector2(t, inner + 2 * t),
        initialPosition: Vector2(kBoardSize - kBoardMargin + t / 2, mid),
      ),
    ]);
  }

  static Color _colorFor(String id) {
    if (id == kQueenId) return Colors.red;
    return colourOfCoin(id) == kWhite ? Colors.white : const Color(0xFF212121);
  }

  // ==================== SYNC ====================
  void applyState(CarromState state, {required bool animate}) {
    if (!_loaded) {
      _pendingState = state;
      return;
    }
    _finishAnimation();
    if (!animate) {
      _setExact(state);
      return;
    }
    _animFrom.clear();
    _animTo.clear();
    coins.forEach((id, coin) {
      final from = coin.currentPosition;
      final target = state.coins[id];
      _animFrom[id] = from;
      _animTo[id] =
          target != null ? Vector2(target.x, target.y) : _nearestPocket(from);
    });
    _animTarget = state;
    _animT = 0;
  }

  void _setExact(CarromState state, {bool withEffects = false}) {
    for (final id in coins.keys.toList()) {
      if (!state.coins.containsKey(id)) {
        final coin = coins.remove(id)!;
        if (withEffects) {
          world.add(PocketEffect(effectPosition: coin.currentPosition));
        }
        coin.removeFromParent();
      }
    }
    state.coins.forEach((id, p) {
      final pos = Vector2(p.x, p.y);
      final existing = coins[id];
      if (existing != null) {
        existing.moveTo(pos);
      } else {
        final coin = Coin(
          id: id,
          initialPosition: pos,
          radius: radiusOfCoin(id),
          color: _colorFor(id),
        );
        coins[id] = coin;
        world.add(coin);
      }
    });
  }

  void _finishAnimation() {
    final target = _animTarget;
    if (target == null) return;
    _animTarget = null;
    _animT = -1;
    _setExact(target, withEffects: true);
    _resetStriker();
  }

  Vector2 _nearestPocket(Vector2 from) {
    var best = kPockets.first;
    for (final p in kPockets) {
      if (CarromPos(from.x, from.y).distanceTo(p) <
          CarromPos(from.x, from.y).distanceTo(best)) {
        best = p;
      }
    }
    return Vector2(best.x, best.y);
  }

  // ==================== STRIKER ====================
  void setStrikerSide({required bool hostSide}) {
    if (_strikerHostSide == hostSide) return;
    _strikerHostSide = hostSide;
    if (!_shotInProgress) _resetStriker();
  }

  bool _strikerSpotFree(Vector2 p) => coins.entries.every(
        (e) =>
            e.value.currentPosition.distanceTo(p) >=
            kStrikerRadius + radiusOfCoin(e.key),
      );

  void _resetStriker() {
    final s = striker;
    if (s == null) return;
    final y = baselineY(hostSide: _strikerHostSide);
    const mid = kBoardSize / 2;
    for (double off = 0; off <= kBaselineMaxX - mid; off += 0.5) {
      for (final x in [mid + off, mid - off]) {
        final p = Vector2(x, y);
        if (_strikerSpotFree(p)) {
          s.moveTo(p);
          return;
        }
      }
    }
    s.moveTo(Vector2(mid, y));
  }

  void handleDragStart(Vector2 canvasPos) {
    _placing = false;
    final s = striker;
    if (s == null || !s.isBodyCreated) return;
    if (_shotInProgress || isAnimating || !canShoot()) return;
    final w = _canvasToWorld(canvasPos);
    if (w.distanceTo(s.body.position) <= kStrikerRadius * 2.5) {
      _placing = true;
    }
  }

  /// Striker only slides along the current player's baseline.
  void handleDragUpdate(Vector2 canvasPos) {
    if (!_placing) return;
    if (!canShoot()) {
      _placing = false;
      return;
    }
    final w = _canvasToWorld(canvasPos);
    final target = Vector2(
      w.x.clamp(kBaselineMinX, kBaselineMaxX).toDouble(),
      baselineY(hostSide: _strikerHostSide),
    );
    if (_strikerSpotFree(target)) striker!.moveTo(target);
  }

  /// A forward flick on release shoots; a sideways release only places.
  void handleDragEnd(Vector2 canvasVelocity) {
    if (!_placing) return;
    _placing = false;
    if (!canShoot() || _shotInProgress || isAnimating) return;
    final v = _canvasVelocityToWorld(canvasVelocity);
    final forward = _strikerHostSide ? -v.y : v.y;
    if (forward < _minFlickSpeed) return;
    if (v.length > _maxShotSpeed) {
      v
        ..normalize()
        ..scale(_maxShotSpeed);
    }
    _startShot(v);
  }

  void handleDragCancel() => _placing = false;

  void _startShot(Vector2 velocity) {
    final s = striker!;
    _shotPocketed.clear();
    _strikerPocketed = false;
    _shotTime = 0;
    _shotData = {
      'sx': s.body.position.x,
      'sy': s.body.position.y,
      'vx': velocity.x,
      'vy': velocity.y,
    };
    s.body.setAwake(true);
    s.body.linearVelocity = velocity;
    _shotInProgress = true;
    audioService?.playStrike();
  }

  // ==================== LOOP ====================
  @override
  void update(double dt) {
    super.update(dt);
    if (!_loaded) return;
    if (isAnimating) {
      _stepAnimation(dt);
    } else if (_shotInProgress) {
      _stepShot(dt);
    }
  }

  void _stepAnimation(double dt) {
    _animT += dt / _animSeconds;
    if (_animT >= 1) {
      _finishAnimation();
      return;
    }
    final t = Curves.easeOut.transform(_animT);
    _animFrom.forEach((id, from) {
      final to = _animTo[id]!;
      coins[id]?.moveTo(from + (to - from) * t);
    });
  }

  bool _inPocket(Vector2 p, double radius) => kPockets
      .any((pocket) => CarromPos(p.x, p.y).distanceTo(pocket) <= radius);

  /// Pocketing is only detected on the shooter's device during its own shot.
  void _stepShot(double dt) {
    _shotTime += dt;

    for (final entry in coins.entries.toList()) {
      final coin = entry.value;
      if (!coin.isBodyCreated) continue;
      final p = coin.body.position;
      if (_inPocket(p, kPocketRadius)) {
        coins.remove(entry.key);
        _shotPocketed.add(entry.key);
        world.add(PocketEffect(effectPosition: p.clone()));
        coin.removeFromParent();
        audioService?.playPocket();
      }
    }

    final s = striker;
    if (s != null &&
        s.isBodyCreated &&
        !_strikerPocketed &&
        _inPocket(
          s.body.position,
          kPocketRadius + kStrikerRadius - kCoinRadius,
        )) {
      _strikerPocketed = true;
      world.add(PocketEffect(
        effectPosition: s.body.position.clone(),
        color: Colors.yellow,
      ));
      s.park();
    }

    final moving = (s != null &&
            s.isBodyCreated &&
            s.body.linearVelocity.length > _restSpeed) ||
        coins.values.any(
          (c) => c.isBodyCreated && c.body.linearVelocity.length > _restSpeed,
        );

    if (!moving || _shotTime > _maxShotSeconds) _finishShot();
  }

  void _finishShot() {
    _shotInProgress = false;

    final after = <String, CarromPos>{};
    coins.forEach((id, coin) {
      final p = coin.currentPosition;
      final r = radiusOfCoin(id);
      final lo = kBoardMargin + r;
      final hi = kBoardSize - kBoardMargin - r;
      final clamped = Vector2(
        p.x.clamp(lo, hi).toDouble(),
        p.y.clamp(lo, hi).toDouble(),
      );
      coin.moveTo(clamped);
      after[id] = CarromPos(clamped.x, clamped.y);
    });

    final shot = LocalShot(
      coinsAfter: after,
      pocketed: List<String>.from(_shotPocketed),
      strikerPocketed: _strikerPocketed,
      shotData: _shotData,
    );
    _shotPocketed.clear();
    _strikerPocketed = false;
    _resetStriker();

    onShotComplete(shot);
  }
}

/// Full-board input layer in canvas coordinates.
class _InputLayer extends PositionComponent with DragCallbacks {
  _InputLayer(this.board) : super(priority: 100);

  final CarromBoardGame board;

  @override
  Future<void> onLoad() async {
    size = board.size.clone();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size.clone();
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    board.handleDragStart(event.canvasPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    board.handleDragUpdate(event.canvasEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    board.handleDragEnd(event.velocity);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    board.handleDragCancel();
  }
}

/// ==================== GRAPHICS COMPONENTS ====================
/// Bodies live in `world`; render() draws in body-local coordinates.

// 1. Static Wall Component
class Wall extends BodyComponent {
  final Vector2 wallSize;
  final Vector2 initialPosition;

  Wall({required this.wallSize, required this.initialPosition});

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.static,
      position: initialPosition,
    );

    final shape = PolygonShape()
      ..setAsBox(wallSize.x / 2, wallSize.y / 2, Vector2.zero(), 0);

    final fixtureDef = FixtureDef(shape)
      ..friction = 0.8
      ..restitution = 0.2;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void render(Canvas canvas) {
    // Walls are invisible
  }
}

/// Moves a body (or its pending spawn point) and stops it.
mixin _Teleport on BodyComponent {
  Vector2 get spawnPosition;
  set spawnPosition(Vector2 value);
  bool get isBodyCreated;

  Vector2 get currentPosition =>
      isBodyCreated ? body.position.clone() : spawnPosition.clone();

  void moveTo(Vector2 p) {
    if (!isBodyCreated) {
      spawnPosition = p.clone();
      return;
    }
    body.setTransform(p, 0);
    body.linearVelocity = Vector2.zero();
    body.angularVelocity = 0;
  }
}

// 2. 3D Coin with body initialization tracking
class Coin extends BodyComponent with _Teleport {
  final String id;
  final Color color;
  final double radius;

  @override
  Vector2 spawnPosition;

  bool _bodyCreated = false;
  @override
  bool get isBodyCreated => _bodyCreated;

  Coin({
    required this.id,
    required Vector2 initialPosition,
    required this.radius,
    required this.color,
  }) : spawnPosition = initialPosition.clone();

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: spawnPosition.clone(),
    );

    final shape = CircleShape()..radius = radius;

    final fixtureDef = FixtureDef(shape)
      ..density = 1.0
      ..friction = 0.3
      ..restitution = 0.8;

    final body = world.createBody(bodyDef)..createFixture(fixtureDef);
    body.linearDamping = 2.5;
    body.angularDamping = 2.5;
    body.userData = {'type': 'coin', 'id': id};

    _bodyCreated = true;
    return body;
  }

  @override
  void render(Canvas canvas) {
    if (!_bodyCreated) return;
    final r = radius;

    // Shadow
    canvas.drawCircle(
      Offset(r * 0.15, r * 0.15),
      r,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.15),
    );

    // Body
    canvas.drawCircle(Offset.zero, r, Paint()..color = color);

    // Inner Ring
    canvas.drawCircle(
      Offset.zero,
      r * 0.7,
      Paint()
        ..color = Colors.black12
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.15,
    );

    // Highlight
    canvas.drawOval(
      Rect.fromLTWH(-r * 0.5, -r * 0.6, r * 0.6, r * 0.3),
      Paint()..color = Colors.white.withOpacity(0.2),
    );
  }
}

// 3. 3D Striker with body initialization tracking
class Striker extends BodyComponent with _Teleport {
  final double radius = kStrikerRadius;
  final double mass = 2.0;

  @override
  Vector2 spawnPosition;

  bool _bodyCreated = false;
  @override
  bool get isBodyCreated => _bodyCreated;

  Striker({required Vector2 initialPosition})
      : spawnPosition = initialPosition.clone();

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: spawnPosition.clone(),
    )..bullet = true;

    final shape = CircleShape()..radius = radius;

    final fixtureDef = FixtureDef(shape)
      ..density = mass
      ..friction = 0.2
      ..restitution = 0.7;

    final body = world.createBody(bodyDef)..createFixture(fixtureDef);
    body.linearDamping = 2.0;
    body.angularDamping = 2.0;
    body.userData = {'type': 'striker'};

    _bodyCreated = true;
    return body;
  }

  /// Takes a pocketed striker out of play until the next reset.
  void park() => moveTo(Vector2(-10, -10));

  @override
  void render(Canvas canvas) {
    if (!_bodyCreated) return;
    final r = radius;

    // Shadow
    canvas.drawCircle(
      Offset(r * 0.12, r * 0.12),
      r,
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );

    // Body gradient
    final bodyRect = Rect.fromCircle(center: Offset.zero, radius: r);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.yellow.shade50, Colors.orange.shade100],
      ).createShader(bodyRect);
    canvas.drawCircle(Offset.zero, r, paint);

    // Ring
    canvas.drawCircle(
      Offset.zero,
      r * 0.7,
      Paint()
        ..color = Colors.blue.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12,
    );

    // Shine
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r * 0.9),
      pi,
      pi / 2,
      false,
      Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.fill,
    );
  }
}

// 4. Pocket Effect
class PocketEffect extends PositionComponent {
  double life = 0.8;
  Color color;
  final Vector2 effectPosition;

  PocketEffect({
    required this.effectPosition,
    this.color = Colors.orange,
  }) : super(
          position: effectPosition,
          size: Vector2.all(1),
          anchor: Anchor.center,
        );

  @override
  void update(double dt) {
    super.update(dt);
    life -= dt;
    if (life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final r = (1.0 - life.clamp(0.0, 1.0)) * 3.5;
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      r,
      Paint()..color = color.withOpacity(life.clamp(0.0, 1.0)),
    );
  }
}

// 5. Realistic Carrom Board (Visual Only), drawn in board units.
class CarromBoard extends PositionComponent {
  CarromBoard() : super(size: Vector2.all(kBoardSize), priority: -1);

  @override
  void render(Canvas canvas) {
    // Frame Gradient (Dark Wood)
    final framePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(size.toRect());
    canvas.drawRect(size.toRect(), framePaint);

    // Playing Surface (Light Cream)
    const margin = kBoardMargin;
    final surfaceRect = Rect.fromLTWH(
      margin,
      margin,
      size.x - margin * 2,
      size.y - margin * 2,
    );
    canvas.drawRect(surfaceRect, Paint()..color = const Color(0xFFF3E5AB));

    // Board Lines
    final linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 0.15
      ..style = PaintingStyle.stroke;
    canvas.drawRect(surfaceRect.deflate(0.5), linePaint);

    // Pockets (Holes)
    final pocketPaint = Paint()..color = const Color(0xFF1A1A1A);
    for (final p in kPockets) {
      canvas.drawCircle(Offset(p.x, p.y), 2.2, pocketPaint);
    }

    // Baselines (host bottom, guest top)
    final strikerPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 0.15;
    for (final host in const [true, false]) {
      final y = baselineY(hostSide: host);
      canvas.drawLine(
        Offset(kBaselineMinX - kStrikerRadius, y),
        Offset(kBaselineMaxX + kStrikerRadius, y),
        strikerPaint,
      );
      for (final x in const [
        kBaselineMinX - kStrikerRadius,
        kBaselineMaxX + kStrikerRadius,
      ]) {
        canvas.drawCircle(Offset(x, y), 0.6, Paint()..color = Colors.red);
      }
    }

    // Center Design
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(
      center,
      7.0,
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.2,
    );
    canvas.drawCircle(center, 1.0, Paint()..color = Colors.red);
  }
}
