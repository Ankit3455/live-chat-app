// lib/feature/games/carrom/carrom_match_screen.dart
// STATUS: ENHANCED WITH VS ANIMATION ✅

import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'carrom_game_screen.dart';

class CarromMatchScreen extends StatefulWidget {
  final String matchId;
  const CarromMatchScreen({Key? key, required this.matchId}) : super(key: key);

  @override
  State<CarromMatchScreen> createState() => _CarromMatchScreenState();
}

class _CarromMatchScreenState extends State<CarromMatchScreen>
    with TickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Map<String, dynamic>? _matchData;

  // Player Info
  String _myName = 'You';
  String _myAvatar = '';
  String _opponentName = 'Opponent';
  String _opponentAvatar = '';

  // Countdown
  int _countdown = 3;
  bool _countdownStarted = false;
  bool _showGo = false;

  // Animation Controllers
  late AnimationController _vsController;
  late AnimationController _playerSlideController;
  late AnimationController _countdownController;
  late AnimationController _glowController;
  late AnimationController _backgroundController;

  // Animations
  late Animation<double> _vsScaleAnimation;
  late Animation<double> _vsRotateAnimation;
  late Animation<Offset> _leftPlayerSlide;
  late Animation<Offset> _rightPlayerSlide;
  late Animation<double> _countdownScale;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _listenMatch();
  }

  void _initAnimations() {
    // VS Badge Animation
    _vsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _vsScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _vsController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _vsRotateAnimation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _vsController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Player Slide Animation
    _playerSlideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _leftPlayerSlide = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _playerSlideController,
      curve: Curves.easeOutBack,
    ));
    _rightPlayerSlide = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _playerSlideController,
      curve: Curves.easeOutBack,
    ));

    // Countdown Animation
    _countdownController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _countdownScale = Tween<double>(begin: 2.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _countdownController,
        curve: Curves.easeOut,
      ),
    );

    // Glow Animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Background Animation
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  void _listenMatch() {
    final myUid = _auth.currentUser?.uid;

    _sub = _firestore
        .collection('carrom_matches')
        .doc(widget.matchId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) {
        Navigator.pop(context);
        return;
      }

      final data = snap.data()!;
      setState(() => _matchData = data);

      // Extract player info
      final players = Map<String, dynamic>.from(data['players'] ?? {});

      players.forEach((uid, info) {
        final playerInfo = info as Map<String, dynamic>? ?? {};
        if (uid == myUid) {
          _myName = playerInfo['displayName']?.toString() ?? 'You';
          _myAvatar = playerInfo['avatar']?.toString() ?? '';
        } else {
          _opponentName = playerInfo['displayName']?.toString() ?? 'Opponent';
          _opponentAvatar = playerInfo['avatar']?.toString() ?? '';
        }
      });

      final status = data['status'] as String? ?? 'waiting';

      if (status == 'ready' && !_countdownStarted) {
        _startMatchSequence(data['host'] == myUid);
      }

      if (status == 'started' && _countdown <= 0) {
        _navigateToGame();
      }
    });
  }

  Future<void> _startMatchSequence(bool isHost) async {
    _countdownStarted = true;

    // Step 1: Slide in players
    await Future.delayed(const Duration(milliseconds: 300));
    _playerSlideController.forward();

    // Step 2: Show VS badge
    await Future.delayed(const Duration(milliseconds: 500));
    _vsController.forward();

    // Step 3: Start countdown
    await Future.delayed(const Duration(milliseconds: 1000));

    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      _countdownController.forward(from: 0);
      await Future.delayed(const Duration(seconds: 1));
    }

    // Show "GO!"
    if (!mounted) return;
    setState(() {
      _countdown = 0;
      _showGo = true;
    });
    _countdownController.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 500));

    // Host sets status to started
    if (isHost && mounted) {
      await _firestore
          .collection('carrom_matches')
          .doc(widget.matchId)
          .update({
        'status': 'started',
        'startedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _navigateToGame() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CarromGameScreen(matchId: widget.matchId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _cancelMatch() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null && !_countdownStarted) {
      try {
        await _firestore
            .collection('carrom_matches')
            .doc(widget.matchId)
            .delete();
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _vsController.dispose();
    _playerSlideController.dispose();
    _countdownController.dispose();
    _glowController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          _buildAnimatedBackground(),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Match Found Title
                _buildMatchFoundTitle(),

                const Spacer(flex: 1),

                // VS Display
                _buildVsDisplay(),

                const Spacer(flex: 1),

                // Countdown or Status
                _buildCountdownOrStatus(),

                const Spacer(flex: 2),

                // Cancel Button
                if (!_countdownStarted) _buildCancelButton(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(
                math.cos(_backgroundController.value * 2 * math.pi) * 0.5,
                math.sin(_backgroundController.value * 2 * math.pi) * 0.5,
              ),
              end: Alignment(
                math.cos((_backgroundController.value + 0.5) * 2 * math.pi) * 0.5,
                math.sin((_backgroundController.value + 0.5) * 2 * math.pi) * 0.5,
              ),
              colors: const [
                Color(0xFF1A0E2E),
                Color(0xFF2D1B4E),
                Color(0xFF3D2B5E),
                Color(0xFF2D1B4E),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchFoundTitle() {
    return Column(
      children: [
        // Stars/Sparkles
        const Text(
          '✨',
          style: TextStyle(fontSize: 32),
        ),
        const SizedBox(height: 8),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.orange, Colors.yellow, Colors.orange],
          ).createShader(bounds),
          child: const Text(
            'MATCH FOUND!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Get ready to play!',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildVsDisplay() {
    return SizedBox(
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Player (Me)
          SlideTransition(
            position: _leftPlayerSlide,
            child: _buildPlayerCard(
              name: _myName,
              avatar: _myAvatar,
              isMe: true,
              color: Colors.blue,
            ),
          ),

          // VS Badge
          ScaleTransition(
            scale: _vsScaleAnimation,
            child: RotationTransition(
              turns: _vsRotateAnimation,
              child: AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.red.shade400,
                          Colors.red.shade700,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3 + (_glowAnimation.value * 0.3)),
                          blurRadius: 20 + (_glowAnimation.value * 15),
                          spreadRadius: 5 + (_glowAnimation.value * 5),
                        ),
                      ],
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Right Player (Opponent)
          SlideTransition(
            position: _rightPlayerSlide,
            child: _buildPlayerCard(
              name: _opponentName,
              avatar: _opponentAvatar,
              isMe: false,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard({
    required String name,
    required String avatar,
    required bool isMe,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar with glow
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3 + (_glowAnimation.value * 0.2)),
                    blurRadius: 15 + (_glowAnimation.value * 10),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: avatar.isNotEmpty
                    ? Image.network(
                  avatar,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _defaultAvatar(name, color),
                )
                    : _defaultAvatar(name, color),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Name
        SizedBox(
          width: 90,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // "YOU" Badge
        if (isMe) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'YOU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _defaultAvatar(String name, Color color) {
    return Container(
      color: color.withOpacity(0.3),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: color,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownOrStatus() {
    if (!_countdownStarted) {
      return Column(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Preparing match...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      );
    }

    return ScaleTransition(
      scale: _countdownScale,
      child: Column(
        children: [
          // Countdown Number or GO!
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _showGo ? Colors.green : Colors.white.withOpacity(0.1),
              border: Border.all(
                color: _showGo ? Colors.green : Colors.white.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                _showGo ? 'GO!' : '$_countdown',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _showGo ? 36 : 60,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _showGo ? 'Starting game...' : 'Get ready!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return TextButton(
      onPressed: _cancelMatch,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.close, color: Colors.red.shade300, size: 18),
          const SizedBox(width: 8),
          Text(
            'Cancel',
            style: TextStyle(
              color: Colors.red.shade300,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}