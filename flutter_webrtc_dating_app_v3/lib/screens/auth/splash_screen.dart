import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
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

    _controller.forward();

    // Auto navigate after 2 seconds
    Future.delayed(const Duration(seconds: 2), _checkAuthAndNavigate);
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
    await AuthRouter.routeCurrentUser(context);
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
                  child: const BrandHeader(),
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
