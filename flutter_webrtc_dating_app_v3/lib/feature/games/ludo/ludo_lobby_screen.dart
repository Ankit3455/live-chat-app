// lib/feature/games/ludo/ludo_lobby_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/ludo_game_service.dart';
import 'ludo_wrapper_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/custom_button.dart';

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
      setState(() => _error = 'Log in to play Ludo.');
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
      if (_waitSeconds > 120) {
        // 2 min timeout for 4P
        t.cancel();
        _cancelSearch(
          "No one's available right now. Try again in a few minutes.",
        );
      }
    });

    try {
      debugPrint('🔍 Looking for ${_selectedPlayerCount}P game...');

      // A match created by another player claims (deletes) our queue entry,
      // so listen for matches we are part of before entering the queue.
      final since = _searchStartedAt!.subtract(_matchCreatedSlack);
      _matchListener = _newMatchesFor(user.uid, since).snapshots().listen((
        snapshot,
      ) {
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
      }, onError: (e) => debugPrint('❌ Match listener error: $e'));

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
      _queueListener = queueRef.snapshots().listen((snap) {
        if (!snap.exists) _onQueueEntryGone();
      }, onError: (e) => debugPrint('❌ Queue listener error: $e'));

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
      _cancelSearch("Couldn't connect. Check your internet and try again.");
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
        _cancelSearch("Couldn't join the match. Tap Find match to try again.");
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

  void _navigateToGame(String matchId, {bool matchFound = true}) {
    if (_navigated) return;
    _navigated = true;
    if (matchFound) Haptics.success();

    _stopTimers();
    _cleanupQueue();

    if (!mounted) return;

    debugPrint('🎮 Navigating to game: $matchId');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LudoWrapperScreen(matchId: matchId)),
    );
  }

  void _resumeMatch() {
    final matchId = _resumeMatchId;
    if (matchId == null) return;
    _navigateToGame(matchId, matchFound: false);
  }

  void _cancelSearch([String? errorMessage]) {
    if (errorMessage != null) Haptics.error();
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
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: () {
              _cancelSearch();
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                _searching ? 'Ludo · Find a match' : 'Ludo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyView() {
    final error = _error;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandPurpleMid.withOpacity(0.16),
                border: Border.all(
                  color: AppColors.brandPurpleMid.withOpacity(0.4),
                ),
              ),
              child: const Icon(
                Icons.casino_outlined,
                size: 60,
                color: AppColors.brandPurpleLight,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Play Ludo online',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a mode and find opponents.',
            style: TextStyle(color: AppColors.lavender, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_resumeMatchId != null) ...[
            AppBanner(
              message: 'You have a match in progress.',
              icon: Icons.sports_esports_outlined,
              actionLabel: 'Resume',
              onAction: _resumeMatch,
            ),
            const SizedBox(height: 20),
          ],
          _buildPlayerCountSelector(),
          const SizedBox(height: 20),
          if (error != null) ...[
            AppBanner(message: error, tone: AppBannerTone.error),
            const SizedBox(height: 16),
          ],
          CustomButton(
            text: 'Find $_selectedPlayerCount-player match',
            leftIcon: Icons.search,
            onPressed: _findMatch,
          ),
          const SizedBox(height: 24),
          _buildGameInfo(),
        ],
      ),
    );
  }

  Widget _buildPlayerCountSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeOption(
              count: 2,
              icon: Icons.people_outline,
              label: '2 players',
              caption: 'Quick match',
            ),
          ),
          Expanded(
            child: _modeOption(
              count: 4,
              icon: Icons.groups_outlined,
              label: '4 players',
              caption: 'Full game',
            ),
          ),
        ],
      ),
    );
  }

  void _selectMode(int count) {
    if (_selectedPlayerCount == count) return;
    Haptics.selection();
    setState(() => _selectedPlayerCount = count);
  }

  Widget _modeOption({
    required int count,
    required IconData icon,
    required String label,
    required String caption,
  }) {
    final selected = _selectedPlayerCount == count;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $caption',
      excludeSemantics: true,
      onTap: () => _selectMode(count),
      child: InkWell(
        onTap: () => _selectMode(count),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandPurple.withOpacity(0.24)
                : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? AppColors.brandPurpleMid : AppColors.surfaceCard,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color:
                    selected ? AppColors.brandPurpleLight : AppColors.lavender,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.white : AppColors.lavender,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.people_outline,
            _selectedPlayerCount == 2 ? '2 players' : '4 players',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.timer_outlined, '30 sec per turn'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.chat_bubble_outline, 'In-game chat available'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.brandPurpleLight, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.lavender, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchingView() {
    final user = _auth.currentUser;
    final multi = _selectedPlayerCount > 2;
    final mins = _waitSeconds ~/ 60;
    final secs = (_waitSeconds % 60).toString().padLeft(2, '0');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          children: [
            _SearchPulse(
              photoUrl: user?.photoURL,
              name: user?.displayName,
              accent: AppColors.brandPurpleLight,
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Column(
                children: [
                  Text(
                    multi ? 'Looking for players…' : 'Looking for an opponent…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$mins:$secs',
                    semanticsLabel: '$_waitSeconds seconds',
                    style: const TextStyle(
                      color: AppColors.brandPurpleLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Keep this screen open',
                    style: TextStyle(color: AppColors.lavender, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (multi) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...List.generate(_selectedPlayerCount, (index) {
                      final isFound = index < _playersFound;
                      return Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isFound ? AppColors.success : AppColors.surface2,
                          border: Border.all(color: AppColors.borderStrong),
                        ),
                      );
                    }),
                    const SizedBox(width: 4),
                    Text(
                      '$_playersFound / $_selectedPlayerCount players',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            CustomButton(
              text: 'Cancel',
              type: ButtonType.outline,
              onPressed: () => _cancelSearch(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searching visual: rings pulse outward from the player's avatar.
class _SearchPulse extends StatefulWidget {
  const _SearchPulse({
    required this.photoUrl,
    required this.name,
    required this.accent,
  });

  final String? photoUrl;
  final String? name;
  final Color accent;

  @override
  State<_SearchPulse> createState() => _SearchPulseState();
}

class _SearchPulseState extends State<_SearchPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: decorative rings stay still.
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photoUrl;
    final name = widget.name?.trim() ?? '';
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Semantics(
      label: 'Searching for players',
      image: true,
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ...List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final value = (_controller.value + index / 3) % 1.0;
                  final size = 220 * (0.35 + 0.65 * value);
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.accent.withOpacity(0.5 * (1 - value)),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              );
            }),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface2,
                border: Border.all(color: widget.accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withOpacity(0.35),
                    blurRadius: 40,
                  ),
                ],
              ),
              child: ClipOval(
                child: photo != null && photo.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: photo,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => fallback,
                        errorWidget: (_, __, ___) => fallback,
                      )
                    : fallback,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
