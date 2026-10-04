// lib/feature/games/carrom/carrom_match_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'carrom_game_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../widgets/custom_button.dart';

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
  bool _countdownDone = false;
  bool _showGo = false;

  // If the match has not started by then, it is cancelled.
  static const Duration _joinTimeout = Duration(seconds: 20);
  static const Duration _startTimeout = Duration(seconds: 15);
  Timer? _joinTimer;
  bool _navigated = false;
  bool _closing = false;
  String? _myUid;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('carrom_matches').doc(widget.matchId);

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
  late Animation<double> _playerFade;
  late Animation<double> _playerScale;
  late Animation<double> _countdownScale;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _myUid = _auth.currentUser?.uid;
    Haptics.success();
    _initAnimations();
    _markJoined();
    _listenMatch();
    _joinTimer = Timer(_joinTimeout, _onStartTimeout);
  }

  Future<void> _markJoined() async {
    final uid = _myUid;
    if (uid == null) return;
    try {
      await _ref.update({'joined.$uid': true});
    } catch (e) {
      debugPrint('Carrom join failed: $e');
    }
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

    _playerFade = CurvedAnimation(
      parent: _playerSlideController,
      curve: Curves.easeOut,
    );
    _playerScale = Tween<double>(begin: 0.8, end: 1).animate(_playerFade);

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
    );
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Background Animation
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: the glow and drifting background stay still.
    if (MediaQuery.of(context).disableAnimations) {
      _glowController.stop();
      _backgroundController.stop();
    } else {
      if (!_glowController.isAnimating) _glowController.repeat(reverse: true);
      if (!_backgroundController.isAnimating) _backgroundController.repeat();
    }
  }

  void _listenMatch() {
    final myUid = _myUid;

    _sub = _ref.snapshots().listen((snap) {
      if (!mounted) return;
      if (!snap.exists) {
        _close('The match was cancelled. Find a new one from the lobby.');
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
      final joined = Map<String, dynamic>.from(data['joined'] ?? {});
      final bothJoined =
          players.length >= 2 && players.keys.every((u) => joined[u] == true);

      if (status == 'ready' && bothJoined && !_countdownStarted) {
        _startMatchSequence(data['host'] == myUid);
      } else if (status == 'started' &&
          (_countdownDone || !_countdownStarted)) {
        _navigateToGame();
      } else if (status == 'cancelled' || status == 'finished') {
        _close('The match was cancelled. Find a new one from the lobby.');
      }
    }, onError: (Object e) => debugPrint('Carrom match listener error: $e'));
  }

  Future<void> _startMatchSequence(bool isHost) async {
    _countdownStarted = true;
    _joinTimer?.cancel();
    _joinTimer = Timer(_startTimeout, _onStartTimeout);

    // Step 1: Slide in players
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _playerSlideController.value = 1;
    } else {
      _playerSlideController.forward();
    }

    // Step 2: Show VS badge
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (reduceMotion) {
      _vsController.value = 1;
    } else {
      _vsController.forward();
    }

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
    if (!mounted) return;
    _countdownDone = true;

    if (isHost) {
      try {
        await _firestore.runTransaction((tx) async {
          final d = (await tx.get(_ref)).data();
          if (d == null || d['status'] != 'ready') return;
          tx.update(_ref, {
            'status': 'started',
            'startedAt': FieldValue.serverTimestamp(),
            'turnStartedAt': FieldValue.serverTimestamp(),
          });
        });
      } catch (e) {
        debugPrint('Carrom start failed: $e');
      }
    }

    // The 'started' snapshot may already have arrived during the countdown.
    if (mounted && _matchData?['status'] == 'started') _navigateToGame();
  }

  /// Nobody joined or started in time: cancel so neither player is stuck.
  Future<void> _onStartTimeout() async {
    if (!mounted || _navigated) return;
    await _cancelIfNotStarted();
    if (mounted && _matchData?['status'] != 'started') {
      _close("Your opponent didn't join. Tap Find match to try again.");
    }
  }

  Future<void> _cancelIfNotStarted() async {
    try {
      await _firestore.runTransaction((tx) async {
        final d = (await tx.get(_ref)).data();
        if (d == null || d['status'] != 'ready') return;
        tx.update(_ref, {
          'status': 'cancelled',
          'cancelledBy': _myUid,
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('Carrom cancel failed: $e');
    }
  }

  void _navigateToGame() {
    if (!mounted || _navigated || _closing) return;
    _navigated = true;
    _joinTimer?.cancel();
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
    if (_navigated || _closing) return;
    await _cancelIfNotStarted();
    if (mounted && _matchData?['status'] != 'started') _close(null);
  }

  void _close(String? message) {
    if (!mounted || _navigated || _closing) return;
    _closing = true;
    if (message != null) Haptics.error();
    _joinTimer?.cancel();
    _sub?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _joinTimer?.cancel();
    _vsController.dispose();
    _playerSlideController.dispose();
    _countdownController.dispose();
    _glowController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelMatch();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Animated Background
            _buildAnimatedBackground(),

            // Main Content
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
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

                          // Cancel Button (until the game has started)
                          if (!_navigated && _matchData?['status'] != 'started')
                            _buildCancelButton(),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
                math.cos((_backgroundController.value + 0.5) * 2 * math.pi) *
                    0.5,
                math.sin((_backgroundController.value + 0.5) * 2 * math.pi) *
                    0.5,
              ),
              colors: const [
                AppColors.backgroundDeep,
                AppColors.surfaceCard,
                AppColors.surface2,
                AppColors.surfaceCard,
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchFoundTitle() {
    final title = Column(
      children: [
        // Stars/Sparkles
        const Text(
          '✨',
          style: TextStyle(fontSize: 32),
        ),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          liveRegion: true,
          child: ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.primaryGradient.createShader(bounds),
            child: const Text(
              'Match found!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Get ready to play',
          style: TextStyle(color: AppColors.lavender, fontSize: 15),
        ),
      ],
    );
    if (MediaQuery.disableAnimationsOf(context)) return title;
    // One-off pop-in for the "Match found!" moment.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
      ),
      child: title,
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
            child: _fadeScaleIn(_buildPlayerCard(
              name: _myName,
              avatar: _myAvatar,
              isMe: true,
              color: AppColors.brandPurpleLight,
            )),
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
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandPink
                              .withOpacity(0.3 + (_glowAnimation.value * 0.3)),
                          blurRadius: 20 + (_glowAnimation.value * 15),
                          spreadRadius: 5 + (_glowAnimation.value * 5),
                        ),
                      ],
                    ),
                    child: const Text(
                      'VS',
                      semanticsLabel: 'versus',
                      style: TextStyle(
                        color: AppColors.white,
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
            child: _fadeScaleIn(_buildPlayerCard(
              name: _opponentName,
              avatar: _opponentAvatar,
              isMe: false,
              color: AppColors.pinkLight,
            )),
          ),
        ],
      ),
    );
  }

  /// Avatars fade and grow in alongside the slide.
  Widget _fadeScaleIn(Widget child) {
    return FadeTransition(
      opacity: _playerFade,
      child: ScaleTransition(scale: _playerScale, child: child),
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
                    color:
                        color.withOpacity(0.3 + (_glowAnimation.value * 0.2)),
                    blurRadius: 15 + (_glowAnimation.value * 10),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: avatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatar,
                        memCacheWidth: 270,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _defaultAvatar(name, color),
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
              color: AppColors.white,
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
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Text(
              'You',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
      return const Column(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppColors.brandPurpleLight,
              strokeWidth: 2,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Getting the board ready…',
            style: TextStyle(color: AppColors.lavender, fontSize: 16),
          ),
        ],
      );
    }

    return ScaleTransition(
      scale: _countdownScale,
      child: Semantics(
        liveRegion: true,
        child: Column(
          children: [
            // Countdown Number or GO!
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _showGo
                    ? AppColors.success.withOpacity(0.2)
                    : AppColors.surface2,
                border: Border.all(
                  color: _showGo ? AppColors.success : AppColors.borderStrong,
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  _showGo ? 'Go!' : '$_countdown',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: _showGo ? 36 : 60,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _showGo ? 'Starting the game…' : 'Get ready',
              style: const TextStyle(color: AppColors.lavender, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return CustomButton(
      text: 'Cancel',
      leftIcon: Icons.close,
      type: ButtonType.text,
      width: 200,
      onPressed: _cancelMatch,
    );
  }
}
