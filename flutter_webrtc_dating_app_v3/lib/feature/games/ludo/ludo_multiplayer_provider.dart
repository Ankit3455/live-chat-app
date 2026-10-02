// lib/feature/games/ludo/ludo_multiplayer_provider.dart
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'constants.dart';
import 'ludo_player.dart';
import 'audio.dart';

class LudoMultiplayerProvider extends ChangeNotifier {
  final String matchId;
  final int turnDurationSeconds;
  bool _opponentLeft = false;
  DateTime? _forfeitDeadline;
  int _activePlayers = 2;
  int _maxPlayers = 2;
  String? _finishReason;

  // Firestore
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _matchSub;

  // Local User
  final String? _localUid = FirebaseAuth.instance.currentUser?.uid;
  String? _localColor;

  // Game State
  final List<LudoPlayer> players = [];
  final List<LudoPlayerType> winners = [];
  final List<String> _activeColors = [];

  bool get opponentLeft => _opponentLeft;
  int get activePlayers => _activePlayers;
  int get maxPlayers => _maxPlayers;
  String? get finishReason => _finishReason;

  LudoGameState _gameState = LudoGameState.throwDice;
  LudoGameState get gameState => _gameState;

  String _currentTurnColor = 'green';
  LudoPlayerType get currentTurnType => _stringToType(_currentTurnColor);

  int _diceResult = 1;
  int get diceResult => _diceResult.clamp(1, 6);

  bool _diceStarted = false;
  bool get diceStarted => _diceStarted;

  bool _isMoving = false;

  // Timer
  Timer? _turnTimer;
  int turnTimeLeft = 30;

  bool ready = false;
  bool _matchLoaded = false;

  // Opponent info
  Map<String, Map<String, dynamic>> playersInfo = {};

  LudoMultiplayerProvider({
    required this.matchId,
    this.turnDurationSeconds = 30,
  });

  // ============ GETTERS ============

  String get forfeitTimeLeft {
    if (_forfeitDeadline == null) return '5:00';
    final remaining = _forfeitDeadline!.difference(DateTime.now());
    if (remaining.isNegative) return '0:00';
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  double get forfeitProgress {
    if (_forfeitDeadline == null) return 0;
    final total = const Duration(minutes: 5).inSeconds;
    final remaining = _forfeitDeadline!.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) return 1.0;
    return 1.0 - (remaining / total);
  }


  bool get isLocalPlayerTurn {
    if (_localColor == null) return false;
    if (_activeColors.length < 2) return false; // Need 2 players
    return _localColor == _currentTurnColor;
  }

  bool get isGameReady => _matchLoaded && _activeColors.length >= 2;

  String? get localColor => _localColor;

  LudoPlayer get currentPlayer =>
      players.firstWhere((p) => p.type == currentTurnType,
          orElse: () => players.first);

  LudoPlayer player(LudoPlayerType type) =>
      players.firstWhere((p) => p.type == type);

  // ============ INITIALIZATION ============

  Future<void> start() async {
    _initializePlayers();

    _matchSub = _fs
        .collection('ludo_matches')
        .doc(matchId)
        .snapshots()
        .listen(_onMatchSnapshot, onError: (e) {
      debugPrint('❌ Match listener error: $e');
    });

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

  // ============ FIRESTORE LISTENER ============

  void _onMatchSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) {
      debugPrint('❌ Match document does not exist');
      return;
    }

    final data = snap.data() ?? {};
    debugPrint('📥 Match update received: ${data.keys.join(', ')}');

    // 1. Get active players
    final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
    _activeColors.clear();
    playersInfo.clear();

    playersMap.forEach((uid, info) {
      if (info is Map) {
        final color = info['color']?.toString() ?? '';
        if (color.isNotEmpty) {
          _activeColors.add(color);
          playersInfo[uid] = Map<String, dynamic>.from(info);

          if (uid == _localUid) {
            _localColor = color;
            debugPrint('🎨 Local player color: $_localColor');
          }
        }
      }
    });

    debugPrint('👥 Active colors: $_activeColors');

    // 2. Check if game is ready
    if (_activeColors.length >= 2) {
      _matchLoaded = true;
      ready = true;
    }

    // 3. Update current turn
    final newTurnColor = (data['turnColor'] ?? 'green').toString();
    final turnChanged = newTurnColor != _currentTurnColor;
    _currentTurnColor = newTurnColor;
    debugPrint('🎯 Current turn: $_currentTurnColor (isMyTurn: $isLocalPlayerTurn)');

