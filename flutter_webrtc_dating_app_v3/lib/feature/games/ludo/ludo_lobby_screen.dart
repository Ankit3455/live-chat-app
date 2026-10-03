// lib/feature/games/ludo/ludo_lobby_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/ludo_game_service.dart';
import 'ludo_wrapper_screen.dart';
import '../../../core/constants/app_colors.dart';

class LudoLobbyScreen extends StatefulWidget {
  const LudoLobbyScreen({Key? key}) : super(key: key);

  @override
  State<LudoLobbyScreen> createState() => _LudoLobbyScreenState();
}

class _LudoLobbyScreenState extends State<LudoLobbyScreen> {
  final _service = LudoGameService();
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  static const Duration _scanEvery = Duration(seconds: 3);
  // Tolerates clock skew between this device and the match creator.
  static const Duration _matchCreatedSlack = Duration(seconds: 30);

  bool _searching = false;
  String? _error;
  Timer? _waitingTimer;
  Timer? _searchTimer;
  Timer? _heartbeatTimer;
  Timer? _claimTimeout;
  int _waitSeconds = 0;
  String? _myQueueDocId;
  StreamSubscription? _matchListener;
  StreamSubscription? _queueListener;
  bool _navigated = false;
  bool _creating = false;
  DateTime? _searchStartedAt;
  String? _resumeMatchId;

  // NEW: Player count selection
  int _selectedPlayerCount = 2;
  int _playersFound = 0;

  @override
  void initState() {
    super.initState();
    _loadResumableMatch();
  }

  @override
  void dispose() {
    _stopTimers();
    _cleanupQueue();
    super.dispose();
  }

  void _stopTimers() {
    _waitingTimer?.cancel();
    _searchTimer?.cancel();
    _heartbeatTimer?.cancel();
    _claimTimeout?.cancel();
    _claimTimeout = null;
    _matchListener?.cancel();
    _matchListener = null;
    _queueListener?.cancel();
    _queueListener = null;
  }

  /// Matches created for this search only, newest first (indexed on
  /// playerUids + state + createdAt), so old games are never re-read.
  Query<Map<String, dynamic>> _newMatchesFor(String uid, DateTime since) => _fs
      .collection('ludo_matches')
      .where('playerUids', arrayContains: uid)
      .where('state', isEqualTo: 'playing')
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
      .orderBy('createdAt', descending: true)
      .limit(5);

