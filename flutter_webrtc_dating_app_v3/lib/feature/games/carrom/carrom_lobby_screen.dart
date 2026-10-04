// lib/feature/games/carrom/carrom_lobby_screen.dart
// STATUS: ENHANCED WITH ANIMATIONS ✅

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'carrom_match_screen.dart';
import '../../../core/constants/app_colors.dart';

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

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _waveController;
  late AnimationController _dotsController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _waveAnimation;

  // Tips
  final List<String> _tips = [
    '💡 Aim carefully before striking!',
    '💡 Pocket the Queen and cover it for bonus!',
    '💡 Don\'t pocket the striker - it\'s a foul!',
    '💡 Clear all your coins after the Queen is covered to win!',
    '💡 Use angles to pocket difficult coins!',
    '💡 Control your power for precision shots!',
  ];
  int _currentTipIndex = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
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
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // Wave Animation (for ripple effect)
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOut),
    );

    // Dots Animation (for loading dots)
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  void _startAnimations() {
    _pulseController.repeat(reverse: true);
    _rotateController.repeat();
    _waveController.repeat();
    _dotsController.repeat();
  }

  void _stopAnimations() {
    _pulseController.stop();
    _rotateController.stop();
    _waveController.stop();
    _dotsController.stop();
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
    _pulseController.dispose();
    _rotateController.dispose();
    _waveController.dispose();
    _dotsController.dispose();
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
    final displayName = _auth.currentUser?.displayName ?? 'Player';
    final avatar = _auth.currentUser?.photoURL;

    if (uid == null) {
      _handleError('Not signed in. Please login first.');
      return;
    }

    try {
      final matchDocRef = await _createOrPair(uid, displayName, avatar);

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
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        _handleError('No opponent found. Please try again!');
      }
    } catch (e) {
      _handleError('Connection error. Please check your internet.');
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
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
          return _findMatchCreatedSince(uid, searchStart);
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
                'displayName': candData['displayName'] ?? 'Opponent',
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
          tx.update(candidate.reference, {'matchId': matchRef.id, 'claimedBy': uid});
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
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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

              const Spacer(flex: 2),

              // ===== MAIN CONTENT =====
              _searching ? _buildSearchingState() : _buildIdleState(),

              const Spacer(flex: 1),

              // ===== TIPS SECTION =====
              if (_searching) _buildTipsSection(),

              const Spacer(flex: 2),

              // ===== BOTTOM BUTTON =====
              _buildBottomButton(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _searching ? null : () => Navigator.pop(context),
            ),
          ),

          const Expanded(
            child: Text(
              'CARROM',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
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
    return Column(
      children: [
        // Carrom Icon
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.shade400,
                Colors.orange.shade700,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.radio_button_checked,
            size: 70,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 32),

        // Title
        const Text(
          'Ready to Play?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Subtitle
        Text(
          'Find an opponent and start the match!',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 15,
          ),
        ),

        // Error Message
        if (_error != null) ...[
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchingState() {
    return Column(
      children: [
        // Animated Search Icon with Rings
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple Waves
              ...List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _waveAnimation,
                  builder: (context, child) {
                    final delay = index * 0.3;
                    final value = (_waveAnimation.value + delay) % 1.0;
                    return Container(
                      width: 120 + (value * 100),
                      height: 120 + (value * 100),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.5 * (1 - value)),
                          width: 2,
                        ),
                      ),
                    );
                  },
                );
              }),

              // Rotating Outer Ring
              AnimatedBuilder(
                animation: _rotateAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotateAnimation.value,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: CustomPaint(
                        painter: _DashedCirclePainter(
                          color: Colors.orange.withOpacity(0.6),
                          dashCount: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Pulsing Inner Circle
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade700,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.5),
                            blurRadius: 25,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_search,
                        size: 55,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Searching Text with Animated Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Finding Opponent',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            _buildAnimatedDots(),
          ],
        ),
        const SizedBox(height: 16),

        // Timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(_waitingSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedDots() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        final value = _dotsController.value;
        return Row(
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final opacity = (math.sin((value + delay) * math.pi * 2) + 1) / 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: const Text(
                  '.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildTipsSection() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<int>(_currentTipIndex),
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lightbulb_outline,
                color: Colors.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _tips[_currentTipIndex],
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: _searching
            ? OutlinedButton(
          onPressed: _cancelSearch,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close, size: 22),
              SizedBox(width: 8),
              Text(
                'CANCEL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        )
            : ElevatedButton(
          onPressed: _findMatch,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: Colors.orange.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 24),
              SizedBox(width: 12),
              Text(
                'FIND MATCH',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== DASHED CIRCLE PAINTER =====
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final int dashCount;

  _DashedCirclePainter({
    required this.color,
    required this.dashCount,
  });

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