    if (turnChanged && isGameReady) {
      _gameState = LudoGameState.throwDice;
      _startTurnTimer(data);
    }

    // 4. Update dice
    final dice = data['dice'];
    if (dice != null && dice is int) {
      _diceResult = dice;
    }

    // 5. Apply pawn positions
    final pawnSteps = Map<String, dynamic>.from(data['pawnSteps'] ?? {});
    _applyPawnSteps(pawnSteps);

    // 6. Apply winners
    final winnersList = List<String>.from(data['winners'] ?? []);
    _applyWinners(winnersList);

    // 7. Check game state
    final state = data['state']?.toString() ?? '';
    if (state == 'finished') {
      _gameState = LudoGameState.finish;
    }

    // 8. Check for opponent left
    _activePlayers = data['activePlayers'] ?? 2;
    _maxPlayers = data['maxPlayers'] ?? 2;
    _finishReason = data['finishReason']?.toString();

    // Get forfeit deadline
    final forfeitDeadlineTs = data['forfeitDeadline'] as Timestamp?;
    _forfeitDeadline = forfeitDeadlineTs?.toDate();

    // Check if any opponent left
    _opponentLeft = false;
    playersMap.forEach((uid, info) {
      if (info is Map && uid != _localUid) {
        final status = info['status']?.toString() ?? 'active';
        if (status == 'left') {
          _opponentLeft = true;
          debugPrint('⚠️ Opponent left the game!');
        }
      }
    });

