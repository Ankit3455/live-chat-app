// lib/screens/profile/avatar_loading_screen.dart
import 'package:flutter/material.dart';

class AvatarLoadingScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const AvatarLoadingScreen({
    super.key,
    this.title = '🎨 Creating your unique avatar…',
    this.subtitle = 'We’re styling it from your answers. Just a moment.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E2E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                SizedBox(height: 20),
                Text(
                  '🎨 Creating your unique avatar…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'We’re styling it from your answers. Just a moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
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
