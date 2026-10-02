// // lib/feature/games/carrom/carrom_game_screen.dart
// // STATUS: FINAL FIXED VERSION (Timer Conflict Resolved) ✅
//
// import 'dart:async'; // Standard Timer lives here
// import 'dart:math';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flame/game.dart';
// import 'package:flame/components.dart' hide Timer; // <--- FIXED: Hidden Flame's Timer to avoid conflict
// import 'package:flame/events.dart';
//
// import 'carrom_result_screen.dart';
// import 'services/carrom_audio_service.dart';
//
// /// ==================== MAIN GAME SCREEN ====================
// class CarromGameScreen extends StatefulWidget {
// final String matchId;
//
// const CarromGameScreen({Key? key, required this.matchId}) : super(key: key);
//
// @override
// State<CarromGameScreen> createState() => _CarromGameScreenState();
// }
//
// class _CarromGameScreenState extends State<CarromGameScreen> {
// // Firebase
// final FirebaseFirestore _firestore = FirebaseFirestore.instance;
// final FirebaseAuth _auth = FirebaseAuth.instance;
//
// // Audio
// final CarromAudioService _audioService = CarromAudioService();
//
// // Game timing
// DateTime? _gameStartTime;
//
// // Turn Timer
// Timer? _turnTimer;
// int _turnTimeLeft = 30;
// static const int _turnDuration = 30;
//
// // Subscriptions
// StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _matchSub;
//
// // Game state
// Map<String, dynamic>? _matchData;
// late CarromBoardGame _game;
// bool _isHost = false;
// String? _myUid;
// String? _opponentUid;
// String _status = 'waiting';
// String _turnUid = '';
// bool _loading = true;
//
// @override
// void initState() {
// super.initState();
// _myUid = _auth.currentUser?.uid;
// _game = CarromBoardGame(
// onShot: _onLocalShot,
// audioService: _audioService,
// );
// _audioService.initialize();
// _listenMatch();
// }
//
// @override
// void dispose() {
// _turnTimer?.cancel();
// _matchSub?.cancel();
// _game.onDispose();
// super.dispose();
// }
//
// // ==================== FIREBASE LISTENER ====================
// Future<void> _listenMatch() async {
// final ref = _firestore.collection('carrom_matches').doc(widget.matchId);
//
// _matchSub = ref.snapshots().listen((snap) {
// if (!snap.exists) return;
//
// final data = snap.data()!;
// _matchData = data;
//
// final newTurnUid = data['turn'] as String? ?? '';
// final newStatus = data['status'] as String? ?? 'waiting';
//
// // Handle Timer Reset on Turn Change
// if (newStatus == 'started' && newTurnUid != _turnUid) {
// _startTurnTimer();
// }
//
// setState(() {
// _status = newStatus;
// _turnUid = newTurnUid;
// _loading = false;
// });
//
// // Track game start time
// if (_status == 'started' && _gameStartTime == null) {
// _gameStartTime = DateTime.now();
// }
//
// // Parse players
// final players = Map<String, dynamic>.from(data['players'] ?? {});
// if (_myUid != null && players.isNotEmpty) {
// _opponentUid = players.keys.firstWhere(
// (k) => k != _myUid,
// orElse: () => '',
// );
// _isHost = (data['host'] == _myUid);
//
// // Assign player colors deterministically
// final uids = players.keys.toList();
// if (uids.length >= 2) {
// _game.playerColorForUid.clear();
// _game.playerColorForUid[uids[0]] = 'white';
// _game.playerColorForUid[uids[1]] = 'black';
// } else if (_myUid != null) {
// _game.playerColorForUid[_myUid!] = 'white';
// }
// }
//
// // Apply board state if present
// if (data['boardState'] != null) {
// try {
// _game.setBoardState(Map<String, dynamic>.from(data['boardState']));
// } catch (_) {}
// }
//
// // Apply lastMove if it's from opponent
// final lastMove = data['lastMove'] as Map<String, dynamic>?;
// if (lastMove != null) {
// final fromUid = lastMove['fromUid'] as String?;
// if (fromUid != null && fromUid != _myUid) {
// _game.applyRemoteShot(lastMove);
// }
// }
//
// // If finished, show result
// if (_status == 'finished') {
// _turnTimer?.cancel();
// final scores = Map<String, dynamic>.from(data['scores'] ?? {});
// _showResultAndExit(scores);
// }
// });
// }
//
// // ==================== TIMER LOGIC ====================
// void _startTurnTimer() {
// _turnTimer?.cancel();
// setState(() => _turnTimeLeft = _turnDuration);
//
// _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
// if (_turnTimeLeft > 0) {
// setState(() => _turnTimeLeft--);
// } else {
// _turnTimer?.cancel();
// // Auto-switch if it's my turn and time ran out
// if (_turnUid == _myUid && _status == 'started') {
// _handleTurnTimeout();
// }
// }
// });
// }
//
// Future<void> _handleTurnTimeout() async {
// if (!mounted) return;
//
// // Auto-switch turn
// final ref = _firestore.collection('carrom_matches').doc(widget.matchId);
// final opponent = _opponentUid ?? _myUid;
//
// // Update turn without making a move
// await ref.update({
// 'turn': opponent,
// });
//
// ScaffoldMessenger.of(context).showSnackBar(
// const SnackBar(
// content: Text("Time's up! Turn passed."),
// backgroundColor: Colors.red,
// duration: Duration(seconds: 2),
// ),
// );
// }
//
// // ==================== LOCAL SHOT HANDLER ====================
// Future<void> _onLocalShot(
// Map<String, dynamic> shotData,
// Map<String, dynamic> boardStateAfterShot,
// List<String> pocketed,
// List<String> fouls,
// ) async {
// _turnTimer?.cancel(); // Stop timer immediately on shot
//
// // Play strike sound
// _audioService.playStrike();
//
// // Play pocket sound for each pocketed coin
// if (pocketed.isNotEmpty) {
// for (int i = 0; i < pocketed.length; i++) {
// Future.delayed(Duration(milliseconds: i * 150), () {
// _audioService.playPocket();
// });
// }
// }
//
// // Play foul sound if any fouls
// if (fouls.isNotEmpty) {
// _audioService.playFoul();
// }
//
// // Write to Firebase
// final ref = _firestore.collection('carrom_matches').doc(widget.matchId);
// final myUid = _myUid!;
// final opponent = _opponentUid ?? myUid;
//
// // Compute next turn
// bool playerKeepsTurn = false;
// final color = _game.playerColorForUid[myUid] ?? 'white';
//
// for (final id in pocketed) {
// if (id == 'q') {
// // Queen pocketed - check cover
// if ((boardStateAfterShot['queenCoveredBy'] ?? null) == myUid) {
// playerKeepsTurn = true;
// }
// } else if (_isCoinOfColor(id, color)) {
// playerKeepsTurn = true;
// }
// }
//
// final writeMap = <String, dynamic>{
// 'lastMove': {
// 'fromUid': myUid,
// 'shot': shotData,
// 'pocketed': pocketed,
// 'fouls': fouls,
// 'ts': FieldValue.serverTimestamp(),
// },
// 'boardState': boardStateAfterShot,
// 'scores': boardStateAfterShot['scores'] ?? {},
// 'turn': playerKeepsTurn ? myUid : opponent,
// };
//
// // Check finish condition
// final remaining = (boardStateAfterShot['remaining'] ?? 0) as int;
// final scores = Map<String, dynamic>.from(boardStateAfterShot['scores'] ?? {});
// final myScore = (scores[myUid] ?? 0) as int;
// final opScore = (scores[opponent] ?? 0) as int;
//
// if (myScore >= 25 || opScore >= 25 || remaining == 0) {
// writeMap['status'] = 'finished';
// writeMap['finishedAt'] = FieldValue.serverTimestamp();
// writeMap['scores'] = scores;
// }
//
// await ref.update(writeMap);
// }
//
// bool _isCoinOfColor(String id, String color) {
// if (id == 'q') return false;
// if (color == 'white') return id.startsWith('w');
// if (color == 'black') return id.startsWith('b');
// return false;
// }
//
// // ==================== RESULT SCREEN NAVIGATION ====================
// void _showResultAndExit(Map<String, dynamic> scores) {
// final myScore = (scores[_myUid] ?? 0) as int;
// final oppScore = (scores[_opponentUid] ?? 0) as int;
//
// // Play result sound
// if (myScore > oppScore) {
// _audioService.playVictory();
// } else {
// _audioService.playDefeat();
// }
//
// // Calculate game duration
// int? gameDuration;
// if (_gameStartTime != null) {
// gameDuration = DateTime.now().difference(_gameStartTime!).inSeconds;
// }
//
// // Get opponent name safely
// String opponentName = 'Opponent';
// if (_matchData != null) {
// final players = Map<String, dynamic>.from(_matchData!['players'] ?? {});
// if (_opponentUid != null) {
// final userData = players[_opponentUid];
// if (userData is Map && userData['displayName'] != null) {
// opponentName = userData['displayName'].toString();
// }
// }
// }
//
// if (!mounted) return;
//
// Navigator.pushReplacement(
// context,
// MaterialPageRoute(
// builder: (_) => CarromResultScreen(
// matchId: widget.matchId,
// myScore: myScore,
// opponentScore: oppScore,
// opponentUid: _opponentUid ?? '',
// opponentName: opponentName,
// gameDurationSeconds: gameDuration,
// ),
// ),
// );
// }
//
// // ==================== REPLAY HANDLER ====================
// Future<void> _onReplayPressed() async {
// if (!_isHost) {
// ScaffoldMessenger.of(context).showSnackBar(
// const SnackBar(content: Text('Only host can restart match')),
// );
// return;
// }
//
// final ref = _firestore.collection('carrom_matches').doc(widget.matchId);
// final initialBoard = _game.initialBoardState();
//
// await ref.update({
// 'boardState': initialBoard,
// 'lastMove': null,
// 'status': 'started',
// 'turn': _matchData?['host'] ?? _myUid,
// 'scores': initialBoard['scores'],
// });
//
// _game.resetBoard();
// _gameStartTime = DateTime.now();
// _startTurnTimer();
// }
//
// // ==================== HUD WIDGET ====================
// Widget _buildHUD() {
// final players = Map<String, dynamic>.from(_matchData?['players'] ?? {});
//
// // Safe name extraction
// String getSafeName(String? uid, String defaultName) {
// if (uid == null) return defaultName;
// final userData = players[uid];
// if (userData != null && userData is Map) {
// return userData['displayName']?.toString() ?? defaultName;
// }
// return defaultName;
// }
//
// final myName = getSafeName(_myUid, 'You');
// final opName = getSafeName(_opponentUid, _status == 'waiting' ? 'Waiting...' : 'Opponent');
//
// final myScore = _game.scores[_myUid] ?? 0;
// final opScore = _game.scores[_opponentUid] ?? 0;
// final myLives = _game.lives[_myUid] ?? 0;
// final opLives = _game.lives[_opponentUid] ?? 0;
// final isMyTurn = _turnUid == _myUid;
//
// return Container(
// padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// decoration: BoxDecoration(
// color: Colors.black.withOpacity(0.3),
// ),
// child: Row(
// mainAxisAlignment: MainAxisAlignment.spaceBetween,
// children: [
// // My Info
// _buildPlayerInfo(
// name: myName,
// score: myScore,
// lives: myLives,
// isActive: isMyTurn,
// isMe: true,
// ),
//
// // Turn & Timer Indicator
// Container(
// padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
// decoration: BoxDecoration(
// color: isMyTurn
// ? Colors.green.withOpacity(0.3)
//     : Colors.orange.withOpacity(0.3),
// borderRadius: BorderRadius.circular(20),
// border: Border.all(
// color: isMyTurn ? Colors.green : Colors.orange,
// width: 2,
// ),
// ),
// child: Column(
// mainAxisSize: MainAxisSize.min,
// children: [
// Text(
// isMyTurn ? 'YOUR TURN' : 'OPPONENT',
// style: TextStyle(
// color: isMyTurn ? Colors.green : Colors.orange,
// fontSize: 12,
// fontWeight: FontWeight.bold,
// ),
// ),
// if (_status == 'started')
// Text(
// '$_turnTimeLeft s',
// style: TextStyle(
// color: _turnTimeLeft < 10 ? Colors.red : Colors.white,
// fontSize: 14,
// fontWeight: FontWeight.bold,
// ),
// ),
// ],
// ),
// ),
//
// // Opponent Info
// _buildPlayerInfo(
// name: opName,
// score: opScore,
// lives: opLives,
// isActive: !isMyTurn,
// isMe: false,
// ),
// ],
// ),
// );
// }
//
// Widget _buildPlayerInfo({
// required String name,
// required int score,
// required int lives,
// required bool isActive,
// required bool isMe,
// }) {
// return Column(
// crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
// children: [
// Row(
// mainAxisSize: MainAxisSize.min,
// children: [
// if (isMe && isActive)
// Container(
// width: 8,
// height: 8,
// margin: const EdgeInsets.only(right: 6),
// decoration: const BoxDecoration(
// color: Colors.green,
// shape: BoxShape.circle,
// ),
// ),
// Text(
// name.length > 10 ? '${name.substring(0, 8)}..' : name,
// style: TextStyle(
// color: Colors.white,
// fontSize: 14,
// fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
// ),
// ),
// if (!isMe && isActive)
// Container(
// width: 8,
// height: 8,
// margin: const EdgeInsets.only(left: 6),
// decoration: const BoxDecoration(
// color: Colors.green,
// shape: BoxShape.circle,
// ),
// ),
// ],
// ),
// const SizedBox(height: 4),
// Text(
// 'Score: $score',
// style: TextStyle(
// color: Colors.white.withOpacity(0.8),
// fontSize: 13,
// fontWeight: FontWeight.w600,
// ),
// ),
// Text(
// 'Lives: ${'❤️' * lives}${lives == 0 ? '💔' : ''}',
// style: const TextStyle(fontSize: 11),
// ),
// ],
// );
// }
//
// // ==================== BUILD METHOD ====================
// @override
// Widget build(BuildContext context) {
// return Scaffold(
// backgroundColor: const Color(0xFF1A0E2E),
// appBar: AppBar(
// backgroundColor: const Color(0xFF2D1B4E),
// title: const Text('Carrom Match'),
// actions: [
// IconButton(
// icon: Icon(
// _audioService.isMuted ? Icons.volume_off : Icons.volume_up,
// color: Colors.white,
// ),
// onPressed: () {
// setState(() {
// _audioService.toggleMute();
// });
// },
// ),
// IconButton(
// icon: const Icon(Icons.refresh, color: Colors.white),
// onPressed: _onReplayPressed,
// ),
// ],
// ),
// body: _loading
// ? const Center(
// child: CircularProgressIndicator(color: Colors.orange),
// )
//     : Column(
// children: [
// _buildHUD(),
// Expanded(
// child: Container(
// margin: const EdgeInsets.all(8),
// decoration: BoxDecoration(
// borderRadius: BorderRadius.circular(12),
// border: Border.all(
// color: Colors.orange.withOpacity(0.3),
// width: 2,
// ),
// ),
// child: ClipRRect(
// borderRadius: BorderRadius.circular(10),
// child: GameWidget(game: _game),
// ),
// ),
// ),
// Container(
// padding: const EdgeInsets.all(16),
// child: Text(
// _status == 'started'
// ? (_turnUid == _myUid
// ? '👆 Your Turn - Drag to Shoot!'
//     : '⏳ Waiting for opponent...')
//     : '⏳ Loading...',
// style: TextStyle(
// color: Colors.white.withOpacity(0.7),
// fontSize: 14,
// ),
// ),
// ),
// ],
// ),
// );
// }
// }
//
// /// ==================== CARROM BOARD GAME (FLAME) ====================
// class CarromBoardGame extends FlameGame with HasCollisionDetection {
// // Board dimensions
// final double boardSize = 600.0;
// final double pocketRadius = 28.0;
//
// // Game objects
// final Map<String, Coin> coins = {};
// late Striker striker;
//
// // Player data
// final Map<String, int> scores = {};
// final Map<String, int> lives = {};
// final Map<String, String> playerColorForUid = {};
//
// // Audio
// final CarromAudioService? audioService;
//
// // Callbacks
// final Future<void> Function(
// Map<String, dynamic> shotData,
// Map<String, dynamic> boardStateAfterShot,
// List<String> pocketed,
// List<String> fouls,
// )? onShot;
//
// // Internal state
// Map<String, Coin> _preShotCoinSnapshot = {};
// Map<String, dynamic>? _lastLocalShot;
// bool _disposed = false;
//
// CarromBoardGame({this.onShot, this.audioService});
//
// @override
// Future<void> onLoad() async {
// await super.onLoad();
//
// // Set up camera
// camera.viewfinder.anchor = Anchor.topLeft;
//
// // Add board background
// add(CarromBoard(size: Vector2.all(boardSize)));
//
// // Initialize striker
// final center = Vector2(boardSize / 2, boardSize / 2);
// striker = Striker(
// position: center + Vector2(0, boardSize / 2 - 100),
// gameRef: this,
// );
// add(striker);
//
// // Initialize coins
// _initCoins(center);
// }
//
// void _initCoins(Vector2 center) {
// coins.clear();
//
// // Queen (red, center)
// coins['q'] = Coin(
// id: 'q',
// position: center.clone(),
// radius: 12.0,
// color: Colors.red,
// mass: 1.2,
// );
// add(coins['q']!);
//
// // Arrange coins in circular pattern
// const double r = 35.0;
// int b = 0, w = 0;
//
// for (int i = 0; i < 18; i++) {
// final double ang = (i / 18) * pi * 2;
//
// if (i % 2 == 0 && b < 9) {
// final coin = Coin(
// id: 'b$b',
// position: center + Vector2(cos(ang), sin(ang)) * (r + 8.0),
// radius: 10.0,
// color: Colors.black87,
// mass: 1.0,
// );
// coins['b$b'] = coin;
// add(coin);
// b++;
// } else if (i % 2 == 1 && w < 9) {
// final coin = Coin(
// id: 'w$w',
// position: center + Vector2(cos(ang), sin(ang)) * (r + 22.0),
// radius: 10.0,
// color: Colors.white,
// mass: 1.0,
// );
// coins['w$w'] = coin;
// add(coin);
// w++;
// }
// }
//
// scores.clear();
// lives.clear();
// }
//
// Map<String, dynamic> initialBoardState() {
// final coinMap = <String, Map<String, double>>{};
// coins.forEach((k, c) {
// coinMap[k] = {'x': c.position.x, 'y': c.position.y};
// });
// return {'coins': coinMap, 'scores': scores, 'remaining': coins.length};
// }
//
// void resetBoard() {
// for (final coin in coins.values) {
// coin.removeFromParent();
// }
// coins.clear();
//
// final center = Vector2(boardSize / 2, boardSize / 2);
// striker.position = center + Vector2(0, boardSize / 2 - 100);
// striker.velocity = Vector2.zero();
//
// _initCoins(center);
// _lastLocalShot = null;
// }
//
// void setBoardState(Map<String, dynamic> board) {
// final coinMap = Map<String, dynamic>.from(board['coins'] ?? {});
//
// final currentIds = coins.keys.toList();
// for (final id in currentIds) {
// if (!coinMap.containsKey(id)) {
// coins[id]?.removeFromParent();
// coins.remove(id);
// }
// }
//
// coinMap.forEach((id, pos) {
// final p = Map<String, dynamic>.from(pos);
// final x = (p['x'] ?? 0) as num;
// final y = (p['y'] ?? 0) as num;
//
// if (coins.containsKey(id)) {
// coins[id]!.position = Vector2(x.toDouble(), y.toDouble());
// coins[id]!.velocity = Vector2.zero();
// } else {
// Color color = Colors.grey;
// if (id == 'q') color = Colors.red;
// else if (id.startsWith('w')) color = Colors.white;
// else if (id.startsWith('b')) color = Colors.black87;
//
// final coin = Coin(
// id: id,
// position: Vector2(x.toDouble(), y.toDouble()),
// radius: id == 'q' ? 12.0 : 10.0,
// color: color,
// );
// coins[id] = coin;
// add(coin);
// }
// });
//
// final sc = Map<String, dynamic>.from(board['scores'] ?? {});
// sc.forEach((k, v) {
// scores[k] = (v as num).toInt();
// });
// }
//
// void applyRemoteShot(Map<String, dynamic> lastMove) {
// final shot = lastMove['shot'] as Map<String, dynamic>? ?? {};
// final vx = (shot['vx'] ?? 0) as num;
// final vy = (shot['vy'] ?? 0) as num;
// final sx = (shot['sx'] ?? 0) as num;
// final sy = (shot['sy'] ?? 0) as num;
//
// striker.position = Vector2(sx.toDouble(), sy.toDouble());
// striker.velocity = Vector2(vx.toDouble(), vy.toDouble());
// }
//
// void localPlayerShot(String fromUid, Vector2 strikerPos, Vector2 velocityVector) {
// _preShotCoinSnapshot = {
// for (final e in coins.entries) e.key: e.value.cloneCoin()
// };
//
// striker.position = strikerPos.clone();
// striker.velocity = velocityVector.clone();
//
// _lastLocalShot = {
// 'fromUid': fromUid,
// 'sx': strikerPos.x,
// 'sy': strikerPos.y,
// 'vx': velocityVector.x,
// 'vy': velocityVector.y,
// 'timestamp': DateTime.now().millisecondsSinceEpoch,
// };
// }
//
// @override
// void update(double dt) {
// super.update(dt);
// if (_disposed) return;
//
// striker.applyPhysics(dt, boardSize);
//
// for (final c in coins.values) {
// c.applyPhysics(dt, boardSize);
// }
//
// for (final c in coins.values) {
// _handleCircleCollision(striker, c);
// }
//
// final coinList = coins.values.toList();
// for (int i = 0; i < coinList.length; i++) {
// for (int j = i + 1; j < coinList.length; j++) {
// _handleCircleCollision(coinList[i], coinList[j]);
// }
// }
//
// final pockets = [
// Vector2(0, 0),
// Vector2(boardSize, 0),
// Vector2(0, boardSize),
// Vector2(boardSize, boardSize),
// ];
//
// final pocketed = <String>[];
// for (final entry in coins.entries.toList()) {
// final c = entry.value;
// for (final p in pockets) {
// if ((c.position - p).length <= pocketRadius) {
// pocketed.add(entry.key);
// break;
// }
// }
// }
//
// if (pocketed.isNotEmpty) {
// for (final id in pocketed) {
// final c = coins.remove(id);
// if (c != null) {
// c.removeFromParent();
// add(PocketEffect(position: c.position.clone()));
// }
// }
// }
//
// final moving = striker.velocity.length > 2.0 ||
// coins.values.any((c) => c.velocity.length > 2.0);
//
// if (!moving && _lastLocalShot != null) {
// _finalizeShot(pockets);
// }
// }
//
// void _finalizeShot(List<Vector2> pockets) {
// final beforeIds = Set<String>.from(_preShotCoinSnapshot.keys);
// final afterIds = Set<String>.from(coins.keys);
// final pocketedIds = beforeIds.difference(afterIds).toList();
//
// final fouls = <String>[];
//
// for (final p in pockets) {
// if ((striker.position - p).length <= pocketRadius) {
// fouls.add('striker_pocketed');
// striker.position = Vector2(boardSize / 2, boardSize / 2 + boardSize / 2 - 100);
// striker.velocity = Vector2.zero();
// add(PocketEffect(position: p.clone(), color: Colors.yellow));
// audioService?.playFoul();
// }
// }
//
// final shotFrom = _lastLocalShot!['fromUid'] as String;
// scores.putIfAbsent(shotFrom, () => 0);
// lives.putIfAbsent(shotFrom, () => 1);
//
// bool queenPocketed = pocketedIds.contains('q');
// bool playerPocketedOwnCoin = false;
// final myColor = playerColorForUid[shotFrom] ?? 'white';
//
// for (final id in pocketedIds) {
// if (id == 'q') continue;
// if (_isCoinOfColor(id, myColor)) {
// playerPocketedOwnCoin = true;
// scores[shotFrom] = (scores[shotFrom] ?? 0) + 1;
// } else {
// scores[shotFrom] = (scores[shotFrom] ?? 0) + 1;
// }
// }
//
// if (queenPocketed) {
// if (playerPocketedOwnCoin) {
// scores[shotFrom] = (scores[shotFrom] ?? 0) + 5;
// } else {
// final center = Vector2(boardSize / 2, boardSize / 2);
// final queen = Coin(
// id: 'q',
// position: center,
// radius: 12.0,
// color: Colors.red,
// mass: 1.2,
// );
// coins['q'] = queen;
// add(queen);
// fouls.add('queen_not_covered');
// }
// }
//
// if (fouls.contains('striker_pocketed')) {
// scores[shotFrom] = max(0, (scores[shotFrom] ?? 0) - 1);
// lives[shotFrom] = max(0, (lives[shotFrom] ?? 1) - 1);
// }
// if (fouls.contains('queen_not_covered')) {
// scores[shotFrom] = max(0, (scores[shotFrom] ?? 0) - 2);
// }
//
// if ((scores[shotFrom] ?? 0) >= 15 && (lives[shotFrom] ?? 0) < 2) {
// lives[shotFrom] = (lives[shotFrom] ?? 0) + 1;
// }
//
// final boardMap = _serializeBoardState();
// if (queenPocketed && playerPocketedOwnCoin) {
// boardMap['queenCoveredBy'] = shotFrom;
// }
// boardMap['lastPocketed'] = pocketedIds;
// boardMap['scores'] = scores;
// boardMap['remaining'] = coins.length;
//
// if (onShot != null) {
// final shotData = {
// 'sx': _lastLocalShot!['sx'],
// 'sy': _lastLocalShot!['sy'],
// 'vx': _lastLocalShot!['vx'],
// 'vy': _lastLocalShot!['vy'],
// };
//
// try {
// onShot!(shotData, boardMap, pocketedIds, fouls);
// } catch (_) {}
// }
//
// _lastLocalShot = null;
// }
//
// bool _isCoinOfColor(String id, String color) {
// if (id == 'q') return false;
// if (color == 'white') return id.startsWith('w');
// if (color == 'black') return id.startsWith('b');
// return false;
// }
//
// Map<String, dynamic> _serializeBoardState() {
// final coinsMap = <String, Map<String, double>>{};
// coins.forEach((k, c) {
// coinsMap[k] = {'x': c.position.x, 'y': c.position.y};
// });
// return {
// 'coins': coinsMap,
// 'scores': Map<String, int>.from(scores),
// 'lives': Map<String, int>.from(lives),
// 'remaining': coins.length,
// };
// }
//
// void _handleCircleCollision(dynamic a, dynamic b) {
// final diff = a.position - b.position;
// final dist = diff.length;
// final minDist = a.radius + b.radius;
//
// if (dist <= 0.0 || dist >= minDist) return;
//
// final normal = diff / dist;
// final overlap = minDist - dist;
//
// a.position += normal * (overlap * 0.5);
// b.position -= normal * (overlap * 0.5);
//
// final rel = a.velocity - b.velocity;
// final velAlongNormal = rel.dot(normal);
//
// if (velAlongNormal > 0) return;
//
// const restitution = 0.85;
// final ma = a.mass as double;
// final mb = b.mass as double;
// final j = -(1 + restitution) * velAlongNormal / (1 / ma + 1 / mb);
//
// final impulse = normal * j;
// a.velocity += impulse / ma;
// b.velocity -= impulse / mb;
//
// audioService?.playCollision();
// }
//
// void onDispose() {
// _disposed = true;
// }
//
// @override
// void onRemove() {
// _disposed = true;
// super.onRemove();
// }
// }
//
// /// ==================== CARROM BOARD BACKGROUND ====================
// class CarromBoard extends PositionComponent {
// CarromBoard({required Vector2 size}) : super(size: size);
//
// @override
// void render(Canvas canvas) {
// final bgPaint = Paint()..color = const Color(0xFFDEB887);
// canvas.drawRect(size.toRect(), bgPaint);
//
// final playPaint = Paint()..color = const Color(0xFFF5DEB3);
// const margin = 30.0;
// canvas.drawRect(
// Rect.fromLTWH(margin, margin, size.x - margin * 2, size.y - margin * 2),
// playPaint,
// );
//
// final linePaint = Paint()
// ..color = Colors.brown.shade800
// ..strokeWidth = 3
// ..style = PaintingStyle.stroke;
//
// canvas.drawRect(
// Rect.fromLTWH(margin, margin, size.x - margin * 2, size.y - margin * 2),
// linePaint,
// );
//
// final pocketPaint = Paint()..color = Colors.black;
// const pocketRadius = 25.0;
//
// canvas.drawCircle(const Offset(0, 0), pocketRadius, pocketPaint);
// canvas.drawCircle(Offset(size.x, 0), pocketRadius, pocketPaint);
// canvas.drawCircle(Offset(0, size.y), pocketRadius, pocketPaint);
// canvas.drawCircle(Offset(size.x, size.y), pocketRadius, pocketPaint);
//
// final centerPaint = Paint()
// ..color = Colors.brown.shade300
// ..style = PaintingStyle.stroke
// ..strokeWidth = 2;
//
// canvas.drawCircle(
// Offset(size.x / 2, size.y / 2),
// 50,
// centerPaint,
// );
//
// final strikerLinePaint = Paint()
// ..color = Colors.brown.shade400
// ..strokeWidth = 2;
//
// canvas.drawLine(
// Offset(margin + 50, size.y - margin - 80),
// Offset(size.x - margin - 50, size.y - margin - 80),
// strikerLinePaint,
// );
//
// canvas.drawLine(
// Offset(margin + 50, margin + 80),
// Offset(size.x - margin - 50, margin + 80),
// strikerLinePaint,
// );
// }
// }
//
// /// ==================== COIN COMPONENT ====================
// class Coin extends PositionComponent {
// final String id;
// final Color color;
// Vector2 velocity = Vector2.zero();
// double radius;
// double mass;
//
// Coin({
// required this.id,
// required Vector2 position,
// required this.radius,
// required this.color,
// this.mass = 1.0,
// }) : super(
// position: position,
// size: Vector2.all(radius * 2),
// anchor: Anchor.center,
// );
//
// void applyPhysics(double dt, double boardSize) {
// position += velocity * dt;
//
// velocity *= pow(0.995, dt * 60).toDouble();
// if (velocity.length < 0.5) velocity = Vector2.zero();
//
// if (position.x < radius) {
// position.x = radius;
// velocity.x = -velocity.x * 0.7;
// } else if (position.x > boardSize - radius) {
// position.x = boardSize - radius;
// velocity.x = -velocity.x * 0.7;
// }
// if (position.y < radius) {
// position.y = radius;
// velocity.y = -velocity.y * 0.7;
// } else if (position.y > boardSize - radius) {
// position.y = boardSize - radius;
// velocity.y = -velocity.y * 0.7;
// }
// }
//
// Coin cloneCoin() {
// return Coin(
// id: id,
// position: position.clone(),
// radius: radius,
// color: color,
// mass: mass,
// );
// }
//
// @override
// void render(Canvas canvas) {
// final paint = Paint()..color = color;
// canvas.drawCircle(Offset.zero, radius, paint);
//
// final borderPaint = Paint()
// ..color = color == Colors.white ? Colors.grey : Colors.grey.shade700
// ..style = PaintingStyle.stroke
// ..strokeWidth = 1.5;
// canvas.drawCircle(Offset.zero, radius, borderPaint);
//
// if (id == 'q') {
// final innerPaint = Paint()..color = Colors.yellow;
// canvas.drawCircle(Offset.zero, radius * 0.4, innerPaint);
// }
//
// final highlightPaint = Paint()
// ..color = Colors.white.withOpacity(0.3);
// canvas.drawCircle(
// Offset(-radius * 0.3, -radius * 0.3),
// radius * 0.3,
// highlightPaint,
// );
// }
// }
//
// /// ==================== STRIKER COMPONENT ====================
// class Striker extends PositionComponent with DragCallbacks {
// final CarromBoardGame gameRef;
// Vector2 velocity = Vector2.zero();
// double radius = 22.0;
// double mass = 2.0;
//
// bool _dragging = false;
// Vector2 _dragStart = Vector2.zero();
// Vector2 _initialPosition = Vector2.zero();
//
// Striker({
// required Vector2 position,
// required this.gameRef,
// }) : super(
// position: position,
// size: Vector2.all(44),
// anchor: Anchor.center,
// );
//
// void applyPhysics(double dt, double boardSize) {
// position += velocity * dt;
//
// velocity *= pow(0.994, dt * 60).toDouble();
// if (velocity.length < 0.5) velocity = Vector2.zero();
//
// if (position.x < radius) {
// position.x = radius;
// velocity.x = -velocity.x * 0.7;
// } else if (position.x > boardSize - radius) {
// position.x = boardSize - radius;
// velocity.x = -velocity.x * 0.7;
// }
// if (position.y < radius) {
// position.y = radius;
// velocity.y = -velocity.y * 0.7;
// } else if (position.y > boardSize - radius) {
// position.y = boardSize - radius;
// velocity.y = -velocity.y * 0.7;
// }
// }
//
// @override
// bool onDragStart(DragStartEvent event) {
// if (velocity.length > 4.0) return false;
// _dragging = true;
// _dragStart = event.localPosition;
// _initialPosition = position.clone();
// return true;
// }
//
// @override
// bool onDragUpdate(DragUpdateEvent event) {
// if (!_dragging) return false;
//
// position = _initialPosition + (event.localEndPosition - _dragStart);
//
// position.x = position.x.clamp(radius, 600 - radius);
// position.y = position.y.clamp(radius, 600 - radius);
//
// return true;
// }
//
// @override
// bool onDragEnd(DragEndEvent event) {
// if (!_dragging) return false;
// _dragging = false;
//
// velocity = event.velocity / 2;
//
// if (velocity.length > 500) {
// velocity = velocity.normalized() * 500;
// }
//
// final myUid = gameRef.scores.keys.firstWhere(
// (k) => k == FirebaseAuth.instance.currentUser?.uid,
// orElse: () => '');
//
// if (myUid.isNotEmpty && gameRef.onShot != null) {
// gameRef.localPlayerShot(myUid, position, velocity);
// }
//
// return true;
// }
//
// @override
// void render(Canvas canvas) {
// final outerPaint = Paint()..color = const Color(0xFF1565C0);
// canvas.drawCircle(Offset.zero, radius, outerPaint);
//
// final middlePaint = Paint()..color = const Color(0xFF42A5F5);
// canvas.drawCircle(Offset.zero, radius * 0.75, middlePaint);
//
// final centerPaint = Paint()..color = Colors.white;
// canvas.drawCircle(Offset.zero, radius * 0.35, centerPaint);
//
// final borderPaint = Paint()
// ..color = Colors.blue.shade900
// ..style = PaintingStyle.stroke
// ..strokeWidth = 2;
// canvas.drawCircle(Offset.zero, radius, borderPaint);
// }
// }
//
// /// ==================== POCKET EFFECT ====================
// class PocketEffect extends PositionComponent {
// double life = 0.8;
// Color color;
//
// PocketEffect({
// required Vector2 position,
// this.color = Colors.orange,
// }) : super(
// position: position,
// size: Vector2.all(1),
// anchor: Anchor.center,
// );
//
// @override
// void update(double dt) {
// super.update(dt);
// life -= dt;
// if (life <= 0) removeFromParent();
// }
//
// @override
// void render(Canvas canvas) {
// final t = life.clamp(0.0, 1.0);
// final r = (1.0 - t) * 40.0;
// final paint = Paint()..color = color.withOpacity(t);
// canvas.drawCircle(Offset.zero, r, paint);
// }
// }



