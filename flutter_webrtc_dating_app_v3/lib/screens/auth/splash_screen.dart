import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../services/session_service.dart' show StartDestination;
import 'auth_router.dart';
import 'widgets/auth_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _navigated = false;
  late final Future<StartDestination> _destination;

  @override
  void initState() {
    super.initState();
    // Setup animations
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    // The destination (a Firestore read) resolves while the splash plays,
    // instead of starting only after it.
    _destination = FirebaseAuth.instance
        .authStateChanges()
        .first
        .then((_) => AuthRouter.resolveDestination());
    Future.delayed(const Duration(seconds: 2), _checkAuthAndNavigate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    // Reduced motion: show the final frame.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Guard stops a double push.
  Future<void> _checkAuthAndNavigate() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    final destination = await _destination;
    if (!mounted) return;
    AuthRouter.routeTo(context, destination);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: Starfield()),
          // Soft halo behind the brand mark.
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.brandPurple.withOpacity(0.28),
                    AppColors.brandPurple.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: Lottie.asset(
                          AppAssets.starAnimation,
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                          animate: !MediaQuery.disableAnimationsOf(context),
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const BrandHeader(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: SafeArea(top: false, child: Center(child: LoadingDots())),
          ),
        ],
      ),
    );
  }
}
