// lib/screens/profile/avatar_loading_screen.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AvatarLoadingScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const AvatarLoadingScreen({
    super.key,
    this.title = 'Creating your avatar…',
    this.subtitle = 'We’re styling it from your answers. Just a moment.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