// lib/feature/games/carrom/carrom_game_screen.dart
// STATUS: FINAL UI POLISHED VERSION ✅
//
// Features:
// - Realistic 3D Graphics (Wood texture, shadows, gloss)
// - Perfect Square Aspect Ratio
// - 30s Turn Timer
// - Queen cover rules & Fouls
// - Physics & Audio
//
// import 'dart:async';
// import 'dart:math';
// import 'dart:ui'; // For gradients and filters
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flame/game.dart';
// import 'package:flame/components.dart' hide Timer;
// import 'package:flame/events.dart';
//
// import 'carrom_result_screen.dart';
// import 'services/carrom_audio_service.dart';
//
// /// ==================== MAIN GAME SCREEN ====================
// class CarromGameScreen extends StatefulWidget {
//   final String matchId;
//
//   const CarromGameScreen({Key? key, required this.matchId}) : super(key: key);
//
//   @override
//   State<CarromGameScreen> createState() => _CarromGameScreenState();
// }
//
// class _CarromGameScreenState extends State<CarromGameScreen> {
//   // Firebase
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   // Audio
//   final CarromAudioService _audioService = CarromAudioService();
//
//   // Game timing
//   DateTime? _gameStartTime;
//
//   // Turn Timer
//   Timer? _turnTimer;
//   int _turnTimeLeft = 30;
//   static const int _turnDuration = 30;
//
//   // Subscriptions
//   StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _matchSub;
//
//   // Game state
//   Map<String, dynamic>? _matchData;
//   late CarromBoardGame _game;
//   bool _isHost = false;
//   String? _myUid;
//   String? _opponentUid;
//   String _status = 'waiting';
//   String _turnUid = '';
//   bool _loading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _myUid = _auth.currentUser?.uid;
//     _game = CarromBoardGame(
//       onShot: _onLocalShot,
//       audioService: _audioService,
//     );
//     _audioService.initialize();
//     _listenMatch();
//   }
//
//   @override
//   void dispose() {
//     _turnTimer?.cancel();
//     _matchSub?.cancel();
//     _game.onDispose();
//     super.dispose();
//   }
//
//   // ==================== FIREBASE LISTENER ====================
//   Future<void> _listenMatch() async {
//     final ref = _firestore.collection('carrom_matches').doc(widget.matchId);
//
//     _matchSub = ref.snapshots().listen((snap) {
//       if (!snap.exists) return;
//
//       final data = snap.data()!;
//       _matchData = data;
//
//       final newTurnUid = data['turn'] as String? ?? '';
//       final newStatus = data['status'] as String? ?? 'waiting';
//
//       if (newStatus == 'started' && newTurnUid != _turnUid) {
//         _startTurnTimer();
//       }
//
//       setState(() {
//         _status = newStatus;
//         _turnUid = newTurnUid;
//         _loading = false;
//       });
//
//       if (_status == 'started' && _gameStartTime == null) {
//         _gameStartTime = DateTime.now();
//       }
//
//       final players = Map<String, dynamic>.from(data['players'] ?? {});
//       if (_myUid != null && players.isNotEmpty) {
//         _opponentUid = players.keys.firstWhere(
//               (k) => k != _myUid,
//           orElse: () => '',
//         );
//         _isHost = (data['host'] == _myUid);
//
//         final uids = players.keys.toList();
//         if (uids.length >= 2) {
//           _game.playerColorForUid.clear();
//           _game.playerColorForUid[uids[0]] = 'white';
//           _game.playerColorForUid[uids[1]] = 'black';
//         } else if (_myUid != null) {
//           _game.playerColorForUid[_myUid!] = 'white';
//         }
//       }
//
//       if (data['boardState'] != null) {
//         try {
//           _game.setBoardState(Map<String, dynamic>.from(data['boardState']));
//         } catch (_) {}
//       }
//
//       final lastMove = data['lastMove'] as Map<String, dynamic>?;
//       if (lastMove != null) {
//         final fromUid = lastMove['fromUid'] as String?;
//         if (fromUid != null && fromUid != _myUid) {
//           _game.applyRemoteShot(lastMove);
//         }
//       }
//
//       if (_status == 'finished') {
//         _turnTimer?.cancel();
//         final scores = Map<String, dynamic>.from(data['scores'] ?? {});
//         _showResultAndExit(scores);
//       }
//     });
//   }
//
//   void _startTurnTimer() {
//     _turnTimer?.cancel();
//     setState(() => _turnTimeLeft = _turnDuration);
//
//     _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_turnTimeLeft > 0) {
//         setState(() => _turnTimeLeft--);
//       } else {
//         _turnTimer?.cancel();
//         if (_turnUid == _myUid && _status == 'started') {
//           _handleTurnTimeout();
//         }
//       }
//     });
//   }
//
//   Future<void> _handleTurnTimeout() async {
//     if (!mounted) return;
//
//     final ref = _firestore.collection('carrom_matches').doc(widget.matchId);
//     final opponent = _opponentUid ?? _myUid;
//
//     await ref.update({
//       'turn': opponent,
//     });
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text("Time's up! Turn passed."),
//         backgroundColor: Colors.red,
//         duration: Duration(seconds: 2),
//       ),
//     );
//   }
//
//   Future<void> _onLocalShot(
//       Map<String, dynamic> shotData,
//       Map<String, dynamic> boardStateAfterShot,
//       List<String> pocketed,
//       List<String> fouls,
//       ) async {
//     _turnTimer?.cancel();
//
//     _audioService.playStrike();
//
//     if (pocketed.isNotEmpty) {
//       for (int i = 0; i < pocketed.length; i++) {
//         Future.delayed(Duration(milliseconds: i * 150), () {
//           _audioService.playPocket();
//         });
//       }
//     }
//
//     if (fouls.isNotEmpty) {
//       _audioService.playFoul();
//     }
//
//     final ref = _firestore.collection('carrom_matches').doc(widget.matchId);
//     final myUid = _myUid!;
//     final opponent = _opponentUid ?? myUid;
//
//     bool playerKeepsTurn = false;
//     final color = _game.playerColorForUid[myUid] ?? 'white';
//
//     for (final id in pocketed) {
//       if (id == 'q') {
//         if ((boardStateAfterShot['queenCoveredBy'] ?? null) == myUid) {
//           playerKeepsTurn = true;
//         }
//       } else if (_isCoinOfColor(id, color)) {
//         playerKeepsTurn = true;
//       }
//     }
//
//     final writeMap = <String, dynamic>{
//       'lastMove': {
//         'fromUid': myUid,
//         'shot': shotData,
//         'pocketed': pocketed,
//         'fouls': fouls,
//         'ts': FieldValue.serverTimestamp(),
//       },
//       'boardState': boardStateAfterShot,
//       'scores': boardStateAfterShot['scores'] ?? {},
//       'turn': playerKeepsTurn ? myUid : opponent,
//     };
//
//     final remaining = (boardStateAfterShot['remaining'] ?? 0) as int;
//     final scores = Map<String, dynamic>.from(boardStateAfterShot['scores'] ?? {});
//     final myScore = (scores[myUid] ?? 0) as int;
//     final opScore = (scores[opponent] ?? 0) as int;
//
//     if (myScore >= 25 || opScore >= 25 || remaining == 0) {
//       writeMap['status'] = 'finished';
//       writeMap['finishedAt'] = FieldValue.serverTimestamp();
//       writeMap['scores'] = scores;
//     }
//
//     await ref.update(writeMap);
//   }
//
//   bool _isCoinOfColor(String id, String color) {
//     if (id == 'q') return false;
//     if (color == 'white') return id.startsWith('w');
//     if (color == 'black') return id.startsWith('b');
//     return false;
//   }
//
//   void _showResultAndExit(Map<String, dynamic> scores) {
//     final myScore = (scores[_myUid] ?? 0) as int;
//     final oppScore = (scores[_opponentUid] ?? 0) as int;
//
//     if (myScore > oppScore) {
//       _audioService.playVictory();
//     } else {
//       _audioService.playDefeat();
//     }
//
//     int? gameDuration;
//     if (_gameStartTime != null) {
//       gameDuration = DateTime.now().difference(_gameStartTime!).inSeconds;
//     }
//
//     String opponentName = 'Opponent';
//     if (_matchData != null) {
//       final players = Map<String, dynamic>.from(_matchData!['players'] ?? {});
//       if (_opponentUid != null) {
//         final userData = players[_opponentUid];
//         if (userData is Map && userData['displayName'] != null) {
//           opponentName = userData['displayName'].toString();
//         }
//       }
//     }
//
//     if (!mounted) return;
//
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(
//         builder: (_) => CarromResultScreen(
//           matchId: widget.matchId,
//           myScore: myScore,
//           opponentScore: oppScore,
//           opponentUid: _opponentUid ?? '',
//           opponentName: opponentName,
//           gameDurationSeconds: gameDuration,
//         ),
//       ),
//     );
//   }
//
//   Future<void> _onReplayPressed() async {
//     if (!_isHost) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Only host can restart match')),
//       );
//       return;
//     }
//
//     final ref = _firestore.collection('carrom_matches').doc(widget.matchId);
//     final initialBoard = _game.initialBoardState();
//
//     await ref.update({
//       'boardState': initialBoard,
//       'lastMove': null,
//       'status': 'started',
//       'turn': _matchData?['host'] ?? _myUid,
//       'scores': initialBoard['scores'],
//     });
//
//     _game.resetBoard();
//     _gameStartTime = DateTime.now();
//     _startTurnTimer();
//   }
//
//   // ==================== UI BUILDER ====================
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       // Dark Wood Background
//       backgroundColor: const Color(0xFF2A1C10),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator(color: Colors.amber))
//           : SafeArea(
//         child: Column(
//           children: [
//             // 1. Custom Game AppBar
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.6),
//                 boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   IconButton(
//                     icon: const Icon(Icons.arrow_back_ios, color: Colors.amber),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                   const Text(
//                     "CARROM CLASH",
//                     style: TextStyle(
//                         color: Colors.amber,
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                         letterSpacing: 2),
//                   ),
//                   Row(
//                     children: [
//                       IconButton(
//                         icon: Icon(
//                           _audioService.isMuted ? Icons.volume_off : Icons.volume_up,
//                           color: Colors.amber,
//                         ),
//                         onPressed: () => setState(() => _audioService.toggleMute()),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.refresh, color: Colors.amber),
//                         onPressed: _onReplayPressed,
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//
//             // 2. HUD (Score Board)
//             _buildHUD(),
//
//             const Spacer(),
//
//             // 3. THE BOARD (Centerpiece)
//             // AspectRatio ensures the board is always a Perfect Square
//             Center(
//               child: Container(
//                 constraints: const BoxConstraints(maxWidth: 400),
//                 child: AspectRatio(
//                   aspectRatio: 1.0,
//                   child: Container(
//                     margin: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(24),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.8),
//                           blurRadius: 20,
//                           offset: const Offset(0, 10),
//                         ),
//                       ],
//                     ),
//                     child: ClipRRect(
//                       borderRadius: BorderRadius.circular(24),
//                       child: GameWidget(game: _game),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//
//             const Spacer(),
//
//             // 4. Bottom Status Bar
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.5),
//                 borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.touch_app, color: Colors.white.withOpacity(0.7), size: 20),
//                   const SizedBox(width: 8),
//                   Text(
//                     _status == 'started'
//                         ? (_turnUid == _myUid
//                         ? 'YOUR TURN - Drag Striker to Shoot!'
//                         : 'Opponent is thinking...')
//                         : 'Waiting for game to start...',
//                     style: TextStyle(
//                       color: Colors.white.withOpacity(0.9),
//                       fontSize: 14,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHUD() {
//     final players = Map<String, dynamic>.from(_matchData?['players'] ?? {});
//
//     String getSafeName(String? uid, String defaultName) {
//       if (uid == null) return defaultName;
//       final userData = players[uid];
//       if (userData != null && userData is Map) {
//         return userData['displayName']?.toString() ?? defaultName;
//       }
//       return defaultName;
//     }
//
//     final myName = getSafeName(_myUid, 'You');
//     final opName = getSafeName(_opponentUid, _status == 'waiting' ? 'Waiting...' : 'Opponent');
//
//     final myScore = _game.scores[_myUid] ?? 0;
//     final opScore = _game.scores[_opponentUid] ?? 0;
//     final isMyTurn = _turnUid == _myUid;
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.3),
//         border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           _buildPlayerInfo(myName, myScore, isMyTurn, true),
//
//           // Timer / Turn Indicator
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//             decoration: BoxDecoration(
//               color: isMyTurn ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(color: isMyTurn ? Colors.green : Colors.red),
//             ),
//             child: Column(
//               children: [
//                 Text(
//                   isMyTurn ? "YOUR TURN" : "OPPONENT",
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                     color: isMyTurn ? Colors.green : Colors.red,
//                   ),
//                 ),
//                 if (_status == 'started')
//                   Text(
//                     '$_turnTimeLeft s',
//                     style: TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                       color: _turnTimeLeft < 10 ? Colors.redAccent : Colors.white,
//                     ),
//                   ),
//               ],
//             ),
//           ),
//
//           _buildPlayerInfo(opName, opScore, !isMyTurn, false),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildPlayerInfo(String name, int score, bool isActive, bool isMe) {
//     return Column(
//       crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
//       children: [
//         Text(
//           name.length > 10 ? '${name.substring(0, 8)}..' : name,
//           style: TextStyle(
//             color: isActive ? Colors.amber : Colors.white70,
//             fontWeight: FontWeight.bold,
//             fontSize: 14,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           '$score pts',
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// /// ==================== CARROM BOARD GAME LOGIC ====================
// class CarromBoardGame extends FlameGame with HasCollisionDetection {
//   final double pocketRadius = 28.0;
//   late double boardSize;
//
//   final Map<String, Coin> coins = {};
//   late Striker striker;
//
//   final Map<String, int> scores = {};
//   final Map<String, int> lives = {};
//   final Map<String, String> playerColorForUid = {};
//
//   final CarromAudioService? audioService;
//   final Future<void> Function(
//       Map<String, dynamic> shotData,
//       Map<String, dynamic> boardStateAfterShot,
//       List<String> pocketed,
//       List<String> fouls,
//       )? onShot;
//
//   Map<String, Coin> _preShotCoinSnapshot = {};
//   Map<String, dynamic>? _lastLocalShot;
//   bool _disposed = false;
//
//   CarromBoardGame({this.onShot, this.audioService});
//
//   @override
//   Future<void> onLoad() async {
//     await super.onLoad();
//
//     // ✅ Game widget ka actual size le lo
//     boardSize = min(size.x, size.y);
//
//     // (optional) camera default hi theek hai, kuch set karne ki need nahi
//     // camera.viewfinder.anchor = Anchor.topLeft;  // isko hata bhi sakte ho
//
//     // Board add karo
//     add(CarromBoard(size: Vector2.all(boardSize)));
//
//     // Striker & coins center ke hisaab se
//     final center = Vector2(boardSize / 2, boardSize / 2);
//
//     striker = Striker(
//       position: center + Vector2(0, boardSize / 2 - 100),
//       gameRef: this,
//     );
//     add(striker);
//
//     _initCoins(center);
//   }
//
//
//   void _initCoins(Vector2 center) {
//     coins.clear();
//     // Queen
//     coins['q'] = Coin(id: 'q', position: center.clone(), radius: 12.0, color: Colors.red, mass: 1.2);
//     add(coins['q']!);
//
//     const double r = 35.0;
//     int b = 0, w = 0;
//     for (int i = 0; i < 18; i++) {
//       final double ang = (i / 18) * pi * 2;
//       if (i % 2 == 0 && b < 9) {
//         final coin = Coin(id: 'b$b', position: center + Vector2(cos(ang), sin(ang)) * (r + 8.0), radius: 10.0, color: Colors.black87, mass: 1.0);
//         coins['b$b'] = coin;
//         add(coin);
//         b++;
//       } else if (i % 2 == 1 && w < 9) {
//         final coin = Coin(id: 'w$w', position: center + Vector2(cos(ang), sin(ang)) * (r + 22.0), radius: 10.0, color: Colors.white, mass: 1.0);
//         coins['w$w'] = coin;
//         add(coin);
//         w++;
//       }
//     }
//     scores.clear();
//     lives.clear();
//   }
//
//   Map<String, dynamic> initialBoardState() {
//     final coinMap = <String, Map<String, double>>{};
//     coins.forEach((k, c) => coinMap[k] = {'x': c.position.x, 'y': c.position.y});
//     return {'coins': coinMap, 'scores': scores, 'remaining': coins.length};
//   }
//
//   void resetBoard() {
//     for (final coin in coins.values) coin.removeFromParent();
//     coins.clear();
//     final center = Vector2(boardSize / 2, boardSize / 2);
//     striker.position = center + Vector2(0, boardSize / 2 - 100);
//     striker.velocity = Vector2.zero();
//     _initCoins(center);
//     _lastLocalShot = null;
//   }
//
//   void setBoardState(Map<String, dynamic> board) {
//     final coinMap = Map<String, dynamic>.from(board['coins'] ?? {});
//     final currentIds = coins.keys.toList();
//     for (final id in currentIds) {
//       if (!coinMap.containsKey(id)) {
//         coins[id]?.removeFromParent();
//         coins.remove(id);
//       }
//     }
//     coinMap.forEach((id, pos) {
//       final p = Map<String, dynamic>.from(pos);
//       final x = (p['x'] ?? 0) as num;
//       final y = (p['y'] ?? 0) as num;
//       if (coins.containsKey(id)) {
//         coins[id]!.position = Vector2(x.toDouble(), y.toDouble());
//         coins[id]!.velocity = Vector2.zero();
//       } else {
//         Color color = id == 'q' ? Colors.red : (id.startsWith('w') ? Colors.white : Colors.black87);
//         final coin = Coin(id: id, position: Vector2(x.toDouble(), y.toDouble()), radius: id == 'q' ? 12.0 : 10.0, color: color);
//         coins[id] = coin;
//         add(coin);
//       }
//     });
//     final sc = Map<String, dynamic>.from(board['scores'] ?? {});
//     sc.forEach((k, v) => scores[k] = (v as num).toInt());
//   }
//
//   void applyRemoteShot(Map<String, dynamic> lastMove) {
//     final shot = lastMove['shot'] as Map<String, dynamic>? ?? {};
//     final vx = (shot['vx'] ?? 0) as num;
//     final vy = (shot['vy'] ?? 0) as num;
//     final sx = (shot['sx'] ?? 0) as num;
//     final sy = (shot['sy'] ?? 0) as num;
//     striker.position = Vector2(sx.toDouble(), sy.toDouble());
//     striker.velocity = Vector2(vx.toDouble(), vy.toDouble());
//   }
//
//   void localPlayerShot(String fromUid, Vector2 strikerPos, Vector2 velocityVector) {
//     _preShotCoinSnapshot = { for (final e in coins.entries) e.key: e.value.cloneCoin() };
//     striker.position = strikerPos.clone();
//     striker.velocity = velocityVector.clone();
//     _lastLocalShot = {
//       'fromUid': fromUid,
//       'sx': strikerPos.x,
//       'sy': strikerPos.y,
//       'vx': velocityVector.x,
//       'vy': velocityVector.y,
//       'timestamp': DateTime.now().millisecondsSinceEpoch,
//     };
//   }
//
//   @override
//   void update(double dt) {
//     super.update(dt);
//     if (_disposed) return;
//     striker.applyPhysics(dt, boardSize);
//     for (final c in coins.values) c.applyPhysics(dt, boardSize);
//     for (final c in coins.values) _handleCircleCollision(striker, c);
//     final coinList = coins.values.toList();
//     for (int i = 0; i < coinList.length; i++) {
//       for (int j = i + 1; j < coinList.length; j++) {
//         _handleCircleCollision(coinList[i], coinList[j]);
//       }
//     }
//
//     final pockets = [Vector2(0, 0), Vector2(boardSize, 0), Vector2(0, boardSize), Vector2(boardSize, boardSize)];
//     final pocketed = <String>[];
//     for (final entry in coins.entries.toList()) {
//       final c = entry.value;
//       for (final p in pockets) {
//         if ((c.position - p).length <= pocketRadius) {
//           pocketed.add(entry.key);
//           break;
//         }
//       }
//     }
//     if (pocketed.isNotEmpty) {
//       for (final id in pocketed) {
//         final c = coins.remove(id);
//         if (c != null) {
//           c.removeFromParent();
//           add(PocketEffect(position: c.position.clone()));
//         }
//       }
//     }
//     final moving = striker.velocity.length > 2.0 || coins.values.any((c) => c.velocity.length > 2.0);
//     if (!moving && _lastLocalShot != null) _finalizeShot(pockets);
//   }
//
//   void _finalizeShot(List<Vector2> pockets) {
//     final beforeIds = Set<String>.from(_preShotCoinSnapshot.keys);
//     final afterIds = Set<String>.from(coins.keys);
//     final pocketedIds = beforeIds.difference(afterIds).toList();
//     final fouls = <String>[];
//
//     for (final p in pockets) {
//       if ((striker.position - p).length <= pocketRadius) {
//         fouls.add('striker_pocketed');
//         striker.position = Vector2(boardSize / 2, boardSize / 2 + boardSize / 2 - 100);
//         striker.velocity = Vector2.zero();
//         add(PocketEffect(position: p.clone(), color: Colors.yellow));
//         audioService?.playFoul();
//       }
//     }
//
//     final shotFrom = _lastLocalShot!['fromUid'] as String;
//     scores.putIfAbsent(shotFrom, () => 0);
//     lives.putIfAbsent(shotFrom, () => 1);
//
//     if (onShot != null) {
//       final shotData = {
//         'sx': _lastLocalShot!['sx'], 'sy': _lastLocalShot!['sy'],
//         'vx': _lastLocalShot!['vx'], 'vy': _lastLocalShot!['vy'],
//       };
//       try { onShot!(shotData, _serializeBoardState(), pocketedIds, fouls); } catch (_) {}
//     }
//     _lastLocalShot = null;
//   }
//
//   Map<String, dynamic> _serializeBoardState() {
//     final coinsMap = <String, Map<String, double>>{};
//     coins.forEach((k, c) => coinsMap[k] = {'x': c.position.x, 'y': c.position.y});
//     return {'coins': coinsMap, 'scores': Map<String, int>.from(scores), 'lives': Map<String, int>.from(lives), 'remaining': coins.length};
//   }
//
//   void _handleCircleCollision(dynamic a, dynamic b) {
//     final diff = a.position - b.position;
//     final dist = diff.length;
//     final minDist = a.radius + b.radius;
//     if (dist <= 0.0 || dist >= minDist) return;
//     final normal = diff / dist;
//     final overlap = minDist - dist;
//     a.position += normal * (overlap * 0.5);
//     b.position -= normal * (overlap * 0.5);
//     final rel = a.velocity - b.velocity;
//     final velAlongNormal = rel.dot(normal);
//     if (velAlongNormal > 0) return;
//     const restitution = 0.85;
//     final ma = a.mass as double;
//     final mb = b.mass as double;
//     final j = -(1 + restitution) * velAlongNormal / (1 / ma + 1 / mb);
//     final impulse = normal * j;
//     a.velocity += impulse / ma;
//     b.velocity -= impulse / mb;
//     audioService?.playCollision();
//   }
//
//   void onDispose() => _disposed = true;
//   @override void onRemove() { _disposed = true; super.onRemove(); }
// }
//
// /// ==================== GRAPHICS COMPONENTS ====================
//
// // 1. Realistic Carrom Board
// class CarromBoard extends PositionComponent {
//   CarromBoard({required Vector2 size}) : super(size: size);
//
//   @override
//   void render(Canvas canvas) {
//     // Frame Gradient (Dark Wood)
//     final framePaint = Paint()
//       ..shader = const LinearGradient(
//         colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
//         begin: Alignment.topLeft,
//         end: Alignment.bottomRight,
//       ).createShader(size.toRect());
//     canvas.drawRect(size.toRect(), framePaint);
//
//     // Playing Surface (Light Cream)
//     const margin = 25.0;
//     final surfaceRect = Rect.fromLTWH(margin, margin, size.x - margin * 2, size.y - margin * 2);
//     canvas.drawRect(surfaceRect, Paint()..color = const Color(0xFFF3E5AB));
//
//     // Board Lines
//     final linePaint = Paint()..color = Colors.black87..strokeWidth = 1.5..style = PaintingStyle.stroke;
//     canvas.drawRect(Rect.fromLTWH(margin + 5, margin + 5, size.x - (margin * 2) - 10, size.y - (margin * 2) - 10), linePaint);
//
//     // Pockets (Holes)
//     final pocketPaint = Paint()..color = const Color(0xFF1A1A1A);
//     final pockets = [Offset(margin, margin), Offset(size.x - margin, margin), Offset(margin, size.y - margin), Offset(size.x - margin, size.y - margin)];
//     for (final p in pockets) canvas.drawCircle(p, 22.0, pocketPaint);
//
//     // Striker Lines
//     final strikerPaint = Paint()..color = Colors.black..strokeWidth = 1.5;
//     canvas.drawLine(Offset(margin + 40, size.y - margin - 80), Offset(size.x - margin - 40, size.y - margin - 80), strikerPaint);
//     canvas.drawLine(Offset(margin + 40, margin + 80), Offset(size.x - margin - 40, margin + 80), strikerPaint);
//
//     // Center Design
//     final center = Offset(size.x / 2, size.y / 2);
//     canvas.drawCircle(center, 50, Paint()..color = const Color(0xFF8D6E63)..style = PaintingStyle.stroke..strokeWidth = 2);
//     canvas.drawCircle(center, 10, Paint()..color = Colors.red);
//   }
// }
//
// // 2. 3D Coin
// class Coin extends PositionComponent {
//   final String id;
//   final Color color;
//   Vector2 velocity = Vector2.zero();
//   double radius;
//   double mass;
//
//   Coin({required this.id, required Vector2 position, required this.radius, required this.color, this.mass = 1.0})
//       : super(position: position, size: Vector2.all(radius * 2), anchor: Anchor.center);
//
//   void applyPhysics(double dt, double boardSize) {
//     position += velocity * dt;
//     velocity *= pow(0.995, dt * 60).toDouble();
//     if (velocity.length < 0.5) velocity = Vector2.zero();
//
//     final min = radius;
//     final max = boardSize - radius;
//     if (position.x < min) { position.x = min; velocity.x *= -0.7; }
//     if (position.x > max) { position.x = max; velocity.x *= -0.7; }
//     if (position.y < min) { position.y = min; velocity.y *= -0.7; }
//     if (position.y > max) { position.y = max; velocity.y *= -0.7; }
//   }
//
//   Coin cloneCoin() => Coin(id: id, position: position.clone(), radius: radius, color: color, mass: mass);
//
//   @override
//   void render(Canvas canvas) {
//     // Shadow
//     canvas.drawCircle(const Offset(2, 2), radius, Paint()..color = Colors.black.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
//     // Body
//     final paint = Paint()..color = color;
//     if (color == Colors.black87) paint.color = const Color(0xFF212121);
//     canvas.drawCircle(Offset.zero, radius, paint);
//     // Inner Ring
//     canvas.drawCircle(Offset.zero, radius * 0.7, Paint()..color = Colors.black12..style = PaintingStyle.stroke..strokeWidth = 2);
//     // Highlight
//     canvas.drawOval(Rect.fromLTWH(-radius * 0.5, -radius * 0.6, radius * 0.6, radius * 0.3), Paint()..color = Colors.white.withOpacity(0.2));
//   }
// }
//
// // 3. 3D Striker
// class Striker extends PositionComponent with DragCallbacks {
//   final CarromBoardGame gameRef;
//   Vector2 velocity = Vector2.zero();
//   double radius = 22.0;
//   double mass = 2.0;
//   bool _dragging = false;
//   Vector2 _dragStart = Vector2.zero();
//   Vector2 _initialPosition = Vector2.zero();
//
//   Striker({required Vector2 position, required this.gameRef})
//       : super(position: position, size: Vector2.all(44), anchor: Anchor.center);
//
//   void applyPhysics(double dt, double boardSize) {
//     position += velocity * dt;
//     velocity *= pow(0.994, dt * 60).toDouble();
//     if (velocity.length < 0.5) velocity = Vector2.zero();
//
//     final min = radius;
//     final max = boardSize - radius;
//     if (position.x < min) { position.x = min; velocity.x *= -0.7; }
//     if (position.x > max) { position.x = max; velocity.x *= -0.7; }
//     if (position.y < min) { position.y = min; velocity.y *= -0.7; }
//     if (position.y > max) { position.y = max; velocity.y *= -0.7; }
//   }
//
//   @override
//   bool onDragStart(DragStartEvent event) {
//     if (velocity.length > 4.0) return false;
//     _dragging = true;
//     _dragStart = event.localPosition;
//     _initialPosition = position.clone();
//     return true;
//   }
//
//   @override
//   bool onDragUpdate(DragUpdateEvent event) {
//     if (!_dragging) return false;
//     position = _initialPosition + (event.localEndPosition - _dragStart);
//     position.x = position.x.clamp(radius, 600 - radius);
//     position.y = position.y.clamp(radius, 600 - radius);
//     return true;
//   }
//
//   @override
//   bool onDragEnd(DragEndEvent event) {
//     if (!_dragging) return false;
//     _dragging = false;
//     velocity = event.velocity / 2;
//     if (velocity.length > 500) velocity = velocity.normalized() * 500;
//
//     final myUid = gameRef.scores.keys.firstWhere((k) => k == FirebaseAuth.instance.currentUser?.uid, orElse: () => '');
//     if (myUid.isNotEmpty && gameRef.onShot != null) gameRef.localPlayerShot(myUid, position, velocity);
//     return true;
//   }
//
//   @override
//   void render(Canvas canvas) {
//     // Shadow
//     canvas.drawCircle(const Offset(3, 3), radius, Paint()..color = Colors.black.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
//     // Body (Cream Acrylic)
//     final paint = Paint()..shader = RadialGradient(colors: [Colors.yellow.shade50, Colors.orange.shade100]).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
//     canvas.drawCircle(Offset.zero, radius, paint);
//     // Ring
//     canvas.drawCircle(Offset.zero, radius * 0.7, Paint()..color = Colors.blue.shade900..style = PaintingStyle.stroke..strokeWidth = 3);
//     // Shine
//     canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius - 2), pi, pi/2, false, Paint()..color = Colors.white.withOpacity(0.6)..style = PaintingStyle.fill);
//   }
// }
//
// // 4. Pocket Effect
// class PocketEffect extends PositionComponent {
//   double life = 0.8;
//   Color color;
//   PocketEffect({required Vector2 position, this.color = Colors.orange}) : super(position: position, size: Vector2.all(1), anchor: Anchor.center);
//
//   @override void update(double dt) { super.update(dt); life -= dt; if (life <= 0) removeFromParent(); }
//   @override void render(Canvas canvas) {
//     final r = (1.0 - life.clamp(0.0, 1.0)) * 40.0;
//     canvas.drawCircle(Offset.zero, r, Paint()..color = color.withOpacity(life.clamp(0.0, 1.0)));
//   }
// }

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart' hide Timer;
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'carrom_result_screen.dart';
import 'services/carrom_audio_service.dart';

