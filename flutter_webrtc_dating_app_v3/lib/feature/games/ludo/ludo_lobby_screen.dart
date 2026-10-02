// // lib/feature/games/ludo/ludo_lobby_screen.dart
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// import 'services/ludo_game_service.dart';
// import 'ludo_wrapper_screen.dart';
//
// class LudoLobbyScreen extends StatefulWidget {
//   const LudoLobbyScreen({Key? key}) : super(key: key);
//
//   @override
//   State<LudoLobbyScreen> createState() => _LudoLobbyScreenState();
// }
//
// class _LudoLobbyScreenState extends State<LudoLobbyScreen> {
//   final _service = LudoGameService();
//   final _auth = FirebaseAuth.instance;
//   final _fs = FirebaseFirestore.instance;
//
//   bool _searching = false;
//   String? _error;
//   Timer? _waitingTimer;
//   Timer? _searchTimer;
//   int _waitSeconds = 0;
//   String? _myQueueDocId;
//   StreamSubscription? _matchListener;
//   bool _navigated = false;
//
//   @override
//   void dispose() {
//     _waitingTimer?.cancel();
//     _searchTimer?.cancel();
//     _matchListener?.cancel();
//     _cleanupQueue();
//     super.dispose();
//   }
//
//   Future<void> _cleanupQueue() async {
//     if (_myQueueDocId != null) {
//       try {
//         final currentUid = _auth.currentUser?.uid;
//         if (currentUid != null) {
//           final docRef = _fs.collection('ludo_queue').doc(_myQueueDocId);
//           final docSnap = await docRef.get();
//           if (docSnap.exists && docSnap.data()?['uid'] == currentUid) {
//             await _service.dequeue(_myQueueDocId!);
//             debugPrint('✅ Cleaned up queue doc: $_myQueueDocId');
//           }
//         }
//       } catch (e) {
//         debugPrint('❌ Cleanup error: $e');
//       }
//       _myQueueDocId = null;
//     }
//   }
//
//   Future<void> _findMatch() async {
//     final user = _auth.currentUser;
//     if (user == null) {
//       setState(() => _error = 'Please sign in to play');
//       return;
//     }
//
//     // Reset state
//     _navigated = false;
//     setState(() {
//       _searching = true;
//       _error = null;
//       _waitSeconds = 0;
//     });
//
//     // Start wait timer
//     _waitingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
//       if (mounted && !_navigated) {
//         setState(() => _waitSeconds++);
//       }
//       if (_waitSeconds > 60) {
//         t.cancel();
//         _cancelSearch('No opponent found. Try again later.');
//       }
//     });
//
//     try {
//       debugPrint('🔍 Looking for opponent...');
//
//       // Step 1: Check for existing opponent in queue FIRST
//       final opponents = await _service.findQueueOpponents(user.uid, 1);
//
//       if (opponents.isNotEmpty && !_navigated) {
//         debugPrint('✅ Found opponent in queue!');
//
//         final opponent = opponents.first;
//         final oppData = opponent.data() ?? {};
//         final oppUid = oppData['uid']?.toString() ?? '';
//
//         if (oppUid.isNotEmpty && oppUid != user.uid) {
//           try {
//             final matchRef = await _service.createMatchFromQueue2Players(
//               opponentRef: opponent.reference,
//               opponentUid: oppUid,
//               opponentName: oppData['displayName']?.toString() ?? 'Player',
//               opponentAvatar: oppData['avatar']?.toString() ?? '',
//               hostUid: user.uid,
//               hostName: user.displayName ?? 'Player',
//               hostAvatar: user.photoURL ?? '',
//             );
//
//             debugPrint('✅ Match created: ${matchRef.id}');
//
//             // Delete opponent from queue
//             try {
//               await opponent.reference.delete();
//             } catch (_) {}
//
//             _navigateToGame(matchRef.id);
//             return;
//           } catch (e) {
//             debugPrint('❌ Match creation failed: $e');
//             // Continue to enqueue self
//           }
//         }
//       }
//
//       // Step 2: No opponent found, add self to queue
//       debugPrint('📝 Adding self to queue...');
//
//       try {
//         final queueRef = await _service.enqueue(
//           user.uid,
//           user.displayName ?? 'Player',
//           user.photoURL,
//         );
//         _myQueueDocId = queueRef.id;
//         debugPrint('✅ Added to queue: ${queueRef.id}');
//       } catch (e) {
//         debugPrint('❌ Failed to enqueue: $e');
//         _cancelSearch('Connection error. Please try again.');
//         return;
//       }
//
//       // Step 3: Listen for matches where we are a participant
//       _matchListener = _fs
//           .collection('ludo_matches')
//           .where('state', isEqualTo: 'playing')  // Only active games
//           .snapshots()
//           .listen((snapshot) {
//         if (_navigated) return;
//
//         for (final doc in snapshot.docs) {
//           final data = doc.data();
//           final players = Map<String, dynamic>.from(data['players'] ?? {});
//           final createdAt = data['createdAt'] as Timestamp?;
//
//           // Skip old matches (older than 1 hour)
//           if (createdAt != null) {
//             final age = DateTime.now().difference(createdAt.toDate());
//             if (age.inHours > 1) continue;
//           }
//
//           // Check if current user is in this match AND is active
//           if (players.containsKey(user.uid)) {
//             final playerInfo = players[user.uid] as Map<String, dynamic>?;
//             final status = playerInfo?['status']?.toString() ?? 'active';
//
//             // Only join if player is active (not left)
//             if (status == 'active') {
//               debugPrint('✅ Found active match: ${doc.id}');
//               _cleanupQueue();
//               _navigateToGame(doc.id);
//               return;
//             }
//           }
//         }
//       });
//
//       // Step 4: Periodically check for new opponents
//       _searchTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
//         if (_navigated || !_searching || !mounted) {
//           timer.cancel();
//           return;
//         }
//
//         debugPrint('🔄 Checking for opponents... (${_waitSeconds}s)');
//
//         final newOpponents = await _service.findQueueOpponents(user.uid, 1);
//
//         for (final opponent in newOpponents) {
//           if (_navigated) break;
//
//           final oppData = opponent.data() ?? {};
//           final oppUid = oppData['uid']?.toString() ?? '';
//
//           // Skip if it's our own queue entry
//           if (oppUid == user.uid || opponent.id == _myQueueDocId) continue;
//
//           debugPrint('✅ Found new opponent: $oppUid');
//
//           try {
//             final matchRef = await _service.createMatchFromQueue2Players(
//               opponentRef: opponent.reference,
//               opponentUid: oppUid,
//               opponentName: oppData['displayName']?.toString() ?? 'Player',
//               opponentAvatar: oppData['avatar']?.toString() ?? '',
//               hostUid: user.uid,
//               hostName: user.displayName ?? 'Player',
//               hostAvatar: user.photoURL ?? '',
//             );
//
//             debugPrint('✅ Match created: ${matchRef.id}');
//
//             try {
//               await opponent.reference.delete();
//             } catch (_) {}
//
//             timer.cancel();
//             _cleanupQueue();
//             _navigateToGame(matchRef.id);
//             return;
//           } catch (e) {
//             debugPrint('❌ Match creation failed: $e');
//           }
//         }
//       });
//
//     } catch (e) {
//       debugPrint('❌ Find match error: $e');
//       _cancelSearch('Connection error. Please try again.');
//     }
//   }
//
//   void _navigateToGame(String matchId) {
//     if (_navigated) return;
//     _navigated = true;
//
//     _waitingTimer?.cancel();
//     _searchTimer?.cancel();
//     _matchListener?.cancel();
//
//     if (!mounted) return;
//
//     debugPrint('🎮 Navigating to game: $matchId');
//
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(
//         builder: (_) => LudoWrapperScreen(matchId: matchId),
//       ),
//     );
//   }
//
//   void _cancelSearch([String? errorMessage]) {
//     _waitingTimer?.cancel();
//     _searchTimer?.cancel();
//     _matchListener?.cancel();
//     _cleanupQueue();
//
//     if (mounted) {
//       setState(() {
//         _searching = false;
//         _error = errorMessage;
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [Color(0xFF1A0E2E), Color(0xFF2D1B4E)],
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               _buildHeader(),
//               Expanded(
//                 child: _searching ? _buildSearchingView() : _buildLobbyView(),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHeader() {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         children: [
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: IconButton(
//               icon: const Icon(Icons.arrow_back, color: Colors.white),
//               onPressed: () {
//                 _cancelSearch();
//                 Navigator.pop(context);
//               },
//             ),
//           ),
//           const SizedBox(width: 16),
//           const Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   '🎲 Ludo',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 Text(
//                   'Classic Board Game',
//                   style: TextStyle(color: Colors.white54, fontSize: 14),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLobbyView() {
//     return Padding(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           // Game icon
//           Container(
//             padding: const EdgeInsets.all(32),
//             decoration: BoxDecoration(
//               color: Colors.blue.withOpacity(0.2),
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(
//               Icons.casino,
//               size: 80,
//               color: Colors.blue,
//             ),
//           ),
//
//           const SizedBox(height: 32),
//
//           const Text(
//             'Play Ludo Online',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 28,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//
//           const SizedBox(height: 8),
//
//           Text(
//             'Challenge players from around the world!',
//             style: TextStyle(
//               color: Colors.white.withOpacity(0.7),
//               fontSize: 16,
//             ),
//             textAlign: TextAlign.center,
//           ),
//
//           const SizedBox(height: 16),
//
//           // Error message
//           if (_error != null)
//             Container(
//               padding: const EdgeInsets.all(12),
//               margin: const EdgeInsets.only(bottom: 16),
//               decoration: BoxDecoration(
//                 color: Colors.red.withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.red.withOpacity(0.5)),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(Icons.error_outline, color: Colors.red),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       _error!,
//                       style: const TextStyle(color: Colors.red),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//
//           const SizedBox(height: 24),
//
//           // Find Match Button
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton.icon(
//               onPressed: _findMatch,
//               icon: const Icon(Icons.search, size: 24),
//               label: const Padding(
//                 padding: EdgeInsets.symmetric(vertical: 16),
//                 child: Text(
//                   'FIND MATCH',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//               ),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//               ),
//             ),
//           ),
//
//           const SizedBox(height: 32),
//
//           // Game info
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.05),
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: Column(
//               children: [
//                 _buildInfoRow(Icons.people, '2 Players'),
//                 const SizedBox(height: 12),
//                 _buildInfoRow(Icons.timer, '30 sec per turn'),
//                 const SizedBox(height: 12),
//                 _buildInfoRow(Icons.emoji_events, 'Win to earn points'),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInfoRow(IconData icon, String text) {
//     return Row(
//       children: [
//         Icon(icon, color: Colors.white54, size: 20),
//         const SizedBox(width: 12),
//         Text(
//           text,
//           style: const TextStyle(color: Colors.white70, fontSize: 14),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildSearchingView() {
//     return Padding(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           // Animated search indicator
//           Stack(
//             alignment: Alignment.center,
//             children: [
//               SizedBox(
//                 width: 150,
//                 height: 150,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 4,
//                   valueColor: AlwaysStoppedAnimation(
//                     Colors.blue.withOpacity(0.3),
//                   ),
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.all(24),
//                 decoration: BoxDecoration(
//                   color: Colors.blue.withOpacity(0.2),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(
//                   Icons.search,
//                   size: 60,
//                   color: Colors.blue,
//                 ),
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 32),
//
//           const Text(
//             'Finding Opponent...',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//
//           const SizedBox(height: 8),
//
//           Text(
//             'Waiting for another player to join',
//             style: TextStyle(
//               color: Colors.white.withOpacity(0.7),
//               fontSize: 16,
//             ),
//           ),
//
//           const SizedBox(height: 24),
//
//           // Timer
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(24),
//             ),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Icon(Icons.timer, color: Colors.white54),
//                 const SizedBox(width: 8),
//                 Text(
//                   '${_waitSeconds}s',
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           const SizedBox(height: 32),
//
//           // Cancel button
//           OutlinedButton.icon(
//             onPressed: () => _cancelSearch(),
//             icon: const Icon(Icons.close),
//             label: const Text('CANCEL'),
//             style: OutlinedButton.styleFrom(
//               foregroundColor: Colors.white70,
//               side: BorderSide(color: Colors.white.withOpacity(0.3)),
//               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// lib/feature/games/ludo/ludo_lobby_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/ludo_game_service.dart';
import 'ludo_wrapper_screen.dart';

class LudoLobbyScreen extends StatefulWidget {
  const LudoLobbyScreen({Key? key}) : super(key: key);

  @override
  State<LudoLobbyScreen> createState() => _LudoLobbyScreenState();
}

class _LudoLobbyScreenState extends State<LudoLobbyScreen> {
  final _service = LudoGameService();
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _searching = false;
  String? _error;
  Timer? _waitingTimer;
  Timer? _searchTimer;
  int _waitSeconds = 0;
  String? _myQueueDocId;
  StreamSubscription? _matchListener;
  bool _navigated = false;

  // NEW: Player count selection
  int _selectedPlayerCount = 2;
  int _playersFound = 0;

  @override
  void dispose() {
    _waitingTimer?.cancel();
    _searchTimer?.cancel();
    _matchListener?.cancel();
    _cleanupQueue();
    super.dispose();
  }

  Future<void> _cleanupQueue() async {
    if (_myQueueDocId != null) {
      try {
        final currentUid = _auth.currentUser?.uid;
        if (currentUid != null) {
          final docRef = _fs.collection('ludo_queue').doc(_myQueueDocId);
          final docSnap = await docRef.get();
          if (docSnap.exists && docSnap.data()?['uid'] == currentUid) {
            await _service.dequeue(_myQueueDocId!);
            debugPrint('✅ Cleaned up queue doc: $_myQueueDocId');
          }
        }
      } catch (e) {
        debugPrint('❌ Cleanup error: $e');
      }
      _myQueueDocId = null;
    }
  }

  Future<void> _findMatch() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _error = 'Please sign in to play');
      return;
    }

    _navigated = false;
    _playersFound = 1; // Self
    setState(() {
      _searching = true;
      _error = null;
      _waitSeconds = 0;
    });

    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted && !_navigated) {
        setState(() => _waitSeconds++);
      }
      if (_waitSeconds > 120) { // 2 min timeout for 4P
        t.cancel();
        _cancelSearch('No players found. Try again later.');
      }
    });

    try {
      debugPrint('🔍 Looking for ${_selectedPlayerCount}P game...');

      // Add self to queue with player count preference
      final queueRef = await _service.enqueue(
        user.uid,
        user.displayName ?? 'Player',
        user.photoURL,
        playerCount: _selectedPlayerCount,
      );
      _myQueueDocId = queueRef.id;
      debugPrint('✅ Added to queue: ${queueRef.id}');

      // Listen for matches
      _matchListener = _fs
          .collection('ludo_matches')
          .where('state', whereIn: ['waiting', 'playing'])
          .where('maxPlayers', isEqualTo: _selectedPlayerCount)
          .snapshots()
          .listen((snapshot) {
        if (_navigated) return;

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final players = Map<String, dynamic>.from(data['players'] ?? {});
          final createdAt = data['createdAt'] as Timestamp?;

          // Skip old matches
          if (createdAt != null) {
            final age = DateTime.now().difference(createdAt.toDate());
            if (age.inHours > 1) continue;
          }

          if (players.containsKey(user.uid)) {
            final playerInfo = players[user.uid] as Map<String, dynamic>?;
            final status = playerInfo?['status']?.toString() ?? 'active';

            if (status == 'active') {
              // Check if game is ready to start
              final activePlayers = data['activePlayers'] ?? players.length;
              final maxPlayers = data['maxPlayers'] ?? 2;

              setState(() => _playersFound = activePlayers);

              if (activePlayers >= maxPlayers) {
                debugPrint('✅ Match ready: ${doc.id}');
                _cleanupQueue();
                _navigateToGame(doc.id);
                return;
              }
            }
          }
        }
      });

      // Periodically try to create/join match
      _searchTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (_navigated || !_searching || !mounted) {
          timer.cancel();
          return;
        }

        await _tryCreateOrJoinMatch(user);
      });

      // Initial attempt
      await _tryCreateOrJoinMatch(user);

    } catch (e) {
      debugPrint('❌ Find match error: $e');
      _cancelSearch('Connection error. Please try again.');
    }
  }

  Future<void> _tryCreateOrJoinMatch(User user) async {
    try {
      if (_selectedPlayerCount == 2) {
        // 2 Player: Find one opponent
        final opponents = await _service.findQueueOpponents(
          user.uid,
          1,
          playerCount: 2,
        );

        if (opponents.isNotEmpty && !_navigated) {
          final opponent = opponents.first;
          final oppData = opponent.data() ?? {};
          final oppUid = oppData['uid']?.toString() ?? '';

          if (oppUid.isNotEmpty && oppUid != user.uid) {
            final matchRef = await _service.createMatchFromQueue(
              opponentRefs: [opponent.reference],
              opponentUids: [oppUid],
              opponentNames: [oppData['displayName']?.toString() ?? 'Player'],
              opponentAvatars: [oppData['avatar']?.toString() ?? ''],
              hostUid: user.uid,
              hostName: user.displayName ?? 'Player',
              hostAvatar: user.photoURL ?? '',
              playerCount: 2,
            );

            try { await opponent.reference.delete(); } catch (_) {}
            _cleanupQueue();
            _navigateToGame(matchRef.id);
          }
        }
      } else {
        // 4 Player: Find three opponents
        final opponents = await _service.findQueueOpponents(
          user.uid,
          3,
          playerCount: 4,
        );

        setState(() => _playersFound = 1 + opponents.length);

        if (opponents.length >= 3 && !_navigated) {
          final matchRef = await _service.createMatchFromQueue(
            opponentRefs: opponents.map((o) => o.reference).toList(),
            opponentUids: opponents.map((o) => o.data()?['uid']?.toString() ?? '').toList(),
            opponentNames: opponents.map((o) => o.data()?['displayName']?.toString() ?? 'Player').toList(),
            opponentAvatars: opponents.map((o) => o.data()?['avatar']?.toString() ?? '').toList(),
            hostUid: user.uid,
            hostName: user.displayName ?? 'Player',
            hostAvatar: user.photoURL ?? '',
            playerCount: 4,
          );

          for (final opp in opponents) {
            try { await opp.reference.delete(); } catch (_) {}
          }
          _cleanupQueue();
          _navigateToGame(matchRef.id);
        }
      }
    } catch (e) {
      debugPrint('❌ Create/Join match error: $e');
    }
  }

  void _navigateToGame(String matchId) {
    if (_navigated) return;
    _navigated = true;

    _waitingTimer?.cancel();
    _searchTimer?.cancel();
    _matchListener?.cancel();

    if (!mounted) return;

    debugPrint('🎮 Navigating to game: $matchId');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LudoWrapperScreen(matchId: matchId),
      ),
    );
  }

  void _cancelSearch([String? errorMessage]) {
    _waitingTimer?.cancel();
    _searchTimer?.cancel();
    _matchListener?.cancel();
    _cleanupQueue();

    if (mounted) {
      setState(() {
        _searching = false;
        _error = errorMessage;
        _playersFound = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0E2E), Color(0xFF2D1B4E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _searching ? _buildSearchingView() : _buildLobbyView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                _cancelSearch();
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎲 Ludo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Classic Board Game',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Game icon
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.casino,
              size: 80,
              color: Colors.blue,
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'Play Ludo Online',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Choose game mode and find opponents!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Player Count Selection
          _buildPlayerCountSelector(),

          const SizedBox(height: 24),

          // Error message
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // Find Match Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _findMatch,
              icon: const Icon(Icons.search, size: 24),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'FIND ${_selectedPlayerCount}P MATCH',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedPlayerCount == 2 ? Colors.blue : Colors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Game info
          _buildGameInfo(),
        ],
      ),
    );
  }

  Widget _buildPlayerCountSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 2 Players
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPlayerCount = 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _selectedPlayerCount == 2
                      ? Colors.blue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.people,
                      color: _selectedPlayerCount == 2
                          ? Colors.white
                          : Colors.white54,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '2 Players',
                      style: TextStyle(
                        color: _selectedPlayerCount == 2
                            ? Colors.white
                            : Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Quick Match',
                      style: TextStyle(
                        color: _selectedPlayerCount == 2
                            ? Colors.white70
                            : Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4 Players
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPlayerCount = 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _selectedPlayerCount == 4
                      ? Colors.purple
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.groups,
                      color: _selectedPlayerCount == 4
                          ? Colors.white
                          : Colors.white54,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '4 Players',
                      style: TextStyle(
                        color: _selectedPlayerCount == 4
                            ? Colors.white
                            : Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Full Game',
                      style: TextStyle(
                        color: _selectedPlayerCount == 4
                            ? Colors.white70
                            : Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.people,
            _selectedPlayerCount == 2 ? '2 Players' : '4 Players',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.timer, '30 sec per turn'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.emoji_events, 'Win to earn points'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.chat, 'In-game chat available'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSearchingView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated search indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation(
                    (_selectedPlayerCount == 2 ? Colors.blue : Colors.purple)
                        .withOpacity(0.3),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (_selectedPlayerCount == 2 ? Colors.blue : Colors.purple)
                      .withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _selectedPlayerCount == 2 ? Icons.people : Icons.groups,
                  size: 60,
                  color: _selectedPlayerCount == 2 ? Colors.blue : Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          Text(
            'Finding ${_selectedPlayerCount}P Match...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Players found indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.green.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '$_playersFound / $_selectedPlayerCount Players',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_selectedPlayerCount, (index) {
              final isFound = index < _playersFound;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFound ? Colors.green : Colors.white24,
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: Colors.white54),
                const SizedBox(width: 8),
                Text(
                  '${_waitSeconds}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Cancel button
          OutlinedButton.icon(
            onPressed: () => _cancelSearch(),
            icon: const Icon(Icons.close),
            label: const Text('CANCEL'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}