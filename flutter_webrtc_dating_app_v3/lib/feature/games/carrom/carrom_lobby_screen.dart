// lib/feature/games/carrom/carrom_lobby_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'carrom_match_screen.dart';
import '../game_identity.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/custom_button.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';

class CarromLobbyScreen extends StatefulWidget {
  const CarromLobbyScreen({Key? key}) : super(key: key);

  @override
  State<CarromLobbyScreen> createState() => _CarromLobbyScreenState();
}

class _CarromLobbyScreenState extends State<CarromLobbyScreen>
    with TickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // State
  bool _searching = false;
  String? _error;
  int _waitingSeconds = 0;
  Timer? _waitingTimer;
  String? _myQueueDocId;
  GameIdentity? _me = GameIdentity.current;

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _waveController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _waveAnimation;

  // Tips
  final List<String> _tips = [
    'Tip: Take a moment to aim before you shoot.',
    'Tip: Pocket the Queen and cover it for 3 bonus points.',
    "Tip: Don't pocket the striker. It's a foul.",
    'Tip: Clear all your coins once the Queen is covered to win.',
    'Tip: Bounce off the edges to reach tricky coins.',
    'Tip: Use less power for more accurate shots.',
  ];
  int _currentTipIndex = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    GameIdentity.mine().then((me) {
      if (mounted) setState(() => _me = me);
    });
  }

  void _initAnimations() {
    // Pulse Animation (for search icon)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotate Animation (for outer ring)
    _rotateController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _rotateController, curve: Curves.linear));

    // Wave Animation (for ripple effect)
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _waveController, curve: Curves.easeOut));
  }

  void _startAnimations() {
    // Reduced motion: keep the searching rings static.
    if (MediaQuery.of(context).disableAnimations) return;
    _pulseController.repeat(reverse: true);
    _rotateController.repeat();
    _waveController.repeat();
  }

  void _stopAnimations() {
    _pulseController.stop();
    _rotateController.stop();
    _waveController.stop();
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
    _pulseController.dispose();
    _rotateController.dispose();
    _waveController.dispose();
    _cleanupQueue();
    super.dispose();
  }

  Future<void> _cleanupQueue() async {
    if (_myQueueDocId != null) {
      try {
        await _firestore.collection('carrom_queue').doc(_myQueueDocId).delete();
      } catch (_) {}
    }
  }

  Future<void> _findMatch() async {
    setState(() {
      _searching = true;
      _error = null;
      _waitingSeconds = 0;
      _currentTipIndex = 0;
    });

    _startAnimations();

    // Start waiting timer
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _waitingSeconds++;
          // Change tip every 5 seconds
          if (_waitingSeconds % 5 == 0) {
            _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
          }
        });
      }
    });

    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      _handleError('Log in to play Carrom.');
      return;
    }

    try {
      final me = await GameIdentity.mine();
      if (!mounted || !_searching) return;
      if (_me != me) setState(() => _me = me);
      final matchDocRef = await _createOrPair(uid, me.name, me.avatar);

      if (matchDocRef != null) {
        _stopAnimations();
        _waitingTimer?.cancel();

        if (!mounted) return;

        // Navigate with animation
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                CarromMatchScreen(matchId: matchDocRef.id),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        _handleError(
          "No one's available right now. Tap Find match to try again.",
        );
      }
    } catch (e) {
      _handleError("Couldn't connect. Check your internet and try again.");
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    Haptics.error();
    setState(() {
      _error = message;
      _searching = false;
    });
    _stopAnimations();
    _waitingTimer?.cancel();
  }

  static const Duration _searchTimeout = Duration(seconds: 45);
  static const Duration _queueTtl = Duration(seconds: 60);
  static const Duration _recheckEvery = Duration(seconds: 3);
  // Tolerates clock skew between this device and the match creator.
  static const Duration _matchCreatedSlack = Duration(seconds: 30);

  /// Pairs via `carrom_queue/{uid}`. The waiting player keeps re-checking the
  /// queue and also listens to its own entry: whoever pairs first writes the
  /// new match id into the other player's entry (a "claim").
  Future<DocumentReference<Map<String, dynamic>>?> _createOrPair(
    String uid,
    String displayName,
    String? avatar,
  ) async {
    final myQueueRef = _firestore.collection('carrom_queue').doc(uid);
    final searchStart = DateTime.now();

    // Overwrites any stale entry (and old claim) from a previous search.
    await myQueueRef.set({
      'uid': uid,
      'displayName': displayName,
      'avatar': avatar,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(searchStart.add(_queueTtl)),
    });
    _myQueueDocId = uid;

    final claimed = Completer<String>();
    var entryGone = false;
    final claimSub = myQueueRef.snapshots().listen((snap) {
      if (!snap.exists) entryGone = true;
      final matchId = snap.data()?['matchId'] as String?;
      if (matchId != null && !claimed.isCompleted) claimed.complete(matchId);
    }, onError: (Object e) => debugPrint('Carrom queue listener error: $e'));

    try {
      final end = searchStart.add(_searchTimeout);
      while (DateTime.now().isBefore(end)) {
        if (!mounted || !_searching) return null;
        if (claimed.isCompleted) break;

        final paired = await _tryClaimOpponent(uid, displayName, avatar);
        if (paired != null) {
          _myQueueDocId = null;
          return paired;
        }
        if (claimed.isCompleted) break;

        // Entry gone without a claim we saw (deleted or expired): the match
        // may still exist, so look it up once instead of scanning forever.
        if (entryGone) {
          _myQueueDocId = null;
          return await _findMatchCreatedSince(uid, searchStart);
        }

        await Future.any([claimed.future, Future.delayed(_recheckEvery)]);
      }

      if (claimed.isCompleted) {
        final matchId = await claimed.future;
        try {
          await myQueueRef.delete();
        } catch (_) {}
        _myQueueDocId = null;
        return _firestore.collection('carrom_matches').doc(matchId);
      }
    } finally {
      await claimSub.cancel();
    }

    await _cleanupQueue();
    return null;
  }

  /// Our newest match created during this search (indexed on
  /// playerUids + createdAt).
  Future<DocumentReference<Map<String, dynamic>>?> _findMatchCreatedSince(
    String uid,
    DateTime searchStart,
  ) async {
    final since = searchStart.subtract(_matchCreatedSlack);
    final snap = await _firestore
        .collection('carrom_matches')
        .where('playerUids', arrayContains: uid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    if (data['status'] != 'ready' && data['status'] != 'started') return null;
    // Invited from a chat: not a lobby match.
    if (data['private'] == true) return null;
    return snap.docs.first.reference;
  }

  /// Claims the oldest live entry in one transaction: creates the match,
  /// writes its id into the opponent's entry and removes our own entry.
  Future<DocumentReference<Map<String, dynamic>>?> _tryClaimOpponent(
    String uid,
    String displayName,
    String? avatar,
  ) async {
    final now = DateTime.now();
    // Only live entries are read; expiresAt order follows join order.
    final snap = await _firestore
        .collection('carrom_queue')
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt')
        .limit(10)
        .get();

    final candidates = snap.docs.where((d) {
      final data = d.data();
      final expires = data['expiresAt'];
      return d.id != uid &&
          data['uid'] != uid &&
          data['matchId'] == null &&
          expires is Timestamp &&
          expires.toDate().isAfter(now);
    });

    final myQueueRef = _firestore.collection('carrom_queue').doc(uid);
    for (final candidate in candidates) {
      final matchRef = _firestore.collection('carrom_matches').doc();
      try {
        final ok = await _firestore.runTransaction<bool>((tx) async {
          final mine = await tx.get(myQueueRef);
          final cand = await tx.get(candidate.reference);
          final candData = cand.data();
          final candUid = candData?['uid'] as String?;
          final expires = candData?['expiresAt'];
          if (!mine.exists || mine.data()?['matchId'] != null) return false;
          if (candData == null ||
              candUid == null ||
              candUid == uid ||
              candData['matchId'] != null ||
              expires is! Timestamp ||
              !expires.toDate().isAfter(DateTime.now())) {
            return false;
          }

          tx.set(matchRef, {
            'players': {
              uid: {'displayName': displayName, 'avatar': avatar},
              candUid: {
                'displayName':
                    GameIdentity.shown(candData['displayName'], 'Opponent'),
                'avatar': candData['avatar'],
              },
            },
            'playerUids': [uid, candUid],
            'status': 'ready',
            'host': uid,
            'turn': uid,
            'joined': <String, bool>{},
            'createdAt': FieldValue.serverTimestamp(),
            'boardState': null,
            'lastMove': null,
            'scores': {uid: 0, candUid: 0},
            'moveSeq': 0,
            'turnSeq': 0,
          });
          tx.update(candidate.reference, {
            'matchId': matchRef.id,
            'claimedBy': uid,
          });
          tx.delete(myQueueRef);
          return true;
        });
        if (ok) return matchRef;
      } catch (e) {
        debugPrint('Carrom pairing attempt failed: $e');
      }
      // Our own entry may have been claimed meanwhile; let the caller see it.
      final mine = await myQueueRef.get();
      if (!mine.exists || mine.data()?['matchId'] != null) return null;
    }
    return null;
  }

  void _cancelSearch() {
    _stopAnimations();
    _waitingTimer?.cancel();
    _cleanupQueue();
    Navigator.pop(context);
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundDeep,
              AppColors.surfaceCard,
              AppColors.backgroundDeep,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ===== HEADER =====
              _buildHeader(),

              // ===== MAIN CONTENT =====
              if (_searching)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      children: [
                        _buildSearchingState(),
                        const SizedBox(height: 24),
                        _buildRulesCard(),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(child: _buildIdleState()),
                      ),
                    ),
                  ),
                ),

              // ===== BOTTOM BUTTON =====
              _buildBottomButton(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: _searching ? null : () => Navigator.pop(context),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                _searching ? 'Carrom · Find a match' : 'Carrom',
                textAlign: TextAlign.center,
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

          // Placeholder for symmetry
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildIdleState() {
    final error = _error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        ExcludeSemantics(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.pinkLight.withOpacity(0.12),
              border: Border.all(color: AppColors.pinkLight.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.pinkLight.withOpacity(0.2),
                  blurRadius: 40,
                ),
              ],
            ),
            child: const Icon(
              Icons.adjust,
              size: 60,
              color: AppColors.pinkLight,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Ready to play?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Find an opponent and start the match.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.lavender, fontSize: 15),
        ),
        if (error != null) ...[
          const SizedBox(height: 20),
          AppBanner(message: error, tone: AppBannerTone.error),
        ],
        const SizedBox(height: 24),
        _buildRulesCard(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSearchingState() {
    final photo = _me?.avatar;
    final name = _me?.name ?? '';
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

    return Column(
      children: [
        // Pulsing rings around your avatar
        Semantics(
          label: 'Searching for an opponent',
          image: true,
          // Rings, dashes and pulse loop while searching; repaint only them.
          child: RepaintBoundary(
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ...List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _waveAnimation,
                      builder: (context, child) {
                        final value = (_waveAnimation.value + index / 3) % 1.0;
                        final size = 220 * (0.35 + 0.65 * value);
                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.pinkLight.withOpacity(
                                0.5 * (1 - value),
                              ),
                              width: 1.5,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  AnimatedBuilder(
                    animation: _rotateAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotateAnimation.value,
                        child: child,
                      );
                    },
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: CustomPaint(
                        painter: _DashedCirclePainter(
                          color: AppColors.borderStrong,
                          dashCount: 24,
                        ),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) => Transform.scale(
                      // Subtle breathing: 1.0 to ~1.05.
                      scale: 1 + (_pulseAnimation.value - 1) * 0.3,
                      child: child,
                    ),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface2,
                        border: Border.all(color: AppColors.pinkLight, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.pinkLight.withOpacity(0.35),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: photo != null && photo.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: photo,
                                fit: BoxFit.cover,
                                memCacheWidth: (96 *
                                        MediaQuery.devicePixelRatioOf(context))
                                    .round(),
                                placeholder: (_, __) => fallback,
                                errorWidget: (_, __, ___) => fallback,
                              )
                            : fallback,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Column(
            children: [
              const Text(
                'Looking for an opponent…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(_waitingSeconds),
                semanticsLabel: '$_waitingSeconds seconds',
                style: const TextStyle(
                  color: AppColors.pinkLight,
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
      ],
    );
  }

  Widget _buildRulesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.pinkLight),
              SizedBox(width: 8),
              Text(
                'Quick rules',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ruleRow(
            coin: AppColors.lavenderLight,
            bold: 'your own coin',
            before: 'Pocket ',
            after: '',
            points: '+1',
            pointsColor: AppColors.success,
          ),
          const Divider(height: 1),
          _ruleRow(
            coin: AppColors.brandPink,
            before: 'Pocket the ',
            bold: 'Queen',
            after: ' and cover it',
            points: '+3',
            pointsColor: AppColors.success,
          ),
          const Divider(height: 1),
          _ruleRow(
            coin: AppColors.textSubtle,
            before: 'Pocket the ',
            bold: 'striker',
            after: ' (foul)',
            points: '−1',
            pointsColor: AppColors.error,
          ),
          const Divider(height: 1),
          _ruleRow(
            coin: AppColors.surface2,
            before: '',
            bold: 'First to clear',
            after: ' all their coins',
            points: 'Wins',
            pointsColor: AppColors.pinkLight,
          ),
        ],
      ),
    );
  }

  Widget _ruleRow({
    required Color coin,
    required String before,
    required String bold,
    required String after,
    required String points,
    required Color pointsColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: coin,
              border: Border.all(color: AppColors.borderStrong),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: before),
                  TextSpan(
                    text: bold,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: after),
                ],
              ),
              style: const TextStyle(color: AppColors.lavender, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            points,
            style: TextStyle(
              color: pointsColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _searching
          ? CustomButton(
              text: 'Cancel',
              type: ButtonType.outline,
              onPressed: _cancelSearch,
            )
          : CustomButton(
              text: 'Find match',
              leftIcon: Icons.search,
              onPressed: _findMatch,
            ),
    );
  }
}

// ===== DASHED CIRCLE PAINTER =====
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final int dashCount;

  _DashedCirclePainter({required this.color, required this.dashCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final dashAngle = (2 * math.pi) / dashCount;
    final dashLength = dashAngle * 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashLength,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