/// Board margin (same for physics + drawing)
const double kBoardMargin = 25.0;

/// ==================== MAIN GAME SCREEN ====================
class CarromGameScreen extends StatefulWidget {
  final String matchId;

  const CarromGameScreen({Key? key, required this.matchId}) : super(key: key);

  @override
  State<CarromGameScreen> createState() => _CarromGameScreenState();
}

class _CarromGameScreenState extends State<CarromGameScreen> {
  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Audio
  final CarromAudioService _audioService = CarromAudioService();

  // Game timing
  DateTime? _gameStartTime;

  // Turn Timer
  Timer? _turnTimer;
  int _turnTimeLeft = 30;
  static const int _turnDuration = 30;

  // Subscriptions
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _matchSub;

  // Game state
  Map<String, dynamic>? _matchData;
  late CarromBoardGame _game;
  bool _isHost = false;
  String? _myUid;
  String? _opponentUid;
  String _status = 'waiting';
  String _turnUid = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _myUid = _auth.currentUser?.uid;
    _game = CarromBoardGame(
      onShot: _onLocalShot,
      audioService: _audioService,
    );
    _audioService.initialize();
    _listenMatch();
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _matchSub?.cancel();
    super.dispose();
  }

  // ==================== FIREBASE LISTENER ====================
  Future<void> _listenMatch() async {
    final ref = _firestore.collection('carrom_matches').doc(widget.matchId);

    _matchSub = ref.snapshots().listen((snap) {
      if (!snap.exists) return;

      final data = snap.data()!;
      _matchData = data;

      final newTurnUid = data['turn'] as String? ?? '';
      final newStatus = data['status'] as String? ?? 'waiting';

      if (newStatus == 'started' && newTurnUid != _turnUid) {
        _startTurnTimer();
      }

      setState(() {
        _status = newStatus;
        _turnUid = newTurnUid;
        _loading = false;
      });

      if (_status == 'started' && _gameStartTime == null) {
        _gameStartTime = DateTime.now();
      }

      final players = Map<String, dynamic>.from(data['players'] ?? {});
      if (_myUid != null && players.isNotEmpty) {
        _opponentUid = players.keys.firstWhere(
              (k) => k != _myUid,
          orElse: () => '',
        );
        _isHost = (data['host'] == _myUid);

        final uids = players.keys.toList();
        if (uids.length >= 2) {
          _game.playerColorForUid.clear();
          _game.playerColorForUid[uids[0]] = 'white';
          _game.playerColorForUid[uids[1]] = 'black';
        } else if (_myUid != null) {
          _game.playerColorForUid[_myUid!] = 'white';
        }
      }

      if (data['boardState'] != null && _game.isLoaded) {
        try {
          _game.setBoardState(Map<String, dynamic>.from(data['boardState']));
        } catch (_) {}
      }

      final lastMove = data['lastMove'] as Map<String, dynamic>?;
      if (lastMove != null && _game.isLoaded) {
        final fromUid = lastMove['fromUid'] as String?;
        if (fromUid != null && fromUid != _myUid) {
          _game.applyRemoteShot(lastMove);
        }
      }

      if (_status == 'finished') {
        _turnTimer?.cancel();
        final scores = Map<String, dynamic>.from(data['scores'] ?? {});
        _showResultAndExit(scores);
      }
    });
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    setState(() => _turnTimeLeft = _turnDuration);

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_turnTimeLeft > 0) {
        setState(() => _turnTimeLeft--);
      } else {
        _turnTimer?.cancel();
        if (_turnUid == _myUid && _status == 'started') {
          _handleTurnTimeout();
        }
      }
    });
  }

  Future<void> _handleTurnTimeout() async {
    if (!mounted) return;

    final ref = _firestore.collection('carrom_matches').doc(widget.matchId);
    final opponent = _opponentUid ?? _myUid;

    await ref.update({
      'turn': opponent,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Time's up! Turn passed."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onLocalShot(
      Map<String, dynamic> shotData,
      Map<String, dynamic> boardStateAfterShot,
      List<String> pocketed,
      List<String> fouls,
      ) async {
    _turnTimer?.cancel();

    _audioService.playStrike();

    if (pocketed.isNotEmpty) {
      for (int i = 0; i < pocketed.length; i++) {
        Future.delayed(Duration(milliseconds: i * 150), () {
          _audioService.playPocket();
        });
      }
    }

    if (fouls.isNotEmpty) {
      _audioService.playFoul();
    }

    final ref = _firestore.collection('carrom_matches').doc(widget.matchId);
    final myUid = _myUid!;
    final opponent = _opponentUid ?? myUid;

    bool playerKeepsTurn = false;
    final color = _game.playerColorForUid[myUid] ?? 'white';

    for (final id in pocketed) {
      if (id == 'q') {
        if ((boardStateAfterShot['queenCoveredBy'] ?? null) == myUid) {
          playerKeepsTurn = true;
        }
      } else if (_isCoinOfColor(id, color)) {
        playerKeepsTurn = true;
      }
    }

    final writeMap = <String, dynamic>{
      'lastMove': {
        'fromUid': myUid,
        'shot': shotData,
        'pocketed': pocketed,
        'fouls': fouls,
        'ts': FieldValue.serverTimestamp(),
      },
      'boardState': boardStateAfterShot,
      'scores': boardStateAfterShot['scores'] ?? {},
      'turn': playerKeepsTurn ? myUid : opponent,
    };

    final remaining = (boardStateAfterShot['remaining'] ?? 0) as int;
    final scores =
    Map<String, dynamic>.from(boardStateAfterShot['scores'] ?? {});
    final myScore = (scores[myUid] ?? 0) as int;
    final opScore = (scores[opponent] ?? 0) as int;

    if (myScore >= 25 || opScore >= 25 || remaining == 0) {
      writeMap['status'] = 'finished';
      writeMap['finishedAt'] = FieldValue.serverTimestamp();
      writeMap['scores'] = scores;
    }

    await ref.update(writeMap);
  }

  bool _isCoinOfColor(String id, String color) {
    if (id == 'q') return false;
    if (color == 'white') return id.startsWith('w');
    if (color == 'black') return id.startsWith('b');
    return false;
  }

  void _showResultAndExit(Map<String, dynamic> scores) {
    final myScore = (scores[_myUid] ?? 0) as int;
    final oppScore = (scores[_opponentUid] ?? 0) as int;

    if (myScore > oppScore) {
      _audioService.playVictory();
    } else {
      _audioService.playDefeat();
    }

    int? gameDuration;
    if (_gameStartTime != null) {
      gameDuration = DateTime.now().difference(_gameStartTime!).inSeconds;
    }

    String opponentName = 'Opponent';
    if (_matchData != null) {
      final players = Map<String, dynamic>.from(_matchData!['players'] ?? {});
      if (_opponentUid != null) {
        final userData = players[_opponentUid];
        if (userData is Map && userData['displayName'] != null) {
          opponentName = userData['displayName'].toString();
        }
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CarromResultScreen(
          matchId: widget.matchId,
          myScore: myScore,
          opponentScore: oppScore,
          opponentUid: _opponentUid ?? '',
          opponentName: opponentName,
          gameDurationSeconds: gameDuration,
        ),
      ),
    );
  }

  Future<void> _onReplayPressed() async {
    if (!_isHost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only host can restart match')),
        );
      }
      return;
    }

    final ref = _firestore.collection('carrom_matches').doc(widget.matchId);
    final initialBoard = _game.initialBoardState();

    await ref.update({
      'boardState': initialBoard,
      'lastMove': null,
      'status': 'started',
      'turn': _matchData?['host'] ?? _myUid,
      'scores': initialBoard['scores'],
    });

    _game.resetBoard();
    _gameStartTime = DateTime.now();
    _startTurnTimer();
  }

  // ==================== UI BUILDER ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A1C10),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: Colors.amber))
          : SafeArea(
        child: Column(
          children: [
            // 1. Custom Game AppBar
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 10)
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Colors.amber),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    "CARROM CLASH",
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _audioService.isMuted
                              ? Icons.volume_off
                              : Icons.volume_up,
                          color: Colors.amber,
                        ),
                        onPressed: () =>
                            setState(() => _audioService.toggleMute()),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh,
                            color: Colors.amber),
                        onPressed: _onReplayPressed,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. HUD (Score Board)
            _buildHUD(),

            const Spacer(),

            // 3. THE BOARD (Centerpiece)
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.8),
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
              ),
            ),

            const Spacer(),

            // 4. Bottom Status Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app,
                      color: Colors.white.withOpacity(0.7), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _status == 'started'
                        ? (_turnUid == _myUid
                        ? 'YOUR TURN - Drag Striker to Shoot!'
                        : 'Opponent is thinking...')
                        : 'Waiting for game to start...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD() {
    final players = Map<String, dynamic>.from(_matchData?['players'] ?? {});

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

    final myScore = _game.scores[_myUid] ?? 0;
    final opScore = _game.scores[_opponentUid] ?? 0;
    final isMyTurn = _turnUid == _myUid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPlayerInfo(myName, myScore, isMyTurn, true),

          // Timer / Turn Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isMyTurn
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isMyTurn ? Colors.green : Colors.red),
            ),
            child: Column(
              children: [
                Text(
                  isMyTurn ? "YOUR TURN" : "OPPONENT",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isMyTurn ? Colors.green : Colors.red,
                  ),
                ),
                if (_status == 'started')
                  Text(
                    '$_turnTimeLeft s',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color:
                      _turnTimeLeft < 10 ? Colors.redAccent : Colors.white,
                    ),
                  ),
              ],
            ),
          ),

          _buildPlayerInfo(opName, opScore, !isMyTurn, false),
        ],
      ),
    );
  }

  Widget _buildPlayerInfo(
      String name,
      int score,
      bool isActive,
      bool isMe,
      ) {
    return Column(
      crossAxisAlignment:
      isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          name.length > 10 ? '${name.substring(0, 8)}..' : name,
          style: TextStyle(
            color: isActive ? Colors.amber : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$score pts',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// ==================== CARROM BOARD GAME LOGIC ====================

class CarromBoardGame extends Forge2DGame with TapCallbacks, HasCollisionDetection {
  final double pocketRadius = 28.0;
  late double boardSize;

  final Map<String, Coin> coins = {};
  Striker? striker;

  final Map<String, int> scores = {};
  final Map<String, String> playerColorForUid = {};

  final CarromAudioService? audioService;
  final Future<void> Function(
      Map<String, dynamic> shotData,
      Map<String, dynamic> boardStateAfterShot,
      List<String> pocketed,
      List<String> fouls,
      )? onShot;

  Set<String> _preShotCoinIds = {};
  Map<String, dynamic>? _lastLocalShot;

  // Track if game is fully loaded
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  CarromBoardGame({this.onShot, this.audioService})
      : super(gravity: Vector2.zero());

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Game widget ka actual square size
    boardSize = size.x < size.y ? size.x : size.y;

    // Add board visual
    add(CarromBoard(boardSize: Vector2.all(boardSize)));

    // Add walls for physics boundaries
    await _addWalls();

    // Center
    final center = Vector2(boardSize / 2, boardSize / 2);

    // Striker bottom inner area
    final strikerY = boardSize - kBoardMargin - 60;
    striker = Striker(
      initialPosition: Vector2(center.x, strikerY),
      gameRef: this,
    );
    await add(striker!);

    await _initCoins(center);

    // Mark as loaded after all components are added
    _isLoaded = true;
  }

  Future<void> _addWalls() async {
    const double thickness = 10.0;

    // Top wall
    await add(Wall(
      wallSize: Vector2(boardSize - 2 * kBoardMargin, thickness),
      initialPosition: Vector2(boardSize / 2, kBoardMargin + thickness / 2),
    ));

    // Bottom wall
    await add(Wall(
      wallSize: Vector2(boardSize - 2 * kBoardMargin, thickness),
      initialPosition:
      Vector2(boardSize / 2, boardSize - kBoardMargin - thickness / 2),
    ));

    // Left wall
    await add(Wall(
      wallSize: Vector2(thickness, boardSize - 2 * kBoardMargin),
      initialPosition: Vector2(kBoardMargin + thickness / 2, boardSize / 2),
    ));

    // Right wall
    await add(Wall(
      wallSize: Vector2(thickness, boardSize - 2 * kBoardMargin),
      initialPosition:
      Vector2(boardSize - kBoardMargin - thickness / 2, boardSize / 2),
    ));
  }

  Future<void> _initCoins(Vector2 center) async {
    coins.clear();

    // Queen
    final queen = Coin(
      id: 'q',
      initialPosition: center.clone(),
      radius: 12.0,
      color: Colors.red,
    );
    coins['q'] = queen;
    await add(queen);

    const double r = 35.0;
    int b = 0, w = 0;
    for (int i = 0; i < 18; i++) {
      final double ang = (i / 18) * pi * 2;
      if (i % 2 == 0 && b < 9) {
        final coin = Coin(
          id: 'b$b',
          initialPosition: center + Vector2(cos(ang), sin(ang)) * (r + 8.0),
          radius: 10.0,
          color: Colors.black87,
        );
        coins['b$b'] = coin;
        await add(coin);
        b++;
      } else if (i % 2 == 1 && w < 9) {
        final coin = Coin(
          id: 'w$w',
          initialPosition: center + Vector2(cos(ang), sin(ang)) * (r + 22.0),
          radius: 10.0,
          color: Colors.white,
        );
        coins['w$w'] = coin;
        await add(coin);
        w++;
      }
    }

    scores.clear();
  }

  Map<String, dynamic> initialBoardState() {
    final coinMap = <String, Map<String, double>>{};
    coins.forEach((k, c) {
      if (c.isBodyCreated) {
        coinMap[k] = {'x': c.body.position.x, 'y': c.body.position.y};
      }
    });
    return {
      'coins': coinMap,
      'scores': scores,
      'remaining': coins.length,
    };
  }

  void resetBoard() {
    for (final coin in coins.values) {
      coin.removeFromParent();
    }
    coins.clear();

    final center = Vector2(boardSize / 2, boardSize / 2);
    final strikerY = boardSize - kBoardMargin - 60;

    if (striker != null && striker!.isBodyCreated) {
      striker!.body.setTransform(Vector2(center.x, strikerY), 0);
      striker!.body.linearVelocity = Vector2.zero();
    }

    _initCoins(center);
    _lastLocalShot = null;
  }

  void setBoardState(Map<String, dynamic> board) {
    if (!_isLoaded) return;

    final coinMap = Map<String, dynamic>.from(board['coins'] ?? {});
    final currentIds = coins.keys.toList();

    for (final id in currentIds) {
      if (!coinMap.containsKey(id)) {
        coins[id]?.removeFromParent();
        coins.remove(id);
      }
    }

    coinMap.forEach((id, pos) {
      final p = Map<String, dynamic>.from(pos);
      final x = (p['x'] ?? 0) as num;
      final y = (p['y'] ?? 0) as num;

      if (coins.containsKey(id)) {
        final c = coins[id]!;
        if (c.isBodyCreated) {
          c.body.setTransform(Vector2(x.toDouble(), y.toDouble()), 0);
          c.body.linearVelocity = Vector2.zero();
        }
      } else {
        Color color = id == 'q'
            ? Colors.red
            : (id.startsWith('w') ? Colors.white : Colors.black87);
        final coin = Coin(
          id: id,
          initialPosition: Vector2(x.toDouble(), y.toDouble()),
          radius: id == 'q' ? 12.0 : 10.0,
          color: color,
        );
        coins[id] = coin;
        add(coin);
      }
    });

    final sc = Map<String, dynamic>.from(board['scores'] ?? {});
    sc.forEach((k, v) => scores[k] = (v as num).toInt());
  }

  void applyRemoteShot(Map<String, dynamic> lastMove) {
    if (!_isLoaded || striker == null || !striker!.isBodyCreated) return;

    final shot = lastMove['shot'] as Map<String, dynamic>? ?? {};
    final vx = (shot['vx'] ?? 0) as num;
    final vy = (shot['vy'] ?? 0) as num;
    final sx = (shot['sx'] ?? 0) as num;
    final sy = (shot['sy'] ?? 0) as num;
    striker!.body.setTransform(Vector2(sx.toDouble(), sy.toDouble()), 0);
    striker!.body.linearVelocity = Vector2(vx.toDouble(), vy.toDouble());
  }

  void localPlayerShot(
      String fromUid,
      Vector2 strikerPos,
      Vector2 velocityVector,
      ) {
    if (striker == null || !striker!.isBodyCreated) return;

    // Store only IDs, not the coins themselves
    _preShotCoinIds = Set<String>.from(coins.keys);

    striker!.body.setTransform(strikerPos, 0);
    striker!.body.linearVelocity = velocityVector;

    _lastLocalShot = {
      'fromUid': fromUid,
      'sx': strikerPos.x,
      'sy': strikerPos.y,
      'vx': velocityVector.x,
      'vy': velocityVector.y,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_isLoaded || striker == null || !striker!.isBodyCreated) return;

    // Pockets: inner corners with margin
    final pockets = [
      Vector2(kBoardMargin, kBoardMargin),
      Vector2(boardSize - kBoardMargin, kBoardMargin),
      Vector2(kBoardMargin, boardSize - kBoardMargin),
      Vector2(boardSize - kBoardMargin, boardSize - kBoardMargin),
    ];

    final pocketed = <String>[];
    for (final entry in coins.entries.toList()) {
      final c = entry.value;
      if (!c.isBodyCreated) continue;

      for (final p in pockets) {
        final coinPos = c.body.position;
        if ((coinPos - p).length <= pocketRadius) {
          pocketed.add(entry.key);
          break;
        }
      }
    }

    if (pocketed.isNotEmpty) {
      for (final id in pocketed) {
        final c = coins.remove(id);
        if (c != null && c.isBodyCreated) {
          final pos = c.body.position.clone();
          c.removeFromParent();
          add(PocketEffect(effectPosition: pos, color: Colors.orange));
        }
      }
    }

    final strikerVelocity = striker!.body.linearVelocity;
    final moving = strikerVelocity.length > 2.0 ||
        coins.values.any((c) {
          if (!c.isBodyCreated) return false;
          return c.body.linearVelocity.length > 2.0;
        });

    if (!moving && _lastLocalShot != null) {
      _finalizeShot(pockets);
    }
  }

  void _finalizeShot(List<Vector2> pockets) {
    if (striker == null || !striker!.isBodyCreated) return;

    final afterIds = Set<String>.from(coins.keys);
    final pocketedIds = _preShotCoinIds.difference(afterIds).toList();
    final fouls = <String>[];

    // Striker pocket foul
    final strikerPos = striker!.body.position;
    for (final p in pockets) {
      if ((strikerPos - p).length <= pocketRadius) {
        fouls.add('striker_pocketed');

        final centerX = boardSize / 2;
        final strikerY = boardSize - kBoardMargin - 60;
        striker!.body.setTransform(Vector2(centerX, strikerY), 0);
        striker!.body.linearVelocity = Vector2.zero();

        add(PocketEffect(effectPosition: p.clone(), color: Colors.yellow));
        audioService?.playFoul();
        break;
      }
    }

    final shotFrom = _lastLocalShot!['fromUid'] as String;
    scores.putIfAbsent(shotFrom, () => 0);

    if (onShot != null) {
      final shotData = {
        'sx': _lastLocalShot!['sx'],
        'sy': _lastLocalShot!['sy'],
        'vx': _lastLocalShot!['vx'],
        'vy': _lastLocalShot!['vy'],
      };
      try {
        onShot!(shotData, _serializeBoardState(), pocketedIds, fouls);
      } catch (_) {}
    }
    _lastLocalShot = null;
  }

  Map<String, dynamic> _serializeBoardState() {
    final coinsMap = <String, Map<String, double>>{};
    coins.forEach((k, c) {
      if (c.isBodyCreated) {
        coinsMap[k] = {'x': c.body.position.x, 'y': c.body.position.y};
      }
    });
    return {
      'coins': coinsMap,
      'scores': Map<String, int>.from(scores),
      'remaining': coins.length,
    };
  }
}

/// ==================== GRAPHICS COMPONENTS ====================

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

// 2. 3D Coin with body initialization tracking
class Coin extends BodyComponent {
  final String id;
  final Color color;
  final double radius;
  final Vector2 initialPosition;

  bool _bodyCreated = false;
  bool get isBodyCreated => _bodyCreated;

  Coin({
    required this.id,
    required this.initialPosition,
    required this.radius,
    required this.color,
  });

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: initialPosition,
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

    final pos = body.position;
    final center = Offset(pos.x, pos.y);
    final r = radius;

    // Shadow
    canvas.drawCircle(
      Offset(center.dx + 2, center.dy + 2),
      r,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Body
    final paint = Paint()..color = color;
    if (color == Colors.black87) {
      paint.color = const Color(0xFF212121);
    }
    canvas.drawCircle(center, r, paint);

    // Inner Ring
    canvas.drawCircle(
      center,
      r * 0.7,
      Paint()
        ..color = Colors.black12
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Highlight
    canvas.drawOval(
      Rect.fromLTWH(
        center.dx - r * 0.5,
        center.dy - r * 0.6,
        r * 0.6,
        r * 0.3,
      ),
      Paint()..color = Colors.white.withOpacity(0.2),
    );
  }
}

// 3. 3D Striker with body initialization tracking
class Striker extends BodyComponent with DragCallbacks {
  final CarromBoardGame gameRef;
  final double radius = 22.0;
  final double mass = 2.0;
  final Vector2 initialPosition;

  bool _dragging = false;
  Vector2 _dragStart = Vector2.zero();
  Vector2 _initialDragPosition = Vector2.zero();

  bool _bodyCreated = false;
  bool get isBodyCreated => _bodyCreated;

  Striker({required this.initialPosition, required this.gameRef});

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: initialPosition,
    );

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

  @override
  bool containsLocalPoint(Vector2 point) {
    if (!_bodyCreated) return false;
    final strikerPos = body.position;
    return (point - strikerPos).length <= radius * 2;
  }

  @override
  bool onDragStart(DragStartEvent event) {
    if (!_bodyCreated) return false;

    final velocity = body.linearVelocity;
    if (velocity.length > 4.0) return false;

    _dragging = true;
    _dragStart = event.localPosition;
    _initialDragPosition = body.position.clone();
    return true;
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    if (!_dragging || !_bodyCreated) return false;

    final delta = event.localEndPosition - _dragStart;
    final newPos = _initialDragPosition + delta;

    final min = kBoardMargin + radius;
    final max = gameRef.boardSize - kBoardMargin - radius;

    final clamped = Vector2(
      newPos.x.clamp(min, max),
      newPos.y.clamp(min, max),
    );

    body.setTransform(clamped, 0);
    return true;
  }

  @override
  bool onDragEnd(DragEndEvent event) {
    if (!_dragging || !_bodyCreated) return false;
    _dragging = false;

    Vector2 impulse = event.velocity / 2;
    if (impulse.length > 500) {
      impulse = impulse.normalized() * 500;
    }

    body.linearVelocity = impulse;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty && gameRef.onShot != null) {
      gameRef.localPlayerShot(uid, body.position.clone(), impulse);
    }

    return true;
  }

  @override
  void render(Canvas canvas) {
    if (!_bodyCreated) return;

    final pos = body.position;
    final center = Offset(pos.x, pos.y);
    final r = radius;

    // Shadow
    canvas.drawCircle(
      Offset(center.dx + 3, center.dy + 3),
      r,
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Body gradient
    final bodyRect = Rect.fromCircle(center: center, radius: r);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.yellow.shade50, Colors.orange.shade100],
      ).createShader(bodyRect);
    canvas.drawCircle(center, r, paint);

    // Ring
    canvas.drawCircle(
      center,
      r * 0.7,
      Paint()
        ..color = Colors.blue.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Shine
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r - 2),
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
    final r = (1.0 - life.clamp(0.0, 1.0)) * 40.0;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()..color = color.withOpacity(life.clamp(0.0, 1.0)),
    );
  }
}

// 5. Realistic Carrom Board (Visual Only)
class CarromBoard extends PositionComponent {
  final Vector2 boardSize;

  CarromBoard({required this.boardSize}) : super(size: boardSize);

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
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(
        margin + 5,
        margin + 5,
        size.x - (margin * 2) - 10,
        size.y - (margin * 2) - 10,
      ),
      linePaint,
    );

    // Pockets (Holes)
    final pocketPaint = Paint()..color = const Color(0xFF1A1A1A);
    final pocketOffsets = [
      Offset(margin, margin),
      Offset(size.x - margin, margin),
      Offset(margin, size.y - margin),
      Offset(size.x - margin, size.y - margin),
    ];
    for (final p in pocketOffsets) {
      canvas.drawCircle(p, 22.0, pocketPaint);
    }

    // Striker Lines
    final strikerPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(margin + 40, size.y - margin - 80),
      Offset(size.x - margin - 40, size.y - margin - 80),
      strikerPaint,
    );
    canvas.drawLine(
      Offset(margin + 40, margin + 80),
      Offset(size.x - margin - 40, margin + 80),
      strikerPaint,
    );

    // Center Design
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(
      center,
      50,
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(center, 10, Paint()..color = Colors.red);
  }
}