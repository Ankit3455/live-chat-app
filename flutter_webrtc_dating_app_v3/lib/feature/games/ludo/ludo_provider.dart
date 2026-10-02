// // lib/feature/games/ludo/ludo_provider.dart
// import 'dart:async';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:http/http.dart';
//
// import 'audio.dart';
// import 'constants.dart';
// import 'ludo_player.dart';
// import 'package:provider/provider.dart';
//
//
// /// Single-source Ludo provider — contains the original local game logic
// /// plus multiplayer integration (Firestore). Multiplayer-only mode.
// class LudoProvider extends ChangeNotifier {
//   // ---------- LOCAL GAME STATE (kept from original) ----------
//   bool _isMoving = false;
//   bool _stopMoving = false;
//
//   LudoGameState _gameState = LudoGameState.throwDice;
//   LudoGameState get gameState => _gameState;
//
//   LudoPlayerType _currentTurn = LudoPlayerType.green;
//
//   int _diceResult = 0;
//   int get diceResult {
//     if (_diceResult < 1) return 1;
//     if (_diceResult > 6) return 6;
//     return _diceResult;
//   }
//
//   bool _diceStarted = false;
//   bool get diceStarted => _diceStarted;
//
//   LudoPlayer get currentPlayer =>
//       players.firstWhere((element) => element.type == _currentTurn);
//
//   final List<LudoPlayer> players = [];
//   final List<LudoPlayerType> winners = [];
//
//   /// Public helper so multiplayer layer can set the current turn by color
//   void setCurrentTurn(LudoPlayerType t) {
//     _currentTurn = t;
//     _gameState = LudoGameState.throwDice;
//     notifyListeners();
//   }
//
//   LudoPlayer player(LudoPlayerType type) =>
//       players.firstWhere((element) => element.type == type);
//
//   bool checkToKill(LudoPlayerType type, int index, int step,
//       List<List<double>> path) {
//     bool killSomeone = false;
//     for (int i = 0; i < 4; i++) {
//       var greenElement = player(LudoPlayerType.green).pawns[i];
//       var blueElement = player(LudoPlayerType.blue).pawns[i];
//       var redElement = player(LudoPlayerType.red).pawns[i];
//       var yellowElement = player(LudoPlayerType.yellow).pawns[i];
//
//       if ((greenElement.step > -1 &&
//           !LudoPath.safeArea
//               .map((e) => e.toString())
//               .contains(player(LudoPlayerType.green).path[greenElement.step]
//               .toString())) &&
//           type != LudoPlayerType.green) {
//         if (player(LudoPlayerType.green)
//             .path[greenElement.step]
//             .toString() ==
//             path[step - 1].toString()) {
//           killSomeone = true;
//           player(LudoPlayerType.green).movePawn(i, -1);
//           notifyListeners();
//         }
//       }
//       if ((yellowElement.step > -1 &&
//           !LudoPath.safeArea
//               .map((e) => e.toString())
//               .contains(player(LudoPlayerType.yellow)
//               .path[yellowElement.step]
//               .toString())) &&
//           type != LudoPlayerType.yellow) {
//         if (player(LudoPlayerType.yellow)
//             .path[yellowElement.step]
//             .toString() ==
//             path[step - 1].toString()) {
//           killSomeone = true;
//           player(LudoPlayerType.yellow).movePawn(i, -1);
//           notifyListeners();
//         }
//       }
//       if ((blueElement.step > -1 &&
//           !LudoPath.safeArea
//               .map((e) => e.toString())
//               .contains(player(LudoPlayerType.blue).path[blueElement.step]
//               .toString())) &&
//           type != LudoPlayerType.blue) {
//         if (player(LudoPlayerType.blue).path[blueElement.step].toString() ==
//             path[step - 1].toString()) {
//           killSomeone = true;
//           player(LudoPlayerType.blue).movePawn(i, -1);
//           notifyListeners();
//         }
//       }
//       if ((redElement.step > -1 &&
//           !LudoPath.safeArea
//               .map((e) => e.toString())
//               .contains(player(LudoPlayerType.red).path[redElement.step]
//               .toString())) &&
//           type != LudoPlayerType.red) {
//         if (player(LudoPlayerType.red).path[redElement.step].toString() ==
//             path[step - 1].toString()) {
//           killSomeone = true;
//           player(LudoPlayerType.red).movePawn(i, -1);
//           notifyListeners();
//         }
//       }
//     }
//     return killSomeone;
//   }
//
//   // ---------- MULTIPLAYER FIELDS ----------
//   bool _multiplayer = false; // set to true by startMultiplayer
//   String? _matchId;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final String? _myUid = FirebaseAuth.instance.currentUser?.uid;
//
//   // map from player type -> uid (filled from match doc)
//   final Map<LudoPlayerType, String> _uidForType = {};
//   // ordered player UIDs (turn order)
//   List<String> _playerOrder = [];
//
//   // turn tracking
//   String _currentTurnUid = '';
//   bool get isMyTurn => _multiplayer ? _currentTurnUid == _myUid : true;
//
//   // moves listener and match listener subscriptions
//   StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _matchSub;
//   StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _movesSub;
//
//   // prevent loops when applying remote moves
//   bool _applyingRemote = false;
//
//   // 30s timer
//   Timer? _turnTimer;
//   int _turnTimeLeft = 30;
//   static const int _turnDuration = 30;
//
//   // ---------- CONSTRUCTOR / START ----------
//   LudoProvider() {
//     startGame(); // initialize local players & pawns
//   }
//
//   /// Initialize local players (same as original)
//   void startGame() {
//     winners.clear();
//     players.clear();
//     players.addAll([
//       LudoPlayer(LudoPlayerType.green),
//       LudoPlayer(LudoPlayerType.yellow),
//       LudoPlayer(LudoPlayerType.blue),
//       LudoPlayer(LudoPlayerType.red),
//     ]);
//     // default turn
//     _currentTurn = LudoPlayerType.green;
//     _gameState = LudoGameState.throwDice;
//     notifyListeners();
//   }
//
//   // ---------- MULTIPLAYER: START / STOP ----------
//   /// Call this to make provider operate in multiplayer mode:
//   /// pass the Firestore match id.
//   void startMultiplayer(String matchId) {
//     if (_multiplayer) return;
//     _multiplayer = true;
//     _matchId = matchId;
//     // ensure local players init
//     if (players.isEmpty) startGame();
//
//     // attach listeners
//     _matchSub = _firestore
//         .collection('ludo_matches')
//         .doc(matchId)
//         .snapshots()
//         .listen(_onMatchUpdate, onError: (_) {});
//
//     _movesSub = _firestore
//         .collection('ludo_matches')
//         .doc(matchId)
//         .collection('moves')
//         .orderBy('ts', descending: false)
//         .snapshots()
//         .listen(_onMovesUpdate, onError: (_) {});
//   }
//
//   void stopMultiplayer() {
//     _matchSub?.cancel();
//     _movesSub?.cancel();
//     _turnTimer?.cancel();
//     _multiplayer = false;
//     _matchId = null;
//   }
//
//   // ---------- FIRESTORE HANDLERS ----------
//   void _onMatchUpdate(DocumentSnapshot<Map<String, dynamic>> snap) {
//     if (!snap.exists) return;
//     final data = snap.data() ?? {};
//
//     // read players map
//     final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
//
//     // prefer 'playersOrder' then 'playerOrder' else keys
//     final order = (data['playersOrder'] as List<dynamic>?)?.cast<String>() ??
//         (data['playerOrder'] as List<dynamic>?)?.cast<String>() ??
//         playersMap.keys.toList();
//     _playerOrder = order.toList();
//
//     // map color->uid if color provided in players
//     _uidForType.clear();
//     playersMap.forEach((uid, info) {
//       if (info is Map<String, dynamic> && info['color'] != null) {
//         final color = info['color'].toString().toLowerCase();
//         switch (color) {
//           case 'green':
//             _uidForType[LudoPlayerType.green] = uid;
//             break;
//           case 'yellow':
//             _uidForType[LudoPlayerType.yellow] = uid;
//             break;
//           case 'blue':
//             _uidForType[LudoPlayerType.blue] = uid;
//             break;
//           case 'red':
//             _uidForType[LudoPlayerType.red] = uid;
//             break;
//         }
//       }
//     });
//
//     // Fill missing mappings by order
//     final typesOrder = [
//       LudoPlayerType.green,
//       LudoPlayerType.yellow,
//       LudoPlayerType.blue,
//       LudoPlayerType.red
//     ];
//     for (int i = 0; i < _playerOrder.length && i < typesOrder.length; i++) {
//       final t = typesOrder[i];
//       _uidForType.putIfAbsent(t, () => _playerOrder[i]);
//     }
//
//     // Update current turn — accept both 'turn' (uid) and 'turnColor'
//     final turnUidFromDoc = (data['turn'] as String?) ?? '';
//     final turnColorFromDoc = (data['turnColor'] as String?) ?? '';
//
//     String newTurnUid = '';
//     LudoPlayerType? newTurnType;
//
//     if (turnColorFromDoc.isNotEmpty) {
//       switch (turnColorFromDoc.toLowerCase()) {
//         case 'green':
//           newTurnType = LudoPlayerType.green;
//           break;
//         case 'yellow':
//           newTurnType = LudoPlayerType.yellow;
//           break;
//         case 'blue':
//           newTurnType = LudoPlayerType.blue;
//           break;
//         case 'red':
//           newTurnType = LudoPlayerType.red;
//           break;
//       }
//       if (newTurnType != null && _uidForType.containsKey(newTurnType)) {
//         newTurnUid = _uidForType[newTurnType] ?? '';
//       }
//     } else if (turnUidFromDoc.isNotEmpty) {
//       newTurnUid = turnUidFromDoc;
//       final found = _uidForType.entries.firstWhere(
//             (e) => e.value == newTurnUid,
//         orElse: () => MapEntry(_currentTurn, ''),
//       );
//       newTurnType = found.key;
//     }
//
//     if (newTurnUid.isNotEmpty && newTurnUid != _currentTurnUid) {
//       _currentTurnUid = newTurnUid;
//       if (newTurnType != null) _currentTurn = newTurnType;
//       _handleTurnChange();
//       notifyListeners();
//     }
//
//     // Optional: apply board state (pawnSteps/winners) if you store them in doc.
//     // You can add code here similar to LudoMultiplayerProvider._applyPawnStepsFromMap
//   }
//
//
//   void _onMovesUpdate(QuerySnapshot<Map<String, dynamic>> snap) {
//     for (final change in snap.docChanges) {
//       if (change.type == DocumentChangeType.added) {
//         final data = change.doc.data();
//         if (data == null) continue;
//         final byUid = data['byUid'] as String? ?? '';
//         if (byUid == _myUid) continue; // skip our own moves
//         _applyRemoteMoveData(data);
//       }
//     }
//   }
//
//   Future<void> _applyRemoteMoveData(Map<String, dynamic> data) async {
//     // Avoid re-sending when applying remote
//     _applyingRemote = true;
//
//     final action = data['action'] as String? ?? 'move';
//
//     try {
//       if (action == 'throw') {
//         final dice = (data['diceResult'] ?? 1) as int;
//         _diceResult = dice;
//         // set state similar to local throwDice result flow
//         if (_diceResult == 6) {
//           currentPlayer.highlightAllPawns();
//           _gameState = LudoGameState.pickPawn;
//         } else {
//           if (currentPlayer.pawnInsideCount == 4) {
//             // next turn will be set by server/match doc
//             _gameState = LudoGameState.throwDice;
//           } else {
//             currentPlayer.highlightOutside();
//             _gameState = LudoGameState.pickPawn;
//           }
//         }
//         notifyListeners();
//       } else if (action == 'move') {
//         // remote move contains type, index, toStep
//         final String typeStr = data['type'] ?? '';
//         final int index = (data['index'] ?? 0) as int;
//         final int toStep = (data['toStep'] ?? -1) as int;
//
//         // convert typeStr to LudoPlayerType
//         LudoPlayerType? type;
//         if (typeStr.contains('green')) type = LudoPlayerType.green;
//         if (typeStr.contains('yellow')) type = LudoPlayerType.yellow;
//         if (typeStr.contains('blue')) type = LudoPlayerType.blue;
//         if (typeStr.contains('red')) type = LudoPlayerType.red;
//
//         if (type != null) {
//           // call the same internal movement flow but set applyingRemote to prevent send
//           await _remoteMove(type, index, toStep);
//         }
//       }
//     } finally {
//       _applyingRemote = false;
//     }
//   }
//
//   // Internal helper to move without re-sending
//   Future<void> _remoteMove(LudoPlayerType type, int index, int step) async {
//     // Copy of original move logic but without write-back
//     if (_isMoving) return;
//     _isMoving = true;
//     _gameState = LudoGameState.moving;
//     notifyListeners();
//
//     final selectedPlayer = player(type);
//     for (int i = selectedPlayer.pawns[index].step; i < step; i++) {
//       if (_stopMoving) break;
//       if (selectedPlayer.pawns[index].step == i) continue;
//       selectedPlayer.movePawn(index, i);
//       await Audio.playMove();
//       notifyListeners();
//       if (_stopMoving) break;
//     }
//     if (checkToKill(type, index, step, selectedPlayer.path)) {
//       _gameState = LudoGameState.throwDice;
//       _isMoving = false;
//       Audio.playKill();
//       notifyListeners();
//       return;
//     }
//
//     validateWin(type);
//
//     if (diceResult == 6) {
//       _gameState = LudoGameState.throwDice;
//       notifyListeners();
//     } else {
//       nextTurn();
//       notifyListeners();
//     }
//     _isMoving = false;
//   }
//
//   // ---------- LOCAL ACTIONS (throwDice & move) ----------
//   // These methods are the same as before but with multiplayer checks and sendMove calls.
//
//   void throwDice() async {
//     if (_gameState != LudoGameState.throwDice) return;
//     // In multiplayer, only current-turn player can throw
//     if (_multiplayer && !isMyTurn) return;
//
//     _diceStarted = true;
//     notifyListeners();
//     Audio.rollDice();
//
//     //Check if already win skip
//     if (winners.contains(currentPlayer.type)) {
//       nextTurn();
//       return;
//     }
//
//     //Turn off highlight for all pawns
//     currentPlayer.highlightAllPawns(false);
//
//     Future.delayed(const Duration(seconds: 1)).then((value) async {
//       _diceStarted = false;
//       var random = Random();
//       _diceResult = random.nextBool() ? 6 : random.nextInt(6) + 1; //Random between 1 - 6
//       notifyListeners();
//
//       if (diceResult == 6) {
//         currentPlayer.highlightAllPawns();
//         _gameState = LudoGameState.pickPawn;
//         notifyListeners();
//       } else {
//         /// all pawns are inside home
//         if (currentPlayer.pawnInsideCount == 4) {
//           return nextTurn();
//         } else {
//           ///Hightlight all pawn outside
//           currentPlayer.highlightOutside();
//           _gameState = LudoGameState.pickPawn;
//           notifyListeners();
//         }
//       }
//
//       ///Check and disable if any pawn already in the finish box
//       for (var i = 0; i < currentPlayer.pawns.length; i++) {
//         var pawn = currentPlayer.pawns[i];
//         if ((pawn.step + diceResult) > currentPlayer.path.length - 1) {
//           currentPlayer.highlightPawn(i, false);
//         }
//       }
//
//       ///Automatically move random pawn if all pawn are in same step
//       var moveablePawn = currentPlayer.pawns.where((e) => e.highlight).toList();
//       if (moveablePawn.length > 1) {
//         var biggestStep = moveablePawn.map((e) => e.step).reduce(max);
//         if (moveablePawn.every((element) => element.step == biggestStep)) {
//           var random = 1 + Random().nextInt(moveablePawn.length - 1);
//           if (moveablePawn[random].step == -1) {
//             var thePawn = moveablePawn[random];
//             move(thePawn.type, thePawn.index, (thePawn.step + 1) + 1);
//             return;
//           } else {
//             var thePawn = moveablePawn[random];
//             move(thePawn.type, thePawn.index, (thePawn.step + 1) + diceResult);
//             return;
//           }
//         }
//       }
//
//       ///If User have 6 dice, but it inside finish line, it will make him to throw again, else it will turn to next player
//       if (currentPlayer.pawns.every((element) => !element.highlight)) {
//         if (diceResult == 6) {
//           _gameState = LudoGameState.throwDice;
//         } else {
//           nextTurn();
//           return;
//         }
//       }
//
//       if (currentPlayer.pawns.where((element) => element.highlight).length == 1) {
//         var index = currentPlayer.pawns.indexWhere((element) => element.highlight);
//         move(currentPlayer.type, index, (currentPlayer.pawns[index].step + 1) + diceResult);
//       }
//
//       // Multiplayer: write the 'throw' action to moves subcollection
//       if (_multiplayer && !_applyingRemote) {
//         await _sendMoveDoc({
//           'action': 'throw',
//           'diceResult': _diceResult,
//           'byUid': _myUid,
//           'ts': FieldValue.serverTimestamp(),
//         });
//
//         // After throw the server/match doc should be updated to reflect who is next.
//         // Here we do not change match.turn directly; the host or client code that manages match should update it.
//       }
//     });
//   }
//
//   void move(LudoPlayerType type, int index, int step) async {
//     // In multiplayer, only current-turn player can move
//     if (_multiplayer && !isMyTurn) return;
//
//     if (_isMoving) return;
//     _isMoving = true;
//     _gameState = LudoGameState.moving;
//
//     currentPlayer.highlightAllPawns(false);
//
//     var selectedPlayer = player(type);
//     for (int i = selectedPlayer.pawns[index].step; i < step; i++) {
//       if (_stopMoving) break;
//       if (selectedPlayer.pawns[index].step == i) continue;
//       selectedPlayer.movePawn(index, i);
//       await Audio.playMove();
//       notifyListeners();
//       if (_stopMoving) break;
//     }
//     if (checkToKill(type, index, step, selectedPlayer.path)) {
//       _gameState = LudoGameState.throwDice;
//       _isMoving = false;
//       Audio.playKill();
//       notifyListeners();
//       return;
//     }
//
//     validateWin(type);
//
//     if (diceResult == 6) {
//       _gameState = LudoGameState.throwDice;
//       notifyListeners();
//     } else {
//       nextTurn();
//       notifyListeners();
//     }
//     _isMoving = false;
//
//     // Multiplayer: send move to Firestore (if this was local)
//     if (_multiplayer && !_applyingRemote) {
//       await _sendMoveDoc({
//         'action': 'move',
//         'type': type.toString(),
//         'index': index,
//         'toStep': step,
//         'byUid': _myUid,
//         'ts': FieldValue.serverTimestamp(),
//       });
//
//       // Also update match doc's turn field to the next player's uid (if playerOrder present)
//       await _advanceTurnInMatch();
//     }
//   }
//
//   // ---------- TURN ADVANCEMENT ----------
//   Future<void> _advanceTurnInMatch() async {
//     if (!_multiplayer || _matchId == null) return;
//     if (_playerOrder.isEmpty) return;
//
//     // find index of currentTurnUid in order
//     int idx = _playerOrder.indexOf(_currentTurnUid);
//     if (idx == -1) {
//       // attempt to find by mapping current LudoPlayerType
//       final nextUid = _uidForType[_currentTurn];
//       if (nextUid != null) idx = _playerOrder.indexOf(nextUid);
//       if (idx == -1) idx = 0;
//     }
//     int nextIdx = (idx + 1) % _playerOrder.length;
//     final nextUid = _playerOrder[nextIdx];
//
//     try {
//       await _firestore.collection('ludo_matches').doc(_matchId).update({
//         'turn': nextUid,
//         'lastUpdatedAt': FieldValue.serverTimestamp(),
//       });
//     } catch (_) {
//       // ignore
//     }
//   }
//
//   // ---------- SEND MOVE DOC ----------
//   Future<void> _sendMoveDoc(Map<String, dynamic> doc) async {
//     if (!_multiplayer || _matchId == null) return;
//     try {
//       await _firestore
//           .collection('ludo_matches')
//           .doc(_matchId)
//           .collection('moves')
//           .add(doc);
//     } catch (_) {}
//   }
//
//   // ---------- TURN TIMER ----------
//   void _handleTurnChange() {
//     _turnTimer?.cancel();
//     _turnTimeLeft = _turnDuration;
//
//     if (!isMyTurn) {
//       notifyListeners();
//       return;
//     }
//
//     // start timer only if it's my turn
//     _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
//       if (_turnTimeLeft > 0) {
//         _turnTimeLeft--;
//         notifyListeners();
//       } else {
//         // time out -> pass turn
//         _turnTimer?.cancel();
//         // Advance turn in match doc
//         await _advanceTurnInMatch();
//       }
//     });
//     notifyListeners();
//   }
//
//   int get turnTimeLeft => _turnTimeLeft;
//
//   // ---------- WIN VALIDATION ----------
//   void validateWin(LudoPlayerType color) {
//     if (winners.map((e) => e.name).contains(color.name)) return;
//     if (player(color)
//         .pawns
//         .map((e) => e.step)
//         .every((element) => element == player(color).path.length - 1)) {
//       winners.add(color);
//       notifyListeners();
//     }
//
//     if (winners.length == 3) {
//       _gameState = LudoGameState.finish;
//     }
//   }
//
//   // ---------- NEXT TURN (local fallback) ----------
//   void nextTurn() {
//     switch (_currentTurn) {
//       case LudoPlayerType.green:
//         _currentTurn = LudoPlayerType.yellow;
//         break;
//       case LudoPlayerType.yellow:
//         _currentTurn = LudoPlayerType.blue;
//         break;
//       case LudoPlayerType.blue:
//         _currentTurn = LudoPlayerType.red;
//         break;
//       case LudoPlayerType.red:
//         _currentTurn = LudoPlayerType.green;
//         break;
//     }
//
//     // If this player is already in winners, skip
//     if (winners.contains(_currentTurn)) return nextTurn();
//     _gameState = LudoGameState.throwDice;
//     notifyListeners();
//   }
//
//   @override
//   void dispose() {
//     _stopMoving = true;
//     _turnTimer?.cancel();
//     _matchSub?.cancel();
//     _movesSub?.cancel();
//     super.dispose();
//   }
//
//   // ---------- UTIL ----------
//   static LudoProvider read(BuildContext context) => context.read();
// }
