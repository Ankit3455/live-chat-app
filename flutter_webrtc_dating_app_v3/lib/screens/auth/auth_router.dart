import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/session_service.dart';
import '../home/home_screen.dart';
import '../questionnaire/post_signup_questions_screen.dart';
import '../questionnaire/avatar_intro_screen.dart';
import 'age_gate_screen.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

/// Maps SessionService's routing decision to a screen. Used by splash, login,
/// signup and the setup screens so every entry point routes the same way.
class AuthRouter {
  AuthRouter._();

  static Widget screenFor(StartDestination destination) {
    switch (destination) {
      case StartDestination.login:
        return const LoginScreen();
      case StartDestination.profileSetup:
        return const AgeGateScreen();
      case StartDestination.underage:
        return const AgeGateScreen(blocked: true);
      case StartDestination.verifyEmail:
        return const VerifyEmailScreen();
      case StartDestination.questionnaire:
        return const AvatarIntroScreen();
      case StartDestination.postSignup:
        return const PostSignupQuestionsScreen();
      case StartDestination.home:
        return const HomeScreen();
    }
  }

  /// Resolves the destination for the current user and makes it the root.
  static Future<void> routeCurrentUser(BuildContext context) async {
    StartDestination destination;
    try {
      destination = await SessionService.instance.resolveStartDestination();
    } catch (_) {
      destination = FirebaseAuth.instance.currentUser == null
          ? StartDestination.login
          : StartDestination.home;
    }
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screenFor(destination)),
      (_) => false,
    );
  }

  static Future<void> signOutToLogin(BuildContext context) async {
    await SessionService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}