    notifyListeners();
  }

  void _applyPawnSteps(Map<String, dynamic> pawnSteps) {
    if (_isMoving) return;

    pawnSteps.forEach((colorStr, steps) {
      if (steps is! List) return;
      if (!_activeColors.contains(colorStr)) return;

      final type = _stringToType(colorStr);
      final targetPlayer = player(type);

      for (int i = 0; i < steps.length && i < 4; i++) {
        final step = (steps[i] is int) ? steps[i] as int : -1;
        if (targetPlayer.pawns[i].step != step) {
          targetPlayer.movePawn(i, step);
        }
      }
    });
  }

  void _applyWinners(List<String> winnersList) {
    winners.clear();
    for (final w in winnersList) {
      if (_activeColors.contains(w)) {
        try {
          winners.add(_stringToType(w));
        } catch (_) {}
      }
    }
  }

  // ============ GAME ACTIONS ============

  Future<void> throwDice() async {
    if (!isGameReady) {
      debugPrint('⏳ Game not ready yet (need 2 players)');
      return;
    }
    if (_gameState != LudoGameState.throwDice) {
      debugPrint('⚠️ Not in throwDice state: $_gameState');
      return;
    }
    if (!isLocalPlayerTurn) {
      debugPrint('⚠️ Not your turn! Current: $_currentTurnColor, You: $_localColor');
      return;
    }
    if (_diceStarted) {
      debugPrint('⚠️ Dice already rolling');
      return;
    }

    // IMPORTANT: Reset _isMoving at start of new dice roll
    _isMoving = false;

    debugPrint('🎲 Rolling dice...');
    _diceStarted = true;
    notifyListeners();

    // Audio with error handling - don't await
    Audio.rollDice();

    await Future.delayed(const Duration(seconds: 1));

    // Generate dice result
    final random = Random();
    final dice = random.nextInt(6) + 1;

    _diceStarted = false;
    _diceResult = dice;
    debugPrint('🎲 Dice result: $dice');

    // Determine next state
    String? nextTurnColor;

    if (dice == 6) {
      // Got 6 - can move any pawn including from home
      currentPlayer.highlightAllPawns();
      _gameState = LudoGameState.pickPawn;
      debugPrint('🎯 Got 6! All pawns highlighted');
    } else if (currentPlayer.pawnInsideCount == 4) {
      // All pawns inside, no 6 - skip turn
      nextTurnColor = _getNextActiveColor(_currentTurnColor);
      _gameState = LudoGameState.throwDice;
      debugPrint('⏭️ All pawns inside, skipping turn');
    } else {
      // Highlight pawns that are outside home
      currentPlayer.highlightOutside();
      _gameState = LudoGameState.pickPawn;
      debugPrint('🎯 Highlighting outside pawns');

      // Disable pawns that can't move (would go beyond finish)
      for (int i = 0; i < currentPlayer.pawns.length; i++) {
        final pawn = currentPlayer.pawns[i];
        if (pawn.step != -1 && (pawn.step + dice) > currentPlayer.path.length - 1) {
          currentPlayer.highlightPawn(i, false);
          debugPrint('❌ Pawn $i disabled - would exceed path');
        }
      }

      // If no pawn can move, skip turn
      final moveablePawns = currentPlayer.pawns.where((p) => p.highlight).toList();
      if (moveablePawns.isEmpty) {
        nextTurnColor = _getNextActiveColor(_currentTurnColor);
        _gameState = LudoGameState.throwDice;
        debugPrint('⏭️ No moveable pawns, skipping turn');
      }
    }

    notifyListeners();

    // Auto-move if only one pawn can move
    final moveablePawns = currentPlayer.pawns.where((p) => p.highlight).toList();
    debugPrint('📊 Moveable pawns count: ${moveablePawns.length}');

    if (moveablePawns.length == 1 && nextTurnColor == null) {
      final pawn = moveablePawns.first;
      final toStep = pawn.step == -1 ? 0 : pawn.step + dice;
      debugPrint('🚀 Auto-moving pawn ${pawn.index} to step $toStep');
      await Future.delayed(const Duration(milliseconds: 300));
      await move(currentPlayer.type, pawn.index, toStep);
      return;
    }

    // Send dice to Firestore
    await _sendDiceResult(dice, nextTurnColor);
  }

  Future<void> move(LudoPlayerType type, int pawnIndex, int toStep) async {
    if (!isLocalPlayerTurn) {
      debugPrint('⚠️ Not your turn to move');
      return;
    }
    if (_isMoving) {
      debugPrint('⚠️ Already moving');
      return;
    }

    debugPrint('🏃 Moving pawn $pawnIndex to step $toStep');
    _isMoving = true;
    _gameState = LudoGameState.moving;
    currentPlayer.highlightAllPawns(false);
    notifyListeners();

    try {
      final selectedPlayer = player(type);
      final fromStep = selectedPlayer.pawns[pawnIndex].step;

      // Clamp toStep to valid range
      final maxStep = selectedPlayer.path.length - 1;
      final clampedToStep = toStep.clamp(-1, maxStep);

      debugPrint('📍 Moving from step $fromStep to $clampedToStep');

      // Animate movement locally
      for (int i = fromStep + 1; i <= clampedToStep; i++) {
        selectedPlayer.movePawn(pawnIndex, i);
        // Audio without await - don't block on audio errors
        Audio.playMove();
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 150));
      }

      // Check for kills
      bool killed = _checkAndKill(type, pawnIndex, clampedToStep);
      if (killed) {
        debugPrint('💀 Killed opponent pawn!');
      }

      // Check for win
      _validateWin(type);

      // Determine next turn
      String? nextTurnColor;
      if (_diceResult == 6 || killed) {
        // Got 6 or killed - get another turn
        _gameState = LudoGameState.throwDice;
        debugPrint('🎯 Extra turn! (6 or kill)');
      } else {
        nextTurnColor = _getNextActiveColor(_currentTurnColor);
        _gameState = LudoGameState.throwDice;
        debugPrint('➡️ Next turn: $nextTurnColor');
      }

      notifyListeners();

      // Send to Firestore
      await _sendMove(type, pawnIndex, clampedToStep, nextTurnColor, killed);

    } catch (e) {
      debugPrint('❌ Move error: $e');
    } finally {
      // IMPORTANT: Always reset _isMoving
      _isMoving = false;
      debugPrint('✅ Move complete, _isMoving reset to false');
    }
  }

  bool _checkAndKill(LudoPlayerType attackerType, int pawnIndex, int step) {
    if (step < 0) return false;

    final attackerPlayer = player(attackerType);
    if (step >= attackerPlayer.path.length) return false;

    final attackerPos = attackerPlayer.path[step];

    // Check if position is safe
    if (LudoPath.safeArea.any((safe) =>
    safe[0] == attackerPos[0] && safe[1] == attackerPos[1])) {
      return false;
    }

    bool killed = false;

    for (final targetPlayer in players) {
      if (targetPlayer.type == attackerType) continue;
      if (!_activeColors.contains(targetPlayer.type.name)) continue;

      for (int i = 0; i < targetPlayer.pawns.length; i++) {
        final targetPawn = targetPlayer.pawns[i];
        if (targetPawn.step < 0 || targetPawn.step >= targetPlayer.path.length) continue;

        final targetPos = targetPlayer.path[targetPawn.step];

        if (targetPos[0] == attackerPos[0] && targetPos[1] == attackerPos[1]) {
          targetPlayer.movePawn(i, -1);
          killed = true;
          Audio.playKill();
        }
      }
    }

    return killed;
  }

  void _validateWin(LudoPlayerType type) {
    if (winners.contains(type)) return;

    final p = player(type);
    final allFinished = p.pawns.every((pawn) =>
    pawn.step == p.path.length - 1);

    if (allFinished) {
      winners.add(type);

      final activeCount = _activeColors.length;
      if (winners.length >= activeCount - 1) {
        _gameState = LudoGameState.finish;
      }
    }
  }

  // ============ FIRESTORE WRITES ============

  Future<void> _sendDiceResult(int dice, String? nextTurnColor) async {
    final updates = <String, dynamic>{
      'dice': dice,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (nextTurnColor != null) {
      updates['turnColor'] = nextTurnColor;
      updates['turnStartedAt'] = FieldValue.serverTimestamp();
    }

    try {
      await _fs.collection('ludo_matches').doc(matchId).update(updates);
      debugPrint('✅ Dice sent to Firestore');
    } catch (e) {
      debugPrint('❌ Failed to send dice: $e');
    }
  }

  Future<void> _sendMove(
      LudoPlayerType type,
      int pawnIndex,
      int toStep,
      String? nextTurnColor,
      bool killed,
      ) async {
    final pawnStepsMap = <String, List<int>>{};
    for (final color in _activeColors) {
      final p = player(_stringToType(color));
      pawnStepsMap[color] = p.pawns.map((pw) => pw.step).toList();
    }

    final updates = <String, dynamic>{
      'pawnSteps': pawnStepsMap,
      'lastMove': {
        'type': type.name,
        'pawnIndex': pawnIndex,
        'toStep': toStep,
        'killed': killed,
        'byUid': _localUid,
        'ts': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (nextTurnColor != null) {
      updates['turnColor'] = nextTurnColor;
      updates['turnStartedAt'] = FieldValue.serverTimestamp();
    }

    if (winners.isNotEmpty) {
      updates['winners'] = winners.map((w) => w.name).toList();
    }

    if (_gameState == LudoGameState.finish) {
      updates['state'] = 'finished';
    }

    try {
      await _fs.collection('ludo_matches').doc(matchId).update(updates);
      debugPrint('✅ Move sent to Firestore');
    } catch (e) {
      debugPrint('❌ Failed to send move: $e');
    }
  }

  // ============ TURN MANAGEMENT ============

  String _getNextActiveColor(String current) {
    final order = ['green', 'yellow', 'blue', 'red'];

    final available = order.where((c) =>
    _activeColors.contains(c) &&
        !winners.any((w) => w.name == c)).toList();

    if (available.isEmpty) return current;

    int idx = available.indexOf(current);
    if (idx < 0) idx = 0;

    return available[(idx + 1) % available.length];
  }

  void _startTurnTimer(Map<String, dynamic> data) {
    _turnTimer?.cancel();

    final ts = data['turnStartedAt'] as Timestamp?;
    if (ts == null) {
      // No timestamp, start fresh
      turnTimeLeft = turnDurationSeconds;
    } else {
      final startTime = ts.toDate();
      final elapsed = DateTime.now().difference(startTime).inSeconds;
      turnTimeLeft = (turnDurationSeconds - elapsed).clamp(0, turnDurationSeconds);
    }

    debugPrint('⏱️ Turn timer started: ${turnTimeLeft}s remaining');

    if (turnTimeLeft <= 0 && isLocalPlayerTurn) {
      _handleTurnTimeout();
      return;
    }

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (turnTimeLeft > 0) {
        turnTimeLeft--;
        notifyListeners();
      }

      if (turnTimeLeft <= 0) {
        timer.cancel();
        if (isLocalPlayerTurn) {
          _handleTurnTimeout();
        }
      }
    });
  }

  Future<void> _handleTurnTimeout() async {
    if (!isLocalPlayerTurn) return;

    debugPrint('⏰ Turn timeout! Skipping turn...');
    final nextColor = _getNextActiveColor(_currentTurnColor);

    try {
      await _fs.collection('ludo_matches').doc(matchId).update({
        'turnColor': nextColor,
        'turnStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Failed to skip turn: $e');
    }
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
    _turnTimer?.cancel();
  }

  @override
  void dispose() {
    disposeProvider();
    super.dispose();
  }
}