  Future<void> _loadResumableMatch() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final matchId = await _service.findResumableMatch(uid);
    if (mounted) setState(() => _resumeMatchId = matchId);
  }

  Future<void> _cleanupQueue() async {
    final docId = _myQueueDocId;
    if (docId == null) return;
    _myQueueDocId = null;
    await _service.dequeue(docId);
  }

  Future<void> _findMatch() async {
    if (_searching) return;
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _error = 'Please sign in to play');
      return;
    }

    _navigated = false;
    _creating = false;
    _playersFound = 1; // Self
    _searchStartedAt = DateTime.now();
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

      // A match created by another player claims (deletes) our queue entry,
      // so listen for matches we are part of before entering the queue.
      final since = _searchStartedAt!.subtract(_matchCreatedSlack);
      _matchListener = _newMatchesFor(user.uid, since).snapshots().listen(
        (snapshot) {
          if (_navigated) return;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data['maxPlayers'] != _selectedPlayerCount) continue;
            final players = Map<String, dynamic>.from(data['players'] ?? {});
            final info = players[user.uid];
            if (info is Map && info['status'] == 'active') {
              debugPrint('✅ Match ready: ${doc.id}');
              _navigateToGame(doc.id);
              return;
            }
          }
        },
        onError: (e) => debugPrint('❌ Match listener error: $e'),
      );

      final queueRef = await _service.enqueue(
        user.uid,
        user.displayName ?? 'Player',
        user.photoURL,
        playerCount: _selectedPlayerCount,
      );
      _myQueueDocId = queueRef.id;
      if (!_searching || _navigated) {
        _cleanupQueue();
        return;
      }
      debugPrint('✅ Added to queue: ${queueRef.id}');

      // The host's transaction deletes our entry when it claims us.
      _queueListener = queueRef.snapshots().listen(
        (snap) {
          if (!snap.exists) _onQueueEntryGone();
        },
        onError: (e) => debugPrint('❌ Queue listener error: $e'),
      );

      _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        if (_navigated || !_searching) return;
        final stillQueued = await _service.heartbeat(user.uid);
        if (!stillQueued) _onQueueEntryGone();
      });

      _searchTimer = Timer.periodic(_scanEvery, (timer) async {
        if (_navigated || !_searching || !mounted) {
          timer.cancel();
          return;
        }
        await _tryCreateOrJoinMatch(user);
      });

      await _tryCreateOrJoinMatch(user);
    } catch (e) {
      debugPrint('❌ Find match error: $e');
      _cancelSearch('Connection error. Please try again.');
    }
  }

  /// Our queue entry was claimed by another player's match: stop polling
  /// and wait for the match listener.
  void _onQueueEntryGone() {
    if (_navigated || !_searching) return;
    _myQueueDocId = null;
    _searchTimer?.cancel();
    _heartbeatTimer?.cancel();
    _queueListener?.cancel();
    _queueListener = null;
    _claimTimeout ??= Timer(const Duration(seconds: 15), () {
      if (!_navigated) {
        _cancelSearch('Could not join the match. Please try again.');
      }
    });
  }

  Future<void> _tryCreateOrJoinMatch(User user) async {
    if (_creating || _navigated || !_searching) return;
    _creating = true;
    try {
      // Cleared by the queue listener once our entry is claimed.
      if (_myQueueDocId == null) return;

      final needed = _selectedPlayerCount - 1;
      final opponents = await _service.findQueueOpponents(
        user.uid,
        needed,
        playerCount: _selectedPlayerCount,
      );

      if (mounted && _selectedPlayerCount > 2) {
        setState(() => _playersFound = 1 + opponents.length);
      }

      if (opponents.length < needed || _navigated || !_searching) return;

      final matchRef = await _service.createMatchFromQueue(
        hostQueueRef: _service.queueRef(user.uid),
        opponentRefs: opponents.map((o) => o.reference).toList(),
        opponentUids:
            opponents.map((o) => o.data()?['uid']?.toString() ?? '').toList(),
        opponentNames: opponents
            .map((o) => o.data()?['displayName']?.toString() ?? 'Player')
            .toList(),
        opponentAvatars: opponents
            .map((o) => o.data()?['avatar']?.toString() ?? '')
            .toList(),
        hostUid: user.uid,
        hostName: user.displayName ?? 'Player',
        hostAvatar: user.photoURL ?? '',
        playerCount: _selectedPlayerCount,
      );

      _myQueueDocId = null; // claimed inside the transaction
      _navigateToGame(matchRef.id);
    } catch (e) {
      // Usually another player claimed one of the entries first.
      debugPrint('❌ Create/Join match error: $e');
    } finally {
      _creating = false;
    }
  }

  void _navigateToGame(String matchId) {
    if (_navigated) return;
    _navigated = true;

    _stopTimers();
    _cleanupQueue();

    if (!mounted) return;

    debugPrint('🎮 Navigating to game: $matchId');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LudoWrapperScreen(matchId: matchId),
      ),
    );
  }

  void _resumeMatch() {
    final matchId = _resumeMatchId;
    if (matchId == null) return;
    _navigateToGame(matchId);
  }

  void _cancelSearch([String? errorMessage]) {
    _stopTimers();
    _cleanupQueue();

    if (mounted) {
      setState(() {
        _searching = false;
        _error = errorMessage;
        _playersFound = 0;
      });
    } else {
      _searching = false;
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
            colors: [AppColors.backgroundDeep, AppColors.surfaceCard],
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
              tooltip: 'Back',
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

          if (_resumeMatchId != null) ...[
            _buildResumeBanner(),
            const SizedBox(height: 24),
          ],

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
                            : Colors.white60,
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
                            : Colors.white60,
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
          _buildInfoRow(Icons.chat, 'In-game chat available'),
        ],
      ),
    );
  }

  Widget _buildResumeBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sports_esports, color: Colors.green),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You have a match in progress.',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: _resumeMatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Resume match'),
          ),
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